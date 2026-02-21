//
//  NudgyToolExecutor.swift
//  Nudge
//
//  Phase 7: Execute tool calls from the LLM against real data.
//  Bridges between OpenAI function calling and NudgeRepository.
//  Each tool call returns a string result that feeds back to the LLM.
//

import Foundation
import SwiftData
import os

// MARK: - Tool Execution Result

/// Result of executing a tool call.
struct ToolExecutionResult {
    let toolCallId: String
    let result: String
    let sideEffects: [ToolSideEffect]
    
    enum ToolSideEffect {
        case taskCreated(content: String)
        case taskCompleted(content: String)
        case taskSnoozed(content: String)
        case memoryLearned(fact: String, category: String)
        case actionExecuted(actionType: String, target: String)
        case draftGenerated(type: String, recipient: String, body: String, subject: String?)
    }
}

// MARK: - NudgyToolExecutor

/// Executes tool calls from the LLM against the user's real data.
@MainActor
final class NudgyToolExecutor {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Execute a tool call and return the result string.
    func execute(_ toolCall: LLMToolCall) -> ToolExecutionResult {
        let args = toolCall.parsedArguments() ?? [:]
        
        Log.ai.debug("Executing tool: \(toolCall.functionName) id=\(toolCall.id) args=\(toolCall.arguments.prefix(120))")
        
        switch toolCall.functionName {
        case "lookup_tasks":
            return executeLookupTasks(toolCallId: toolCall.id, args: args)
        case "get_task_stats":
            return executeGetTaskStats(toolCallId: toolCall.id, args: args)
        case "get_current_time":
            return executeGetCurrentTime(toolCallId: toolCall.id)
        case "task_action":
            return executeTaskAction(toolCallId: toolCall.id, args: args)
        case "execute_action":
            return executeExecuteAction(toolCallId: toolCall.id, args: args)
        case "generate_draft":
            return executeGenerateDraft(toolCallId: toolCall.id, args: args)
        case "extract_memory":
            return executeExtractMemory(toolCallId: toolCall.id, args: args)
        default:
            return ToolExecutionResult(
                toolCallId: toolCall.id,
                result: "Unknown tool: \(toolCall.functionName)",
                sideEffects: []
            )
        }
    }
    
    /// Execute multiple tool calls.
    func executeAll(_ toolCalls: [LLMToolCall]) -> [ToolExecutionResult] {
        toolCalls.map { execute($0) }
    }
    
    // MARK: - Tool Implementations
    
    private func executeLookupTasks(toolCallId: String, args: [String: Any]) -> ToolExecutionResult {
        let status = args["status"] as? String ?? "active"
        let keyword = args["keyword"] as? String ?? ""
        
        let repo = NudgeRepository(modelContext: modelContext)
        let allItems: [NudgeItem]
        
        switch status {
        case "active":
            allItems = repo.fetchActiveQueue()
        case "snoozed":
            let grouped = repo.fetchAllGrouped()
            allItems = grouped.snoozed
        case "done":
            let grouped = repo.fetchAllGrouped()
            allItems = grouped.doneToday
        default:
            let grouped = repo.fetchAllGrouped()
            allItems = grouped.active + grouped.snoozed + grouped.doneToday
        }
        
        var filtered = allItems
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !kw.isEmpty {
            filtered = filtered.filter { $0.content.lowercased().contains(kw) }
        }
        
        if filtered.isEmpty {
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: "No tasks found matching that criteria.",
                sideEffects: []
            )
        }
        
        let lines = filtered.prefix(8).map { item in
            var line = "- \(item.content) [\(item.statusRaw)]"
            if item.isOverdue { line += " OVERDUE" }
            else if item.isStale { line += " stale(\(item.ageInDays)d)" }
            if let contact = item.contactName, !contact.isEmpty {
                line += " → \(contact)"
            }
            return line
        }
        
        let total = filtered.count
        var result = "Found \(total) task\(total == 1 ? "" : "s"):\n" + lines.joined(separator: "\n")
        if total > 8 { result += "\n...and \(total - 8) more." }
        
        return ToolExecutionResult(toolCallId: toolCallId, result: result, sideEffects: [])
    }
    
    private func executeGetTaskStats(toolCallId: String, args: [String: Any]) -> ToolExecutionResult {
        let repo = NudgeRepository(modelContext: modelContext)
        let grouped = repo.fetchAllGrouped()
        let active = grouped.active
        let snoozed = grouped.snoozed
        let doneToday = grouped.doneToday
        
        let overdue = active.filter { $0.isOverdue }
        let stale = active.filter { $0.isCategoryStale }
        let oldest = active.max(by: { $0.ageInDays < $1.ageInDays })
        
        var lines: [String] = []
        lines.append("Active: \(active.count)")
        lines.append("Snoozed: \(snoozed.count)")
        lines.append("Done today: \(doneToday.count)")
        if !overdue.isEmpty { lines.append("⚠️ Overdue: \(overdue.count)") }
        if !stale.isEmpty { lines.append("⏰ Stale (category-aware): \(stale.count)") }
        if let o = oldest, o.ageInDays > 0 {
            lines.append("Oldest active: \"\(o.content)\" (\(o.ageInDays) days)")
        }
        
        // Category breakdown of active tasks
        var activeByCat: [String: Int] = [:]
        for item in active {
            let label = item.resolvedCategory.label
            activeByCat[label, default: 0] += 1
        }
        if !activeByCat.isEmpty {
            let sorted = activeByCat.sorted { $0.value > $1.value }
            let catList = sorted.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            lines.append("Active by category: \(catList)")
        }
        
        // Category breakdown of done today
        var doneByCat: [String: Int] = [:]
        for item in doneToday {
            let label = item.resolvedCategory.label
            doneByCat[label, default: 0] += 1
        }
        if !doneByCat.isEmpty {
            let sorted = doneByCat.sorted { $0.value > $1.value }
            let catList = sorted.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            lines.append("Done today by category: \(catList)")
        }
        
        return ToolExecutionResult(
            toolCallId: toolCallId,
            result: lines.joined(separator: "\n"),
            sideEffects: []
        )
    }
    
    private func executeGetCurrentTime(toolCallId: String) -> ToolExecutionResult {
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
        
        return ToolExecutionResult(
            toolCallId: toolCallId,
            result: "\(timeString). It's \(period).",
            sideEffects: []
        )
    }
    
    private func executeTaskAction(toolCallId: String, args: [String: Any]) -> ToolExecutionResult {
        let action = (args["action"] as? String ?? "").lowercased()
        let taskContent = args["task_content"] as? String ?? ""
        
        let repo = NudgeRepository(modelContext: modelContext)
        
        switch action {
        case "complete":
            let active = repo.fetchActiveQueue()
            if let match = active.first(where: { $0.content.lowercased().contains(taskContent.lowercased()) }) {
                repo.markDone(match)
                HapticService.shared.completionHaptic(for: match.resolvedCategory)
                return ToolExecutionResult(
                    toolCallId: toolCallId,
                    result: "Marked '\(match.content)' as done! ✅",
                    sideEffects: [.taskCompleted(content: match.content)]
                )
            }
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: "Couldn't find a task matching '\(taskContent)'.",
                sideEffects: []
            )
            
        case "snooze":
            let active = repo.fetchActiveQueue()
            if let match = active.first(where: { $0.content.lowercased().contains(taskContent.lowercased()) }) {
                repo.snooze(match, until: Date.tomorrowMorning)
                return ToolExecutionResult(
                    toolCallId: toolCallId,
                    result: "Snoozed '\(match.content)' until tomorrow. 💤",
                    sideEffects: [.taskSnoozed(content: match.content)]
                )
            }
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: "Couldn't find a task matching '\(taskContent)'.",
                sideEffects: []
            )
            
        case "create":
            // Parse rich metadata from tool call arguments
            let emoji = args["emoji"] as? String
            let priorityRaw = args["priority"] as? String ?? "medium"
            let dueDateRaw = args["due_date"] as? String ?? ""
            let actionTypeRaw = args["action_type"] as? String ?? ""
            let contactName = args["contact_name"] as? String
            
            Log.ai.debug("task_action CREATE: '\(taskContent)' emoji=\(emoji ?? "nil") priority=\(priorityRaw) due=\(dueDateRaw) action=\(actionTypeRaw) contact=\(contactName ?? "nil")")
            
            // Map action type
            let actionType: ActionType?
            switch actionTypeRaw.uppercased() {
            case "CALL": actionType = .call
            case "TEXT": actionType = .text
            case "EMAIL": actionType = .email
            case "ALARM": actionType = .setAlarm
            default: actionType = nil
            }
            
            // Map priority
            let priority: TaskPriority
            switch priorityRaw.lowercased() {
            case "high": priority = .high
            case "low": priority = .low
            default: priority = .medium
            }
            
            // Parse due date
            let dueDate = Self.parseDueDate(dueDateRaw)
            
            // Create rich task
            let item = repo.createManualWithDetails(
                content: taskContent,
                emoji: emoji,
                actionType: actionType,
                contactName: contactName
            )
            item.priority = priority
            if let dueDate {
                item.dueDate = dueDate
            }
            
            // Force save to ensure persistence
            do { try modelContext.save() } catch { Log.ai.error("[ToolExecutor] Task create save failed: \(error, privacy: .public)") }
            
            HapticService.shared.cardAppear()
            
            Log.ai.info("Task created: '\(taskContent)' — saved to SwiftData")
            
            // Build concise confirmation for LLM (it reads this and responds to user)
            var details = "\(emoji ?? "doc.text.fill") Created: '\(taskContent)'"
            if priority == .high { details += " ⚡️HIGH" }
            if dueDate != nil { details += " 📅\(dueDateRaw)" }
            if let contact = contactName, !contact.isEmpty { details += " → \(contact)" }
            
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: details,
                sideEffects: [.taskCreated(content: taskContent)]
            )
            
        default:
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: "Unknown action '\(action)'. Use 'complete', 'snooze', or 'create'.",
                sideEffects: []
            )
        }
    }
    
    private func executeExtractMemory(toolCallId: String, args: [String: Any]) -> ToolExecutionResult {
        let fact = args["fact"] as? String ?? ""
        let categoryRaw = args["category"] as? String ?? "contextual"
        
        guard !fact.isEmpty else {
            return ToolExecutionResult(toolCallId: toolCallId, result: "No fact provided.", sideEffects: [])
        }
        
        let category: NudgyMemoryFact.FactCategory
        switch categoryRaw {
        case "preference": category = .preference
        case "personal": category = .personal
        case "emotional": category = .emotional
        case "behavioral": category = .behavioral
        default: category = .contextual
        }
        
        NudgyMemory.shared.learn(fact, category: category)
        
        // Check if fact contains a name
        if categoryRaw == "personal" && fact.lowercased().contains("name") {
            // Try to extract the name
            let words = fact.components(separatedBy: " ")
            if let nameIndex = words.firstIndex(where: { $0.lowercased() == "is" || $0.lowercased() == "name" }),
               nameIndex + 1 < words.count {
                let name = words[(nameIndex + 1)...].joined(separator: " ")
                    .trimmingCharacters(in: .punctuationCharacters)
                NudgyMemory.shared.updateUserName(name)
            }
        }
        
        return ToolExecutionResult(
            toolCallId: toolCallId,
            result: "Remembered: \(fact)",
            sideEffects: [.memoryLearned(fact: fact, category: categoryRaw)]
        )
    }
    
    // MARK: - Execute Action (from Chat)
    
    private func executeExecuteAction(toolCallId: String, args: [String: Any]) -> ToolExecutionResult {
        let actionTypeRaw = (args["action_type"] as? String ?? "").uppercased()
        let target = args["target"] as? String ?? ""
        let taskContent = args["task_content"] as? String ?? ""
        let draftBody = args["draft_body"] as? String ?? ""
        let draftSubject = args["draft_subject"] as? String ?? ""
        let contactName = args["contact_name"] as? String ?? ""
        
        Log.ai.debug("execute_action: type=\(actionTypeRaw) target=\(target) contact=\(contactName)")
        
        // Try to find matching task first
        let repo = NudgeRepository(modelContext: modelContext)
        var matchedItem: NudgeItem?
        if !taskContent.isEmpty {
            let active = repo.fetchActiveQueue()
            matchedItem = active.first { $0.content.lowercased().contains(taskContent.lowercased()) }
        }
        
        // Post execution notification with all context
        var userInfo: [String: Any] = [
            "actionType": actionTypeRaw,
            "target": target,
            "contactName": contactName,
            "draftBody": draftBody,
            "draftSubject": draftSubject
        ]
        if let item = matchedItem {
            userInfo["itemID"] = item.id.uuidString
            // Update draft on the item if provided
            if !draftBody.isEmpty {
                item.aiDraft = draftBody
                if !draftSubject.isEmpty { item.aiDraftSubject = draftSubject }
                item.draftGeneratedAt = Date()
                do { try modelContext.save() } catch { Log.ai.error("[ToolExecutor] Draft save failed: \(error, privacy: .public)") }
            }
        }
        
        NotificationCenter.default.post(
            name: .nudgeChatExecuteAction,
            object: nil,
            userInfo: userInfo
        )
        
        HapticService.shared.actionButtonTap()
        
        let actionLabel: String
        switch actionTypeRaw {
        case "CALL": actionLabel = "Opening phone to call \(contactName.isEmpty ? target : contactName)"
        case "TEXT": actionLabel = "Opening Messages for \(contactName.isEmpty ? target : contactName) with your draft"
        case "EMAIL": actionLabel = "Opening Mail to \(contactName.isEmpty ? target : contactName) with your draft"
        case "SEARCH": actionLabel = "Opening search for '\(target)' in the app"
        case "NAVIGATE": actionLabel = "Getting directions to \(target)"
        case "LINK": actionLabel = "Opening \(target) in the browser"
        case "ALARM": actionLabel = "Setting alarm for \(target)"
        default: actionLabel = "Executing action"
        }
        
        return ToolExecutionResult(
            toolCallId: toolCallId,
            result: "\(actionLabel). ✅",
            sideEffects: [.actionExecuted(actionType: actionTypeRaw, target: target)]
        )
    }
    
    // MARK: - Generate Draft (from Chat)
    
    private func executeGenerateDraft(toolCallId: String, args: [String: Any]) -> ToolExecutionResult {
        let draftType = args["draft_type"] as? String ?? "text"
        let recipientName = args["recipient_name"] as? String ?? ""
        let subject = args["subject"] as? String
        let body = args["body"] as? String ?? ""
        let context = args["context"] as? String ?? ""
        
        Log.ai.debug("generate_draft: type=\(draftType) to=\(recipientName) context=\(context)")
        
        guard !body.isEmpty else {
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: "Draft body is empty. Please provide the message content.",
                sideEffects: []
            )
        }
        
        // Post notification with draft data for the chat UI to show a review card
        NotificationCenter.default.post(
            name: .nudgeChatExecuteAction,
            object: nil,
            userInfo: [
                "actionType": draftType == "email" ? "EMAIL_DRAFT" : "TEXT_DRAFT",
                "contactName": recipientName,
                "draftBody": body,
                "draftSubject": subject ?? ""
            ]
        )
        
        var resultLines = [String]()
        if draftType == "email" {
            resultLines.append("📧 Email draft for \(recipientName):")
            if let subject, !subject.isEmpty {
                resultLines.append("Subject: \(subject)")
            }
            resultLines.append("---")
            resultLines.append(body)
        } else {
            resultLines.append("💬 Text draft for \(recipientName):")
            resultLines.append("---")
            resultLines.append(body)
        }
        resultLines.append("---")
        resultLines.append("Draft ready. Ask the user if they want to send it or make changes.")
        
        return ToolExecutionResult(
            toolCallId: toolCallId,
            result: resultLines.joined(separator: "\n"),
            sideEffects: [.draftGenerated(type: draftType, recipient: recipientName, body: body, subject: subject)]
        )
    }
    
    // MARK: - Date Parsing Helper
    
    /// Parse a due date string (YYYY-MM-DD or relative expression) into a Date.
    /// Replicates the logic from ExtractedTask.parsedDueDate for tool-call usage.
    private static func parseDueDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        
        // Try ISO 8601 / YYYY-MM-DD
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        if let date = df.date(from: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let cal = Calendar.current
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: date)
        }
        
        let cal = Calendar.current
        let now = Date()
        
        if trimmed.contains("today") || trimmed.contains("tonight") {
            return cal.date(bySettingHour: trimmed.contains("tonight") ? 20 : 17, minute: 0, second: 0, of: now)
        }
        if trimmed.contains("tomorrow") {
            let tom = cal.date(byAdding: .day, value: 1, to: now)!
            if trimmed.contains("morning") {
                return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tom)
            } else if trimmed.contains("afternoon") {
                return cal.date(bySettingHour: 14, minute: 0, second: 0, of: tom)
            } else if trimmed.contains("evening") || trimmed.contains("night") {
                return cal.date(bySettingHour: 19, minute: 0, second: 0, of: tom)
            }
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tom)
        }
        if trimmed.contains("this weekend") {
            let weekday = cal.component(.weekday, from: now)
            let daysUntilSat = (7 - weekday) % 7
            let sat = cal.date(byAdding: .day, value: max(daysUntilSat, 1), to: now)!
            return cal.date(bySettingHour: 10, minute: 0, second: 0, of: sat)
        }
        if trimmed.contains("next week") {
            let nextMon = cal.date(byAdding: .day, value: (9 - cal.component(.weekday, from: now)) % 7 + 1, to: now)!
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: nextMon)
        }
        
        return nil
    }
}
