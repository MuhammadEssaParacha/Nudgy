//
//  NudgyTools.swift
//  Nudge
//
//  Foundation Models Tool implementations that give Nudgy the ability
//  to query and act on the user's real task data. The on-device model
//  decides when to call these tools based on user interaction context.
//
//  Architecture:
//  - Tools are Sendable structs conforming to `Tool` protocol
//  - Each tool defines @Generable `Arguments` and returns String output
//  - NudgyToolbox provides a factory for creating tool arrays with live data
//  - Tools receive a data snapshot (not live ModelContext) to stay Sendable
//
//  Apple recommends 3-5 tools per session for reliability.
//

import Foundation
import FoundationModels
import SwiftData

// MARK: - Task Data Snapshot (Sendable)

/// A lightweight, Sendable snapshot of a NudgeItem for tool consumption.
/// Tools can't hold @Model references, so we pass these frozen snapshots.
struct TaskSnapshot: Sendable {
    let id: UUID
    let content: String
    let emoji: String?
    let statusRaw: String
    let createdAt: Date
    let completedAt: Date?
    let snoozedUntil: Date?
    let ageInDays: Int
    let isStale: Bool
    let isOverdue: Bool
    let actionTypeRaw: String?
    let contactName: String?
    let sortOrder: Int
}

// MARK: - Task Lookup Tool

/// Lets the model query the user's tasks by status, content keyword, etc.
struct TaskLookupTool: Tool {
    let name = "lookupTasks"
    let description = "Search the user's tasks by status (active, snoozed, done) or by keyword. Returns matching tasks with their details."
    
    @Generable
    struct Arguments {
        @Guide(description: "Status filter: 'active', 'snoozed', 'done', or 'all'")
        var status: String
        
        @Guide(description: "Optional keyword to search in task content. Empty string for no filter.")
        var keyword: String
    }
    
    let tasks: [TaskSnapshot]
    
    func call(arguments: Arguments) async throws -> String {
        var filtered = tasks
        
        // Filter by status
        if arguments.status != "all" {
            filtered = filtered.filter { $0.statusRaw == arguments.status }
        }
        
        // Filter by keyword
        let kw = arguments.keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !kw.isEmpty {
            filtered = filtered.filter { $0.content.lowercased().contains(kw) }
        }
        
        if filtered.isEmpty {
            return "No tasks found matching that criteria."
        }
        
        // Format results concisely (context window is limited)
        let lines = filtered.prefix(8).map { task in
            var line = "- \(task.emoji ?? "doc.text.fill") \(task.content) [\(task.statusRaw)]"
            if task.isOverdue { line += " ⚠️OVERDUE" }
            else if task.isStale { line += " ⏰stale(\(task.ageInDays)d)" }
            if let contact = task.contactName, !contact.isEmpty {
                line += " → \(contact)"
            }
            return line
        }
        
        let total = filtered.count
        var result = "Found \(total) task\(total == 1 ? "" : "s"):\n" + lines.joined(separator: "\n")
        if total > 8 { result += "\n...and \(total - 8) more." }
        return result
    }
}

// MARK: - Task Stats Tool

/// Gives the model statistics about the user's tasks.
struct TaskStatsTool: Tool {
    let name = "getTaskStats"
    let description = "Get statistics about the user's tasks: counts by status, overdue count, streak info, and oldest task age."
    
    @Generable
    struct Arguments {
        @Guide(description: "Set to 'summary' for a quick overview")
        var detail: String
    }
    
    let tasks: [TaskSnapshot]
    
    func call(arguments: Arguments) async throws -> String {
        let active = tasks.filter { $0.statusRaw == "active" }
        let snoozed = tasks.filter { $0.statusRaw == "snoozed" }
        let doneToday = tasks.filter { task in
            task.statusRaw == "done" &&
            task.completedAt.map { Calendar.current.isDateInToday($0) } ?? false
        }
        let overdue = active.filter { $0.isOverdue }
        let stale = active.filter { $0.isStale }
        let oldest = active.max(by: { $0.ageInDays < $1.ageInDays })
        
        var lines: [String] = []
        lines.append("Active: \(active.count)")
        lines.append("Snoozed: \(snoozed.count)")
        lines.append("Done today: \(doneToday.count)")
        if !overdue.isEmpty { lines.append("⚠️ Overdue: \(overdue.count)") }
        if !stale.isEmpty { lines.append("⏰ Stale (3+ days): \(stale.count)") }
        if let o = oldest, o.ageInDays > 0 {
            lines.append("Oldest active: \"\(o.content)\" (\(o.ageInDays) days)")
        }
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - Time Context Tool

/// Gives the model current date/time/day-of-week for contextual responses.
struct TimeContextTool: Tool {
    let name = "getCurrentTime"
    let description = "Get the current date, time, and day of the week. Use this to make time-aware responses."
    
    @Generable
    struct Arguments {
        @Guide(description: "Set to 'now' to get current time")
        var query: String
    }
    
    func call(arguments: Arguments) async throws -> String {
        let now = Date()
        let timeString = now.formatted(.dateTime.weekday(.wide).month(.wide).day().year().hour().minute())
        let hour = Calendar.current.component(.hour, from: now)
        
        let period: String
        switch hour {
        case 5..<12: period = "morning"
        case 12..<17: period = "afternoon"
        case 17..<21: period = "evening"
        default: period = "late night"
        }
        
        return "\(timeString). It's \(period)."
    }
}

// MARK: - Task Action Tool

/// Lets the model request actions on tasks (complete, snooze, create).
/// Returns a description of the action — the actual mutation is handled
/// by the caller after the model's response.
struct TaskActionTool: Tool {
    let name = "taskAction"
    let description = "Request an action on a task: 'complete' to mark done, 'snooze' to snooze, 'create' to add a new task. Returns confirmation."
    
    @Generable
    struct Arguments {
        @Guide(description: "Action: 'complete', 'snooze', or 'create'")
        var action: String
        
        @Guide(description: "For complete/snooze: the task content to match. For create: the new task text.")
        var taskContent: String
    }
    
    let activeTasks: [TaskSnapshot]
    
    /// Tracks requested actions for the caller to execute after generation.
    /// This is a reference type shared with the caller.
    let pendingActions: PendingToolActions
    
    func call(arguments: Arguments) async throws -> String {
        switch arguments.action.lowercased() {
        case "complete":
            // Find the matching task
            let match = activeTasks.first { $0.content.lowercased().contains(arguments.taskContent.lowercased()) }
            if let task = match {
                await pendingActions.add(.complete(taskId: task.id))
                return "Marked '\(task.content)' as done! ✅"
            }
            return "Couldn't find a task matching '\(arguments.taskContent)'."
            
        case "snooze":
            let match = activeTasks.first { $0.content.lowercased().contains(arguments.taskContent.lowercased()) }
            if let task = match {
                await pendingActions.add(.snooze(taskId: task.id))
                return "Snoozed '\(task.content)' for later. 💤"
            }
            return "Couldn't find a task matching '\(arguments.taskContent)'."
            
        case "create":
            await pendingActions.add(.create(content: arguments.taskContent))
            return "Created new task: '\(arguments.taskContent)' 📝"
            
        default:
            return "Unknown action '\(arguments.action)'. Use 'complete', 'snooze', or 'create'."
        }
    }
}

// MARK: - Pending Tool Actions

/// Collects actions requested by tools during a generation session.
/// The caller reads these after generation completes and executes them.
actor PendingToolActions {
    enum Action: Sendable {
        case complete(taskId: UUID)
        case snooze(taskId: UUID)
        case create(content: String)
    }
    
    private(set) var actions: [Action] = []
    
    func add(_ action: Action) {
        actions.append(action)
    }
    
    func clear() {
        actions.removeAll()
    }
}

// MARK: - Toolbox Factory

/// Creates arrays of tools with live data snapshots for a session.
@MainActor
enum NudgyToolbox {
    
    /// Create a snapshot of all tasks from the model context.
    static func snapshotTasks(from modelContext: ModelContext) -> [TaskSnapshot] {
        let descriptor = FetchDescriptor<NudgeItem>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        
        guard let items = try? modelContext.fetch(descriptor) else { return [] }
        
        return items.map { item in
            TaskSnapshot(
                id: item.id,
                content: item.content,
                emoji: item.emoji,
                statusRaw: item.statusRaw,
                createdAt: item.createdAt,
                completedAt: item.completedAt,
                snoozedUntil: item.snoozedUntil,
                ageInDays: item.ageInDays,
                isStale: item.isStale,
                isOverdue: item.isOverdue,
                actionTypeRaw: item.actionTypeRaw,
                contactName: item.contactName,
                sortOrder: item.sortOrder
            )
        }
    }
    
    /// Build the standard set of tools for a conversational session.
    /// Returns (tools array, pendingActions actor).
    static func conversationTools(
        from modelContext: ModelContext
    ) -> (tools: [any Tool], pendingActions: PendingToolActions) {
        let snapshots = snapshotTasks(from: modelContext)
        let activeTasks = snapshots.filter { $0.statusRaw == "active" }
        let pendingActions = PendingToolActions()
        
        let tools: [any Tool] = [
            TaskLookupTool(tasks: snapshots),
            TaskStatsTool(tasks: snapshots),
            TimeContextTool(),
            TaskActionTool(activeTasks: activeTasks, pendingActions: pendingActions)
        ]
        
        return (tools, pendingActions)
    }
    
    /// Lightweight tools for quick one-shot queries (no action tool).
    static func readOnlyTools(
        from modelContext: ModelContext
    ) -> [any Tool] {
        let snapshots = snapshotTasks(from: modelContext)
        return [
            TaskLookupTool(tasks: snapshots),
            TaskStatsTool(tasks: snapshots),
            TimeContextTool()
        ]
    }
}
