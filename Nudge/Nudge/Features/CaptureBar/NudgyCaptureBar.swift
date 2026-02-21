//
//  NudgyCaptureBar.swift
//  Nudge
//
//  THE universal capture + chat surface — available on every tab.
//  This is the single entry point for all user input in the app.
//
//  Dynamic Island-inspired: morphs from a tiny pill into whatever
//  the user needs — text input, voice recorder, task preview,
//  or full Nudgy conversation thread.
//
//  State machine:
//    .collapsed  →  Tiny pill: "Ask Nudgy…" + 🎤
//    .typing     →  Text field + send/mic
//    .recording  →  Waveform + live transcript
//    .processing →  "Nudgy is thinking…"
//    .preview    →  Captured task(s) for review/edit before saving
//    .chatting   →  Conversation thread with reply input
//
//  Replaces: InlineQuickCapture, QuickAddSheet, NudgyHome chat bar,
//  NudgyHome bottom buttons, NudgyChatView.
//

import SwiftUI
import SwiftData

// MARK: - State Machine

enum CaptureBarPhase: Equatable {
    case collapsed
    case typing
    case recording
    case processing
    case preview
    case chatting

    var isExpanded: Bool {
        self != .collapsed
    }
}

// MARK: - Captured Task (local edit model)

struct CapturedTask: Identifiable {
    let id = UUID()
    var content: String
    var emoji: String
    var actionType: ActionType?
    var contactName: String?
    var actionTarget: String?
    var dueDate: Date?
    var priority: TaskPriority
    /// Auto-detected category from content
    var category: TaskCategory?
    /// True when ContactResolver couldn't auto-resolve this contact
    var contactUnresolved: Bool = false
    /// True when a similar task already exists in the active queue
    var possibleDuplicate: Bool = false

    init(from extracted: ExtractedTask) {
        self.content = extracted.content
        self.emoji = extracted.emoji
        self.actionType = extracted.mappedActionType
        self.contactName = extracted.contactName.isEmpty ? nil : extracted.contactName
        self.actionTarget = extracted.actionTarget.isEmpty ? nil : extracted.actionTarget
        self.dueDate = extracted.parsedDueDate
        self.priority = extracted.mappedPriority
        self.category = CategoryClassifier.classify(content: extracted.content, actionType: extracted.mappedActionType)
    }
}

// MARK: - View

struct NudgyCaptureBar: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.selectedTab) private var selectedTab

    // Phase
    @State private var phase: CaptureBarPhase = .collapsed

    // Text input
    @State private var inputText = ""
    @FocusState private var isTextFieldFocused: Bool

    // Task capture
    @State private var capturedTasks: [CapturedTask] = []
    @State private var editingTaskID: UUID? = nil

    // Voice
    @State private var speechService = SpeechService()
    @State private var liveTranscript = ""
    @State private var isBrainDumpRecording = false

    // Keyboard tracking
    @State private var keyboardHeight: CGFloat = 0

    // Swipe-to-dismiss drag
    @State private var dragOffset: CGFloat = 0

    // Smart prompt rotation
    @State private var promptIndex: Int = 0
    @State private var promptTimer: Timer? = nil

    // Post-save "add another" chip
    @State private var showAddAnother = false

    // Contact picker fallback (when auto-resolution fails)
    @State private var showContactPicker = false
    @State private var contactPickerTargetIndex: Int? = nil

    // Auto-dismiss
    @State private var autoDismissTask: Task<Void, Never>?

    // Live category preview (debounced while typing)
    @State private var liveCategory: TaskCategory?
    @State private var liveCategoryDebounce: Task<Void, Never>?

    // External callback
    var onDataChanged: () -> Void = {}

    // MARK: - Layout Constants

    private let pillHeight: CGFloat = 40
    private let pillRadius: CGFloat = 20
    private let expandedRadius: CGFloat = 24

    /// Safe area bottom inset detected from the device.
    /// On physical iPhones this includes the home indicator + tab bar.
    @State private var safeAreaBottom: CGFloat = 0

    // MARK: - Smooth spring

    private var smoothSpring: Animation {
        reduceMotion ? .default : .spring(response: 0.38, dampingFraction: 0.84)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrim overlay when expanded
            if phase.isExpanded {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
                    .transition(.opacity)
                    .zIndex(0)
            }

            // The bar, anchored to bottom
            barContent
                .offset(y: dragOffset)
                .gesture(swipeToDismissGesture)
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.bottom, effectiveBottomPadding)
                .zIndex(1)

            // Post-save "add another" chip
            if showAddAnother {
                addAnotherChip
                    .padding(.bottom, effectiveBottomPadding + pillHeight + DesignTokens.spacingSM)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
            }

            // Invisible geometry reader to detect safe area insets
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        safeAreaBottom = geo.safeAreaInsets.bottom
                    }
                    .onChange(of: geo.safeAreaInsets.bottom) { _, newValue in
                        safeAreaBottom = newValue
                    }
            }
            .frame(height: 0)
            .allowsHitTesting(false)
        }
        .animation(smoothSpring, value: phase)
        .animation(smoothSpring, value: capturedTasks.count)
        .animation(smoothSpring, value: keyboardHeight)
        .animation(smoothSpring, value: showAddAnother)
        .onChange(of: inputText) { _, newValue in
            liveCategoryDebounce?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 3 {
                withAnimation(.easeOut(duration: 0.15)) { liveCategory = nil }
                return
            }
            liveCategoryDebounce = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                let detected = CategoryClassifier.classify(content: trimmed, actionType: nil)
                withAnimation(.easeOut(duration: 0.2)) {
                    liveCategory = detected == .general ? nil : detected
                }
            }
        }
        .onChange(of: speechService.state) { _, newState in
            handleSpeechState(newState)
        }
        // Route notifications through the capture bar
        .onReceive(NotificationCenter.default.publisher(for: .nudgeOpenQuickAdd)) { _ in
            expandToTyping()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeOpenChat)) { _ in
            expandToTyping()
        }
        // Keyboard tracking
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        // Smart prompt rotation (only while collapsed)
        .onAppear { startPromptRotation() }
        .onDisappear { promptTimer?.invalidate() }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .collapsed {
                startPromptRotation()
            } else {
                promptTimer?.invalidate()
            }
        }
        // Contact picker fallback — opens when auto-resolution fails
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView(
                onContactSelected: { name, phone, email in
                    if let idx = contactPickerTargetIndex, capturedTasks.indices.contains(idx) {
                        capturedTasks[idx].contactName = name
                        if let actionType = capturedTasks[idx].actionType {
                            capturedTasks[idx].actionTarget = ContactHelper.actionTarget(
                                phone: phone, email: email, for: actionType
                            )
                        }
                        capturedTasks[idx].contactUnresolved = false
                    }
                    showContactPicker = false
                    contactPickerTargetIndex = nil
                },
                onCancelled: {
                    showContactPicker = false
                    contactPickerTargetIndex = nil
                }
            )
        }
    }

    /// When the keyboard is up, ride the bar above it; otherwise sit above tab bar.
    private var effectiveBottomPadding: CGFloat {
        if keyboardHeight > 0 {
            // Keyboard is showing — sit just above it (subtract safe area since keyboard height includes it)
            return keyboardHeight - safeAreaBottom
        }
        // Above the tab bar: safe area bottom covers home indicator,
        // add clearance for the ~49pt tab bar strip itself.
        return max(safeAreaBottom + 8, 56)
    }

    // MARK: - Swipe to Dismiss Gesture

    private var swipeToDismissGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Only allow downward swipe
                if value.translation.height > 0 && phase.isExpanded {
                    dragOffset = value.translation.height * 0.6 // dampened
                }
            }
            .onEnded { value in
                if value.translation.height > 60 && phase.isExpanded {
                    dismiss()
                }
                withAnimation(smoothSpring) { dragOffset = 0 }
            }
    }

    // MARK: - Bar Content

    private var barContent: some View {
        VStack(spacing: 0) {
            // Expanded area grows upward
            expandedArea

            // The pill strip is always at the bottom of the card
            pillStrip
        }
        .contentShape(.rect(cornerRadius: phase.isExpanded ? expandedRadius : pillRadius))
        .glassEffect(
            .regular,
            in: .rect(cornerRadius: phase.isExpanded ? expandedRadius : pillRadius)
        )
        .shadow(
            color: .black.opacity(phase.isExpanded ? 0.35 : 0.12),
            radius: phase.isExpanded ? 24 : 8,
            y: 2
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Pill Strip (phase-dependent bottom row)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var pillStrip: some View {
        switch phase {
        case .collapsed:    collapsedPill
        case .typing:       typingPill
        case .recording:    recordingPill
        case .processing:   processingPill
        case .preview:      previewActionBar
        case .chatting:     chattingPill
        }
    }

    // MARK: Collapsed

    private var collapsedPill: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Plus icon — clear affordance to add
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.accentActive)

            Text(currentPlaceholder)
                .font(AppTheme.footnote.weight(.medium))
                .foregroundStyle(DesignTokens.textSecondary)
                .contentTransition(.opacity)
                .id("placeholder-\(promptIndex)")

            Spacer()

            // Chat history count (if any)
            if !penguinState.chatMessages.isEmpty {
                Button {
                    withAnimation(smoothSpring) { phase = .chatting }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.15))
                        isTextFieldFocused = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 10))
                        Text("\(penguinState.chatMessages.count)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(DesignTokens.accentActive.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignTokens.accentActive.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }

            // Mic button — tap = single capture, long-press = brain dump
            Image(systemName: "mic.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignTokens.accentActive)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
                .onTapGesture { startRecording() }
                .onLongPressGesture(minimumDuration: 0.5) {
                    startBrainDumpRecording()
                }
                .nudgeAccessibility(
                    label: String(localized: "Voice input"),
                    hint: String(localized: "Tap to add a task. Hold for unload mode."),
                    traits: .isButton
                )
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .frame(height: 44)
        .background {
            Capsule().fill(DesignTokens.accentActive.opacity(0.08))
        }
        .contentShape(Capsule())
        .onTapGesture { expandToTyping() }
        .nudgeAccessibility(
            label: String(localized: "Add a nudge"),
            hint: String(localized: "Tap to type a task, or use the mic to speak"),
            traits: .isButton
        )
    }

    // MARK: Typing

    private var typingPill: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.spacingSM) {
                TextField(
                    String(localized: "Add a task, ask anything…"),
                    text: $inputText,
                    axis: .vertical
                )
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(1...4)
                .submitLabel(.send)
                .focused($isTextFieldFocused)
                .onSubmit { submitText() }

                if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Mic when text is empty — tap = single, long-press = brain dump
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignTokens.accentActive)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .onTapGesture { startRecording() }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            startBrainDumpRecording()
                        }
                } else {
                    // Send arrow when text entered
                    Button { submitText() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM + 2)
            
            // Live category preview chip
            if let cat = liveCategory {
                HStack(spacing: 4) {
                    Image(systemName: cat.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(cat.primaryColor)
                    Text(cat.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(cat.primaryColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(cat.primaryColor.opacity(0.15))
                        .overlay(
                            Capsule()
                                .strokeBorder(cat.primaryColor.opacity(0.3), lineWidth: 0.5)
                        )
                )
                .transition(.scale.combined(with: .opacity))
                .padding(.bottom, DesignTokens.spacingXS)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.spacingMD)
            }
        }
    }

    // MARK: Recording

    private var recordingPill: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Live waveform
            HStack(spacing: 2) {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(DesignTokens.accentActive)
                        .frame(width: 2.5, height: waveBarHeight(for: i))
                }
            }
            .frame(height: 20)

            if liveTranscript.isEmpty {
                Text(isBrainDumpRecording
                     ? String(localized: "Unload mode — keep talking…")
                     : String(localized: "Listening…"))
                    .font(AppTheme.footnote)
                    .foregroundStyle(isBrainDumpRecording
                                     ? DesignTokens.accentStale
                                     : DesignTokens.textTertiary)
            } else {
                Text(liveTranscript)
                    .font(AppTheme.footnote)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(2)
            }

            Spacer()

            // Stop button (red square)
            Button { stopRecording() } label: {
                ZStack {
                    Circle()
                        .fill(DesignTokens.accentOverdue.opacity(0.15))
                        .frame(width: 30, height: 30)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DesignTokens.accentOverdue)
                        .frame(width: 10, height: 10)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.vertical, DesignTokens.spacingMD)
    }

    // MARK: Processing

    private var processingPill: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(DesignTokens.accentActive)

            Text(String(localized: "Nudgy is thinking…"))
                .font(AppTheme.footnote)
                .foregroundStyle(DesignTokens.textSecondary)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .frame(height: pillHeight)
    }

    // MARK: Preview Action Bar

    private var previewActionBar: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.accentComplete)

            Text(capturedTasks.count == 1
                 ? String(localized: "1 nudge captured")
                 : String(localized: "\(capturedTasks.count) nudges captured"))
                .font(AppTheme.footnote.weight(.medium))
                .foregroundStyle(DesignTokens.textPrimary)

            Spacer()

            Button { dismiss() } label: {
                Text(String(localized: "Cancel"))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .buttonStyle(.plain)

            Button { saveAllTasks() } label: {
                Text(String(localized: "Save"))
                    .font(AppTheme.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, 6)
                    .background(DesignTokens.accentActive, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .frame(height: pillHeight)
    }

    // MARK: Chatting Pill (reply bar + rewind)

    private var chattingPill: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Rewind / clear history
            if !penguinState.chatMessages.isEmpty {
                Button {
                    withAnimation(smoothSpring) {
                        NudgyEngine.shared.clearChat()
                    }
                    dismiss()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "Clear conversation"),
                    hint: String(localized: "Reset chat history with Nudgy"),
                    traits: .isButton
                )
            }

            // Reply text field
            TextField(
                String(localized: "Reply to Nudgy…"),
                text: $inputText,
                axis: .vertical
            )
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(DesignTokens.textPrimary)
            .lineLimit(1...3)
            .submitLabel(.send)
            .focused($isTextFieldFocused)
            .onSubmit { submitText() }

            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
            } else {
                Button { submitText() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(DesignTokens.accentActive)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM + 2)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Expanded Area (content above the pill)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var expandedArea: some View {
        switch phase {
        case .preview where !capturedTasks.isEmpty:
            previewCards
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))

        case .chatting:
            conversationThread
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))

        default:
            EmptyView()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Preview Cards
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var previewCards: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            ForEach(Array(capturedTasks.enumerated()), id: \.element.id) { index, _ in
                taskRow(at: index)
            }
        }
        .padding(.horizontal, DesignTokens.spacingSM)
        .padding(.top, DesignTokens.spacingMD)
        .padding(.bottom, DesignTokens.spacingXS)
    }

    private func taskRow(at index: Int) -> some View {
        let task = capturedTasks[index]
        let isEditing = editingTaskID == task.id

        return HStack(spacing: DesignTokens.spacingSM) {
            // Task icon
            Image(systemName: TaskIconResolver.resolveSymbol(for: task.emoji))
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.accentActive)
                .frame(width: 20)

            if isEditing {
                // Inline editing
                TextField(String(localized: "Edit task…"), text: Binding(
                    get: { capturedTasks.indices.contains(index) ? capturedTasks[index].content : "" },
                    set: { newValue in
                        if capturedTasks.indices.contains(index) {
                            capturedTasks[index].content = newValue
                        }
                    }
                ))
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .onSubmit { editingTaskID = nil }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.content)
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(2)

                    // Action badge (call/text/email)
                    if let action = task.actionType {
                        HStack(spacing: 3) {
                            Image(systemName: actionIcon(for: action))
                                .font(.system(size: 9))
                            Text(task.contactName ?? action.rawValue)
                                .font(.system(size: 10, weight: .medium))
                            // Unresolved contact warning
                            if task.contactUnresolved {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(DesignTokens.accentStale)
                            }
                        }
                        .foregroundStyle(task.contactUnresolved
                            ? DesignTokens.accentStale.opacity(0.9)
                            : DesignTokens.accentActive.opacity(0.7))
                        .onTapGesture {
                            if task.contactUnresolved {
                                contactPickerTargetIndex = index
                                showContactPicker = true
                            }
                        }
                    }
                    
                    // Duplicate warning
                    if task.possibleDuplicate {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 9))
                            Text(String(localized: "Similar task exists"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(DesignTokens.accentStale.opacity(0.9))
                    }
                    
                    // Category chip
                    if let cat = task.category, cat != .general {
                        HStack(spacing: 3) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(cat.primaryColor)
                            Text(cat.label)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(cat.primaryColor.opacity(0.9))
                    }
                }
            }

            Spacer(minLength: 4)

            // Edit / confirm toggle
            Button {
                withAnimation(smoothSpring) {
                    editingTaskID = isEditing ? nil : task.id
                }
            } label: {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)

            // Delete
            Button {
                let taskID = task.id
                withAnimation(smoothSpring) {
                    capturedTasks.removeAll { $0.id == taskID }
                    if capturedTasks.isEmpty { dismiss() }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignTokens.textTertiary.opacity(0.5))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.spacingSM)
        .padding(.vertical, DesignTokens.spacingSM)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func actionIcon(for action: ActionType) -> String {
        switch action {
        case .call:          return "phone.fill"
        case .text:          return "message.fill"
        case .email:         return "envelope.fill"
        case .openLink:      return "link"
        case .search:        return "magnifyingglass"
        case .navigate:      return "map.fill"
        case .addToCalendar: return "calendar"
        case .setAlarm:      return "alarm.fill"
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Conversation Thread
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var conversationThread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignTokens.spacingSM) {
                    let recent = penguinState.chatMessages.suffix(20)
                    ForEach(recent) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    // Typing indicator
                    if penguinState.isChatGenerating {
                        typingIndicator
                            .id("capture-bar-typing")
                    }
                }
                .padding(.horizontal, DesignTokens.spacingSM)
                .padding(.vertical, DesignTokens.spacingSM)
            }
            .frame(maxHeight: 240)
            .onChange(of: penguinState.chatMessages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    if penguinState.isChatGenerating {
                        proxy.scrollTo("capture-bar-typing", anchor: .bottom)
                    } else if let lastID = penguinState.chatMessages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        if message.role == .system {
            Text(message.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.horizontal, DesignTokens.spacingSM)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                if message.role == .user { Spacer(minLength: 56) }

                if message.role == .nudgy {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                        .padding(.bottom, 2)
                }

                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingSM + 2)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(message.role == .user
                                  ? DesignTokens.accentActive.opacity(0.25)
                                  : Color.white.opacity(0.06))
                    )
                    .frame(maxWidth: 260, alignment: message.role == .user ? .trailing : .leading)

                if message.role == .nudgy { Spacer(minLength: 56) }
            }
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DesignTokens.accentActive.opacity(0.5))
                    .frame(width: 5, height: 5)
                    .offset(y: penguinState.isChatGenerating ? -2 : 2)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.12),
                        value: penguinState.isChatGenerating
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, DesignTokens.spacingSM)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Helpers
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // MARK: Waveform

    private func waveBarHeight(for index: Int) -> CGFloat {
        let samples = speechService.waveformSamples
        guard index < samples.count else { return 3 }
        return max(3, min(18, CGFloat(samples[index]) * 40 + 3))
    }

    // MARK: Expand

    private func expandToTyping() {
        guard phase == .collapsed else { return }
        HapticService.shared.prepare()
        showAddAnother = false
        withAnimation(smoothSpring) {
            phase = .typing
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
            isTextFieldFocused = true
        }
    }

    // MARK: Recording

    private func startRecording() {
        HapticService.shared.micStart()
        liveTranscript = ""

        withAnimation(smoothSpring) {
            phase = .recording
        }

        speechService.silenceAutoSendEnabled = true
        do {
            try speechService.startRecording()
        } catch {
            withAnimation(smoothSpring) { phase = .collapsed }
        }
    }

    private func startBrainDumpRecording() {
        HapticService.shared.actionButtonTap()
        liveTranscript = ""
        isBrainDumpRecording = true

        withAnimation(smoothSpring) {
            phase = .recording
        }

        // Brain dump keeps listening longer — disable auto-send on silence
        speechService.silenceAutoSendEnabled = false
        do {
            try speechService.startRecording()
        } catch {
            isBrainDumpRecording = false
            withAnimation(smoothSpring) { phase = .collapsed }
        }
    }

    private func stopRecording() {
        speechService.stopRecording()
        HapticService.shared.micStop()
        let wasBrainDump = isBrainDumpRecording
        isBrainDumpRecording = false

        let transcript = speechService.liveTranscript
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcript.isEmpty {
            if wasBrainDump {
                // Brain dump always goes to multi-task extraction
                processBrainDump(transcript)
            } else {
                processInput(transcript)
            }
        } else {
            withAnimation(smoothSpring) { phase = .collapsed }
        }
    }

    private func handleSpeechState(_ newState: SpeechService.SpeechState) {
        switch newState {
        case .recording:
            liveTranscript = speechService.liveTranscript
        case .silenceDetected(let transcript):
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { processInput(trimmed) }
        case .finished(let transcript):
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                processInput(trimmed)
            } else {
                withAnimation(smoothSpring) { phase = .collapsed }
            }
        case .error:
            withAnimation(smoothSpring) { phase = .collapsed }
        default:
            if phase == .recording { liveTranscript = speechService.liveTranscript }
        }
    }

    // MARK: Submit

    private func submitText() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isTextFieldFocused = false
        let text = trimmed
        inputText = ""
        processInput(text)
    }

    private func processInput(_ text: String) {
        autoDismissTask?.cancel()
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ── Layer 1: Instant local extraction for obvious task patterns ──
        // No spinner, no API — feels instant.
        if let instant = tryInstantExtraction(lower, original: text) {
            Task {
                var captured = CapturedTask(from: instant)
                captured = await resolveContactForTask(captured)
                checkForDuplicate(&captured)
                withAnimation(smoothSpring) {
                    capturedTasks = [captured]
                    phase = .preview
                }
                HapticService.shared.swipeDone()
            }
            return
        }
        
        // ── Layer 2: Conversational / emotional → pure chat ──
        if isConversational(lower) {
            withAnimation(smoothSpring) { phase = .processing }
            Task { await handleChat(text) }
            return
        }
        
        // ── Layer 3: Ambiguous input → chat-first with smart routing ──
        // Nudgy processes it conversationally AND extracts tasks.
        // If AI finds a clear task, show preview. If not, Nudgy responds helpfully.
        withAnimation(smoothSpring) { phase = .processing }
        Task { await handleSmartRoute(text) }
    }
    
    // MARK: - Instant Local Extraction (No AI)
    
    /// Matches clear, short task patterns and returns immediately.
    /// "call mom", "buy milk", "text Sarah about dinner", "email boss report" etc.
    private func tryInstantExtraction(_ lower: String, original: String) -> ExtractedTask? {
        // ── URL detection — instant "Open Link" task ──
        if let urlMatch = original.range(of: "https?://\\S+", options: .regularExpression) {
            let url = String(original[urlMatch])
            let label = original.replacingOccurrences(of: url, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let content = label.isEmpty ? "Open link" : label
            return ExtractedTask(
                content: content,
                emoji: "link",
                actionType: "LINK",
                contactName: "",
                actionTarget: url,
                isActionable: true,
                priority: detectPriority(lower),
                dueDateString: detectDueDate(lower)
            )
        }
        
        let words = lower.split(separator: " ").map(String.init)
        guard words.count >= 2, words.count <= 12 else { return nil }
        
        // Action verb patterns: call/text/message/email + name
        let actionVerbs: [(prefix: String, type: String, emoji: String)] = [
            ("call ",    "CALL",  "phone.fill"),
            ("ring ",    "CALL",  "phone.fill"),
            ("phone ",   "CALL",  "phone.fill"),
            ("text ",    "TEXT",  "message.fill"),
            ("message ", "TEXT",  "message.fill"),
            ("msg ",     "TEXT",  "message.fill"),
            ("email ",   "EMAIL", "envelope.fill"),
            ("mail ",    "EMAIL", "envelope.fill"),
        ]
        
        for verb in actionVerbs {
            if lower.hasPrefix(verb.prefix) {
                let rest = String(original.dropFirst(verb.prefix.count)).trimmingCharacters(in: .whitespaces)
                let contactName = extractNameFromRest(rest)
                return ExtractedTask(
                    content: original.prefix(1).uppercased() + original.dropFirst(),
                    emoji: verb.emoji,
                    actionType: verb.type,
                    contactName: contactName,
                    actionTarget: "",
                    isActionable: true,
                    priority: detectPriority(lower),
                    dueDateString: detectDueDate(lower)
                )
            }
        }
        
        // Navigate/search/calendar action verbs
        let richActionVerbs: [(prefix: String, type: String, emoji: String)] = [
            ("navigate to ", "NAVIGATE", "location.fill"),
            ("directions to ", "NAVIGATE", "location.fill"),
            ("drive to ",   "NAVIGATE", "car.fill"),
            ("go to ",      "NAVIGATE", "location.fill"),
            ("search ",     "SEARCH",   "magnifyingglass"),
            ("google ",     "SEARCH",   "magnifyingglass"),
            ("look up ",    "SEARCH",   "magnifyingglass"),
            ("find ",       "SEARCH",   "magnifyingglass"),
            ("schedule ",   "CALENDAR", "calendar.badge.plus"),
            ("book ",       "CALENDAR", "calendar.badge.plus"),
            ("set up meeting ", "CALENDAR", "calendar.badge.plus"),
            ("add event ",  "CALENDAR", "calendar.badge.plus"),
        ]
        
        for verb in richActionVerbs {
            if lower.hasPrefix(verb.prefix) {
                let rest = String(original.dropFirst(verb.prefix.count)).trimmingCharacters(in: .whitespaces)
                return ExtractedTask(
                    content: original.prefix(1).uppercased() + original.dropFirst(),
                    emoji: verb.emoji,
                    actionType: verb.type,
                    contactName: "",
                    actionTarget: rest,
                    isActionable: true,
                    priority: detectPriority(lower),
                    dueDateString: detectDueDate(lower)
                )
            }
        }
        
        // Simple task verbs
        let taskVerbs: [(prefix: String, emoji: String)] = [
            ("buy ",       "cart.fill"),
            ("get ",       "bag.fill"),
            ("pick up ",   "bag.fill"),
            ("grab ",      "bag.fill"),
            ("order ",     "cart.fill"),
            ("cancel ",    "xmark.circle.fill"),
            ("return ",    "arrow.uturn.left"),
            ("exchange ",  "arrow.uturn.left"),
            ("clean ",     "sparkles"),
            ("tidy ",      "sparkles"),
            ("organize ",  "sparkles"),
            ("fix ",       "wrench.fill"),
            ("repair ",    "wrench.fill"),
            ("update ",    "arrow.clockwise"),
            ("send ",      "paperplane.fill"),
            ("pay ",       "dollarsign.circle.fill"),
            ("deposit ",   "dollarsign.circle.fill"),
            ("transfer ",  "dollarsign.circle.fill"),
            ("finish ",    "checkmark.circle.fill"),
            ("complete ",  "checkmark.circle.fill"),
            ("submit ",    "paperplane.fill"),
            ("renew ",     "arrow.clockwise"),
            ("sign up ",   "pencil"),
            ("register ",  "pencil"),
            ("apply for ", "pencil"),
            ("remind me ", "bell.fill"),
            ("remember to ", "bell.fill"),
            ("don't forget ", "bell.fill"),
            ("need to ",   "exclamationmark.circle.fill"),
            ("gotta ",     "exclamationmark.circle.fill"),
            ("have to ",   "exclamationmark.circle.fill"),
            ("must ",      "exclamationmark.circle.fill"),
            ("do ",        "checkmark.circle"),
            ("make ",      "hammer.fill"),
            ("prepare ",   "hammer.fill"),
            ("cook ",      "fork.knife"),
            ("take ",      "hand.raised.fill"),
            ("drop off ",  "shippingbox.fill"),
            ("deliver ",   "shippingbox.fill"),
            ("check ",     "magnifyingglass"),
            ("look into ", "magnifyingglass"),
            ("research ",  "magnifyingglass"),
            ("review ",    "doc.text.magnifyingglass"),
            ("read ",      "book.fill"),
            ("watch ",     "play.rectangle.fill"),
            ("listen to ", "headphones"),
            ("practice ",  "figure.run"),
            ("study ",     "book.fill"),
            ("learn ",     "lightbulb.fill"),
            ("write ",     "pencil.line"),
            ("draft ",     "pencil.line"),
            ("plan ",      "list.bullet"),
            ("pack ",      "suitcase.fill"),
            ("move ",      "shippingbox.fill"),
            ("set up ",    "gearshape.fill"),
            ("install ",   "arrow.down.circle.fill"),
            ("charge ",    "battery.100.bolt"),
            ("wash ",      "drop.fill"),
            ("water ",     "drop.fill"),
            ("feed ",      "leaf.fill"),
            ("walk ",      "figure.walk"),
        ]
        
        for verb in taskVerbs {
            if lower.hasPrefix(verb.prefix) {
                return ExtractedTask(
                    content: original.prefix(1).uppercased() + original.dropFirst(),
                    emoji: verb.emoji,
                    actionType: "",
                    contactName: "",
                    actionTarget: "",
                    isActionable: true,
                    priority: detectPriority(lower),
                    dueDateString: detectDueDate(lower)
                )
            }
        }
        
        return nil
    }
    
    /// Extract a likely contact name from the rest of the string after an action verb.
    private func extractNameFromRest(_ rest: String) -> String {
        let stopWords: Set<String> = [
            "about", "regarding", "re", "the", "to", "for", "that",
            "when", "by", "and", "tomorrow", "today", "tonight",
            "asap", "urgent", "later", "soon", "back"
        ]
        var nameWords: [String] = []
        for word in rest.split(separator: " ").map(String.init) {
            if stopWords.contains(word.lowercased()) { break }
            nameWords.append(word)
            if nameWords.count >= 3 { break } // Max 3-word name
        }
        return nameWords.joined(separator: " ")
    }
    
    private func detectPriority(_ lower: String) -> String {
        if lower.contains("urgent") || lower.contains("asap") || lower.contains("important") || lower.contains("deadline") { return "high" }
        if lower.contains("maybe") || lower.contains("someday") || lower.contains("whenever") { return "low" }
        return "medium"
    }
    
    private func detectDueDate(_ lower: String) -> String {
        if lower.contains("today") || lower.contains("tonight") { return "today" }
        if lower.contains("tomorrow") { return "tomorrow" }
        if lower.contains("next week") { return "next week" }
        if lower.contains("this week") { return "this week" }
        return ""
    }
    
    // MARK: - Duplicate Detection
    
    /// Check if a similar task already exists in the active queue.
    /// Uses normalized fuzzy matching — "Buy milk" matches "buy milk from store".
    private func checkForDuplicate(_ task: inout CapturedTask) {
        let repo = NudgeRepository(modelContext: modelContext)
        let active = repo.fetchActiveQueue()
        let normalizedNew = task.content.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract core words (drop filler)
        let fillerWords: Set<String> = ["a", "an", "the", "my", "some", "to", "for", "from"]
        let newWords = Set(normalizedNew.split(separator: " ")
            .map(String.init)
            .filter { !fillerWords.contains($0) })
        
        for existing in active {
            let existingNorm = existing.content.lowercased()
            let existingWords = Set(existingNorm.split(separator: " ")
                .map(String.init)
                .filter { !fillerWords.contains($0) })
            
            // High overlap = likely duplicate
            let intersection = newWords.intersection(existingWords)
            let smaller = min(newWords.count, existingWords.count)
            if smaller > 0 && Double(intersection.count) / Double(smaller) >= 0.7 {
                task.possibleDuplicate = true
                return
            }
        }
    }

    /// Pure conversational check — questions, greetings, emotional support.
    private func isConversational(_ lower: String) -> Bool {
        if lower.contains("?") { return true }

        let chatPrefixes = [
            "what", "how", "why", "when", "where", "who",
            "can you", "could you", "do you", "are you", "is there",
            "tell me", "help me", "show me",
            "i'm feeling", "i feel", "i need help", "i can't", "i don't know",
            "thank", "thanks", "hi ", "hey ", "hello",
            "good morning", "good afternoon", "good evening"
        ]
        if chatPrefixes.contains(where: { lower.hasPrefix($0) }) { return true }

        let emotionalWords = [
            "overwhelmed", "stressed", "anxious", "frustrated", "tired",
            "can't focus", "distracted", "procrastinating", "paralyzed",
            "struggling", "burned out", "unmotivated"
        ]
        if emotionalWords.contains(where: { lower.contains($0) }) { return true }

        return false
    }
    
    // MARK: Smart Route (Layer 3)
    
    /// For ambiguous input: try AI extraction. If the result is actionable,
    /// show task preview. If not, route to chat so Nudgy helps clarify.
    @MainActor
    private func handleSmartRoute(_ text: String) async {
        let extracted = await NudgyEngine.shared.extractTask(from: text)
        
        if extracted.isActionable && !extracted.content.isEmpty {
            // AI found a real task — show preview
            var captured = CapturedTask(from: extracted)
            captured = await resolveContactForTask(captured)
            checkForDuplicate(&captured)
            withAnimation(smoothSpring) {
                capturedTasks = [captured]
                phase = .preview
            }
            HapticService.shared.swipeDone()
        } else {
            // Not clearly a task — let Nudgy chat about it
            await handleChat(text)
        }
    }

    // MARK: Chat

    @MainActor
    private func handleChat(_ text: String) async {
        NudgyEngine.shared.chat(text, modelContext: modelContext)

        // Wait for generation to complete (max ~10s)
        var ticks = 0
        while NudgyEngine.shared.isGenerating && ticks < 100 {
            try? await Task.sleep(for: .milliseconds(100))
            ticks += 1
        }

        withAnimation(smoothSpring) {
            phase = .chatting
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
            isTextFieldFocused = true
        }

        // Auto-dismiss after 15s — ADHD users may need more time to read/process
        scheduleAutoDismiss(seconds: 15)
    }

    // MARK: Brain Dump

    private func processBrainDump(_ text: String) {
        autoDismissTask?.cancel()
        withAnimation(smoothSpring) { phase = .processing }

        Task {
            let tasks = await NudgyEngine.shared.splitBrainDump(transcript: text)
            var captured = tasks.map { CapturedTask(from: $0) }
            if captured.isEmpty {
                let fallback = await NudgyEngine.shared.extractTask(from: text)
                captured = [CapturedTask(from: fallback)]
            }
            captured = await resolveContactsForTasks(captured)
            withAnimation(smoothSpring) {
                capturedTasks = captured
                phase = .preview
            }
            HapticService.shared.swipeDone()
        }
    }

    // MARK: - Contact Resolution Failsafe
    
    /// Resolve contacts for an array of tasks — proactive failsafe.
    /// If AI extracted a contactName but no actionTarget, we attempt on-device
    /// contact resolution BEFORE showing the preview. If resolution fails,
    /// we mark the task so the UI can surface a "contact not found" indicator.
    @MainActor
    private func resolveContactsForTasks(_ tasks: [CapturedTask]) async -> [CapturedTask] {
        var resolved = tasks
        for i in resolved.indices {
            resolved[i] = await resolveContactForTask(resolved[i])
        }
        return resolved
    }
    
    /// Resolve contact for a single task. Three-layer failsafe:
    /// 1. If actionTarget already populated (from AI) — validate it.
    /// 2. If contactName exists but no actionTarget — resolve via CNContactStore.
    /// 3. If resolution fails — flag as unresolved so UI shows manual-pick hint.
    @MainActor
    private func resolveContactForTask(_ task: CapturedTask) async -> CapturedTask {
        var task = task
        
        // Only process tasks with a contact-relevant action type
        guard let actionType = task.actionType,
              [.call, .text, .email].contains(actionType) else {
            return task
        }
        
        // Layer 1: actionTarget already filled — trust AI (could be phone/email/url)
        if let target = task.actionTarget, !target.isEmpty {
            return task
        }
        
        // Layer 2: contactName exists but no target — resolve from Contacts
        if let name = task.contactName, !name.isEmpty {
            let (target, resolvedName) = await ContactResolver.shared.resolveActionTarget(
                name: name,
                for: actionType
            )
            if let target, !target.isEmpty {
                task.actionTarget = target
                // Use the full resolved name from Contacts (e.g. "mom" → "Sarah Johnson")
                if let resolvedName, !resolvedName.isEmpty {
                    task.contactName = resolvedName
                }
                task.contactUnresolved = false
                return task
            }
        }
        
        // Layer 3: Resolution failed — flag for UI
        if task.contactName != nil {
            task.contactUnresolved = true
        }
        
        return task
    }

    // MARK: Tab-Aware Placeholder + Smart Prompt Rotation

    /// Rotating prompts per tab — ADHD users benefit from variety.
    private static let nudgyPrompts: [LocalizedStringResource] = [
        "Chat with Nudgy…",
        "How are you feeling?",
        "Need help focusing?",
        "What\'s on your mind?"
    ]

    private static let nudgesPrompts: [LocalizedStringResource] = [
        "Type to add a nudge…",
        "What do you need to do?",
        "Capture a thought…",
        "Add a task…"
    ]

    private static let youPrompts: [LocalizedStringResource] = [
        "Ask anything…",
        "Change a setting?",
        "How\'s your streak going?"
    ]

    private var currentPlaceholder: String {
        let prompts: [LocalizedStringResource]
        switch selectedTab {
        case .nudgy:  prompts = Self.nudgyPrompts
        case .nudges: prompts = Self.nudgesPrompts
        case .you:    prompts = Self.youPrompts
        }
        let index = promptIndex % prompts.count
        return String(localized: prompts[index])
    }

    private func startPromptRotation() {
        promptTimer?.invalidate()
        promptTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.4)) {
                    promptIndex += 1
                }
            }
        }
    }

    // MARK: Add Another Chip

    private var addAnotherChip: some View {
        Button {
            showAddAnother = false
            expandToTyping()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text(String(localized: "Add another"))
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(DesignTokens.accentActive)
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .background(
                Capsule()
                    .fill(DesignTokens.accentActive.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Save

    private func saveAllTasks() {
        let repo = NudgeRepository(modelContext: modelContext)

        for task in capturedTasks {
            _ = repo.createManualWithDetails(
                content: task.content,
                emoji: task.emoji,
                actionType: task.actionType,
                actionTarget: task.actionTarget,
                contactName: task.contactName,
                priority: task.priority,
                dueDate: task.dueDate
            )
        }

        HapticService.shared.swipeDone()
        SoundService.shared.playTaskDone()
        onDataChanged()

        withAnimation(smoothSpring) {
            capturedTasks = []
            editingTaskID = nil
            phase = .collapsed
            showAddAnother = true
        }

        // Switch to the Nudges tab first, THEN post data-changed
        // so NudgesPageView is visible and can receive the refresh.
        let needsTabSwitch = selectedTab != .nudges
        Task { @MainActor in
            if needsTabSwitch {
                try? await Task.sleep(for: .seconds(0.15))
                NotificationCenter.default.post(name: .nudgeSwitchToNudges, object: nil)
                try? await Task.sleep(for: .seconds(0.2))
            } else {
                try? await Task.sleep(for: .seconds(0.05))
            }
            NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        }

        // Auto-hide the "add another" chip after 4s
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(smoothSpring) { showAddAnother = false }
        }
    }

    // MARK: Dismiss

    private func dismiss() {
        autoDismissTask?.cancel()
        isTextFieldFocused = false
        editingTaskID = nil
        isBrainDumpRecording = false
        showAddAnother = false

        if phase == .recording {
            speechService.stopRecording()
        }

        withAnimation(smoothSpring) {
            phase = .collapsed
            capturedTasks = []
            inputText = ""
            liveTranscript = ""
            dragOffset = 0
        }
    }

    private func scheduleAutoDismiss(seconds: Double) {
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !isTextFieldFocused {
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            Text("Page content here")
                .foregroundStyle(.gray)
            Spacer()
        }
        NudgyCaptureBar()
    }
    .preferredColorScheme(.dark)
    .environment(PenguinState())
}
