//
//  Routine.swift
//  Nudge
//
//  Reusable task templates that repeat on a schedule.
//  A Routine contains a sequence of steps that auto-generate
//  NudgeItems at the start of each scheduled day.
//
//  Example: "Morning Routine" → wake up, shower, breakfast, meds
//  repeating weekdays at 7:30 AM.
//

import SwiftData
import SwiftUI

// MARK: - Repeat Schedule

/// How often a routine repeats
enum RepeatSchedule: String, Codable, CaseIterable {
    case daily      = "daily"
    case weekdays   = "weekdays"
    case weekends   = "weekends"
    case weekly     = "weekly"
    case custom     = "custom"
    
    var label: String {
        switch self {
        case .daily:    return String(localized: "Every Day")
        case .weekdays: return String(localized: "Weekdays")
        case .weekends: return String(localized: "Weekends")
        case .weekly:   return String(localized: "Weekly")
        case .custom:   return String(localized: "Custom Days")
        }
    }
    
    var icon: String {
        switch self {
        case .daily:    return "arrow.trianglehead.2.counterclockwise"
        case .weekdays: return "briefcase.fill"
        case .weekends: return "sun.max.fill"
        case .weekly:   return "calendar"
        case .custom:   return "calendar.badge.checkmark"
        }
    }
}

// MARK: - Routine Step

/// A single step within a routine (stored as JSON in Routine.stepsJSON)
struct RoutineStep: Codable, Identifiable, Hashable {
    var id: UUID
    var content: String
    var emoji: String?
    var estimatedMinutes: Int?
    var sortOrder: Int
    /// Phase 16: Optional per-step category override (rawValue of TaskCategory)
    var categoryRaw: String?
    
    /// Resolved step category (nil = inherit from routine)
    var category: TaskCategory? {
        get { categoryRaw.flatMap { TaskCategory(rawValue: $0) } }
        set { categoryRaw = newValue?.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        content: String,
        emoji: String? = nil,
        estimatedMinutes: Int? = nil,
        sortOrder: Int = 0,
        categoryRaw: String? = nil
    ) {
        self.id = id
        self.content = content
        self.emoji = emoji
        self.estimatedMinutes = estimatedMinutes
        self.sortOrder = sortOrder
        self.categoryRaw = categoryRaw
    }
}

// MARK: - Routine Model

@Model
final class Routine {
    
    // MARK: Identity
    var id: UUID
    
    // MARK: Content
    
    /// Display name (e.g. "Morning Routine", "Bedtime Wind-Down")
    var name: String
    
    /// Emoji for the routine card
    var emoji: String
    
    /// Optional color hex for the routine card
    var colorHex: String?
    
    /// Optional category association (rawValue of TaskCategory)
    var categoryRaw: String?
    
    /// Resolved category (nil = no category assigned)
    var category: TaskCategory? {
        get { categoryRaw.flatMap { TaskCategory(rawValue: $0) } }
        set {
            categoryRaw = newValue?.rawValue
            if let cat = newValue {
                colorHex = cat.primaryColorHex
            }
        }
    }
    
    // MARK: Schedule
    
    /// Repeat schedule type
    var scheduleRaw: String
    
    /// For .custom schedule: comma-separated weekday numbers (1=Sunday, 2=Monday, etc.)
    var customDaysRaw: String?
    
    /// Time of day to start the routine (hour component used for scheduling)
    var startHour: Int
    var startMinute: Int
    
    // MARK: Steps (JSON-encoded)
    
    /// Steps encoded as JSON string (SwiftData-safe)
    var stepsJSON: String
    
    // MARK: State
    
    /// Whether this routine is active (user can pause routines)
    var isActive: Bool
    
    /// Date this routine was created
    var createdAt: Date
    
    /// Last date tasks were generated from this routine
    var lastGeneratedDate: Date?
    
    // MARK: Init
    
    init(
        name: String,
        emoji: String = "checklist",
        schedule: RepeatSchedule = .daily,
        startHour: Int = 8,
        startMinute: Int = 0,
        steps: [RoutineStep] = [],
        colorHex: String? = nil,
        categoryRaw: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.scheduleRaw = schedule.rawValue
        self.startHour = startHour
        self.startMinute = startMinute
        self.stepsJSON = "[]"
        self.isActive = true
        self.createdAt = Date()
        self.colorHex = colorHex
        self.categoryRaw = categoryRaw
        
        // Encode steps
        if let data = try? JSONEncoder().encode(steps),
           let json = String(data: data, encoding: .utf8) {
            self.stepsJSON = json
        }
    }
    
    // MARK: Computed — Schedule
    
    var schedule: RepeatSchedule {
        get { RepeatSchedule(rawValue: scheduleRaw) ?? .daily }
        set { scheduleRaw = newValue.rawValue }
    }
    
    /// Custom days as an array of weekday numbers (1=Sun, 2=Mon, ..., 7=Sat)
    var customDays: [Int] {
        get {
            customDaysRaw?
                .split(separator: ",")
                .compactMap { Int($0) }
                ?? []
        }
        set {
            customDaysRaw = newValue.map(String.init).joined(separator: ",")
        }
    }
    
    // MARK: Computed — Steps
    
    var steps: [RoutineStep] {
        get {
            guard let data = stepsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([RoutineStep].self, from: data) else {
                return []
            }
            return decoded.sorted { $0.sortOrder < $1.sortOrder }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                stepsJSON = json
            }
        }
    }
    
    /// Total estimated duration of all steps
    var totalEstimatedMinutes: Int {
        steps.compactMap(\.estimatedMinutes).reduce(0, +)
    }
    
    /// Formatted start time string
    var startTimeLabel: String {
        let calendar = Calendar.current
        let components = DateComponents(hour: startHour, minute: startMinute)
        if let date = calendar.date(from: components) {
            return date.formatted(.dateTime.hour().minute())
        }
        return "\(startHour):\(String(format: "%02d", startMinute))"
    }
    
    /// Card accent color
    var color: Color {
        if let hex = colorHex {
            return Color(hex: hex)
        }
        return DesignTokens.accentActive
    }
    
    // MARK: - Schedule Logic
    
    /// Whether this routine should run today
    var shouldRunToday: Bool {
        guard isActive else { return false }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        switch schedule {
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday) // Mon-Fri
        case .weekends:
            return weekday == 1 || weekday == 7 // Sun, Sat
        case .weekly:
            // Run on the same weekday as creation
            let createdWeekday = calendar.component(.weekday, from: createdAt)
            return weekday == createdWeekday
        case .custom:
            return customDays.contains(weekday)
        }
    }
    
    /// Whether tasks have already been generated today
    var hasGeneratedToday: Bool {
        guard let last = lastGeneratedDate else { return false }
        return Calendar.current.isDateInToday(last)
    }
    
    /// Whether this routine needs task generation
    var needsGeneration: Bool {
        shouldRunToday && !hasGeneratedToday
    }
}
