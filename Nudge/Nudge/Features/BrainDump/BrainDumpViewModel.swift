//
//  BrainDumpViewModel.swift
//  Nudge
//
//  Orchestrates the brain dump flow:
//  1. Mic tap → SpeechService starts recording
//  2. Stop → transcript finalized
//  3. AIService splits into tasks (on-device Apple Intelligence)
//  4. User reviews → saves to SwiftData
//

import SwiftUI
import SwiftData
import TipKit
import os

@Observable
final class BrainDumpViewModel {
    
    // MARK: - State
    
    enum Phase: Equatable {
        case idle
        case recording
        case processing
        case results([SplitTask])
        case error(String)
        
        /// Simple tag for Equatable observation (ignoring associated values).
        var tag: String {
            switch self {
            case .idle: return "idle"
            case .recording: return "recording"
            case .processing: return "processing"
            case .results: return "results"
            case .error: return "error"
            }
        }
    }
    
    private(set) var phase: Phase = .idle
    private(set) var editableTasks: [EditableTask] = []
    
    private var speechService = SpeechService()
    
    var isRecording: Bool { speechService.isRecording }
    var liveTranscript: String { speechService.liveTranscript }
    var remainingTime: TimeInterval { speechService.remainingTime }
    var showCountdown: Bool { speechService.showCountdown }
    var audioLevel: Float { speechService.audioLevel }
    var waveformSamples: [Float] { speechService.waveformSamples }
    
    // MARK: - Editable Task (for review screen)
    
    struct EditableTask: Identifiable {
        let id = UUID()
        var content: String
        var emoji: String?
        var actionType: ActionType?
        var actionTarget: String?
        var contactName: String?
        var priority: TaskPriority
        var dueDate: Date?
        var category: TaskCategory?
        var isIncluded: Bool = true
    }
    
    // MARK: - Toggle Recording
    
    @MainActor
    func toggleRecording() async {
        if isRecording {
            stopAndProcess()
        } else {
            await startRecording()
        }
    }
    
    @MainActor
    private func startRecording() async {
        let authorized = await speechService.requestPermission()
        guard authorized else {
            if case .error(let msg) = speechService.state {
                phase = .error(msg)
            }
            return
        }
        
        do {
            try speechService.startRecording()
            phase = .recording
            HapticService.shared.micStart()
            SoundService.shared.playBrainDumpStart()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    private func stopAndProcess() {
        HapticService.shared.micStop()
        speechService.stopRecording()
        
        let transcript: String
        if case .finished(let text) = speechService.state {
            transcript = text
        } else {
            transcript = speechService.liveTranscript
        }
        
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .idle
            return
        }
        
        phase = .processing
        
        Task {
            await processTranscript(transcript)
        }
    }
    
    // MARK: - Text Input (type instead of speak)
    
    /// Process typed text through the same AI extraction pipeline as voice.
    @MainActor
    func processTypedInput(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard phase.tag != "processing" else { return }
        
        Log.ui.debug("[BrainDump] Processing typed input (\(trimmed.count) chars): \"\(trimmed.prefix(100))...\"")
        phase = .processing
        Task {
            await processTranscript(trimmed)
        }
    }
    
    // MARK: - AI Processing
    
    @MainActor
    private func processTranscript(_ transcript: String) async {
        // Route through NudgyEngine for OpenAI-powered task extraction
        let extractedTasks = await NudgyEngine.shared.splitBrainDump(transcript: transcript)
        
        // Convert ExtractedTask to SplitTask for backward compat with .results phase
        let splitTasks = extractedTasks.map { task in
            SplitTask(
                task: task.content,
                emoji: task.emoji,
                action: task.actionType,
                contact: task.contactName,
                actionTarget: task.actionTarget
            )
        }
        
        editableTasks = extractedTasks.map { task in
            let mappedAction = task.mappedActionType
            let inferredCategory = CategoryClassifier.classify(content: task.content, actionType: mappedAction)
            return EditableTask(
                content: task.content,
                emoji: task.emoji.isEmpty ? nil : task.emoji,
                actionType: mappedAction,
                actionTarget: task.actionTarget.isEmpty ? nil : task.actionTarget,
                contactName: task.contactName.isEmpty ? nil : task.contactName,
                priority: task.mappedPriority,
                dueDate: task.parsedDueDate,
                category: inferredCategory
            )
        }
        
        if editableTasks.isEmpty {
            // Offline or API error — save as single task
            editableTasks = [
                EditableTask(
                    content: transcript,
                    emoji: "📝",
                    actionType: nil,
                    actionTarget: nil,
                    contactName: nil,
                    priority: .medium,
                    dueDate: nil
                )
            ]
            phase = .results([
                SplitTask(task: transcript, emoji: "📝", action: "", contact: "", actionTarget: "")
            ])
        } else {
            phase = .results(splitTasks)
        }
    }
    
    // MARK: - Save Tasks
    
    /// Save all included tasks to SwiftData
    @MainActor
    func saveTasks(modelContext: ModelContext, settings: AppSettings) {
        let includedTasks = editableTasks.filter(\.isIncluded)
        guard !includedTasks.isEmpty else { return }
        
        // Create brain dump record
        let dump = BrainDump(rawTranscript: speechService.liveTranscript)
        modelContext.insert(dump)
        
        let repository = NudgeRepository(modelContext: modelContext)
        
        for task in includedTasks {
            let item = repository.createFromBrainDump(
                content: task.content,
                emoji: task.emoji,
                actionType: task.actionType,
                actionTarget: task.actionTarget,
                contactName: task.contactName,
                priority: task.priority,
                dueDate: task.dueDate,
                category: task.category,
                brainDump: dump
            )
            
            // If the task has a contact name but no target, try resolving in the background
            if task.actionTarget == nil,
               let contactName = task.contactName,
               let actionType = task.actionType {
                Task {
                    let (target, resolvedName) = await ContactResolver.shared.resolveActionTarget(
                        name: contactName,
                        for: actionType
                    )
                    if let target, !target.isEmpty {
                        item.actionTarget = target
                        if let resolvedName { item.contactName = resolvedName }
                        do { try modelContext.save() } catch { Log.data.error("[BrainDump] Contact resolve save failed: \(error, privacy: .public)") }
                    }
                }
            }
        }
        
        do {
            try modelContext.save()
            // Notify NudgesView to refresh — without this, new tasks don't appear
            NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        } catch {
            Log.data.error("Failed to save brain dump tasks: \(error, privacy: .public)")
            phase = .error(String(localized: "Couldn't save your tasks. Please try again."))
            return
        }
        
        // Record usage for free tier
        settings.recordBrainDump()
        
        // Invalidate TipKit tips
        Task {
            await BrainDumpTip.brainDumpCompleted.donate()
            await ShareTip.firstBrainDumpDone.donate()
        }
        
        // Haptic feedback
        HapticService.shared.shareSaved()
        
        reset()
    }
    
    // MARK: - Reset
    
    func reset() {
        speechService.reset()
        phase = .idle
        editableTasks = []
    }
    
    // MARK: - Update Task
    
    func updateTaskContent(id: UUID, content: String) {
        if let index = editableTasks.firstIndex(where: { $0.id == id }) {
            editableTasks[index].content = content
        }
    }
    
    func toggleTaskInclusion(id: UUID) {
        if let index = editableTasks.firstIndex(where: { $0.id == id }) {
            editableTasks[index].isIncluded.toggle()
        }
    }
}
