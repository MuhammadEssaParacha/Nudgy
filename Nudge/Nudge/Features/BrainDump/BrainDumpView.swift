//
//  BrainDumpView.swift
//  Nudge
//
//  Full-screen overlay: mic button → waveform → penguin thinking → task cards.
//  Presented as .fullScreenCover from ContentView.
//

import SwiftUI
import SwiftData

struct BrainDumpView: View {
    
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var viewModel = BrainDumpViewModel()
    @State private var micScale: CGFloat = 1.0
    @State private var glowOpacity: Double = AnimationConstants.glowMinOpacity
    @State private var showPaywall = false
    @State private var showCloseConfirmation = false
    @State private var audioFeedTask: Task<Void, Never>?
    @State private var showTextInput = false
    @State private var typedText = ""
    @FocusState private var textFieldFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close button
                closeButton
                
                Spacer()
                
                // Main content changes by phase
                switch viewModel.phase {
                case .idle:
                    idleState
                case .recording:
                    recordingState
                case .processing:
                    processingState
                case .results:
                    resultsState
                case .error(let message):
                    errorState(message)
                }
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.phase.tag) { _, _ in
            handlePhaseChange(viewModel.phase)
        }
        .onDisappear {
            stopAudioFeed()
            penguinState.exitBrainDump()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                // If recording, processing, or showing results, confirm before closing
                switch viewModel.phase {
                case .recording, .processing, .results:
                    showCloseConfirmation = true
                default:
                    viewModel.reset()
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(DesignTokens.spacingLG)
            .nudgeAccessibility(label: String(localized: "Close"), traits: .isButton)
            .confirmationDialog(
                String(localized: "Discard brain unload?"),
                isPresented: $showCloseConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Discard"), role: .destructive) {
                    viewModel.reset()
                    isPresented = false
                }
                Button(String(localized: "Keep Recording"), role: .cancel) {}
            } message: {
                Text(String(localized: "Your recording and any extracted tasks will be lost."))
            }
        }
    }
    
    // MARK: - Idle State
    
    private var idleState: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            // Nudgy in greeting/idle pose — he speaks the instruction
            PenguinSceneView(
                size: .large,
                expressionOverride: .waving,
                accentColorOverride: DesignTokens.accentActive
            )
            .onAppear {
                penguinState.interactionMode = .ambient
                penguinState.expression = .waving
                penguinState.say(
                    NudgyDialogueEngine.shared.brainDumpStart(),
                    style: .speech,
                    autoDismiss: nil  // Stay until mic tap
                )
            }
            
            Text(String(localized: "Brain Unload"))
                .font(AppTheme.displayFont)
                .foregroundStyle(DesignTokens.textPrimary)
            
            if showTextInput {
                // Text input mode
                textInputView
            } else {
                micButton
            }
            
            // Toggle between mic and keyboard
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showTextInput.toggle()
                    if showTextInput {
                        textFieldFocused = true
                    }
                }
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: showTextInput ? "mic.fill" : "keyboard")
                        .font(.system(size: 14))
                    Text(showTextInput
                         ? String(localized: "Use voice instead")
                         : String(localized: "Type instead"))
                        .font(AppTheme.caption)
                }
                .foregroundStyle(DesignTokens.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.spacingSM)
            
            // Free tier indicator
            if !settings.isPro {
                let remaining = FreeTierLimits.maxDailyBrainDumps - settings.dailyDumpsUsed
                Text(String(localized: "\(remaining) unloads left today"))
                    .font(AppTheme.caption)
                    .foregroundStyle(remaining > 0 ? DesignTokens.textTertiary : DesignTokens.accentOverdue)
            }
        }
    }
    
    // MARK: - Recording State
    
    private var recordingState: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            // Countdown timer (shows in last 10 seconds)
            if viewModel.showCountdown {
                Text("\(Int(viewModel.remainingTime))s")
                    .font(AppTheme.displayFont)
                    .foregroundStyle(DesignTokens.accentOverdue)
                    .transition(.opacity)
            } else {
                Text(String(localized: "Listening..."))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.accentActive)
            }
            
            // Penguin in listening mode with waveform
            PenguinSceneView(
                size: .large,
                expressionOverride: .listening,
                accentColorOverride: DesignTokens.accentActive
            )
            
            // Waveform visualization
            waveformView
            
            micButton
            
            // Live transcript
            if !viewModel.liveTranscript.isEmpty {
                ScrollView {
                    Text(viewModel.liveTranscript)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .padding(DesignTokens.spacingLG)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
                .padding(.horizontal, DesignTokens.spacingXL)
            }
            
            Text(String(localized: "Tap mic to stop"))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .nudgeAnnouncement(String(localized: "Recording started"))
    }
    
    // MARK: - Waveform Visualization
    
    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(Array(viewModel.waveformSamples.enumerated()), id: \.offset) { _, sample in
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.accentActive)
                    .frame(width: 4, height: max(4, CGFloat(sample) * 40 + 4))
                    .animation(.easeOut(duration: 0.1), value: sample)
            }
        }
        .frame(height: 48)
        .nudgeAccessibility(
            label: String(localized: "Audio waveform"),
            hint: String(localized: "Shows voice input levels")
        )
    }
    
    // MARK: - Text Input View
    
    private var textInputView: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            TextEditor(text: $typedText)
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(DesignTokens.spacingMD)
                .frame(minHeight: 120, maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                .stroke(DesignTokens.accentActive.opacity(0.3), lineWidth: 0.5)
                        )
                )
                .focused($textFieldFocused)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(String(localized: "Done")) {
                            textFieldFocused = false
                        }
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if typedText.isEmpty {
                        Text(String(localized: "Unload everything on your mind...\ne.g. \"Call dentist tomorrow, pay rent by the 5th, text Sarah about dinner tonight, maybe get car washed\""))
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textTertiary)
                            .padding(DesignTokens.spacingMD)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
            
            Button {
                if !settings.canDoBrainDump {
                    HapticService.shared.error()
                    showPaywall = true
                    return
                }
                HapticService.shared.micStop()
                viewModel.processTypedInput(typedText)
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(String(localized: "Extract Tasks"))
                }
                .font(AppTheme.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                        .fill(typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? DesignTokens.textTertiary
                              : DesignTokens.accentActive)
                )
            }
            .buttonStyle(.plain)
            .disabled(typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.phase.tag == "processing")
        }
        .padding(.horizontal, DesignTokens.spacingXL)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    // MARK: - Mic Button
    
    private var micButton: some View {
        Button {
            if !settings.canDoBrainDump && !viewModel.isRecording {
                HapticService.shared.error()
                showPaywall = true
                return
            }
            Task {
                await viewModel.toggleRecording()
            }
        } label: {
            ZStack {
                // Glow ring (pulses while recording)
                Circle()
                    .stroke(DesignTokens.accentActive, lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .opacity(viewModel.isRecording ? glowOpacity : 0)
                    .scaleEffect(viewModel.isRecording ? 1.3 : 1.0)
                
                // Button background
                Circle()
                    .fill(DesignTokens.accentActive)
                    .frame(width: 80, height: 80)
                
                // Mic icon
                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(micScale)
        }
        .buttonStyle(.plain)
        .onAppear {
            if !reduceMotion {
                withAnimation(AnimationConstants.glowPulse) {
                    glowOpacity = AnimationConstants.glowMaxOpacity
                }
            }
        }
        .nudgeAccessibility(
            label: viewModel.isRecording
                ? String(localized: "Stop recording")
                : String(localized: "Start brain unload recording"),
            traits: .isButton
        )
    }
    
    // MARK: - Processing State
    
    private var processingState: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            PenguinSceneView(
                size: .large,
                expressionOverride: .thinking,
                accentColorOverride: DesignTokens.accentActive
            )
        }
        .nudgeAnnouncement(String(localized: "Processing your brain unload"))
    }
    
    // MARK: - Results State
    
    private var resultsState: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Text(String(localized: "\(viewModel.editableTasks.filter(\.isIncluded).count) tasks found"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            // Phase 14: Category distribution strip — proportional colored bar
            categoryDistributionStrip
            
            ScrollView {
                VStack(spacing: DesignTokens.spacingMD) {
                    ForEach(Array(viewModel.editableTasks.enumerated()), id: \.element.id) { index, task in
                        taskResultCard(task, index: index)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                )
                            )
                            .animation(
                                AnimationConstants.cardAppear.delay(Double(index) * AnimationConstants.cardStaggerDelay),
                                value: viewModel.editableTasks.count
                            )
                    }
                }
                .padding(.horizontal, DesignTokens.spacingLG)
            }
            .frame(maxHeight: 400)
            
            // Save button
            Button {
                viewModel.saveTasks(modelContext: modelContext, settings: settings)
                isPresented = false
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(String(localized: "Save \(viewModel.editableTasks.filter(\.isIncluded).count) Tasks"))
                }
                .font(AppTheme.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                        .fill(DesignTokens.accentActive)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.spacingXL)
            .nudgeAccessibility(
                label: String(localized: "Save selected tasks"),
                traits: .isButton
            )
        }
        .nudgeAnnouncement(String(localized: "\(viewModel.editableTasks.count) tasks extracted"))
    }
    
    // MARK: - Task Result Card
    
    private func taskResultCard(_ task: BrainDumpViewModel.EditableTask, index: Int) -> some View {
        DarkCard(accentColor: task.isIncluded ? DesignTokens.accentActive : DesignTokens.textTertiary) {
            HStack(spacing: DesignTokens.spacingMD) {
                // Inclusion toggle
                Button {
                    HapticService.shared.snoozeTimeSelected()
                    viewModel.toggleTaskInclusion(id: task.id)
                } label: {
                    Image(systemName: task.isIncluded ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(task.isIncluded ? DesignTokens.accentActive : DesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    HStack {
                        if let emoji = task.emoji {
                            StepIconView(emoji: emoji, size: 16)
                        }
                        
                        Text(task.content)
                            .font(AppTheme.body)
                            .foregroundStyle(task.isIncluded ? DesignTokens.textPrimary : DesignTokens.textTertiary)
                    }
                    
                    // Priority and due date badges
                    HStack(spacing: DesignTokens.spacingSM) {
                        // Priority badge
                        HStack(spacing: 2) {
                            Image(systemName: task.priority.icon)
                                .font(.system(size: 10))
                            Text(task.priority.label)
                                .font(AppTheme.caption)
                        }
                        .foregroundStyle(priorityColor(for: task.priority))
                        
                        // Due date badge
                        if let dueDate = task.dueDate {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(dueDate, format: .dateTime.month(.abbreviated).day())
                                    .font(AppTheme.caption)
                            }
                            .foregroundStyle(DesignTokens.accentStale)
                        }
                    }
                    
                    if let action = task.actionType {
                        HStack(spacing: 4) {
                            Image(systemName: action.icon)
                            Text(action.label)
                            if let contact = task.contactName {
                                Text("· \(contact)")
                            }
                        }
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.accentActive)
                    }
                    
                    // Category chip (pre-classified during extraction)
                    if let cat = task.category, cat != .general {
                        CategoryChip(category: cat, small: true)
                    }
                }
                
                Spacer()
            }
        }
        .opacity(task.isIncluded ? 1.0 : 0.5)
    }
    
    // MARK: - Category Distribution Strip (Phase 14)
    
    /// Proportional colored bar showing category distribution of extracted tasks.
    private var categoryDistributionStrip: some View {
        let included = viewModel.editableTasks.filter(\.isIncluded)
        let catCounts: [(category: TaskCategory, count: Int)] = {
            var counts: [TaskCategory: Int] = [:]
            for task in included {
                let cat = task.category ?? .general
                counts[cat, default: 0] += 1
            }
            return counts
                .map { (category: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
        }()
        let total = max(included.count, 1)
        
        return Group {
            if catCounts.count > 1 || (catCounts.first?.category != .general) {
                VStack(spacing: DesignTokens.spacingSM) {
                    // Proportional bar
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            ForEach(catCounts, id: \.category) { stat in
                                let fraction = CGFloat(stat.count) / CGFloat(total)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: stat.category.gradientColors,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(geo.size.width * fraction, 4))
                            }
                        }
                    }
                    .frame(height: 6)
                    .clipShape(Capsule())
                    
                    // Emoji legend row
                    HStack(spacing: DesignTokens.spacingSM) {
                        ForEach(catCounts.prefix(5), id: \.category) { stat in
                            HStack(spacing: 2) {
                                Image(systemName: stat.category.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(stat.category.primaryColor)
                                Text("\(stat.count)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(stat.category.primaryColor)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, DesignTokens.spacingLG)
            }
        }
    }
    
    // MARK: - Penguin State Wiring
    
    /// Handle phase transitions — wire penguin state to each brain dump phase.
    private func handlePhaseChange(_ phase: BrainDumpViewModel.Phase) {
        switch phase {
        case .idle:
            stopAudioFeed()
            penguinState.exitBrainDump()
            penguinState.expression = .waving
            
        case .recording:
            penguinState.startListening()
            startAudioFeed()
            
        case .processing:
            stopAudioFeed()
            penguinState.startProcessing()
            
        case .results(let tasks):
            HapticService.shared.shareSaved()
            penguinState.showResults(taskCount: tasks.count)
            
        case .error:
            stopAudioFeed()
            penguinState.expression = .confused
            penguinState.say(
                NudgyDialogueEngine.shared.errorLine(),
                style: .speech,
                autoDismiss: nil
            )
        }
    }
    
    /// Start feeding audio levels from SpeechService into PenguinState.
    private func startAudioFeed() {
        stopAudioFeed()
        audioFeedTask = Task {
            while !Task.isCancelled {
                penguinState.updateAudioLevel(
                    viewModel.audioLevel,
                    samples: viewModel.waveformSamples
                )
                try? await Task.sleep(for: .milliseconds(50)) // 20fps audio updates
            }
        }
    }
    
    /// Stop the audio feed loop.
    private func stopAudioFeed() {
        audioFeedTask?.cancel()
        audioFeedTask = nil
        penguinState.resetAudio()
    }
    
    // MARK: - Priority Color
    
    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .high: return DesignTokens.accentOverdue
        case .medium: return DesignTokens.accentActive
        case .low: return DesignTokens.textTertiary
        }
    }
    
    // MARK: - Error State
    
    private func errorState(_ message: String) -> some View {
        VStack(spacing: DesignTokens.spacingXL) {
            // Nudgy shows confusion — he speaks the error
            PenguinSceneView(
                size: .large,
                expressionOverride: .confused,
                accentColorOverride: DesignTokens.accentOverdue
            )
            
            Text(message)
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.spacingXL)
            
            Button {
                HapticService.shared.actionButtonTap()
                viewModel.reset()
            } label: {
                Text(String(localized: "Try Again"))
                    .accentButtonStyle()
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Try Again"),
                hint: String(localized: "Start a new brain unload"),
                traits: .isButton
            )
        }
    }
}

// MARK: - Preview

#Preview {
    BrainDumpView(isPresented: .constant(true))
        .modelContainer(for: [NudgeItem.self, BrainDump.self], inMemory: true)
        .environment(AppSettings())
        .environment(PenguinState())
}
