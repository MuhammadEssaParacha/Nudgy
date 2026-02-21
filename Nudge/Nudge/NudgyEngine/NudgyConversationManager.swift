//
//  NudgyConversationManager.swift
//  Nudge
//
//  Phase 8: Orchestrates the full conversation flow.
//  Ties together LLM, tools, memory, and conversation store.
//  Handles the complete message lifecycle including tool call loops.
//

import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
import os
#endif

// MARK: - Conversation Response

/// Full response from a conversation turn.
struct ConversationResponse {
    let text: String
    let sideEffects: [ToolExecutionResult.ToolSideEffect]
    let toolCallsMade: Int
}

// MARK: - NudgyConversationManager

/// Orchestrates the full conversation flow between user and Nudgy.
@MainActor @Observable
final class NudgyConversationManager {
    
    static let shared = NudgyConversationManager()
    
    // MARK: - State
    
    let conversationStore = ConversationStore()
    
    /// Whether a response is being generated.
    private(set) var isGenerating = false
    
    /// Current streaming partial text.
    private(set) var streamingText = ""
    
    /// In-flight generation task (for cancellation).
    private var generationTask: Task<Void, Never>?
    
    /// Whether the current conversation is in brain dump mode.
    /// Brain dump mode uses a specialized system prompt that instructs the LLM
    /// to actively extract actionable tasks from the user's free-form speech.
    private(set) var isBrainDumpMode = false
    
    /// Accumulated transcript of all user messages in this conversation (for end-of-conversation sweep).
    private(set) var fullTranscript: [String] = []
    
    private init() {}
    
    // MARK: - Brain Dump Mode
    
    /// Start a brain dump conversation — uses the specialized brain dump system prompt.
    func startBrainDumpConversation(modelContext: ModelContext) {
        // End any existing conversation
        if conversationStore.isActive {
            clearConversation()
        }
        
        isBrainDumpMode = true
        fullTranscript = []
        
        let memory = NudgyMemory.shared
        let memoryContext = NudgyConfig.Features.memoryEnabled ? memory.memoryContext() : ""
        
        let hour = Calendar.current.component(.hour, from: .now)
        let timeOfDay = switch hour {
        case 5..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<21: "evening"
        default: "late night"
        }
        let timeContext = "It's \(timeOfDay), \(Date.now.formatted(.dateTime.weekday(.wide).month().day()))"
        
        // Build task context to avoid duplicates
        let repo = NudgeRepository(modelContext: modelContext)
        let activeTasks = repo.fetchActiveQueue()
        let taskContext = activeTasks.prefix(10).map { task in
            "- \(task.emoji ?? "doc.text.fill") \(task.content)"
        }.joined(separator: "\n")
        
        // Phase 14: Build category breakdown for brain dump context
        let categoryContext = Self.buildCategoryContext(from: activeTasks)
        
        let systemPrompt = NudgyPersonality.brainDumpConversationPrompt(
            memoryContext: memoryContext,
            taskContext: taskContext,
            timeContext: timeContext,
            categoryContext: categoryContext
        )
        
        conversationStore.startConversation(systemPrompt: systemPrompt)
        
        Log.ai.debug("Brain dump conversation started. Active tasks: \(activeTasks.count), Memory facts: \(NudgyMemory.shared.store.facts.count)")
        Log.ai.debug("System prompt length: \(systemPrompt.count) chars")
    }
    
    // MARK: - Conversation Lifecycle
    
    /// Ensure a conversation is active with the full system prompt.
    /// Phase 14: Added optional modelContext to build category context.
    func ensureConversationActive(taskContext: String = "", modelContext: ModelContext? = nil) {
        guard !conversationStore.isActive else { return }
        
        let memory = NudgyMemory.shared
        let memoryContext = NudgyConfig.Features.memoryEnabled ? memory.memoryContext() : ""
        
        let hour = Calendar.current.component(.hour, from: .now)
        let timeOfDay = switch hour {
        case 5..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<21: "evening"
        default: "late night"
        }
        let timeContext = "It's \(timeOfDay), \(Date.now.formatted(.dateTime.weekday(.wide).month().day()))"
        
        // Phase 14: Build category context from active tasks if modelContext available
        var categoryContext = ""
        if let modelContext {
            let repo = NudgeRepository(modelContext: modelContext)
            let activeTasks = repo.fetchActiveQueue()
            categoryContext = Self.buildCategoryContext(from: activeTasks)
        }
        
        let systemPrompt = NudgyPersonality.systemPrompt(
            memoryContext: memoryContext,
            taskContext: taskContext,
            timeContext: timeContext,
            categoryContext: categoryContext
        )
        
        conversationStore.startConversation(systemPrompt: systemPrompt)
    }
    
    // MARK: - Send Message (Non-Streaming)
    
    /// Send a user message and get Nudgy's response.
    func send(
        _ userMessage: String,
        modelContext: ModelContext
    ) async -> ConversationResponse {
        ensureConversationActive(modelContext: modelContext)
        conversationStore.addUserMessage(userMessage)
        if isBrainDumpMode { fullTranscript.append(userMessage) }
        isGenerating = true
        
        defer { isGenerating = false }
        
        do {
            let toolExecutor = NudgyToolExecutor(modelContext: modelContext)
            var allSideEffects: [ToolExecutionResult.ToolSideEffect] = []
            var totalToolCalls = 0
            
            // In brain dump mode, force tool calling on first iteration
            let tools = isBrainDumpMode
                ? NudgyToolDefinitions.brainDumpTools
                : NudgyToolDefinitions.allTools
            
            // Tool call loop (max 3 iterations to prevent runaway)
            var iterations = 0
            while iterations < 3 {
                iterations += 1
                
                let response = try await NudgyLLMService.shared.chatCompletion(
                    messages: conversationStore.apiMessages(),
                    tools: tools,
                    toolChoice: iterations == 1 && isBrainDumpMode ? "required" : "auto"
                )
                
                if response.hasToolCalls {
                    // Record assistant message with tool calls
                    let toolCallRecords = response.toolCalls.map {
                        ToolCallRecord(id: $0.id, functionName: $0.functionName, arguments: $0.arguments)
                    }
                    conversationStore.addAssistantMessage(response.content, toolCalls: toolCallRecords)
                    
                    // Execute tool calls
                    let results = toolExecutor.executeAll(response.toolCalls)
                    totalToolCalls += results.count
                    
                    for result in results {
                        conversationStore.addToolMessage(result.result, toolCallId: result.toolCallId)
                        allSideEffects.append(contentsOf: result.sideEffects)
                        
                        // Track side effects from THIS batch only
                        for effect in result.sideEffects {
                            switch effect {
                            case .taskCreated: conversationStore.tasksCreatedCount += 1
                            case .taskCompleted: conversationStore.tasksCompletedCount += 1
                            default: break
                            }
                        }
                    }
                    
                    // Continue loop — LLM will generate final response with tool results
                    continue
                }
                
                // No tool calls — this is the final response
                conversationStore.addAssistantMessage(response.content)
                NudgyMemory.shared.recordInteraction()
                
                // Notify data changes if we modified tasks
                if !allSideEffects.isEmpty {
                    NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
                }
                
                return ConversationResponse(
                    text: response.content,
                    sideEffects: allSideEffects,
                    toolCallsMade: totalToolCalls
                )
            }
            
            // Fallback if loop exhausted
            return ConversationResponse(
                text: "Hmm, I got a bit tangled up there. Could you say that again? 🐧",
                sideEffects: allSideEffects,
                toolCallsMade: totalToolCalls
            )
            
        } catch is NudgyLLMError where NudgyLLMService.shared.isCircuitOpen {
            Log.ai.warning("Circuit breaker open — skipping OpenAI, going to fallbacks")
            
            // Try Apple Foundation Models before dumb fallback
            let appleFMResponse = await appleFMFallback(userMessage, modelContext: modelContext)
            if let appleFMResponse {
                conversationStore.addAssistantMessage(appleFMResponse.text)
                return appleFMResponse
            }
            
            // Last resort: direct action handler (keyword matching)
            let fallbackResponse = directActionFallback(userMessage, modelContext: modelContext)
            conversationStore.addAssistantMessage(fallbackResponse.text)
            return fallbackResponse
            
        } catch {
            Log.ai.error("NudgyConversation error: \(error, privacy: .public)")
            
            // Try Apple Foundation Models before dumb fallback
            let appleFMResponse = await appleFMFallback(userMessage, modelContext: modelContext)
            if let appleFMResponse {
                conversationStore.addAssistantMessage(appleFMResponse.text)
                return appleFMResponse
            }
            
            // Last resort: direct action handler (keyword matching)
            let fallbackResponse = directActionFallback(userMessage, modelContext: modelContext)
            conversationStore.addAssistantMessage(fallbackResponse.text)
            return fallbackResponse
        }
    }
    
    // MARK: - Send Message (Streaming)
    
    /// Send a user message with streaming response.
    /// Calls onPartial with each chunk of text as it arrives.
    func sendStreaming(
        _ userMessage: String,
        modelContext: ModelContext,
        onPartial: @escaping @MainActor (String) -> Void
    ) async -> ConversationResponse {
        // Cancel any in-flight generation
        generationTask?.cancel()
        
        ensureConversationActive(modelContext: modelContext)
        conversationStore.addUserMessage(userMessage)
        if isBrainDumpMode { fullTranscript.append(userMessage) }
        isGenerating = true
        streamingText = ""
        
        defer {
            isGenerating = false
            streamingText = ""
        }
        
        do {
            let toolExecutor = NudgyToolExecutor(modelContext: modelContext)
            var allSideEffects: [ToolExecutionResult.ToolSideEffect] = []
            var totalToolCalls = 0
            
            // In brain dump mode, use task-focused tools with "required" tool_choice
            // so the LLM is forced to create tasks from user input.
            // In normal mode, use "auto" so the LLM decides.
            let tools = isBrainDumpMode
                ? NudgyToolDefinitions.brainDumpTools
                : NudgyToolDefinitions.allTools
            let brainDumpToolChoice = "required"
            
            Log.ai.debug("sendStreaming: brainDump=\(self.isBrainDumpMode), msg='\(userMessage.prefix(60))'")
            
            // Tool call loop — iterate up to 3 times to handle multi-step tool use
            var iterations = 0
            while iterations < 3 {
                iterations += 1
                
                // First pass (or subsequent): check for tool calls (non-streaming)
                let response = try await NudgyLLMService.shared.chatCompletion(
                    messages: conversationStore.apiMessages(),
                    tools: tools,
                    toolChoice: iterations == 1 && isBrainDumpMode ? brainDumpToolChoice : "auto"
                )
                
                Log.ai.debug("iteration \(iterations): hasToolCalls=\(response.hasToolCalls), toolCount=\(response.toolCalls.count), content='\(response.content.prefix(60))'")
                
                if response.hasToolCalls {
                    // Execute tool calls (may be multiple — brain dump can produce several tasks per turn)
                    let toolCallRecords = response.toolCalls.map {
                        ToolCallRecord(id: $0.id, functionName: $0.functionName, arguments: $0.arguments)
                    }
                    conversationStore.addAssistantMessage(response.content, toolCalls: toolCallRecords)
                    
                    let results = toolExecutor.executeAll(response.toolCalls)
                    totalToolCalls += results.count
                    
                    for result in results {
                        Log.ai.debug("Tool result [\(result.toolCallId)]: \(result.result.prefix(80))")
                        conversationStore.addToolMessage(result.result, toolCallId: result.toolCallId)
                        allSideEffects.append(contentsOf: result.sideEffects)
                        
                        // Track side effects from THIS batch only
                        for effect in result.sideEffects {
                            switch effect {
                            case .taskCreated: conversationStore.tasksCreatedCount += 1
                            case .taskCompleted: conversationStore.tasksCompletedCount += 1
                            default: break
                            }
                        }
                    }
                    
                    // Continue loop — LLM will generate final response with tool results
                    continue
                }
                
                // No tool calls — this is the final text response
                // Stream it to the user
                if iterations == 1 && !response.content.isEmpty {
                    // We already have the response from non-streaming call, use it directly
                    conversationStore.addAssistantMessage(response.content)
                    onPartial(response.content)
                    streamingText = response.content
                } else {
                    // After tool calls, stream the final response with tool results context
                    let streamResponse = try await NudgyLLMService.shared.streamChatCompletion(
                        messages: conversationStore.apiMessages()
                    ) { [weak self] partial in
                        self?.streamingText = partial
                        onPartial(partial)
                    }
                    conversationStore.addAssistantMessage(streamResponse.content)
                }
                
                NudgyMemory.shared.recordInteraction()
                
                if !allSideEffects.isEmpty {
                    NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
                }
                
                let finalText = conversationStore.messages.last?.content ?? ""
                Log.ai.debug("Final response (\(totalToolCalls) tools): '\(finalText.prefix(80))'")
                
                return ConversationResponse(
                    text: finalText,
                    sideEffects: allSideEffects,
                    toolCallsMade: totalToolCalls
                )
            }
            
            // Exhausted loop — stream a final response anyway
            let streamResponse = try await NudgyLLMService.shared.streamChatCompletion(
                messages: conversationStore.apiMessages()
            ) { [weak self] partial in
                self?.streamingText = partial
                onPartial(partial)
            }
            conversationStore.addAssistantMessage(streamResponse.content)
            NudgyMemory.shared.recordInteraction()
            
            if !allSideEffects.isEmpty {
                NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
            }
            
            return ConversationResponse(
                text: streamResponse.content,
                sideEffects: allSideEffects,
                toolCallsMade: totalToolCalls
            )
            
        } catch {
            Log.ai.error("NudgyConversation streaming error: \(error, privacy: .public)")
            
            // Try Apple Foundation Models before dumb fallback
            let appleFMResponse = await appleFMFallback(userMessage, modelContext: modelContext)
            if let appleFMResponse {
                conversationStore.addAssistantMessage(appleFMResponse.text)
                onPartial(appleFMResponse.text)
                return appleFMResponse
            }
            
            // Last resort: direct action handler (keyword matching)
            let fallbackResponse = directActionFallback(userMessage, modelContext: modelContext)
            conversationStore.addAssistantMessage(fallbackResponse.text)
            onPartial(fallbackResponse.text)
            return fallbackResponse
        }
    }
    
    // MARK: - One-Shot Generation (Greetings, Reactions)
    
    /// Generate a one-shot response (no conversation context needed).
    /// Falls back: OpenAI → Apple FM → nil.
    func generateOneShotResponse(prompt: String) async -> String? {
        let personality = """
        You are Nudgy, a small excitable penguin ADHD coach.
        \(NudgyPersonality.communicationStyle)
        \(NudgyPersonality.responseRules)
        """
        
        // Try OpenAI first
        do {
            return try await NudgyLLMService.shared.generate(
                systemPrompt: personality,
                userPrompt: prompt,
                temperature: NudgyConfig.OpenAI.conversationTemperature
            )
        } catch {
            Log.ai.warning("NudgyConversation one-shot OpenAI error: \(error, privacy: .public)")
        }
        
        // Fallback: Apple Foundation Models
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                guard SystemLanguageModel.default.isAvailable else { return nil }
                let session = LanguageModelSession(
                    instructions: NudgyPersonality.compactPrompt()
                )
                let response = try await session.respond(to: prompt)
                Log.ai.debug("NudgyConversation one-shot Apple FM success")
                return response.content
            } catch {
                Log.ai.warning("NudgyConversation one-shot Apple FM error: \(error, privacy: .public)")
            }
        }
        #endif
        
        return nil
    }
    
    // MARK: - Session Management
    
    /// End the current conversation and save summary to memory.
    /// Uses AI to generate a proper summary when available.
    /// In brain dump mode, runs a final extraction sweep on the full transcript.
    func endConversation() {
        generationTask?.cancel()
        generationTask = nil
        
        let wasBrainDump = isBrainDumpMode
        let transcript = fullTranscript
        
        // If conversation had enough turns, generate an AI summary
        if conversationStore.needsSummarization {
            let prompt = conversationStore.summarizationPrompt()
            let turnCount = conversationStore.turnCount
            let created = conversationStore.tasksCreatedCount
            let completed = conversationStore.tasksCompletedCount
            
            // End the conversation first (clears messages)
            _ = conversationStore.endConversation()
            
            // Fire-and-forget AI summary
            Task {
                let summaryPrefix = wasBrainDump ? "Brain dump conversation" : "Chat"
                let aiSummary = await generateOneShotResponse(prompt: prompt)
                let summary = ConversationSummary(
                    summary: aiSummary ?? "\(summaryPrefix) with \(turnCount) turns, \(created) tasks created",
                    turnCount: turnCount,
                    tasksCreated: created,
                    tasksCompleted: completed,
                    mood: wasBrainDump ? "brain-dump" : nil
                )
                NudgyMemory.shared.saveConversationSummary(summary)
                Log.ai.debug("Conversation summary saved: \(summary.summary.prefix(80))")
            }
        } else {
            // Short conversation — save basic summary
            if let summary = conversationStore.endConversation() {
                NudgyMemory.shared.saveConversationSummary(summary)
            }
        }
        
        // Reset brain dump state
        isBrainDumpMode = false
        fullTranscript = []
        
        if wasBrainDump {
            Log.ai.debug("Brain dump conversation ended. Transcript segments: \(transcript.count)")
        }
    }
    
    /// End the brain dump conversation and return a summary of tasks created.
    /// Returns the count of tasks created during the conversation.
    func endBrainDumpConversation() -> Int {
        let tasksCreated = conversationStore.tasksCreatedCount
        endConversation()
        return tasksCreated
    }
    
    /// Clear conversation without saving.
    func clearConversation() {
        generationTask?.cancel()
        generationTask = nil
        isBrainDumpMode = false
        fullTranscript = []
        conversationStore.clearConversation()
    }
    
    /// Cancel in-flight generation.
    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        streamingText = ""
    }
    
    // MARK: - Apple Foundation Models Fallback
    
    /// Try Apple Foundation Models when OpenAI is unavailable.
    /// Returns nil if Apple FM is also unavailable, so caller can fall back further.
    private func appleFMFallback(
        _ input: String,
        modelContext: ModelContext
    ) async -> ConversationResponse? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                guard SystemLanguageModel.default.isAvailable else {
                    Log.ai.debug("Apple FM not available on this device")
                    return nil
                }
                
                // Build memory context for personality continuity
                let memoryContext = NudgyConfig.Features.memoryEnabled
                    ? NudgyMemory.shared.memoryContext()
                    : ""
                
                // Build task context from repo
                let repo = NudgeRepository(modelContext: modelContext)
                let activeTasks = repo.fetchActiveQueue()
                let taskContext = activeTasks.prefix(5).map { task in
                    "\(task.emoji ?? "doc.text.fill") \(task.content)"
                }.joined(separator: "\n")
                
                // Use Apple FM tools for task actions
                let (tools, pendingActions) = NudgyToolbox.conversationTools(from: modelContext)
                
                let session = LanguageModelSession(
                    tools: tools,
                    instructions: NudgyPersonality.compactPrompt(
                        memoryContext: memoryContext,
                        taskContext: taskContext
                    )
                )
                
                let response = try await session.respond(to: input)
                
                Log.ai.info("Apple FM fallback success: '\(response.content.prefix(80))'")
                
                // Process any pending tool actions
                var sideEffects: [ToolExecutionResult.ToolSideEffect] = []
                let pendingList = await pendingActions.actions
                for action in pendingList {
                    switch action {
                    case .create(let content):
                        sideEffects.append(.taskCreated(content: content))
                    case .complete(let taskId):
                        sideEffects.append(.taskCompleted(content: taskId.uuidString))
                    case .snooze(let taskId):
                        sideEffects.append(.taskSnoozed(content: taskId.uuidString))
                    }
                }
                
                if !sideEffects.isEmpty {
                    NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
                }
                
                NudgyMemory.shared.recordInteraction()
                
                return ConversationResponse(
                    text: response.content,
                    sideEffects: sideEffects,
                    toolCallsMade: 0
                )
            } catch {
                Log.ai.error("Apple FM fallback error: \(error, privacy: .public)")
                return nil
            }
        }
        #endif
        return nil
    }
    
    // MARK: - Direct Action Fallback (No AI)
    
    /// When AI is unavailable, parse user intent directly.
    private func directActionFallback(
        _ input: String,
        modelContext: ModelContext
    ) -> ConversationResponse {
        let lower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let repo = NudgeRepository(modelContext: modelContext)
        
        // Task creation
        let createPrefixes = [
            "add ", "create ", "new task ", "remind me to ", "remind me ",
            "i need to ", "i gotta ", "i have to ", "i should ", "save ",
            "note ", "remember to "
        ]
        
        for prefix in createPrefixes {
            if lower.hasPrefix(prefix) {
                let content = String(input.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !content.isEmpty {
                    _ = repo.createManual(content: content)
                    HapticService.shared.cardAppear()
                    NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
                    return ConversationResponse(
                        text: "*scribbles with flippers* Got it! Added \"\(content)\" to your nudges! 📝",
                        sideEffects: [.taskCreated(content: content)],
                        toolCallsMade: 0
                    )
                }
            }
        }
        
        // Task lookup
        if lower.contains("how many") || lower.contains("my tasks") || lower.contains("what do i have") {
            let active = repo.fetchActiveQueue()
            if active.isEmpty {
                return ConversationResponse(
                    text: "Clean slate! Nothing on your plate right now 🧊",
                    sideEffects: [], toolCallsMade: 0
                )
            }
            return ConversationResponse(
                text: "You've got \(active.count) nudge\(active.count == 1 ? "" : "s") lined up! Top one: \(active.first?.emoji ?? "pin.fill") \(active.first?.content ?? "") 💪",
                sideEffects: [], toolCallsMade: 0
            )
        }
        
        // Greetings
        if ["hi", "hey", "hello", "yo"].contains(lower) {
            return ConversationResponse(
                text: "*excited waddle* Hey hey! What's on your mind? 🐧",
                sideEffects: [], toolCallsMade: 0
            )
        }
        
        // Emotional support
        if lower.contains("tired") || lower.contains("overwhelm") || lower.contains("stressed") {
            return ConversationResponse(
                text: "Hey. Opening the app already counts — I mean it. One fish at a time 💙",
                sideEffects: [], toolCallsMade: 0
            )
        }
        
        // Default: treat as task
        if lower.count > 2 && lower.count < 200 {
            _ = repo.createManual(content: input.trimmingCharacters(in: .whitespacesAndNewlines))
            HapticService.shared.cardAppear()
            NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
            return ConversationResponse(
                text: "*scribbles furiously* Added that to your nudges! 📝🐧",
                sideEffects: [.taskCreated(content: input)],
                toolCallsMade: 0
            )
        }
        
        return ConversationResponse(
            text: "Tell me what's on your mind! I can add tasks, check your list, or just chat 🐧",
            sideEffects: [], toolCallsMade: 0
        )
    }
    
    // MARK: - Category Context Builder (Phase 14)
    
    /// Build a natural-language category breakdown from active tasks for LLM injection.
    static func buildCategoryContext(from activeTasks: [NudgeItem]) -> String {
        guard !activeTasks.isEmpty else { return "" }
        
        // Group by category
        var catCounts: [TaskCategory: Int] = [:]
        var overdueByCat: [TaskCategory: Int] = [:]
        var staleByCat: [TaskCategory: Int] = [:]
        
        for item in activeTasks {
            let cat = item.resolvedCategory
            catCounts[cat, default: 0] += 1
            if let due = item.dueDate, due < .now {
                overdueByCat[cat, default: 0] += 1
            }
            if item.isCategoryStale {
                staleByCat[cat, default: 0] += 1
            }
        }
        
        let sorted = catCounts.sorted { $0.value > $1.value }
        guard !sorted.isEmpty else { return "" }
        
        var lines: [String] = []
        lines.append("Active tasks by category:")
        for (cat, count) in sorted.prefix(8) {
            var line = "- \(cat.emoji) \(cat.label): \(count) task\(count == 1 ? "" : "s")"
            if let overdue = overdueByCat[cat], overdue > 0 {
                line += " (\(overdue) overdue)"
            }
            if let stale = staleByCat[cat], stale > 0 {
                line += " (\(stale) stale)"
            }
            lines.append(line)
        }
        
        // Add memory patterns
        let memory = NudgyMemory.shared
        if !memory.store.lastWeekTopCategories.isEmpty {
            let weekLabels = memory.store.lastWeekTopCategories
                .compactMap { TaskCategory(rawValue: $0)?.label }
            lines.append("This week they've been most active in: \(weekLabels.joined(separator: ", "))")
        }
        
        return lines.joined(separator: "\n")
    }
}
