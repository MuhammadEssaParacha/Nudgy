//
//  SuggestionChipEngine.swift
//  Nudge
//
//  Phase 16: Dynamic Suggestion Chips.
//  Context-aware chip suggestions based on actual task state,
//  time of day, and conversation context. Replaces static suggestion lists.
//
//  Used in NudgyChatView and NudgyHomeView to show
//  relevant quick-action chips below the input field.
//

import SwiftData
import Foundation

// MARK: - Suggestion Chip

struct SuggestionChip: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let icon: String
    let action: SuggestionAction
    
    enum SuggestionAction: Sendable {
        case sendMessage(String)      // Send this text to Nudgy
        case openBrainDump            // Open brain dump
        case openQuickAdd             // Open quick add
        case showOverdue              // Navigate to overdue filter
        case showAllTasks             // Show all tasks
        case startVoice               // Start voice mode
    }
}

// MARK: - Suggestion Chip Engine

enum SuggestionChipEngine {
    
    /// Generate context-aware suggestion chips based on current state.
    static func generateChips(
        modelContext: ModelContext,
        conversationContext: ConversationContext = .idle,
        limit: Int = 4
    ) -> [SuggestionChip] {
        var chips: [SuggestionChip] = []
        
        let repo = NudgeRepository(modelContext: modelContext)
        let activeQueue = repo.fetchActiveQueue()
        let grouped = repo.fetchAllGrouped()
        
        let overdueCount = activeQueue.filter { $0.accentStatus == .overdue }.count
        let staleCount = activeQueue.filter { $0.accentStatus == .stale }.count
        let doneToday = grouped.doneToday.count
        let totalActive = activeQueue.count
        let hour = Calendar.current.component(.hour, from: .now)
        
        // Context-specific chips based on conversation state
        switch conversationContext {
        case .idle:
            chips += idleChips(
                overdueCount: overdueCount,
                staleCount: staleCount,
                totalActive: totalActive,
                doneToday: doneToday,
                hour: hour,
                activeQueue: activeQueue
            )
            
        case .afterCompletion(let remainingCount):
            chips += postCompletionChips(remainingCount: remainingCount, hour: hour)
            
        case .afterBrainDump(let tasksCreated):
            chips += postBrainDumpChips(tasksCreated: tasksCreated)
            
        case .afterAction(let actionType):
            chips += postActionChips(actionType: actionType)
            
        case .chatting:
            chips += chattingChips(activeQueue: activeQueue, hour: hour)
        }
        
        return Array(chips.prefix(limit))
    }
    
    // MARK: - Idle State Chips
    
    private static func idleChips(
        overdueCount: Int,
        staleCount: Int,
        totalActive: Int,
        doneToday: Int,
        hour: Int,
        activeQueue: [NudgeItem]
    ) -> [SuggestionChip] {
        var chips: [SuggestionChip] = []
        
        // Morning chips (before noon)
        if hour < 12 {
            chips.append(SuggestionChip(
                label: String(localized: "What's my day look like?"),
                icon: "sun.max.fill",
                action: .sendMessage("What's my day look like?")
            ))
        }
        
        // Evening chips (after 8 PM)
        if hour >= 20 {
            chips.append(SuggestionChip(
                label: String(localized: "Review my day"),
                icon: "moon.stars.fill",
                action: .sendMessage("How did my day go? Give me a review.")
            ))
        }
        
        // Overdue urgency
        if overdueCount > 0 {
            chips.append(SuggestionChip(
                label: String(localized: "\(overdueCount) overdue — help!"),
                icon: "exclamationmark.triangle.fill",
                action: .sendMessage("I have \(overdueCount) overdue tasks. Help me tackle them.")
            ))
        }
        
        // Stale tasks
        if staleCount >= 2 {
            chips.append(SuggestionChip(
                label: String(localized: "Unstick my stale tasks"),
                icon: "arrow.clockwise",
                action: .sendMessage("I have \(staleCount) stale tasks I keep avoiding. Help me figure out which to do or drop.")
            ))
        }
        
        // First task of the day
        if doneToday == 0 && totalActive > 0 {
            if let firstTask = activeQueue.first {
                chips.append(SuggestionChip(
                    label: String(localized: "Start with \(firstTask.emoji ?? "") \(String(firstTask.content.prefix(20)))"),
                    icon: "play.fill",
                    action: .sendMessage("Help me get started on: \(firstTask.content)")
                ))
            }
        }
        
        // All clear celebration
        if totalActive == 0 && doneToday > 0 {
            chips.append(SuggestionChip(
                label: String(localized: "Everything done! What now?"),
                icon: "checkmark.seal.fill",
                action: .sendMessage("I finished all my tasks! What should I do now?")
            ))
        }
        
        // Draft-ready tasks
        let draftReady = activeQueue.filter { $0.aiDraft != nil }
        if !draftReady.isEmpty {
            chips.append(SuggestionChip(
                label: String(localized: "\(draftReady.count) draft\(draftReady.count == 1 ? "" : "s") ready to send"),
                icon: "paperplane.fill",
                action: .sendMessage("Show me my drafted messages that are ready to send.")
            ))
        }
        
        // Unload suggestion
        if totalActive < 3 {
            chips.append(SuggestionChip(
                label: String(localized: "Unload"),
                icon: "tray.and.arrow.down.fill",
                action: .openBrainDump
            ))
        }
        
        // Quick add
        chips.append(SuggestionChip(
            label: String(localized: "Quick add"),
            icon: "plus.circle.fill",
            action: .openQuickAdd
        ))
        
        return chips
    }
    
    // MARK: - Post-Completion Chips
    
    private static func postCompletionChips(remainingCount: Int, hour: Int) -> [SuggestionChip] {
        var chips: [SuggestionChip] = []
        
        if remainingCount > 0 {
            chips.append(SuggestionChip(
                label: String(localized: "What's next?"),
                icon: "arrow.right.circle.fill",
                action: .sendMessage("What should I work on next?")
            ))
        }
        
        if remainingCount == 0 {
            chips.append(SuggestionChip(
                label: String(localized: "I'm done for today!"),
                icon: "checkmark.seal.fill",
                action: .sendMessage("I finished everything! Give me a celebration!")
            ))
        }
        
        // Suggest a break for ADHD
        chips.append(SuggestionChip(
            label: String(localized: "Take a break"),
            icon: "cup.and.saucer.fill",
            action: .sendMessage("I need a break. How long should I rest?")
        ))
        
        return chips
    }
    
    // MARK: - Post-Brain-Dump Chips
    
    private static func postBrainDumpChips(tasksCreated: Int) -> [SuggestionChip] {
        var chips: [SuggestionChip] = []
        
        if tasksCreated > 0 {
            chips.append(SuggestionChip(
                label: String(localized: "Show my new tasks"),
                icon: "list.bullet",
                action: .showAllTasks
            ))
            
            chips.append(SuggestionChip(
                label: String(localized: "Which one first?"),
                icon: "1.circle.fill",
                action: .sendMessage("I just brain dumped \(tasksCreated) tasks. Which should I start with?")
            ))
        }
        
        chips.append(SuggestionChip(
            label: String(localized: "More to unload"),
            icon: "brain.head.profile.fill",
            action: .openBrainDump
        ))
        
        return chips
    }
    
    // MARK: - Post-Action Chips
    
    private static func postActionChips(actionType: ActionType) -> [SuggestionChip] {
        var chips: [SuggestionChip] = []
        
        switch actionType {
        case .call:
            chips.append(SuggestionChip(
                label: String(localized: "They didn't answer"),
                icon: "phone.arrow.down.left",
                action: .sendMessage("They didn't answer my call. Should I text them instead?")
            ))
        case .email:
            chips.append(SuggestionChip(
                label: String(localized: "Remind me to check reply"),
                icon: "envelope.badge",
                action: .sendMessage("Remind me to check for a reply tomorrow.")
            ))
        case .search:
            chips.append(SuggestionChip(
                label: String(localized: "I found it!"),
                icon: "checkmark.circle.fill",
                action: .sendMessage("I found what I was looking for!")
            ))
            chips.append(SuggestionChip(
                label: String(localized: "Try a different search"),
                icon: "magnifyingglass",
                action: .sendMessage("That search didn't work. Can you suggest a better one?")
            ))
        case .setAlarm, .addToCalendar:
            chips.append(SuggestionChip(
                label: String(localized: "Alarm set!"),
                icon: "checkmark.circle.fill",
                action: .sendMessage("I set the alarm!")
            ))
        default:
            chips.append(SuggestionChip(
                label: String(localized: "What's next?"),
                icon: "arrow.right.circle.fill",
                action: .sendMessage("What should I do next?")
            ))
        }
        
        return chips
    }
    
    // MARK: - Chatting State Chips
    
    private static func chattingChips(activeQueue: [NudgeItem], hour: Int) -> [SuggestionChip] {
        var chips: [SuggestionChip] = []
        
        chips.append(SuggestionChip(
            label: String(localized: "Show my tasks"),
            icon: "list.bullet",
            action: .sendMessage("Show me all my active tasks.")
        ))
        
        if let nextTask = activeQueue.first {
            chips.append(SuggestionChip(
                label: String(localized: "Help with \(String(nextTask.content.prefix(15)))..."),
                icon: "sparkles",
                action: .sendMessage("Help me with: \(nextTask.content)")
            ))
        }
        
        chips.append(SuggestionChip(
            label: String(localized: "Draft something"),
            icon: "pencil.line",
            action: .sendMessage("I need to draft a message. Can you help?")
        ))
        
        return chips
    }
}

// MARK: - Conversation Context

enum ConversationContext: Sendable {
    case idle
    case afterCompletion(remainingCount: Int)
    case afterBrainDump(tasksCreated: Int)
    case afterAction(ActionType)
    case chatting
}
