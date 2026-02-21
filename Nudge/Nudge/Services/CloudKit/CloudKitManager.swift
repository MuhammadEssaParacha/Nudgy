import Foundation
import CloudKit
import os

@MainActor
final class CloudKitManager {

    static let shared = CloudKitManager()

    enum CloudKitError: Error {
        case accountUnavailable
        case missingUserRecordID
        case containerUnavailable
    }

    /// Lazily-created container — only created when actually needed,
    /// never during app init. `CKContainer` init can trap if the
    /// provisioning profile doesn't include CloudKit entitlements.
    private var _container: CKContainer?
    private var _database: CKDatabase?
    private var didSetup = false

    private init() { }

    // MARK: - Lazy setup

    /// Returns the container if CloudKit is properly configured, nil otherwise.
    private func resolvedContainer() -> CKContainer? {
        if didSetup { return _container }
        didSetup = true

        // Guard: check that the CloudKit entitlement is present in the
        // embedded provisioning profile / signed entitlements. Without this,
        // CKContainer.default() will trap at runtime.
        guard hasCloudKitEntitlement() else {
            Log.sync.warning("CloudKitManager: CloudKit entitlement missing — skipping")
            return nil
        }

        let ck = CKContainer.default()
        _container = ck
        _database = ck.privateCloudDatabase
        return ck
    }

    /// Checks whether the app was signed with CloudKit entitlements.
    private func hasCloudKitEntitlement() -> Bool {
        // On device, the embedded.mobileprovision contains the entitlements.
        // A simpler check: verify the entitlements plist key was embedded
        // into the binary by the build system (via CODE_SIGN_ENTITLEMENTS).
        guard let provisionURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            // Simulator doesn't have embedded.mobileprovision — allow CloudKit there.
            #if targetEnvironment(simulator)
            return true
            #else
            return false
            #endif
        }
        // If the file exists, the provisioning profile is embedded.
        // Check if it contains our iCloud container identifier.
        if let data = try? Data(contentsOf: provisionURL),
           let str = String(data: data, encoding: .ascii),
           str.contains("com.apple.developer.icloud-services") {
            return true
        }
        return false
    }

    private func resolvedDatabase() -> CKDatabase? {
        _ = resolvedContainer()
        return _database
    }

    func accountStatus() async -> CKAccountStatus {
        guard let container = resolvedContainer() else { return .noAccount }
        return await withCheckedContinuation { continuation in
            container.accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }
    }

    func fetchUserRecordID() async throws -> CKRecord.ID {
        guard let container = resolvedContainer() else { throw CloudKitError.containerUnavailable }
        return try await withCheckedThrowingContinuation { continuation in
            container.fetchUserRecordID { recordID, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let recordID else {
                    continuation.resume(throwing: CloudKitError.missingUserRecordID)
                    return
                }
                continuation.resume(returning: recordID)
            }
        }
    }

    /// Creates (or fetches) a per-user profile record in the private DB.
    /// Returns the displayName that should be used.
    func ensureUserProfile(displayName: String?) async throws -> String? {
        guard let database = resolvedDatabase() else { throw CloudKitError.containerUnavailable }
        let recordID = CKRecord.ID(recordName: "UserProfile")

        do {
            let record = try await database.record(for: recordID)
            // Update display name if we have a new one and profile doesn't.
            if let displayName, (record["displayName"] as? String)?.isEmpty != false {
                record["displayName"] = displayName as CKRecordValue
                record["updatedAt"] = Date() as CKRecordValue
                _ = try await database.save(record)
                return displayName
            }
            return record["displayName"] as? String
        } catch {
            // Create new profile.
            let record = CKRecord(recordType: "UserProfile", recordID: recordID)
            if let displayName { record["displayName"] = displayName as CKRecordValue }
            record["createdAt"] = Date() as CKRecordValue
            record["updatedAt"] = Date() as CKRecordValue
            _ = try await database.save(record)
            return displayName
        }
    }

    func privateDatabase() -> CKDatabase? { resolvedDatabase() }
}

private extension CKDatabase {
    func record(for id: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            fetch(withRecordID: id) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let record else {
                    continuation.resume(throwing: CKError(.unknownItem))
                    return
                }
                continuation.resume(returning: record)
            }
        }
    }

    func save(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            save(record) { saved, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: saved ?? record)
            }
        }
    }
}
