//
//  CardView.swift
//  Nudge
//
//  The dark translucent task card — the heart of the One-Thing View.
//  Supports swipe gestures: right = Done, left = Snooze, down = Skip.
//  Accent border color driven by task status. Action button for call/text/link.
//

import SwiftUI

struct CardView: View {
    
    let item: NudgeItem
    let queuePosition: Int
    let queueTotal: Int
    
    var onDone: () -> Void
    var onSnooze: () -> Void
    var onSkip: () -> Void
    var onAction: () -> Void
    var onBreakDown: (() -> Void)?
    
    @State private var dragOffset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var showGreenFlash = false
    @State private var showParticles = false
    @State private var isDragging = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Computed
    
    private var category: TaskCategory { item.resolvedCategory }
    
    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }
    
    /// Category-tinted border color — uses category primary when idle, swipe-direction color during drag.
    private var borderColor: Color {
        if showGreenFlash { return categoryCompletionColor }
        if swipeDirection != .none { return swipeHintColor }
        // Idle: blend category color with status accent
        return category == .general ? accentColor : category.primaryColor
    }
    
    /// Category-specific completion flash color instead of generic green.
    private var categoryCompletionColor: Color {
        category == .general ? DesignTokens.accentComplete : category.primaryColor
    }
    
    private var swipeDirection: SwipeDirection {
        if dragOffset.width > AnimationConstants.swipeDoneThreshold { return .done }
        if dragOffset.width < -AnimationConstants.swipeSnoozeThreshold { return .snooze }
        if dragOffset.height > AnimationConstants.swipeSkipThreshold { return .skip }
        return .none
    }
    
    private var swipeHintColor: Color {
        switch swipeDirection {
        case .done:   return categoryCompletionColor
        case .snooze: return DesignTokens.accentStale
        case .skip:   return DesignTokens.textTertiary
        case .none:   return accentColor
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                cardContent
                    .offset(dragOffset)
                    .rotationEffect(.degrees(rotation))
                    .gesture(swipeGesture)
                    .animation(
                        isDragging ? .interactiveSpring() : AnimationConstants.cardSnapBack,
                        value: dragOffset
                    )
                
                // Queue position indicator
                if queueTotal > 1 {
                    Text("\(queuePosition) of \(queueTotal)")
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                        .padding(.top, DesignTokens.spacingMD)
                }
            }
            
            // Particle burst on completion
            CompletionParticles(isActive: $showParticles)
        }
        .nudgeAccessibilityElement(
            label: cardAccessibilityLabel,
            hint: String(localized: "Swipe right to complete, left to snooze, down to skip")
        )
        .nudgeAccessibilityAction(name: String(localized: "Complete")) { onDone() }
        .nudgeAccessibilityAction(name: String(localized: "Snooze")) { onSnooze() }
        .nudgeAccessibilityAction(name: String(localized: "Skip")) { onSkip() }
    }
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        DarkCard(
            accentColor: borderColor,
            showPulse: item.isStale
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                // Icon + Category chip + Source icon
                HStack {
                    TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .medium)
                    
                    // Category chip (non-general only)
                    if category != .general {
                        HStack(spacing: 3) {
                            Image(systemName: category.icon)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(category.primaryColor)
                            Text(category.label)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(category.primaryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(category.primaryColor.opacity(0.12))
                        )
                    }
                    
                    Spacer()
                    
                    // Source indicator
                    Image(systemName: item.sourceType.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                
                // Task text
                Text(item.content)
                    .font(AppTheme.taskTitle)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Metadata row
                HStack(spacing: DesignTokens.spacingSM) {
                    Text(item.createdAt.relativeDescription)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                    
                    if item.isOverdue {
                        Label(String(localized: "Overdue"), systemImage: "exclamationmark.triangle.fill")
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.accentOverdue)
                    } else if item.isStale {
                        Label(String(localized: "Stale"), systemImage: "exclamationmark.circle")
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.accentStale)
                    }
                    
                    if let contactName = item.contactName {
                        Label(contactName, systemImage: "person.fill")
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
                
                // Action button
                if item.hasAction, let actionType = item.actionType {
                    actionButton(for: actionType)
                }
                
                // AI Draft preview (Pro)
                if item.hasDraft, let draft = item.aiDraft {
                    draftPreview(draft)
                }
                
                // Break it down button (AI-powered coaching)
                if AIService.shared.isAvailable, let onBreakDown {
                    breakDownButton(action: onBreakDown)
                }
                
                // Swipe hints
                swipeHints
            }
        }
        .padding(.horizontal, DesignTokens.spacingLG)
    }
    
    // MARK: - Action Button
    
    private func actionButton(for action: ActionType) -> some View {
        Button {
            HapticService.shared.actionButtonTap()
            onAction()
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: action.icon)
                Text(action.label)
                    .font(AppTheme.body.weight(.semibold))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                    .fill(accentColor.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: "\(action.label) \(item.contactName ?? "")",
            hint: String(localized: "Double tap to \(action.label.lowercased())"),
            traits: .isButton
        )
    }
    
    // MARK: - Draft Preview
    
    @State private var draftExpanded = false
    @State private var draftCopied = false
    
    // MARK: - Break It Down Button
    
    private func breakDownButton(action: @escaping () -> Void) -> some View {
        Button {
            HapticService.shared.prepare()
            action()
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                Text(String(localized: "Break it down"))
                    .font(AppTheme.caption.weight(.medium))
            }
            .foregroundStyle(DesignTokens.accentActive)
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingXS + 2)
            .background(
                Capsule()
                    .fill(DesignTokens.accentActive.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(DesignTokens.accentActive.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: String(localized: "Break it down"),
            hint: String(localized: "Ask Nudgy to split this task into smaller steps"),
            traits: .isButton
        )
    }
    
    private func draftPreview(_ draft: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            Button {
                withAnimation(AnimationConstants.sheetPresent) {
                    draftExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "text.bubble.fill")
                        .foregroundStyle(accentColor)
                    Text(String(localized: "AI Draft"))
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.textSecondary)
                    Spacer()
                    Image(systemName: draftExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .buttonStyle(.plain)
            
            if draftExpanded {
                Text(draft)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .padding(DesignTokens.spacingMD)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .fill(Color.white.opacity(0.05))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                
                // Copy draft button
                Button {
                    UIPasteboard.general.string = draft
                    HapticService.shared.prepare()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        draftCopied = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation(.easeOut(duration: 0.25)) {
                            draftCopied = false
                        }
                    }
                } label: {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: draftCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                        Text(draftCopied ? String(localized: "Copied!") : String(localized: "Copy Draft"))
                            .font(AppTheme.caption)
                    }
                    .foregroundStyle(draftCopied ? DesignTokens.accentComplete : DesignTokens.accentActive)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingXS)
                    .background(
                        Capsule()
                            .fill((draftCopied ? DesignTokens.accentComplete : DesignTokens.accentActive).opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "Copy draft to clipboard"),
                    hint: String(localized: "Copies the AI-generated draft text"),
                    traits: .isButton
                )
            }
        }
    }
    
    // MARK: - Swipe Hints
    
    private var swipeHints: some View {
        HStack {
            Label(String(localized: "Snooze"), systemImage: "arrow.left")
                .foregroundStyle(swipeDirection == .snooze ? DesignTokens.accentStale : DesignTokens.textTertiary)
            
            Spacer()
            
            Label(String(localized: "Skip"), systemImage: "arrow.down")
                .foregroundStyle(swipeDirection == .skip ? DesignTokens.textSecondary : DesignTokens.textTertiary)
            
            Spacer()
            
            Label(String(localized: "Done"), systemImage: "arrow.right")
                .foregroundStyle(swipeDirection == .done ? categoryCompletionColor : DesignTokens.textTertiary)
        }
        .font(AppTheme.footnote)
        .padding(.top, DesignTokens.spacingXS)
    }
    
    // MARK: - Swipe Gesture
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
                
                // Rotation proportional to horizontal drag (max ±15°)
                let maxDrag: CGFloat = 200
                let progress = min(abs(value.translation.width) / maxDrag, 1.0)
                rotation = Double(progress * AnimationConstants.swipeDoneRotation) *
                    (value.translation.width > 0 ? 1 : -1)
            }
            .onEnded { value in
                isDragging = false
                
                switch swipeDirection {
                case .done:
                    commitDone()
                case .snooze:
                    commitSnooze()
                case .skip:
                    commitSkip()
                case .none:
                    // Snap back
                    withAnimation(AnimationConstants.cardSnapBack) {
                        dragOffset = .zero
                        rotation = 0
                    }
                }
            }
    }
    
    // MARK: - Commit Actions
    
    private func commitDone() {
        HapticService.shared.swipeDone()
        SoundService.shared.playTaskDone()
        
        // Particle burst
        showParticles = true
        
        // Green flash
        withAnimation(.easeOut(duration: AnimationConstants.greenFlashDuration)) {
            showGreenFlash = true
        }
        
        // Fly off screen
        let animation = reduceMotion
            ? AnimationConstants.reducedMotionFade
            : AnimationConstants.cardSwipeDone
        
        withAnimation(animation) {
            dragOffset = CGSize(width: 500, height: 0)
            rotation = AnimationConstants.swipeDoneRotation
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.4))
            onDone()
            resetCard()
        }
    }
    
    private func commitSnooze() {
        HapticService.shared.swipeSnooze()
        SoundService.shared.playSnooze()
        
        let animation = reduceMotion
            ? AnimationConstants.reducedMotionFade
            : AnimationConstants.cardSwipeSnooze
        
        withAnimation(animation) {
            dragOffset = CGSize(width: -400, height: 0)
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            onSnooze()
            resetCard()
        }
    }
    
    private func commitSkip() {
        HapticService.shared.swipeSkip()
        
        let animation = reduceMotion
            ? AnimationConstants.reducedMotionFade
            : AnimationConstants.cardSwipeSkip
        
        withAnimation(animation) {
            dragOffset = CGSize(width: 0, height: 500)
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            onSkip()
            resetCard()
        }
    }
    
    private func resetCard() {
        withAnimation(AnimationConstants.cardSnapBack) {
            dragOffset = .zero
            rotation = 0
        }
        showGreenFlash = false
    }
    
    // MARK: - Accessibility
    
    private var cardAccessibilityLabel: String {
        let cat = item.resolvedCategory
        var label = cat != .general
            ? "\(cat.label) \(String(localized: "task")): \(item.content)"
            : item.content
        if item.isStale { label += ", \(String(localized: "stale for")) \(item.ageInDays) \(String(localized: "days"))" }
        if let contact = item.contactName { label += ", \(contact)" }
        if let action = item.actionType { label += ", \(action.label)" }
        label += ", \(queuePosition) \(String(localized: "of")) \(queueTotal)"
        return label
    }
}

// MARK: - Swipe Direction

private enum SwipeDirection {
    case done, snooze, skip, none
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        CardView(
            item: {
                let item = NudgeItem(
                    content: "Call the dentist to book a cleaning",
                    emoji: "📞",
                    actionType: .call,
                    contactName: "Dr. Chen"
                )
                return item
            }(),
            queuePosition: 1,
            queueTotal: 5,
            onDone: {},
            onSnooze: {},
            onSkip: {},
            onAction: {}
        )
    }
}
