//
//  ContactService.swift
//  Nudge
//
//  Contact resolution pipeline:
//  1. ContactResolver — searches CNContactStore to resolve names → phone/email
//  2. ContactPickerView — fallback UI when auto-resolution fails
//  3. ContactHelper — utility to pick the right target for an action type
//

import SwiftUI
import ContactsUI
import Contacts
import os

// MARK: - Contact Resolver

/// On-device contact name resolution. Searches the user's Contacts to resolve
/// an AI-detected contact name (e.g. "Sarah", "the dentist") into a phone number or email.
/// Fully offline — uses CNContactStore with no network calls.
@MainActor
final class ContactResolver {
    
    static let shared = ContactResolver()
    
    private let store = CNContactStore()
    
    /// Current authorization status for Contacts access.
    var isAuthorized: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    
    /// Request Contacts access. Returns true if authorized.
    func requestAccess() async -> Bool {
        guard !isAuthorized else { return true }
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            Log.services.warning("Contacts access request failed: \(error, privacy: .public)")
            return false
        }
    }
    
    // MARK: - Name Resolution
    
    /// Search contacts for a name and return the best match with phone and email.
    /// Returns nil if no match found, contacts access denied, or name is empty.
    func resolve(name: String) async -> ResolvedContact? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Request access if needed
        guard await requestAccess() else { return nil }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]
        
        // Try exact name match first
        if let match = searchContacts(query: trimmed, keys: keysToFetch) {
            return match
        }
        
        // Try individual words (e.g. "Dr. Chen" → "Chen")
        let words = trimmed.split(separator: " ").map(String.init)
        for word in words.reversed() { // Try last name first
            let cleaned = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            guard cleaned.count >= 2 else { continue }
            if let match = searchContacts(query: cleaned, keys: keysToFetch) {
                return match
            }
        }
        
        return nil
    }
    
    /// Resolve a contact name and return the appropriate action target for the given action type.
    func resolveActionTarget(name: String, for actionType: ActionType) async -> (target: String?, resolvedName: String?) {
        guard let resolved = await resolve(name: name) else { return (nil, nil) }
        let target = ContactHelper.actionTarget(phone: resolved.phone, email: resolved.email, for: actionType)
        return (target, resolved.fullName)
    }
    
    // MARK: - Private
    
    private func searchContacts(query: String, keys: [CNKeyDescriptor]) -> ResolvedContact? {
        let predicate = CNContact.predicateForContacts(matchingName: query)
        do {
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
            guard let best = contacts.first else { return nil }
            
            let fullName = CNContactFormatter.string(from: best, style: .fullName) ?? query
            let phone = best.phoneNumbers.first?.value.stringValue
            let email = best.emailAddresses.first?.value as String?
            
            // Must have at least a phone or email to be useful
            guard phone != nil || email != nil else { return nil }
            
            return ResolvedContact(fullName: fullName, phone: phone, email: email)
        } catch {
            Log.services.warning("Contact search failed: \(error, privacy: .public)")
            return nil
        }
    }
}

// MARK: - Resolved Contact

/// Result of a contact name resolution — the resolved name, phone, and email.
struct ResolvedContact {
    let fullName: String
    let phone: String?
    let email: String?
}

// MARK: - Contact Picker View

/// SwiftUI wrapper for CNContactPickerViewController.
/// Fallback UI when ContactResolver can't auto-resolve a name.
struct ContactPickerView: UIViewControllerRepresentable {
    
    /// Called with (name, phoneNumber, email) when a contact is selected.
    var onContactSelected: (_ name: String, _ phone: String?, _ email: String?) -> Void
    var onCancelled: () -> Void = {}
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey
        ]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onContactSelected: onContactSelected,
            onCancelled: onCancelled
        )
    }
    
    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onContactSelected: (_ name: String, _ phone: String?, _ email: String?) -> Void
        let onCancelled: () -> Void
        
        init(
            onContactSelected: @escaping (_ name: String, _ phone: String?, _ email: String?) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.onContactSelected = onContactSelected
            self.onCancelled = onCancelled
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "Unknown"
            let phone = contact.phoneNumbers.first?.value.stringValue
            let email = contact.emailAddresses.first?.value as String?
            onContactSelected(name, phone, email)
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancelled()
        }
    }
}

// MARK: - Contact Helpers

enum ContactHelper {
    
    /// Extract the best action target from a contact based on the desired action type.
    static func actionTarget(
        phone: String?,
        email: String?,
        for actionType: ActionType
    ) -> String? {
        switch actionType {
        case .call, .text:
            return phone
        case .email:
            return email
        case .openLink, .search, .navigate, .addToCalendar, .setAlarm:
            return nil
        }
    }
}
