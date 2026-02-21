//
//  NudgeIntents.swift
//  Nudge
//
//  App Intents for Nudge — powers Shortcuts, Spotlight,
//  Action Button, and Control Center integration.
//
//  Available intents:
//    • AddTaskIntent      — Quick-add a task from anywhere
//    • MarkDoneIntent     — Complete a specific task
//    • SnoozeTaskIntent   — Snooze a task for a chosen duration
//    • GetNextTaskIntent  — Get the next task in your queue
//    • GetActiveCount     — Get how many tasks are active
//    • OpenNudgeIntent    — Open the app to a specific screen
//

import AppIntents
import SwiftData
import SwiftUI
import UIKit
import Foundation

// MARK: - Add Task Intent

/// Add a new task to Nudge from Shortcuts, Spotlight, or the Action Button.
/// This is the most important intent — enables "capture from anywhere".
struct AddTaskIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Add Nudge"
    static var description: IntentDescription = "Quickly add a new task to your Nudge queue."
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "What do you need to do?")
    var content: String
    
    @Parameter(title: "Category", default: nil)
    var category: TaskCategoryAppEnum?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$content) to Nudge")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NudgeTaskEntity> & ProvidesDialog {
        guard let container = IntentModelAccess.makeContainer() else {
            throw NudgeIntentError.notSignedIn
        }
        
        let context = container.mainContext
        let repository = NudgeRepository(modelContext: context)
        let resolvedCat = category?.toTaskCategory
        let item = repository.createManualWithDetails(
            content: content,
            emoji: nil,
            actionType: nil,
            contactName: nil,
            category: resolvedCat
        )
        
        let entity = NudgeTaskEntity(from: item)
        
        // Notify the main app to refresh
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        
        return .result(
            value: entity,
            dialog: "Added to your nudges."
        )
    }
}

// MARK: - Mark Done Intent

/// Complete a task from Shortcuts or other system surfaces.
struct MarkDoneIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Complete Nudge"
    static var description: IntentDescription = "Mark a task as done."
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task")
    var task: NudgeTaskEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$task) as done")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = IntentModelAccess.makeContainer() else {
            throw NudgeIntentError.notSignedIn
        }
        
        let context = container.mainContext
        guard let uuid = UUID(uuidString: task.id) else {
            throw NudgeIntentError.taskNotFound
        }
        
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: #Predicate { $0.statusRaw == "active" }
        )
        
        let items = (try? context.fetch(descriptor)) ?? []
        guard let item = items.first(where: { $0.id == uuid }) else {
            throw NudgeIntentError.taskNotFound
        }
        
        let repository = NudgeRepository(modelContext: context)
        repository.markDone(item)
        
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        
        return .result(dialog: "Done! \(task.title) completed.")
    }
}

// MARK: - Snooze Task Intent

/// Snooze a task from Shortcuts — choose duration.
struct SnoozeTaskIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Snooze Nudge"
    static var description: IntentDescription = "Snooze a task for later."
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task")
    var task: NudgeTaskEntity
    
    @Parameter(title: "Duration", default: .twoHours)
    var duration: SnoozeDuration
    
    static var parameterSummary: some ParameterSummary {
        Summary("Snooze \(\.$task) for \(\.$duration)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = IntentModelAccess.makeContainer() else {
            throw NudgeIntentError.notSignedIn
        }
        
        let context = container.mainContext
        guard let uuid = UUID(uuidString: task.id) else {
            throw NudgeIntentError.taskNotFound
        }
        
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: #Predicate { $0.statusRaw == "active" }
        )
        
        let items = (try? context.fetch(descriptor)) ?? []
        guard let item = items.first(where: { $0.id == uuid }) else {
            throw NudgeIntentError.taskNotFound
        }
        
        let repository = NudgeRepository(modelContext: context)
        repository.snooze(item, until: duration.targetDate)
        
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        
        return .result(dialog: "Snoozed until \(duration.targetDate.formatted(.dateTime.hour().minute())).")
    }
}

// MARK: - Get Next Task Intent

/// Get the next task in queue — great for Action Button or automation triggers.
struct GetNextTaskIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Get Next Nudge"
    static var description: IntentDescription = "Get the next task in your Nudge queue."
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NudgeTaskEntity?> & ProvidesDialog {
        guard let container = IntentModelAccess.makeContainer() else {
            throw NudgeIntentError.notSignedIn
        }
        
        let context = container.mainContext
        let repository = NudgeRepository(modelContext: context)
        
        guard let nextItem = repository.fetchNextItem() else {
            return .result(
                value: nil,
                dialog: "Your queue is clear — nothing pending."
            )
        }
        
        let entity = NudgeTaskEntity(from: nextItem)
        return .result(
            value: entity,
            dialog: "\(nextItem.content)"
        )
    }
}

// MARK: - Get Active Count Intent

/// Returns how many active tasks you have — useful in automations.
struct GetActiveCountIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Count Active Nudges"
    static var description: IntentDescription = "Get the number of active tasks in your queue."
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let container = IntentModelAccess.makeContainer() else {
            throw NudgeIntentError.notSignedIn
        }
        
        let context = container.mainContext
        let repository = NudgeRepository(modelContext: context)
        let count = repository.activeCount()
        
        if count == 0 {
            return .result(value: 0, dialog: "Queue is clear!")
        } else {
            return .result(value: count, dialog: "You have \(count) active nudge\(count == 1 ? "" : "s").")
        }
    }
}

// MARK: - Open Nudge Intent

/// Opens the Nudge app to a specific screen — useful for Shortcuts and Control Center.
struct OpenNudgeIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Open Nudge"
    static var description: IntentDescription = "Open Nudge to a specific screen."
    
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Screen", default: .nudges)
    var screen: NudgeScreen
    
    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$screen)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Use the deep link URL scheme to navigate
        if let url = URL(string: screen.deepLinkURL) {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

// MARK: - Supporting Types

/// Snooze duration choices for the SnoozeTaskIntent.
enum SnoozeDuration: String, AppEnum {
    case twoHours = "2_hours"
    case tonight = "tonight"
    case tomorrow = "tomorrow"
    case nextWeek = "next_week"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Snooze Duration"
    
    static var caseDisplayRepresentations: [SnoozeDuration: DisplayRepresentation] = [
        .twoHours: "2 Hours",
        .tonight: "Tonight",
        .tomorrow: "Tomorrow",
        .nextWeek: "Next Week"
    ]
    
    var targetDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .twoHours:
            return cal.date(byAdding: .hour, value: 2, to: now) ?? now
        case .tonight:
            return cal.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        case .tomorrow:
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        case .nextWeek:
            let nextWeek = cal.date(byAdding: .day, value: 7, to: now) ?? now
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek) ?? nextWeek
        }
    }
}

/// Screen choices for the OpenNudgeIntent.
enum NudgeScreen: String, AppEnum {
    case nudges = "nudges"
    case chat = "chat"
    case brainDump = "brain_dump"
    case quickAdd = "quick_add"
    case settings = "settings"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Screen"
    
    static var caseDisplayRepresentations: [NudgeScreen: DisplayRepresentation] = [
        .nudges: "Nudges",
        .chat: "Chat with Nudgy",
        .brainDump: "Unload",
        .quickAdd: "Quick Add",
        .settings: "Settings"
    ]
    
    var deepLinkURL: String {
        switch self {
        case .nudges:    return "nudge://allItems"
        case .chat:      return "nudge://chat"
        case .brainDump: return "nudge://brainDump"
        case .quickAdd:  return "nudge://quickAdd"
        case .settings:  return "nudge://settings"
        }
    }
}

// MARK: - Errors

enum NudgeIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notSignedIn
    case taskNotFound
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notSignedIn:
            return "Please sign in to Nudge first."
        case .taskNotFound:
            return "That task couldn't be found."
        }
    }
}

// MARK: - Task Category App Enum

/// AppEnum mirroring TaskCategory for Shortcuts/Siri parameter resolution.
enum TaskCategoryAppEnum: String, AppEnum {
    case call, text, email, link
    case homework, cooking, alarm, exercise
    case cleaning, shopping, appointment, finance
    case health, creative, errand, selfCare
    case work, social, maintenance, general
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    
    static var caseDisplayRepresentations: [TaskCategoryAppEnum: DisplayRepresentation] = [
        .call: DisplayRepresentation(title: "Call", subtitle: "📞"),
        .text: DisplayRepresentation(title: "Text", subtitle: "💬"),
        .email: DisplayRepresentation(title: "Email", subtitle: "📧"),
        .link: DisplayRepresentation(title: "Link", subtitle: "🔗"),
        .homework: DisplayRepresentation(title: "Study", subtitle: "📚"),
        .cooking: DisplayRepresentation(title: "Cooking", subtitle: "🍳"),
        .alarm: DisplayRepresentation(title: "Alarm", subtitle: "⏰"),
        .exercise: DisplayRepresentation(title: "Exercise", subtitle: "💪"),
        .cleaning: DisplayRepresentation(title: "Cleaning", subtitle: "🧹"),
        .shopping: DisplayRepresentation(title: "Shopping", subtitle: "🛒"),
        .appointment: DisplayRepresentation(title: "Appointment", subtitle: "📅"),
        .finance: DisplayRepresentation(title: "Finance", subtitle: "💰"),
        .health: DisplayRepresentation(title: "Health", subtitle: "💊"),
        .creative: DisplayRepresentation(title: "Creative", subtitle: "🎨"),
        .errand: DisplayRepresentation(title: "Errand", subtitle: "🏃"),
        .selfCare: DisplayRepresentation(title: "Self-Care", subtitle: "🧘"),
        .work: DisplayRepresentation(title: "Work", subtitle: "💼"),
        .social: DisplayRepresentation(title: "Social", subtitle: "👥"),
        .maintenance: DisplayRepresentation(title: "Fix & Build", subtitle: "🔧"),
        .general: DisplayRepresentation(title: "General", subtitle: "📝")
    ]
    
    /// Convert to the main app's TaskCategory enum.
    var toTaskCategory: TaskCategory {
        TaskCategory(rawValue: self.rawValue) ?? .general
    }
}

// MARK: - Get Tasks By Category Intent

/// Count and list tasks in a specific category — great for automations.
struct GetTasksByCategoryIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Get Nudges by Category"
    static var description: IntentDescription = "Count and get tasks in a specific category."
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Category")
    var category: TaskCategoryAppEnum
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$category) nudges")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let container = IntentModelAccess.makeContainer() else {
            throw NudgeIntentError.notSignedIn
        }
        
        let context = container.mainContext
        let catRaw = category.rawValue
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: #Predicate { $0.statusRaw == "active" },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        
        let items = (try? context.fetch(descriptor)) ?? []
        let matching = items.filter { $0.categoryRaw == catRaw }
        let count = matching.count
        let cat = category.toTaskCategory
        
        if count == 0 {
            return .result(value: 0, dialog: "No active \(cat.label) tasks.")
        } else if let first = matching.first {
            return .result(
                value: count,
                dialog: "\(count) \(cat.emoji) \(cat.label) task\(count == 1 ? "" : "s"). Next up: \(first.content)"
            )
        } else {
            return .result(value: count, dialog: "\(count) \(cat.label) task\(count == 1 ? "" : "s").")
        }
    }
}
