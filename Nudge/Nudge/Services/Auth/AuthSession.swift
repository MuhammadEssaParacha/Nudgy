import Foundation
import AuthenticationServices
import CloudKit
import CryptoKit
import os

@MainActor @Observable
final class AuthSession {

    // MARK: - Types

    enum State: Equatable {
        case checking
        case signedOut(reason: SignedOutReason?)
        case signedIn(UserContext)
        
        var isSignedIn: Bool {
            if case .signedIn = self { return true }
            return false
        }
    }

    enum SignedOutReason: Equatable {
        case appleCredentialRevoked
        case emailInvalid
        case emailAlreadyRegistered
        case wrongPassword
    }

    enum AuthMethod: String, Equatable {
        case apple
        case email
    }

    struct UserContext: Equatable {
        /// Stable user identifier — CloudKit record name when available,
        /// otherwise a locally generated UUID stored in Keychain.
        let userID: String
        let displayName: String?
        let email: String?
        let authMethod: AuthMethod
        /// Whether CloudKit sync is available for this user.
        let cloudKitAvailable: Bool
    }

    // MARK: - Keychain keys

    private enum Keys {
        static let appleUserID     = "nudge.appleUserID"
        static let localUserID     = "nudge.localUserID"
        static let authMethod      = "nudge.authMethod"
        static let emailAddress    = "nudge.emailAddress"
        static let emailPassHash   = "nudge.emailPassHash"
        static let displayName     = "nudge.displayName"
    }

    // MARK: - Public state

    private(set) var state: State = .checking

    private var cloudKitManager: CloudKitManager { CloudKitManager.shared }

    // MARK: - Bootstrap

    func bootstrap() {
        Log.auth.debug("AuthSession.bootstrap() called, current state: \(String(describing: self.state))")
        Task { await restoreSession() }
    }

    /// Try to restore a previous session — Apple Sign In or email.
    func restoreSession() async {
        let method = (try? KeychainService.getString(forKey: Keys.authMethod)) ?? nil
        #if DEBUG
        Log.auth.debug("AuthSession.restoreSession() — stored method: \(method ?? "nil")")
        
        // DEBUG bypass: nuke all auth Keychain entries so the intro shows fresh
        if ProcessInfo.processInfo.arguments.contains("-resetAuth") {
            Log.auth.debug("Resetting auth — clearing all Keychain entries")
            KeychainService.delete(forKey: Keys.appleUserID)
            KeychainService.delete(forKey: Keys.localUserID)
            KeychainService.delete(forKey: Keys.authMethod)
            KeychainService.delete(forKey: Keys.emailAddress)
            KeychainService.delete(forKey: Keys.emailPassHash)
            KeychainService.delete(forKey: Keys.displayName)
            state = .signedOut(reason: nil)
            return
        }
        
        // DEBUG bypass: skip auth for simulator testing
        if ProcessInfo.processInfo.arguments.contains("-skipAuth") {
            Log.auth.debug("Skipping auth — creating test user")
            state = .signedIn(UserContext(
                userID: "debug-test-user",
                displayName: "Test User",
                email: "test@nudge.app",
                authMethod: .email,
                cloudKitAvailable: false
            ))
            return
        }
        #endif

        switch method {
        case AuthMethod.apple.rawValue:
            await restoreAppleSession()

        case AuthMethod.email.rawValue:
            restoreEmailSession()

        default:
            // No stored session
            Log.auth.debug("AuthSession: no stored method → .signedOut")
            state = .signedOut(reason: nil)
        }
    }

    // MARK: - Apple Sign In

    func completeAppleSignIn(with credential: ASAuthorizationAppleIDCredential) async {
        Log.auth.debug("completeAppleSignIn: start — user=\(credential.user.prefix(8))...")
        // Persist Apple user ID
        if !credential.user.isEmpty {
            do {
                try KeychainService.setString(credential.user, forKey: Keys.appleUserID)
            } catch {
                Log.auth.error("Failed to save Apple user ID to Keychain: \(error, privacy: .public)")
            }
        }
        do {
            try KeychainService.setString(AuthMethod.apple.rawValue, forKey: Keys.authMethod)
        } catch {
            Log.auth.error("Failed to save auth method to Keychain: \(error, privacy: .public)")
        }

        let nameComponents = credential.fullName
        let displayName = [nameComponents?.givenName, nameComponents?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let finalName = displayName.isEmpty ? nil : displayName
        if let finalName {
            do {
                try KeychainService.setString(finalName, forKey: Keys.displayName)
            } catch {
                Log.auth.error("Failed to save display name to Keychain: \(error, privacy: .public)")
            }
        }

        let email = credential.email
        if let email {
            do {
                try KeychainService.setString(email, forKey: Keys.emailAddress)
            } catch {
                Log.auth.error("Failed to save email to Keychain: \(error, privacy: .public)")
            }
        }

        // Try CloudKit if available — otherwise use Apple user ID as local identifier
        Log.auth.debug("completeAppleSignIn: resolving userID + cloudKit...")
        let userID = await resolveUserID(fallback: credential.user)
        let cloudKitAvailable = await isCloudKitAvailable()
        Log.auth.debug("completeAppleSignIn: userID=\(userID.prefix(8))..., ck=\(cloudKitAvailable)")

        if cloudKitAvailable {
            // Best-effort profile sync
            Log.auth.debug("completeAppleSignIn: syncing CK profile")
            _ = try? await cloudKitManager.ensureUserProfile(displayName: finalName)
        }
        Log.auth.debug("completeAppleSignIn: setting state → .signedIn")

        state = .signedIn(UserContext(
            userID: userID,
            displayName: finalName ?? storedDisplayName(),
            email: email ?? storedEmail(),
            authMethod: .apple,
            cloudKitAvailable: cloudKitAvailable
        ))
    }

    // MARK: - Email Sign Up

    enum EmailAuthError: LocalizedError {
        case invalidEmail
        case weakPassword
        case alreadyRegistered
        case wrongPassword
        case notRegistered

        var errorDescription: String? {
            switch self {
            case .invalidEmail:       return String(localized: "Please enter a valid email address.")
            case .weakPassword:       return String(localized: "Password must be at least 6 characters.")
            case .alreadyRegistered:  return String(localized: "An account with this email already exists. Please sign in.")
            case .wrongPassword:      return String(localized: "Incorrect password. Please try again.")
            case .notRegistered:      return String(localized: "No account found with this email. Please sign up first.")
            }
        }
    }

    /// Create a new local account with email + password.
    func signUpWithEmail(_ email: String, password: String, name: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValidEmail(trimmedEmail) else { throw EmailAuthError.invalidEmail }
        guard password.count >= 6 else { throw EmailAuthError.weakPassword }

        // Check if email already registered
        if let existingEmail = try? KeychainService.getString(forKey: Keys.emailAddress),
           existingEmail == trimmedEmail,
           (try? KeychainService.getString(forKey: Keys.emailPassHash)) != nil {
            throw EmailAuthError.alreadyRegistered
        }

        // Hash password using SHA256 (local-only, not transmitted)
        let passHash = hashPassword(password)

        // Generate a stable local user ID
        let localUserID = UUID().uuidString

        // Store everything in Keychain
        try KeychainService.setString(trimmedEmail, forKey: Keys.emailAddress)
        try KeychainService.setString(passHash, forKey: Keys.emailPassHash)
        try KeychainService.setString(localUserID, forKey: Keys.localUserID)
        try KeychainService.setString(AuthMethod.email.rawValue, forKey: Keys.authMethod)
        if !trimmedName.isEmpty {
            try KeychainService.setString(trimmedName, forKey: Keys.displayName)
        }

        let cloudKitAvailable = await isCloudKitAvailable()
        let userID = await resolveUserID(fallback: localUserID)

        if cloudKitAvailable {
            _ = try? await cloudKitManager.ensureUserProfile(displayName: trimmedName.isEmpty ? nil : trimmedName)
        }

        state = .signedIn(UserContext(
            userID: userID,
            displayName: trimmedName.isEmpty ? nil : trimmedName,
            email: trimmedEmail,
            authMethod: .email,
            cloudKitAvailable: cloudKitAvailable
        ))
    }

    /// Sign in with an existing email + password.
    func signInWithEmail(_ email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard isValidEmail(trimmedEmail) else { throw EmailAuthError.invalidEmail }

        // Verify credentials exist
        guard let storedEmail = try? KeychainService.getString(forKey: Keys.emailAddress),
              storedEmail == trimmedEmail else {
            throw EmailAuthError.notRegistered
        }

        guard let storedHash = try? KeychainService.getString(forKey: Keys.emailPassHash) else {
            throw EmailAuthError.notRegistered
        }

        let inputHash = hashPassword(password)
        guard inputHash == storedHash else {
            throw EmailAuthError.wrongPassword
        }

        // Credentials match — sign in
        try? KeychainService.setString(AuthMethod.email.rawValue, forKey: Keys.authMethod)

        let localUserID = (try? KeychainService.getString(forKey: Keys.localUserID)) ?? UUID().uuidString
        let cloudKitAvailable = await isCloudKitAvailable()
        let userID = await resolveUserID(fallback: localUserID)

        let displayName = storedDisplayName()

        state = .signedIn(UserContext(
            userID: userID,
            displayName: displayName,
            email: trimmedEmail,
            authMethod: .email,
            cloudKitAvailable: cloudKitAvailable
        ))
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainService.delete(forKey: Keys.appleUserID)
        KeychainService.delete(forKey: Keys.authMethod)
        // Keep email/pass/localUserID so user can sign back in
        state = .signedOut(reason: nil)
    }

    // MARK: - Private — Session Restore

    private func restoreAppleSession() async {
        guard let storedAppleUserID = try? KeychainService.getString(forKey: Keys.appleUserID) else {
            state = .signedOut(reason: nil)
            return
        }

        let provider = ASAuthorizationAppleIDProvider()
        let credentialState = await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: storedAppleUserID) { s, _ in
                continuation.resume(returning: s)
            }
        }

        switch credentialState {
        case .authorized:
            let cloudKitAvailable = await isCloudKitAvailable()
            let userID = await resolveUserID(fallback: storedAppleUserID)

            state = .signedIn(UserContext(
                userID: userID,
                displayName: storedDisplayName(),
                email: storedEmail(),
                authMethod: .apple,
                cloudKitAvailable: cloudKitAvailable
            ))

        case .revoked, .notFound:
            KeychainService.delete(forKey: Keys.appleUserID)
            KeychainService.delete(forKey: Keys.authMethod)
            state = .signedOut(reason: .appleCredentialRevoked)

        default:
            state = .signedOut(reason: nil)
        }
    }

    private func restoreEmailSession() {
        guard let email = try? KeychainService.getString(forKey: Keys.emailAddress),
              let _ = try? KeychainService.getString(forKey: Keys.emailPassHash) else {
            state = .signedOut(reason: nil)
            return
        }

        let localUserID = (try? KeychainService.getString(forKey: Keys.localUserID)) ?? UUID().uuidString

        state = .signedIn(UserContext(
            userID: localUserID,
            displayName: storedDisplayName(),
            email: email,
            authMethod: .email,
            cloudKitAvailable: false // Will be updated async
        ))

        // Check CloudKit in background — update context if available
        Task {
            let ckAvailable = await isCloudKitAvailable()
            let resolvedID = await resolveUserID(fallback: localUserID)
            if ckAvailable || resolvedID != localUserID {
                state = .signedIn(UserContext(
                    userID: resolvedID,
                    displayName: storedDisplayName(),
                    email: email,
                    authMethod: .email,
                    cloudKitAvailable: ckAvailable
                ))
            }
        }
    }

    // MARK: - Private Helpers

    private func isCloudKitAvailable() async -> Bool {
        let status = await cloudKitManager.accountStatus()
        return status == .available
    }

    /// Prefer CloudKit user record name for data scoping; fall back to local ID.
    private func resolveUserID(fallback: String) async -> String {
        do {
            let recordID = try await cloudKitManager.fetchUserRecordID()
            return recordID.recordName
        } catch {
            Log.auth.info("[Auth] CloudKit user ID unavailable, using local fallback: \(error, privacy: .public)")
            return fallback
        }
    }

    private func storedDisplayName() -> String? {
        (try? KeychainService.getString(forKey: Keys.displayName)) ?? nil
    }

    private func storedEmail() -> String? {
        (try? KeychainService.getString(forKey: Keys.emailAddress)) ?? nil
    }

    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}
