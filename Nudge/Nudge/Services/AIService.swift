//
//  AIService.swift
//  Nudge
//
//  Apple Foundation Models integration — fully on-device AI for:
//  1. Task splitting (brain dump transcript → individual task cards)
//  2. Draft generation (task → ready-to-send message)
//  3. Task coaching & breakdown (overwhelm → tiny steps)
//  4. Natural language task extraction
//  5. Smart prioritization
//  6. Tool-powered conversation (Nudgy can query + act on real data)
//  7. Streaming responses for real-time dialogue
//
//  Runs entirely on-device — no API keys, no network, full privacy.
//

import Foundation
import FoundationModels
import SwiftData
import os

// MARK: - Generable Types

/// A single task extracted from a brain dump transcript.
@Generable(description: "An actionable task extracted from a spoken brain dump")
struct SplitTask: Equatable {
    @Guide(description: "Short clear task, max 8 words")
    var task: String
    
    @Guide(description: "An SF Symbol name that best represents this task, e.g. phone.fill, envelope.fill, cart.fill, book.fill, pawprint.fill, checklist")
    var emoji: String
    
    @Guide(description: "CALL if task involves calling, TEXT if texting/messaging, EMAIL if emailing, empty string if none")
    var action: String
    
    @Guide(description: "Person or business name if mentioned, empty string if none")
    var contact: String
    
    @Guide(description: "Phone number, email address, or URL if explicitly mentioned in the text, empty string if none")
    var actionTarget: String
}

/// A list of tasks extracted from a brain dump.
@Generable(description: "Tasks extracted from a brain dump transcript")
struct SplitTaskList {
    @Guide(description: "Individual actionable tasks from the transcript", .count(1...10))
    var tasks: [SplitTask]
}

/// An AI-generated message draft for a task.
@Generable(description: "A ready-to-send message draft")
struct DraftResponse {
    @Guide(description: "The message body, short and natural. Texts: 1-3 sentences. Emails: 3-5 sentences.")
    var draft: String
    
    @Guide(description: "Email subject line. Empty string if not an email.")
    var subject: String
}

/// A task broken down into smaller actionable steps.
@Generable(description: "A task broken down into smaller actionable steps for ADHD brains")
struct TaskBreakdown {
    @Guide(description: "Brief reasoning about why this task feels overwhelming and how to approach it")
    var reasoning: String
    
    @Guide(description: "The smaller sub-tasks, each max 8 words with an SF Symbol name", .count(2...6))
    var steps: [SplitTask]
    
    @Guide(description: "An encouraging one-liner for the user, max 12 words")
    var encouragement: String
}

/// A task extracted from natural language input.
@Generable(description: "A task extracted from natural language input")
struct NaturalTaskExtraction {
    @Guide(description: "The clear, actionable task text (max 8 words)")
    var taskContent: String
    
    @Guide(description: "An SF Symbol name that represents this task, e.g. phone.fill, envelope.fill, cart.fill")
    var emoji: String
    
    @Guide(description: "CALL, TEXT, EMAIL, or empty string")
    var actionType: String
    
    @Guide(description: "Contact name if mentioned, empty string otherwise")
    var contactName: String
    
    @Guide(description: "Phone number, email address, or URL if explicitly mentioned in the text, empty string if none")
    var actionTarget: String
    
    @Guide(description: "true if the input contains an actionable task, false if it is just chat")
    var isActionable: Bool
}

/// A suggestion for which task to tackle first and why.
@Generable(description: "A suggestion for which task to tackle first and why")
struct PrioritySuggestion {
    @Guide(description: "Brief reasoning about task urgency and effort")
    var reasoning: String
    
    @Guide(description: "The recommended task content to focus on")
    var recommendedTask: String
    
    @Guide(description: "A short, motivating reason why this one first (max 15 words)")
    var whyThisFirst: String
}

// MARK: - AI Service

/// On-device AI-powered task splitting and draft generation using Apple Foundation Models.
@MainActor @Observable
final class AIService {
    
    static let shared = AIService()
    
    /// Whether the on-device model is available on this device.
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }
    
    /// Detailed availability status for UI messaging.
    var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }
    
    /// Whether the AI is currently generating a response.
    var isGenerating: Bool = false
    
    // MARK: - Prewarming
    
    /// Pre-warm the language model for faster first response.
    /// Call this at app launch. Runs in background — non-blocking.
    func prewarm() {
        guard isAvailable else { return }
        Task.detached(priority: .background) {
            let session = LanguageModelSession(
                instructions: "You are Nudgy, a helpful penguin assistant in an ADHD-friendly task app."
            )
            session.prewarm(promptPrefix: Prompt("The user just opened the app."))
        }
    }
    
    // MARK: - Task Splitting
    
    /// Split a brain dump transcript into individual actionable tasks.
    /// Returns parsed tasks or falls back to the raw transcript as a single task.
    func splitBrainDump(transcript: String) async throws -> [SplitTask] {
        // Single word/phrase — skip AI, return as-is
        let wordCount = transcript.split(separator: " ").count
        if wordCount <= 4 {
            return [SplitTask(task: transcript, emoji: "doc.text.fill", action: "", contact: "", actionTarget: "")]
        }
        
        // Check model availability — fall back gracefully
        guard isAvailable else {
            return fallbackSingleTask(transcript)
        }
        
        let session = LanguageModelSession(
            instructions: """
            You are a task extraction assistant. The user spoke a stream-of-consciousness brain dump.
            Extract individual actionable items. For each item:
            - Write a short, clear task (max 8 words)
            - Assign one relevant emoji
            - Ignore filler words, "um", "uh", "like", repetitions
            - If something isn't actionable (e.g., "I'm tired"), skip it
            - Detect action types: calling someone → "CALL", texting/messaging → "TEXT", emailing → "EMAIL", otherwise leave action empty
            - If a person or business is mentioned, include their name as contact, otherwise leave contact empty
            """
        )
        
        do {
            let response = try await session.respond(
                to: "Extract tasks from this brain dump transcript:\n\"\(transcript)\"",
                generating: SplitTaskList.self
            )
            
            let tasks = response.content.tasks
            return tasks.isEmpty ? fallbackSingleTask(transcript) : tasks
        } catch {
            Log.ai.warning("Foundation Models task splitting failed: \(error, privacy: .public)")
            return fallbackSingleTask(transcript)
        }
    }
    
    // MARK: - Draft Generation
    
    /// Generate an AI message draft for a task with an action type.
    func generateDraft(
        taskContent: String,
        actionType: ActionType,
        contactName: String?,
        senderName: String? = nil
    ) async throws -> DraftResponse {
        let actionLabel = actionType == .email ? "EMAIL" : "TEXT"
        
        guard isAvailable else {
            throw AIError.modelUnavailable
        }
        
        let session = LanguageModelSession(
            instructions: """
            You are a message drafting assistant. Write a short, ready-to-send message.
            - Texts: 1-3 sentences max. Emails: 3-5 sentences max.
            - Be natural and human — not robotic or overly formal.
            - Include a clear ask or purpose.
            - For emails: also generate a subject line. For texts: leave subject as empty string.
            - Infer tone from context — casual for friends/family, professional for business/services.
            """
        )
        
        let senderLine: String
        if let name = senderName, !name.isEmpty {
            senderLine = "\nSender name: \"\(name)\""
        } else {
            senderLine = ""
        }
        
        let response = try await session.respond(
            to: """
            Write a \(actionLabel.lowercased()) message for this task:
            Task: "\(taskContent)"
            Recipient: "\(contactName ?? "the person mentioned")"\(senderLine)
            """,
            generating: DraftResponse.self
        )
        
        return response.content
    }
    
    // MARK: - Smart Task Coaching
    
    /// Break an overwhelming task into 2-6 tiny, concrete steps.
    /// Uses ADHD coaching principles — no guilt, warm encouragement.
    func breakDownTask(_ taskContent: String) async throws -> TaskBreakdown {
        guard isAvailable else { throw AIError.modelUnavailable }
        
        isGenerating = true
        defer { isGenerating = false }
        
        let session = LanguageModelSession(
            instructions: """
            You are an ADHD coach. Break overwhelming tasks into 2-6 tiny concrete steps.
            Each step: max 8 words, one emoji, clear action verb.
            Be warm and encouraging. No guilt. Make each step feel doable in under 5 minutes.
            """
        )
        
        let response = try await session.respond(
            to: "Break this into smaller steps: \"\(taskContent)\"",
            generating: TaskBreakdown.self
        )
        return response.content
    }
    
    // MARK: - Natural Language Task Extraction
    
    /// Extract an actionable task from free-form natural language.
    /// Returns `isActionable = false` if the input is just chat/nonsense.
    func extractTask(from naturalInput: String) async throws -> NaturalTaskExtraction {
        guard isAvailable else {
            // Fallback: treat everything as a task
            return NaturalTaskExtraction(
                taskContent: String(naturalInput.prefix(80)),
                emoji: "doc.text.fill",
                actionType: "",
                contactName: "",
                actionTarget: "",
                isActionable: true
            )
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        let session = LanguageModelSession(
            instructions: """
            Extract an actionable task from natural language input.
            If input is just chat or not a task, set isActionable to false.
            Otherwise extract a clear task (max 8 words), detect CALL/TEXT/EMAIL actions, and include contact names.
            """
        )
        
        let response = try await session.respond(
            to: "Extract task from: \"\(naturalInput)\"",
            generating: NaturalTaskExtraction.self
        )
        return response.content
    }
    
    // MARK: - Smart Prioritization
    
    /// Suggest which task to tackle first from the active queue.
    /// Uses ADHD principles: overdue is urgent, stale needs attention, quick wins build momentum.
    func suggestPriority(tasks: [TaskSnapshot]) async throws -> PrioritySuggestion {
        guard isAvailable else { throw AIError.modelUnavailable }
        
        isGenerating = true
        defer { isGenerating = false }
        
        let taskList = tasks.prefix(8).map { task in
            var line = "- \(task.emoji ?? "doc.text.fill") \(task.content)"
            if task.isOverdue { line += " [OVERDUE]" }
            else if task.isStale { line += " [stale \(task.ageInDays)d]" }
            return line
        }.joined(separator: "\n")
        
        let session = LanguageModelSession(
            instructions: """
            You are an ADHD coach. Suggest which ONE task to do first.
            Consider: overdue is urgent, stale needs attention, quick wins build momentum.
            Be brief and motivating. Never guilt-trip.
            """
        )
        
        let response = try await session.respond(
            to: "Which task first?\n\(taskList)",
            generating: PrioritySuggestion.self
        )
        return response.content
    }
    
    // MARK: - Tool-Powered Conversation
    
    /// Have a full conversation with Nudgy that can query and act on the user's real task data.
    /// Returns the response text, the session (for multi-turn), and pending actions to execute.
    func converse(
        prompt: String,
        modelContext: ModelContext,
        existingSession: LanguageModelSession? = nil
    ) async throws -> (response: String, session: LanguageModelSession, pendingActions: PendingToolActions) {
        guard isAvailable else { throw AIError.modelUnavailable }
        
        isGenerating = true
        defer { isGenerating = false }
        
        let (tools, pendingActions) = NudgyToolbox.conversationTools(from: modelContext)
        
        let session: LanguageModelSession
        if let existing = existingSession {
            session = existing
        } else {
            session = LanguageModelSession(
                tools: tools,
                instructions: """
                You are Nudgy, a penguin in an ADHD-friendly task app.
                Personality: warm, playful, supportive, a bit cheeky. Think best friend + life coach.
                Rules:
                - Keep responses to 1-3 sentences. Max 40 words.
                - Include one emoji per response.
                - Use tools to look up tasks and stats when relevant.
                - Use taskAction to complete, snooze, or create tasks when asked.
                - Never guilt-trip. Understand ADHD struggles.
                - Be encouraging and make the user feel capable.
                """
            )
        }
        
        let response = try await session.respond(to: prompt)
        return (response.content, session, pendingActions)
    }
    
    // MARK: - Streaming Conversation
    
    /// Stream a conversation response for real-time display.
    /// Calls `onPartial` with progressive text as it generates.
    func streamConverse(
        prompt: String,
        modelContext: ModelContext,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> PendingToolActions {
        guard isAvailable else { throw AIError.modelUnavailable }
        
        isGenerating = true
        defer { isGenerating = false }
        
        let (tools, pendingActions) = NudgyToolbox.conversationTools(from: modelContext)
        
        let session = LanguageModelSession(
            tools: tools,
            instructions: """
            You are Nudgy, a penguin in an ADHD-friendly task app.
            Warm, playful, supportive, cheeky. 1-3 sentences. One emoji.
            Use tools when asked about tasks. Never guilt-trip.
            """
        )
        
        let stream = session.streamResponse(to: prompt)
        for try await partial in stream {
            onPartial(partial.content)
        }
        return pendingActions
    }
    
    // MARK: - Helpers
    
    private func fallbackSingleTask(_ transcript: String) -> [SplitTask] {
        [SplitTask(task: transcript.truncated(to: 80), emoji: "doc.text.fill", action: "", contact: "", actionTarget: "")]
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case modelUnavailable
    case generationFailed(String)
    
    nonisolated var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return String(localized: "Apple Intelligence is not available on this device. Tasks will be saved as-is.")
        case .generationFailed(let detail):
            return String(localized: "AI generation failed: \(detail)")
        }
    }
}
