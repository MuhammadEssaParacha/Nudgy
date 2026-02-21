    //
//  NudgyEngine.swift
//  Nudge
//
//  Main facade that ties the entire NudgyEngine together.
//  Single entry point for all Nudgy functionality.
//  Views and other services only need to interact with this class.
//
//  Architecture:
//  ┌─────────────────────────────────────────────────┐
//  │                  NudgyEngine                     │
//  │  (facade — single entry point for all Nudgy)    │
//  ├─────────────────────────────────────────────────┤
//  │  NudgyConversationManager  ← orchestrates chat  │
//  │    ├── NudgyLLMService     ← OpenAI API calls   │
//  │    ├── ConversationStore   ← message history     │
//  │    ├── NudgyToolExecutor   ← function calling    │
//  │    └── NudgyToolDefinitions ← tool schemas       │
//  │  NudgyMemory               ← persistent memory   │
//  │  NudgyPersonality          ← identity/prompts    │
//  │  NudgyDialogueEngine       ← one-liner gen      │
//  │  NudgyReactionEngine       ← two-tier reactions  │
//  │  NudgyTaskExtractor        ← task parsing        │
//  │  NudgyVoiceOutput          ← text-to-speech      │
//  │  NudgyEmotionMapper        ← text → expression   │
//  │  NudgyStateAdapter         ← → PenguinState      │
//  │  NudgyADHDKnowledge        ← ADHD strategies     │
//  │  NudgyConfig               ← all settings        │
//  └─────────────────────────────────────────────────┘
//

import Foundation
import SwiftData
import os

// MARK: - NudgyEngine

/// Main facade for the Nudgy conversational engine.
/// All Nudgy functionality flows through here.
@MainActor @Observable
final class NudgyEngine {
    
    static let shared = NudgyEngine()
    
    // MARK: - Sub-Engines (public for advanced access)
    
    let conversation = NudgyConversationManager.shared
    let memory = NudgyMemory.shared
    let reactions = NudgyReactionEngine.shared
    let dialogue = NudgyDialogueEngine.shared
    let taskExtractor = NudgyTaskExtractor.shared
    let voiceOutput = NudgyVoiceOutput.shared
    let stateAdapter = NudgyStateAdapter.shared
    
    // MARK: - State
    
    /// Whether the engine is fully initialized.
    private(set) var isInitialized = false
    
    /// Whether any LLM backend is available (OpenAI or Apple FM).
    var isAvailable: Bool {
        if NudgyConfig.isAvailable { return true }
        // Also check Apple Foundation Models
        return AIService.shared.isAvailable
    }
    
    /// Whether OpenAI specifically is available.
    var isOpenAIAvailable: Bool { NudgyConfig.isAvailable }
    
    /// Whether any generation is in progress.
    var isGenerating: Bool { conversation.isGenerating }
    
    /// Current streaming text.
    var streamingText: String { conversation.streamingText }
    
    // MARK: - Body Doubling State
    
    /// Whether a body doubling session is active.
    private(set) var isBodyDoubling = false
    
    /// When the body doubling session started.
    private var bodyDoublingStart: Date?
    
    /// Timer for body doubling check-ins.
    private var bodyDoublingTimer: Timer?
    
    /// Last emotional check-in date (to avoid over-checking).
    private var lastEmotionalCheckIn: Date?
    
    private init() {}
    
    // MARK: - Initialization
    
    /// Bootstrap the engine. Call once at app launch.
    /// Connects to PenguinState and prewarms services.
    func bootstrap(penguinState: PenguinState) {
        guard !isInitialized else { return }
        
        // Connect state adapter
        stateAdapter.connect(to: penguinState)
        
        // Load memory
        _ = memory.store
        
        // Sync user name from AppSettings to memory
        // (will be called again with actual settings)
        
        isInitialized = true
        
        Log.ai.debug("NudgyEngine bootstrapped. LLM available: \(self.isAvailable)")
        Log.ai.debug("Memory: \(self.memory.store.facts.count) facts, \(self.memory.store.conversationSummaries.count) conversations")
    }
    
    /// Sync user name from AppSettings to memory.
    func syncUserName(_ name: String?) {
        if let name = name, !name.isEmpty {
            memory.updateUserName(name)
        }
    }
    
    /// Sync ADHD profile from AppSettings into all sub-engines.
    /// Call after user activation and whenever profile settings change.
    func syncADHDProfile(settings: AppSettings) {
        let context = PersonaAdapter.adhdProfileContext(
            ageGroup: settings.ageGroup,
            subtype: settings.adhdSubtype,
            challenge: settings.adhdBiggestChallenge,
            personalityMode: settings.nudgyPersonalityMode
        )
        NudgyPersonality.activeProfileContext = context
        dialogue.configure(ageGroup: settings.ageGroup, personalityMode: settings.nudgyPersonalityMode)
        stateAdapter.configure(settings: settings)
        Log.ai.debug("NudgyEngine: ADHD profile synced — mode=\(settings.nudgyPersonalityMode.rawValue), age=\(settings.ageGroup.rawValue), challenge=\(settings.adhdBiggestChallenge.rawValue)")
    }
    
    // MARK: - Chat (Primary Interface)
    
    /// Send a chat message. Delegates to state adapter which drives PenguinState.
    func chat(_ text: String, modelContext: ModelContext) {
        stateAdapter.sendChat(text, modelContext: modelContext)
    }
    
    /// Start chat mode.
    func startChat() {
        stateAdapter.startChatting()
    }
    
    /// Exit chat mode (preserves conversation).
    func exitChat() {
        stateAdapter.exitChat()
    }
    
    /// Clear chat history and memory.
    func clearChat() {
        stateAdapter.clearChatHistory()
    }
    
    // MARK: - Greetings
    
    /// Show a smart greeting.
    /// Phase 14: Added categoryContext for category-aware proactive nudges.
    func greet(userName: String?, activeTaskCount: Int, overdueCount: Int = 0, staleCount: Int = 0, doneToday: Int = 0, topCategory: (label: String, emoji: String, count: Int)? = nil, categoryContext: CategoryNudgeContext? = nil) {
        syncUserName(userName)
        stateAdapter.greet(
            userName: userName,
            activeTaskCount: activeTaskCount,
            overdueCount: overdueCount,
            staleCount: staleCount,
            doneToday: doneToday,
            topCategory: topCategory,
            categoryContext: categoryContext
        )
    }
    
    // MARK: - Reactions
    
    /// React to task completion.
    func reactToCompletion(taskContent: String?, remainingCount: Int, categoryLabel: String? = nil) {
        stateAdapter.reactToCompletion(taskContent: taskContent, remainingCount: remainingCount, categoryLabel: categoryLabel)
    }
    
    /// React to task snooze.
    func reactToSnooze(taskContent: String?) {
        stateAdapter.reactToSnooze(taskContent: taskContent)
    }
    
    /// React to tap.
    func handleTap() {
        stateAdapter.handleTap()
    }
    
    // MARK: - Task Presentation
    
    /// Present a task with smart commentary.
    func presentTask(content: String, emoji: String?, position: Int, total: Int, accentColor: any Sendable, isStale: Bool, isOverdue: Bool) {
        stateAdapter.presentTask(
            content: content, emoji: emoji,
            position: position, total: total,
            accentColor: accentColor,
            isStale: isStale, isOverdue: isOverdue
        )
    }
    
    // MARK: - Brain Dump
    
    /// Start a brain dump voice conversation — Nudgy actively extracts tasks.
    func startBrainDumpConversation(modelContext: ModelContext) {
        conversation.startBrainDumpConversation(modelContext: modelContext)
    }
    
    /// End the brain dump conversation and return the count of tasks created.
    func endBrainDumpConversation() -> Int {
        conversation.endBrainDumpConversation()
    }
    
    /// Whether the current conversation is in brain dump mode.
    var isBrainDumpMode: Bool {
        conversation.isBrainDumpMode
    }
    
    /// Transition to brain dump listening.
    func startBrainDumpListening() {
        stateAdapter.startListening()
    }
    
    /// Transition to brain dump processing.
    func startBrainDumpProcessing() {
        stateAdapter.startProcessing()
    }
    
    /// Show brain dump results.
    func showBrainDumpResults(taskCount: Int) {
        stateAdapter.showResults(taskCount: taskCount)
    }
    
    /// Split a brain dump transcript into tasks.
    func splitBrainDump(transcript: String) async -> [ExtractedTask] {
        await taskExtractor.splitBrainDump(transcript: transcript)
    }
    
    /// Extract a single task from natural language.
    func extractTask(from input: String) async -> ExtractedTask {
        await taskExtractor.extractTask(from: input)
    }
    
    // MARK: - Voice
    
    // Voice input is handled directly by SpeechService in NudgyHomeView.
    // NudgyEngine manages voice output (TTS) only.
    
    /// Speak text aloud.
    func speak(_ text: String) {
        voiceOutput.speak(text)
    }
    
    /// Speak a short reaction (interrupts current speech).
    func speakReaction(_ text: String) {
        voiceOutput.speakReaction(text)
    }
    
    /// Stop speaking.
    func stopSpeaking() {
        voiceOutput.stop()
    }
    
    /// Prepare audio session for playback (call after STT stops).
    func prepareVoiceForPlayback() {
        voiceOutput.prepareForPlayback()
    }
    
    // MARK: - One-Shot Insight Generation

    /// Generate a one-shot contextual insight for in-app use (Plan Tomorrow, etc.).
    /// Uses OpenAI if available, falls back to Apple Foundation Models.
    /// Returns nil if no LLM backend is available or generation fails.
    func generateInsight(prompt: String) async -> String? {
        await conversation.generateOneShotResponse(prompt: prompt)
    }

    // MARK: - Draft Generation
    
    /// Generate a message draft for a task.
    func generateDraft(taskContent: String, actionType: String, contactName: String?, senderName: String?, categoryLabel: String? = nil) async -> (draft: String, subject: String)? {
        await taskExtractor.generateDraft(
            taskContent: taskContent,
            actionType: actionType,
            contactName: contactName,
            senderName: senderName,
            categoryLabel: categoryLabel
        )
    }
    
    // MARK: - ADHD Support (NEW — Companion Features)
    
    /// Detect emotional state from user's text.
    /// Used to shape response strategy before generating dialogue.
    func detectMood(from text: String) -> NudgyADHDKnowledge.EmotionalRegulation.DetectedMood {
        NudgyADHDKnowledge.EmotionalRegulation.detectMood(from: text)
    }
    
    /// Get response strategy for a detected mood.
    /// Informs whether to suggest tasks, offer breakdown, or just be present.
    func responseStrategy(for mood: NudgyADHDKnowledge.EmotionalRegulation.DetectedMood) -> NudgyADHDKnowledge.EmotionalRegulation.ResponseStrategy {
        NudgyADHDKnowledge.EmotionalRegulation.strategy(for: mood)
    }
    
    /// Get a curated emotional response for the detected mood.
    func emotionalResponse(for mood: NudgyADHDKnowledge.EmotionalRegulation.DetectedMood) -> String {
        dialogue.emotionalResponse(for: mood)
    }
    
    /// Assess paralysis risk for a task.
    func paralysisRisk(for taskContent: String) -> NudgyADHDKnowledge.ExecutiveFunction.ParalysisRisk {
        NudgyADHDKnowledge.ExecutiveFunction.paralysisRisk(taskContent: taskContent)
    }
    
    /// Get micro-step suggestion for a stuck task.
    func microStep(for taskContent: String) -> String {
        dialogue.microStepSuggestion(taskContent: taskContent)
    }
    
    /// Get gentle time context for right now.
    func currentTimeContext() -> String? {
        dialogue.timeContext()
    }
    
    /// Analyze snooze patterns and get insight.
    func analyzeSnoozePattern(snoozeCount: Int, totalTasks: Int, sameTaskSnoozes: Int) -> NudgyADHDKnowledge.PatternRecognition.SnoozeInsight {
        NudgyADHDKnowledge.PatternRecognition.analyzeSnoozePattern(
            snoozeCount: snoozeCount,
            totalTasks: totalTasks,
            sameTaskSnoozes: sameTaskSnoozes
        )
    }
    
    /// Get a gentle suggestion based on snooze patterns.
    func snoozeSuggestion(for insight: NudgyADHDKnowledge.PatternRecognition.SnoozeInsight) -> String? {
        NudgyADHDKnowledge.PatternRecognition.snoozeSuggestion(insight)
    }
    
    /// Get streak acknowledgment message.
    func streakMessage(days: Int) -> String? {
        dialogue.streakMessage(days: days)
    }
    
    // MARK: - Body Doubling
    
    /// Start a body doubling session — Nudgy sits with the user while they work.
    func startBodyDoubling(taskContent: String) async -> String {
        isBodyDoubling = true
        bodyDoublingStart = .now
        
        // Start periodic check-in timer
        startBodyDoublingTimer()
        
        return await dialogue.bodyDoublingStart(taskContent: taskContent)
    }
    
    /// Get body doubling check-in message (called by timer).
    func bodyDoublingCheckIn() -> String? {
        guard let start = bodyDoublingStart else { return nil }
        let minutes = Int(Date.now.timeIntervalSince(start) / 60)
        return dialogue.bodyDoublingCheckIn(minutesElapsed: minutes)
    }
    
    /// End body doubling session.
    func endBodyDoubling() -> String {
        let minutes: Int
        if let start = bodyDoublingStart {
            minutes = Int(Date.now.timeIntervalSince(start) / 60)
        } else {
            minutes = 0
        }
        
        isBodyDoubling = false
        bodyDoublingStart = nil
        bodyDoublingTimer?.invalidate()
        bodyDoublingTimer = nil
        
        return dialogue.bodyDoublingEnd(minutesWorked: minutes)
    }
    
    private func startBodyDoublingTimer() {
        bodyDoublingTimer?.invalidate()
        // Check every 5 minutes during body doubling
        bodyDoublingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor [weak self] in
                guard let self, self.isBodyDoubling else { return }
                if let message = self.bodyDoublingCheckIn() {
                    self.speak(message)
                    // Update penguin speech bubble if state is connected
                    if let state = self.getState() {
                        state.queueDialogue(message, style: .whisper, autoDismiss: 5.0)
                    }
                }
            }
        }
    }
    
    // MARK: - Transition Support
    
    /// Help with task transition — the hard moment between finishing one thing
    /// and starting another.
    func transitionTo(nextTask: String, from previousTask: String? = nil) async -> String {
        await dialogue.transitionSupport(from: previousTask, to: nextTask)
    }
    
    // MARK: - Emotional Check-In
    
    /// Trigger a gentle emotional check-in.
    /// Returns nil if it's too soon since the last check-in.
    func emotionalCheckIn() async -> String? {
        // Don't check in more than once per day
        if let last = lastEmotionalCheckIn,
           Calendar.current.isDateInToday(last) {
            return nil
        }
        
        let daysSinceLast: Int
        if let last = lastEmotionalCheckIn {
            daysSinceLast = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
        } else {
            daysSinceLast = 999
        }
        
        // Find last mood from memory
        let lastMood = memory.store.conversationSummaries.last?.mood
        
        lastEmotionalCheckIn = .now
        
        return await dialogue.emotionalCheckIn(
            lastMood: lastMood,
            daysSinceLastCheckIn: daysSinceLast
        )
    }
    
    /// Whether it's a good time for an emotional check-in.
    var shouldCheckIn: Bool {
        guard let last = lastEmotionalCheckIn else { return true }
        // Check in if it's been more than 2 days
        let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
        return days >= 2
    }
    
    // MARK: - Paralysis Support
    
    /// Get support for when the user is stuck on tasks.
    func paralysisSupport(staleTasks: [String]) async -> String {
        await dialogue.paralysisSupport(staleTasks: staleTasks)
    }
    
    /// Get overwhelm support when there are too many tasks.
    func overwhelmSupport() -> String {
        dialogue.overwhelmSupport()
    }
    
    /// Hyperfocus check-in for extended work sessions.
    func hyperfocusCheckIn() -> String {
        dialogue.hyperfocusCheckIn()
    }
    
    // MARK: - Smart Resurfacing
    
    /// Generate a welcome-back message based on last focused task and time away.
    /// Returns nil if no meaningful context to resurface.
    func welcomeBack(settings: AppSettings, activeQueue: [NudgeItem]) -> String? {
        guard let lastContent = settings.lastFocusedContent,
              let lastFocusedAt = settings.lastFocusedAt else { return nil }
        
        let minutesAway = Int(Date.now.timeIntervalSince(lastFocusedAt) / 60)
        
        // Less than 2 minutes away — no need for welcome back
        guard minutesAway >= 2 else { return nil }
        
        // Check if the last focused task is still active
        let lastTaskStillActive: Bool
        if let lastID = settings.lastFocusedItemID,
           let uuid = UUID(uuidString: lastID) {
            lastTaskStillActive = activeQueue.contains { $0.id == uuid && $0.status == .active }
        } else {
            lastTaskStillActive = false
        }
        
        if lastTaskStillActive {
            if minutesAway < 30 {
                return "Welcome back! You were working on \(lastContent). Ready to finish? 🐧"
            } else if minutesAway < 120 {
                return "Oh, hello again! \(lastContent) is still here waiting. Shall we? 🐧"
            } else {
                return "You were working on \(lastContent) earlier. Want to pick it back up, or start fresh? 🐧"
            }
        }
        
        // Task was completed while away (e.g., from notification)
        return nil
    }
    
    /// Generate an end-of-day summary prompt.
    func endOfDaySummary(completedToday: Int, remainingCount: Int) -> String? {
        guard completedToday > 0 || remainingCount > 0 else { return nil }
        
        if remainingCount == 0 {
            return "You got everything done today! \(completedToday) task\(completedToday == 1 ? "" : "s") finished. Rest well 🌙"
        }
        
        if completedToday > 0 {
            return "You got \(completedToday) of \(completedToday + remainingCount) done today. That counts. \(remainingCount) can wait until tomorrow 💤"
        }
        
        return "Tomorrow’s a new day. \(remainingCount) nudge\(remainingCount == 1 ? "" : "s") ready when you are 🌅"
    }
    
    // MARK: - All Clear / Rest
    
    /// Show all-clear state.
    func showAllClear(doneCount: Int) {
        // Delegate to PenguinState directly via stateAdapter
        // The adapter doesn't have this method, so we go direct
        guard let state = getState() else { return }
        state.showAllClear(doneCount: doneCount)
    }
    
    /// Transition to rest.
    func rest() {
        guard let state = getState() else { return }
        state.rest()
    }
    
    // MARK: - Private
    
    /// Access the connected PenguinState (through adapter).
    func getState() -> PenguinState? {
        stateAdapter.connectedState
    }
}
