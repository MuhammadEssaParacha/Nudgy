//
//  RemindersImportService.swift
//  Nudge
//
//  Imports incomplete reminders from Apple Reminders as NudgeItems.
//  One-time import per list — users pick which list to import from.
//
//  Privacy: Requests read-only access to Reminders.
//  Imported items become regular NudgeItems (not synced back to Reminders).
//

import EventKit
import SwiftData
import SwiftUI
import os

@MainActor @Observable
final class RemindersImportService {
    
    static let shared = RemindersImportService()
    
    private let eventStore = EKEventStore()
    
    var isAuthorized: Bool = false
    var availableLists: [ReminderList] = []
    var isImporting: Bool = false
    var lastImportCount: Int = 0
    
    private init() {
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        isAuthorized = (status == .fullAccess)
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            isAuthorized = granted
            if granted {
                fetchLists()
            }
            return granted
        } catch {
            Log.services.error("Reminders access error: \(error, privacy: .public)")
            isAuthorized = false
            return false
        }
    }
    
    // MARK: - Fetch Lists
    
    func fetchLists() {
        guard isAuthorized else { return }
        
        let calendars = eventStore.calendars(for: .reminder)
        availableLists = calendars.map { calendar in
            ReminderList(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                color: UIColor(cgColor: calendar.cgColor).reminderHexString,
                count: 0
            )
        }
        
        // Fetch counts in background
        for (index, list) in availableLists.enumerated() {
            guard let calendar = calendars.first(where: { $0.calendarIdentifier == list.id }) else { continue }
            let predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: [calendar]
            )
            eventStore.fetchReminders(matching: predicate) { [weak self] reminders in
                Task { @MainActor in
                    guard let self, index < self.availableLists.count else { return }
                    self.availableLists[index].count = reminders?.count ?? 0
                }
            }
        }
    }
    
    // MARK: - Import
    
    /// Import all incomplete reminders from a specific list into NudgeItems.
    /// Returns the number of items imported.
    func importList(
        _ listID: String,
        into context: ModelContext
    ) async -> Int {
        guard isAuthorized else { return 0 }
        
        guard let calendar = eventStore.calendars(for: .reminder)
                .first(where: { $0.calendarIdentifier == listID }) else { return 0 }
        
        isImporting = true
        defer { isImporting = false }
        
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: [calendar]
        )
        
        // Fetch reminders (bridging the completion handler API)
        let reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        let repository = NudgeRepository(modelContext: context)
        var importedCount = 0
        
        for reminder in reminders {
            guard let title = reminder.title, !title.isEmpty else { continue }
            
            // Check for duplicate (same content)
            let existingItems = repository.fetchActiveQueue() + repository.fetchSnoozed()
            let isDuplicate = existingItems.contains { existing in
                existing.content.lowercased() == title.lowercased()
            }
            guard !isDuplicate else { continue }
            
            // Create NudgeItem from reminder
            let item = NudgeItem(content: title, sourceType: .manual)
            
            // Map due date
            if let dueDate = reminder.dueDateComponents,
               let date = Calendar.current.date(from: dueDate) {
                item.dueDate = date
            }
            
            // Map priority (Reminders: 0=none, 1-4=high, 5=medium, 6-9=low)
            switch reminder.priority {
            case 1...4:
                item.sortOrder = 0  // Push to top
            case 5:
                break  // Default sort
            case 6...9:
                item.sortOrder = 999  // Push to bottom
            default:
                break
            }
            
            // Map notes as draft content
            if let notes = reminder.notes, !notes.isEmpty {
                item.aiDraft = notes
            }
            
            context.insert(item)
            importedCount += 1
        }
        
        if importedCount > 0 {
            do {
                try context.save()
                lastImportCount = importedCount
                
                Log.services.info("Imported \(importedCount) reminders from '\(calendar.title)'")
                
                NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
            } catch {
                Log.services.error("Failed to save imported reminders: \(error, privacy: .public)")
                return 0
            }
        }
        
        return importedCount
    }
    
    /// Import all lists at once.
    func importAllLists(into context: ModelContext) async -> Int {
        var total = 0
        for list in availableLists {
            let count = await importList(list.id, into: context)
            total += count
        }
        return total
    }
}

// MARK: - Model

struct ReminderList: Identifiable, Hashable {
    let id: String
    let title: String
    let color: String
    var count: Int
}

// MARK: - UIColor hex helper

private extension UIColor {
    var reminderHexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
