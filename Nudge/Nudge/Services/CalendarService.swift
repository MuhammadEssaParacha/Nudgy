//
//  CalendarService.swift
//  Nudge
//
//  EventKit integration for reading user calendar events
//  and writing NudgeItem tasks as calendar events.
//
//  Privacy: Requests full access to Calendar.
//  Always check authorization before fetching/writing.
//

import EventKit
import SwiftUI
import os

@MainActor @Observable
final class CalendarService {
    
    static let shared = CalendarService()
    
    private let eventStore = EKEventStore()
    
    var isAuthorized: Bool = false
    var todayEvents: [TimelineEntry] = []
    
    private init() {
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = (status == .fullAccess)
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
            if granted {
                fetchTodayEvents()
            }
            return granted
        } catch {
            Log.services.error("Calendar access error: \(error, privacy: .public)")
            isAuthorized = false
            return false
        }
    }
    
    // MARK: - Fetch Events
    
    func fetchTodayEvents() {
        guard isAuthorized else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
        
        todayEvents = events
            .filter { !$0.isAllDay }   // Skip all-day events for timeline
            .map { event in
                let durationMinutes = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
                let calendarColor = event.calendar.cgColor.flatMap { UIColor(cgColor: $0).hexString }
                
                return TimelineEntry(
                    id: UUID(),
                    type: .calendarEvent,
                    title: event.title ?? String(localized: "Calendar Event"),
                    emoji: "📅",
                    startTime: event.startDate,
                    durationMinutes: max(durationMinutes, 15),
                    colorHex: calendarColor,
                    isDone: event.endDate < Date(),
                    nudgeItem: nil
                )
            }
    }
    
    // MARK: - Write Events
    
    /// Create a calendar event from a NudgeItem.
    /// Returns the event identifier on success.
    @discardableResult
    func createEvent(from item: NudgeItem) async -> String? {
        if !isAuthorized {
            let granted = await requestAccess()
            guard granted else { return nil }
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = item.content
        
        // Use due date if available, otherwise default to next hour
        let startDate: Date
        if let dueDate = item.dueDate {
            startDate = dueDate
        } else {
            let calendar = Calendar.current
            let now = Date()
            let nextHour = calendar.date(byAdding: .hour, value: 1, to: now)
            startDate = calendar.date(
                bySetting: .minute, value: 0, of: nextHour ?? now
            ) ?? now
        }
        
        event.startDate = startDate
        
        // Duration from estimated minutes or default 30min
        let duration = TimeInterval((item.estimatedMinutes ?? 30) * 60)
        event.endDate = startDate.addingTimeInterval(duration)
        
        // Add context as notes
        var notes: [String] = []
        if let contact = item.contactName, !contact.isEmpty {
            notes.append(String(localized: "Contact: \(contact)"))
        }
        if let draft = item.aiDraft, !draft.isEmpty {
            notes.append(draft)
        }
        if !notes.isEmpty {
            event.notes = notes.joined(separator: "\n")
        }
        
        // Default calendar
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // 15-min reminder alert
        event.addAlarm(EKAlarm(relativeOffset: -15 * 60))
        
        do {
            try eventStore.save(event, span: .thisEvent)
            Log.services.debug("Created calendar event: \(item.content)")
            return event.eventIdentifier
        } catch {
            Log.services.error("Failed to create calendar event: \(error, privacy: .public)")
            return nil
        }
    }
}

// MARK: - UIColor hex helper

private extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
