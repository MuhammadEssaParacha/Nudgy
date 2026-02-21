//
//  NudgeFocusFilter.swift
//  Nudge
//
//  SetFocusFilterIntent — integrates with iOS Focus modes.
//  When a Focus is active, Nudge can filter visible tasks by energy level.
//
//  Example: "Work" focus → show only "high energy" tasks
//           "Evening" focus → show only "low energy" tasks
//           "Personal" focus → show all
//
//  Users configure this in Settings → Focus → [Focus Mode] → Focus Filters → Nudge.
//

import AppIntents

/// Focus Filter for Nudge — filters tasks by energy level and category when a Focus mode is active.
struct NudgeFocusFilter: SetFocusFilterIntent {
    
    static var title: LocalizedStringResource = "Set Nudge Filter"
    static var description: IntentDescription = "Filter which tasks Nudge shows during this Focus."
    
    var displayRepresentation: DisplayRepresentation {
        var parts: [String] = []
        
        switch energyFilter {
        case .all:    break
        case .high:   parts.append("High energy")
        case .medium: parts.append("Medium energy")
        case .low:    parts.append("Low energy")
        }
        
        if !categories.isEmpty {
            let names = categories.map { $0.displayName }
            parts.append(names.joined(separator: ", "))
        }
        
        let subtitle = parts.isEmpty ? "Showing all tasks" : parts.joined(separator: " · ")
        return DisplayRepresentation(
            title: "Nudge Filter",
            subtitle: "\(subtitle)"
        )
    }
    
    /// The energy level filter to apply during this Focus.
    @Parameter(title: "Energy Level", default: .all)
    var energyFilter: FocusEnergyFilter
    
    /// Phase 10: Category filter — only show tasks in these categories.
    @Parameter(title: "Categories", default: [])
    var categories: [FocusCategoryGroup]
    
    /// Whether to suppress notifications during this Focus.
    @Parameter(title: "Silence Nudge notifications", default: false)
    var silenceNotifications: Bool
    
    func perform() async throws -> some IntentResult {
        // Store the active filter in shared UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.essaparacha.nudge")
        defaults?.set(energyFilter.rawValue, forKey: "focusFilter_energyLevel")
        defaults?.set(silenceNotifications, forKey: "focusFilter_silenceNotifications")
        
        // Phase 10: Store category filter
        if categories.isEmpty {
            defaults?.removeObject(forKey: "focusFilter_categories")
        } else {
            let rawValues = categories.flatMap { $0.categoryRawValues }
            defaults?.set(rawValues.joined(separator: ","), forKey: "focusFilter_categories")
        }
        
        // Post notification so the app can react
        Task { @MainActor in
            NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        }
        
        return .result()
    }
}

/// Energy level filter options for Focus modes.
enum FocusEnergyFilter: String, AppEnum {
    case all = "all"
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Energy Level"
    
    static var caseDisplayRepresentations: [FocusEnergyFilter: DisplayRepresentation] = [
        .all: DisplayRepresentation(title: "All Tasks", subtitle: "Show everything"),
        .high: DisplayRepresentation(title: "High Energy", subtitle: "Deep work, meetings, calls"),
        .medium: DisplayRepresentation(title: "Medium Energy", subtitle: "Emails, errands, reading"),
        .low: DisplayRepresentation(title: "Low Energy", subtitle: "Quick wins, chores, browsing")
    ]
}

/// Phase 10: Simplified category groups for Focus mode filtering.
/// Grouped to avoid overwhelming the Focus settings UI with 20 options.
enum FocusCategoryGroup: String, AppEnum {
    case work = "work"
    case personal = "personal"
    case health = "health"
    case social = "social"
    case errands = "errands"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Task Category"
    
    static var caseDisplayRepresentations: [FocusCategoryGroup: DisplayRepresentation] = [
        .work: DisplayRepresentation(title: "Work & Study", subtitle: "💼 work, homework, email, finance"),
        .personal: DisplayRepresentation(title: "Personal", subtitle: "🏠 cleaning, cooking, maintenance, creative"),
        .health: DisplayRepresentation(title: "Health & Wellness", subtitle: "💪 exercise, health, self-care"),
        .social: DisplayRepresentation(title: "Social & Communication", subtitle: "💬 call, text, social"),
        .errands: DisplayRepresentation(title: "Errands & Shopping", subtitle: "🛒 errand, shopping, appointment")
    ]
    
    var displayName: String {
        switch self {
        case .work: return "Work & Study"
        case .personal: return "Personal"
        case .health: return "Health"
        case .social: return "Social"
        case .errands: return "Errands"
        }
    }
    
    /// Map group to underlying TaskCategory raw values.
    var categoryRawValues: [String] {
        switch self {
        case .work: return ["work", "homework", "email", "finance", "link"]
        case .personal: return ["cleaning", "cooking", "maintenance", "creative", "alarm", "general"]
        case .health: return ["exercise", "health", "selfCare"]
        case .social: return ["call", "text", "social"]
        case .errands: return ["errand", "shopping", "appointment"]
        }
    }
}
