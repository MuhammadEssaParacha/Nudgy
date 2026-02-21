//
//  FocusTimerView.swift
//  Nudge
//
//  "Antarctic Focus" — an immersive, ADHD-optimized deep work experience.
//
//  Phase flow: Setup → 3-2-1 Countdown → Focusing → (Break) → Completion
//  - Breathing ring animation anchors attention (combats time agnosia)
//  - Nudgy companion reacts in real-time (body doubling effect)
//  - Distraction parking lot captures stray thoughts without leaving focus
//  - Session summary celebrates the effort, not just the outcome
//  - Pomodoro-aware: configurable focus/break intervals
//

import SwiftUI
import SwiftData
import os

// MARK: - Session Phase

enum FocusPhase: Equatable {
    case setup
    case countdown
    case focusing
    case paused
    case breakTime
    case completed
}

// MARK: - Focus Timer State

@Observable
final class FocusTimerState {
    // Configuration
    var focusMinutes: Int = 25
    var breakMinutes: Int = 5
    var sessionsTarget: Int = 1
    var sessionsCompleted: Int = 0
    
    // Timing
    var totalSeconds: Int = 0
    var remainingSeconds: Int = 0
    var breakTotalSeconds: Int = 0
    var breakRemainingSeconds: Int = 0
    var phase: FocusPhase = .setup
    
    // Tracking
    var distractions: [String] = []
    var totalFocusedSeconds: Int = 0  // Across all sessions in this sitting
    
    // Computed
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
    
    var breakProgress: Double {
        guard breakTotalSeconds > 0 else { return 0 }
        return Double(breakTotalSeconds - breakRemainingSeconds) / Double(breakTotalSeconds)
    }
    
    var elapsedSeconds: Int { totalSeconds - remainingSeconds }
    
    var formattedRemaining: String {
        let t = phase == .breakTime ? breakRemainingSeconds : remainingSeconds
        let mins = t / 60
        let secs = t % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var formattedElapsed: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var isActive: Bool {
        switch phase {
        case .focusing, .paused, .breakTime: return true
        default: return false
        }
    }
}

// MARK: - Focus Timer View

struct FocusTimerView: View {
    
    let item: NudgeItem
    @Binding var isPresented: Bool
    
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var timer = FocusTimerState()
    @State private var tickTimer: Timer?
    
    // Animations
    @State private var ringBreathing = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var countdownNumber: Int = 3
    @State private var countdownVisible = false
    
    // Encouragement
    @State private var encouragementText: String = ""
    @State private var showEncouragement = false
    @State private var lastEncouragementElapsed: Int = 0
    
    // Nudgy companion
    @State private var nudgyExpression: PenguinExpression = .idle
    @State private var nudgyMessage: String = ""
    @State private var showNudgyBubble = false
    
    // Distraction capture
    @State private var showDistractionCapture = false
    @State private var distractionText: String = ""
    
    // Completion
    @State private var showCompletionParticles = false
    @State private var completionAppeared = false
    
    // Ring breathing
    @State private var ringScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Immersive background
            focusBackground
                .ignoresSafeArea()
            
            switch timer.phase {
            case .setup:
                setupPhaseView
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                
            case .countdown:
                countdownOverlay
                    .transition(.opacity)
                
            case .focusing, .paused:
                focusingPhaseView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                
            case .breakTime:
                breakPhaseView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                
            case .completed:
                completionPhaseView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Distraction capture overlay
            if showDistractionCapture {
                distractionCaptureOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
            
            // Completion particles
            if showCompletionParticles {
                CompletionParticles(isActive: $showCompletionParticles)
                    .allowsHitTesting(false)
                    .zIndex(99)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Set default from AI estimate
            if let estimate = item.estimatedMinutes, estimate > 0 {
                timer.focusMinutes = estimate
            }
        }
        .onDisappear {
            // Record any in-progress focus time before losing the view
            if timer.phase == .focusing || timer.phase == .paused {
                timer.totalFocusedSeconds += timer.elapsedSeconds
            }
            recordFocusTime()
            tickTimer?.invalidate()
            tickTimer = nil
        }
    }
    
    // MARK: - Immersive Antarctic Background
    
    private var focusBackground: some View {
        GeometryReader { geo in
            ZStack {
                AntarcticEnvironment(
                    mood: RewardService.shared.environmentMood,
                    unlockedProps: RewardService.shared.unlockedProps,
                    fishCount: RewardService.shared.fish,
                    level: RewardService.shared.level,
                    stage: StageTier.from(level: RewardService.shared.level),
                    sceneWidth: geo.size.width,
                    sceneHeight: geo.size.height,
                    isActive: timer.isActive || timer.phase == .setup,
                    timeOverride: .night
                )
                // Frosted veil — scene stays atmospheric without competing
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Setup Phase
    
    private var setupPhaseView: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 44, height: 44)
                        .background {
                            Circle().fill(Color.white.opacity(0.10))
                        }
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .nudgeAccessibility(label: String(localized: "Close focus timer"), hint: nil, traits: .isButton)
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)
            
            Spacer()
            
            // Task info card
            VStack(spacing: DesignTokens.spacingLG) {
                // Nudgy greeting
                PenguinSceneView(
                    size: .medium,
                    expressionOverride: .waving,
                    accentColorOverride: DesignTokens.accentActive
                )
                
                // Glass card for task details
                VStack(spacing: DesignTokens.spacingMD) {
                    TaskIconView(
                        emoji: item.emoji,
                        actionType: item.actionType,
                        size: .large,
                        accentColor: DesignTokens.accentActive
                    )
                    
                    Text(item.content)
                        .font(AppTheme.title3)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, DesignTokens.spacingXXL)
                    
                    if let duration = item.durationLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(String(localized: "Estimated: \(duration)"))
                        }
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                .padding(DesignTokens.spacingLG)
                .background {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(Color.white.opacity(0.04))
                }
                .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
                .padding(.horizontal, DesignTokens.spacingXXL)
            }
            
            Spacer()
            
            // Duration selector — glass pills
            VStack(spacing: DesignTokens.spacingLG) {
                Text(String(localized: "Focus duration"))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .textCase(.uppercase)
                
                // Preset durations
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(focusPresets, id: \.minutes) { preset in
                        durationPill(
                            label: preset.label,
                            minutes: preset.minutes,
                            isSelected: timer.focusMinutes == preset.minutes
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                
                // Custom stepper — only if none of the presets match
                if !focusPresets.map(\.minutes).contains(timer.focusMinutes) {
                    customDurationStepper
                }
                
                // AI estimate pill
                if let estimate = item.estimatedMinutes, !focusPresets.map(\.minutes).contains(estimate) {
                    Button {
                        withAnimation(AnimationConstants.springSmooth) {
                            timer.focusMinutes = estimate
                        }
                        HapticService.shared.actionButtonTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                            Text(String(localized: "AI estimate: \(estimate) min"))
                                .font(AppTheme.footnote.weight(.medium))
                        }
                        .foregroundStyle(DesignTokens.accentFocus)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background {
                            Capsule().fill(DesignTokens.accentFocus.opacity(0.1))
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
            }
            
            Spacer()
            
            // Start button — prominent, inviting
            VStack(spacing: DesignTokens.spacingMD) {
                Button {
                    beginCountdown()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                        Text(String(localized: "Start Focus"))
                            .font(AppTheme.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [DesignTokens.accentActive, DesignTokens.accentFocus],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignTokens.spacingXXL)
                
                Text(String(localized: "\(timer.focusMinutes) min focus"))
                    .font(AppTheme.hintFont)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
        .nudgeAccessibility(
            label: String(localized: "Focus timer setup for \(item.content)"),
            hint: String(localized: "Choose a duration and start focusing")
        )
    }
    
    // MARK: - Countdown Overlay (3-2-1)
    
    private var countdownOverlay: some View {
        ZStack {
            // Let the Antarctic night sky show through
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: DesignTokens.spacingLG) {
                Text("\(countdownNumber)")
                    .font(.system(size: 120, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(DesignTokens.accentActive)
                    .opacity(countdownVisible ? 1 : 0)
                    .scaleEffect(countdownVisible ? 1 : 1.5)
                    .contentTransition(.numericText())
                    .shadow(color: DesignTokens.accentActive.opacity(0.4), radius: 20)
                
                Text(String(localized: "Get ready…"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }
    
    // MARK: - Focusing Phase
    
    private var focusingPhaseView: some View {
        ZStack(alignment: .bottom) {
            // Top chrome + ring centered in upper portion
            VStack(spacing: 0) {
                focusTopBar
                
                Spacer()
                
                // The Ring — hero element
                focusRing
                
                // Encouragement slot
                encouragementBanner
                    .frame(height: 44)
                
                // Reserve space for Nudgy + controls at bottom (~190pt)
                Spacer()
                    .frame(minHeight: 190)
            }
            
            // Nudgy + controls pinned to bottom, over the Antarctic landscape
            // Penguin stands on the ice — feels natural and immersive
            VStack(spacing: DesignTokens.spacingXS) {
                nudgyCompanionStrip
                
                focusBottomControls
                    .padding(.bottom, DesignTokens.spacingXL)
            }
        }
    }
    
    // MARK: - Focus Ring
    
    private var focusRing: some View {
        GeometryReader { geo in
            let ringDiameter = min(geo.size.width, geo.size.height) * 0.68
            let ringRadius = ringDiameter / 2
            let innerDiameter = ringDiameter - 16
            
            ZStack {
                // iOS 26 glass disc — native material, blurs the frosted scene behind it
                // Breathing scale keeps it alive without any glow
                Circle()
                    .fill(Color.clear)
                    .frame(width: innerDiameter, height: innerDiameter)
                    .glassEffect(.regular, in: .circle)
                    .scaleEffect(ringScale)
                
                // Track ring — thin guide line
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 3)
                    .frame(width: ringDiameter, height: ringDiameter)
                
                // Progress arc — clean single color
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(ringAccentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? .none : .easeOut(duration: 0.5), value: timer.progress)
                
                // Endpoint dot
                if timer.progress > 0.02 {
                    Circle()
                        .fill(ringAccentColor)
                        .frame(width: 8, height: 8)
                        .offset(y: -ringRadius)
                        .rotationEffect(.degrees(360 * timer.progress - 90))
                        .animation(reduceMotion ? .none : .easeOut(duration: 0.5), value: timer.progress)
                }
                
                // Center content
                VStack(spacing: DesignTokens.spacingSM) {
                    Text(timer.formattedRemaining)
                        .font(.system(size: min(56, ringDiameter * 0.22), weight: .ultraLight, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: timer.remainingSeconds)
                    
                    HStack(spacing: 6) {
                        if let emoji = item.emoji {
                            Text(emoji)
                                .font(.system(size: 14))
                        }
                        Text(item.content)
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: ringDiameter * 0.7)
                    
                    // Session dots (if multi-session)
                    if timer.sessionsTarget > 1 {
                        HStack(spacing: 4) {
                            ForEach(0..<timer.sessionsTarget, id: \.self) { i in
                                Circle()
                                    .fill(i < timer.sessionsCompleted
                                        ? DesignTokens.accentComplete
                                        : i == timer.sessionsCompleted
                                            ? ringAccentColor
                                            : Color.white.opacity(0.15)
                                    )
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, DesignTokens.spacingLG)
        .onAppear {
            ringBreathing = true
            startRingBreathingAnimation()
        }
    }
    
    // MARK: - Encouragement Banner
    
    private var encouragementBanner: some View {
        Group {
            if showEncouragement {
                Text(encouragementText)
                    .font(AppTheme.rounded(.callout, weight: .medium))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.spacingXXL)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(AnimationConstants.springSmooth, value: showEncouragement)
    }
    
    // MARK: - Focus Top Bar
    
    private var focusTopBar: some View {
        HStack {
            // End session
            Button {
                endSession()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(localized: "End"))
                        .font(AppTheme.caption.weight(.medium))
                }
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .background {
                    Capsule().fill(Color.white.opacity(0.10))
                }
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            
            Spacer()
            
            // Elapsed time badge
            HStack(spacing: 4) {
                Circle()
                    .fill(timer.phase == .paused ? DesignTokens.accentStale : DesignTokens.accentComplete)
                    .frame(width: 6, height: 6)
                
                Text(timer.formattedElapsed)
                    .font(AppTheme.rounded(.caption2, weight: .bold))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, DesignTokens.spacingSM + 2)
            .padding(.vertical, DesignTokens.spacingXS + 2)
            .background {
                Capsule().fill(Color.white.opacity(0.10))
            }
            .glassEffect(.regular.interactive(), in: .capsule)
            
            Spacer()
            
            // Distraction parking lot button
            Button {
                withAnimation(AnimationConstants.springSmooth) {
                    showDistractionCapture.toggle()
                }
                HapticService.shared.actionButtonTap()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.min")
                        .font(.system(size: 12, weight: .medium))
                    if !timer.distractions.isEmpty {
                        Text("\(timer.distractions.count)")
                            .font(AppTheme.rounded(.caption2, weight: .bold))
                    }
                }
                .foregroundStyle(DesignTokens.accentStale)
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .background {
                    Capsule().fill(DesignTokens.accentStale.opacity(0.08))
                }
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .nudgeAccessibility(
                label: String(localized: "Park a distraction"),
                hint: String(localized: "Capture a thought to deal with later"),
                traits: .isButton
            )
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.top, DesignTokens.spacingMD)
    }
    
    // MARK: - Nudgy Companion Strip
    
    private var nudgyCompanionStrip: some View {
        HStack(alignment: .bottom, spacing: DesignTokens.spacingMD) {
            PenguinSceneView(
                size: .medium,
                expressionOverride: nudgyExpression,
                accentColorOverride: ringAccentColor
            )
            
            if showNudgyBubble {
                Text(nudgyMessage)
                    .font(AppTheme.nudgyBubbleFont)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(2)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM + 2)
                    .background {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.12))
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .animation(AnimationConstants.springSmooth, value: showNudgyBubble)
    }
    
    // MARK: - Bottom Controls
    
    private var focusBottomControls: some View {
        HStack(spacing: DesignTokens.spacingXXL) {
            // +5 min extend
            Button {
                extendTimer()
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)
                        
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    Text(String(localized: "+5 min"))
                        .font(AppTheme.hintFont)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .nudgeAccessibility(
                label: String(localized: "Add 5 minutes"),
                hint: String(localized: "Extend the focus session by 5 minutes"),
                traits: .isButton
            )
            
            // Play/Pause — hero button
            Button {
                togglePause()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ringAccentColor,
                                    ringAccentColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: ringAccentColor.opacity(0.2), radius: 8, y: 3)
                    
                    Image(systemName: timer.phase == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .scaleEffect(pulseScale)
            .nudgeAccessibility(
                label: timer.phase == .paused ? String(localized: "Resume") : String(localized: "Pause"),
                traits: .isButton
            )
            
            // Done early
            Button {
                withAnimation(AnimationConstants.springSmooth) {
                    timer.totalFocusedSeconds += timer.elapsedSeconds
                    timer.phase = .completed
                }
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(DesignTokens.accentComplete)
                    }
                    Text(String(localized: "Done"))
                        .font(AppTheme.hintFont)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .nudgeAccessibility(
                label: String(localized: "Finish early"),
                hint: String(localized: "End focus and see your results"),
                traits: .isButton
            )
        }
    }
    
    // MARK: - Break Phase
    
    private var breakPhaseView: some View {
        ZStack(alignment: .bottom) {
            // Top bar
            VStack {
                HStack {
                    Spacer()
                    // Session progress label
                    Text(String(localized: "Session \(timer.sessionsCompleted) of \(timer.sessionsTarget) done"))
                        .font(AppTheme.caption.weight(.medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background { Capsule().fill(Color.white.opacity(0.08)) }
                        .glassEffect(.regular, in: .capsule)
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.top, DesignTokens.spacingMD)
                
                Spacer()
                
                // Centered break content
                VStack(spacing: DesignTokens.spacingLG) {
                    VStack(spacing: DesignTokens.spacingSM) {
                        Text(String(localized: "Nice work."))
                            .font(AppTheme.displayFont)
                            .foregroundStyle(DesignTokens.textPrimary)
                        Text(String(localized: "Take a breather."))
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    
                    // Break countdown ring — generous size
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 5)
                            .frame(width: 160, height: 160)
                        
                        Circle()
                            .trim(from: 0, to: timer.breakProgress)
                            .stroke(DesignTokens.accentComplete.opacity(0.6), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))
                            .animation(reduceMotion ? .none : .easeOut(duration: 0.5), value: timer.breakProgress)
                        
                        VStack(spacing: 2) {
                            Text(breakFormattedRemaining)
                                .font(.system(size: 36, weight: .ultraLight, design: .rounded))
                                .foregroundStyle(DesignTokens.textPrimary)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            
                            Text(String(localized: "break"))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                    }
                    
                    // Distraction count
                    if !timer.distractions.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.min.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DesignTokens.accentStale)
                            Text(String(localized: "\(timer.distractions.count) thoughts parked"))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                    }
                }
                
                Spacer()
                    .frame(minHeight: 190)
            }
            
            // Bottom controls over the landscape
            VStack(spacing: DesignTokens.spacingMD) {
                PenguinSceneView(
                    size: .medium,
                    expressionOverride: .happy,
                    accentColorOverride: DesignTokens.accentComplete
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, DesignTokens.spacingXL)
                
                HStack(spacing: DesignTokens.spacingMD) {
                    Button {
                        skipBreak()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 11))
                            Text(String(localized: "Skip"))
                                .font(AppTheme.caption.weight(.medium))
                        }
                        .foregroundStyle(DesignTokens.textTertiary)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM + 2)
                        .background { Capsule().fill(Color.white.opacity(0.08)) }
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    
                    Button {
                        startNextSession()
                    } label: {
                        HStack(spacing: DesignTokens.spacingSM) {
                            Text(String(localized: "Start Next Session"))
                                .font(AppTheme.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DesignTokens.accentActive.opacity(0.2))
                        }
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.bottom, DesignTokens.spacingXL)
            }
        }
    }
    
    private var breakFormattedRemaining: String {
        let mins = timer.breakRemainingSeconds / 60
        let secs = timer.breakRemainingSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // MARK: - Completion Phase
    
    private var completionPhaseView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: DesignTokens.spacingXL) {
                // Celebration penguin
                PenguinSceneView(
                    size: .large,
                    expressionOverride: .celebrating,
                    accentColorOverride: DesignTokens.accentComplete
                )
                .scaleEffect(completionAppeared ? 1 : 0.8)
                .opacity(completionAppeared ? 1 : 0)
                
                // Title
                VStack(spacing: DesignTokens.spacingSM) {
                    Text(String(localized: "Focus complete."))
                        .font(AppTheme.displayFont)
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    Text(String(localized: "You stayed focused. That's a win."))
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .opacity(completionAppeared ? 1 : 0)
                .offset(y: completionAppeared ? 0 : 20)
                
                // Session summary card
                sessionSummaryCard
                    .opacity(completionAppeared ? 1 : 0)
                    .offset(y: completionAppeared ? 0 : 30)
                
                // Parked distractions reminder
                if !timer.distractions.isEmpty {
                    distractionsSummary
                        .opacity(completionAppeared ? 1 : 0)
                        .offset(y: completionAppeared ? 0 : 30)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: DesignTokens.spacingSM) {
                Button {
                    completeTask()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text(String(localized: "Mark Task Done"))
                            .font(AppTheme.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignTokens.accentComplete.opacity(0.2))
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                Button {
                    endSession()
                } label: {
                    Text(String(localized: "Not done yet — close timer"))
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textTertiary)
                        .padding(.vertical, DesignTokens.spacingMD)
                }
            }
            .padding(.horizontal, DesignTokens.spacingXXL)
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
        .onAppear {
            tickTimer?.invalidate()
            tickTimer = nil
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                completionAppeared = true
            }
            showCompletionParticles = true
            HapticService.shared.swipeDone()
            SoundService.shared.play(.allClear)
        }
    }
    
    // MARK: - Session Summary Card
    
    private var sessionSummaryCard: some View {
        HStack(spacing: DesignTokens.spacingLG) {
            // Total focus time
            statBubble(
                icon: "timer",
                value: "\(totalFocusMinutes)",
                unit: String(localized: "min focused"),
                color: DesignTokens.accentActive
            )
            
            // Sessions
            statBubble(
                icon: "flame.fill",
                value: "\(max(1, timer.sessionsCompleted))",
                unit: timer.sessionsCompleted <= 1 ? String(localized: "session") : String(localized: "sessions"),
                color: DesignTokens.streakOrange
            )
            
            // Distractions parked
            statBubble(
                icon: "lightbulb.min.fill",
                value: "\(timer.distractions.count)",
                unit: String(localized: "parked"),
                color: DesignTokens.accentStale
            )
        }
        .padding(DesignTokens.spacingLG)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(Color.white.opacity(0.03))
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        .padding(.horizontal, DesignTokens.spacingLG)
    }
    
    private func statBubble(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(DesignTokens.textPrimary)
            
            Text(unit)
                .font(AppTheme.hintFont)
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var totalFocusMinutes: Int {
        max(1, timer.totalFocusedSeconds / 60)
    }
    
    // MARK: - Distractions Summary
    
    private var distractionsSummary: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.min.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.accentStale)
                Text(String(localized: "Parked thoughts"))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .textCase(.uppercase)
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                ForEach(Array(timer.distractions.enumerated()), id: \.offset) { _, thought in
                    HStack(spacing: DesignTokens.spacingSM) {
                        Circle()
                            .fill(DesignTokens.accentStale.opacity(0.4))
                            .frame(width: 4, height: 4)
                        Text(thought)
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(Color.white.opacity(0.03))
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        .padding(.horizontal, DesignTokens.spacingLG)
    }
    
    // MARK: - Distraction Capture Overlay
    
    private var distractionCaptureOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: DesignTokens.spacingMD) {
                HStack {
                    Image(systemName: "lightbulb.min.fill")
                        .foregroundStyle(DesignTokens.accentStale)
                    Text(String(localized: "Park a thought"))
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.textPrimary)
                    Spacer()
                    Button {
                        withAnimation(AnimationConstants.springSmooth) {
                            showDistractionCapture = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                
                Text(String(localized: "Write it down, come back to it later. Stay focused."))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                
                HStack(spacing: DesignTokens.spacingSM) {
                    TextField(
                        String(localized: "What popped into your head?"),
                        text: $distractionText
                    )
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM + 2)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.12))
                    }
                    .submitLabel(.done)
                    .onSubmit {
                        commitDistraction()
                    }
                    
                    Button {
                        commitDistraction()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                distractionText.isEmpty
                                    ? DesignTokens.textTertiary
                                    : DesignTokens.accentActive
                            )
                    }
                    .disabled(distractionText.isEmpty)
                }
                
                // Parked list
                if !timer.distractions.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                            ForEach(Array(timer.distractions.enumerated()), id: \.offset) { _, thought in
                                HStack(spacing: DesignTokens.spacingSM) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(DesignTokens.accentComplete.opacity(0.5))
                                    Text(thought)
                                        .font(AppTheme.footnote)
                                        .foregroundStyle(DesignTokens.textSecondary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
            .padding(DesignTokens.spacingLG)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.03))
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, DesignTokens.spacingXXL)
        }
        .background {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(AnimationConstants.springSmooth) {
                        showDistractionCapture = false
                    }
                }
        }
    }
    
    // MARK: - Duration Pill
    
    private func durationPill(label: String, minutes: Int, isSelected: Bool) -> some View {
        Button {
            withAnimation(AnimationConstants.springSmooth) {
                timer.focusMinutes = minutes
            }
            HapticService.shared.actionButtonTap()
        } label: {
            Text(label)
                .font(AppTheme.rounded(.callout, weight: .semibold))
                .foregroundStyle(isSelected ? .white : DesignTokens.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingMD)
                .background {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                        .fill(isSelected ? ringAccentColor.opacity(0.25) : Color.white.opacity(0.10))
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusButton))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                            .strokeBorder(ringAccentColor.opacity(0.4), lineWidth: 1)
                    }
                }
        }
    }
    
    private var customDurationStepper: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            Text(String(localized: "\(timer.focusMinutes) min"))
                .font(AppTheme.rounded(.body, weight: .semibold))
                .foregroundStyle(DesignTokens.textPrimary)
                .monospacedDigit()
            
            Stepper("", value: $timer.focusMinutes, in: 1...120, step: 5)
                .labelsHidden()
                .tint(DesignTokens.accentActive)
        }
        .padding(.horizontal, DesignTokens.spacingXXL)
        .transition(.opacity)
    }
    
    // MARK: - Presets
    
    private var focusPresets: [(label: String, minutes: Int)] {
        let template = CategoryTemplateRegistry.template(for: item.resolvedCategory)
        if let catPresets = template.timerPresets, !catPresets.isEmpty {
            return catPresets.map { ($0.label, $0.minutes) }
        }
        return [
            ("5", 5),
            ("15", 15),
            ("25", 25),
            ("45", 45),
            ("60", 60)
        ]
    }
    
    // MARK: - Ring Color
    
    private var ringAccentColor: Color {
        let categoryColor = item.resolvedCategory == .general
            ? DesignTokens.accentActive
            : item.resolvedCategory.primaryColor
        switch timer.phase {
        case .setup, .countdown:
            return categoryColor
        case .focusing, .paused:
            if timer.progress < 0.5 {
                return DesignTokens.accentActive
            } else if timer.progress < 0.85 {
                return DesignTokens.accentFocus
            } else {
                return DesignTokens.accentComplete
            }
        case .breakTime:
            return DesignTokens.accentComplete
        case .completed:
            return DesignTokens.accentComplete
        }
    }
    
    // MARK: - Timer Logic
    
    private func beginCountdown() {
        timer.phase = .countdown
        countdownNumber = 3
        countdownVisible = true
        HapticService.shared.micStart()
        
        // 3-2-1 countdown sequence
        Task { @MainActor in
            for i in stride(from: 3, through: 1, by: -1) {
                countdownNumber = i
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    countdownVisible = true
                }
                HapticService.shared.actionButtonTap()
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(.easeOut(duration: 0.15)) {
                    countdownVisible = false
                }
                try? await Task.sleep(for: .seconds(0.2))
            }
            
            startFocusing()
        }
    }
    
    private func startFocusing() {
        timer.totalSeconds = timer.focusMinutes * 60
        timer.remainingSeconds = timer.totalSeconds
        timer.phase = .focusing
        lastEncouragementElapsed = 0
        
        nudgyExpression = .thinking
        showNudgyMessage(String(localized: "I'll be right here. You've got this."))
        
        HapticService.shared.actionButtonTap()
        SoundService.shared.play(.micStart)
        
        // Start Live Activity for Dynamic Island
        startFocusLiveActivity()
        
        startTick()
    }
    
    private func startTick() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                tick()
            }
        }
    }
    
    @MainActor
    private func tick() {
        switch timer.phase {
        case .focusing:
            guard timer.remainingSeconds > 0 else {
                focusSessionComplete()
                return
            }
            timer.remainingSeconds -= 1
            checkEncouragement()
            updateNudgyExpression()
            
        case .breakTime:
            guard timer.breakRemainingSeconds > 0 else {
                breakComplete()
                return
            }
            timer.breakRemainingSeconds -= 1
            
        default:
            break
        }
    }
    
    private func togglePause() {
        if timer.phase == .paused {
            timer.phase = .focusing
            startTick()
            nudgyExpression = .thinking
            showNudgyMessage(String(localized: "Welcome back. Let's keep going."))
        } else {
            timer.phase = .paused
            tickTimer?.invalidate()
            tickTimer = nil
            nudgyExpression = .idle
            showNudgyMessage(String(localized: "Taking a pause. No rush."))
        }
        HapticService.shared.snoozeTimeSelected()
    }
    
    private func extendTimer() {
        timer.totalSeconds += 300  // +5 min
        timer.remainingSeconds += 300
        HapticService.shared.actionButtonTap()
        showNudgyMessage(String(localized: "Added 5 more minutes. You're on a roll."))
    }
    
    private func focusSessionComplete() {
        tickTimer?.invalidate()
        tickTimer = nil
        timer.sessionsCompleted += 1
        timer.totalFocusedSeconds += timer.totalSeconds
        
        HapticService.shared.swipeDone()
        SoundService.shared.play(.taskDone)
        
        if timer.sessionsCompleted >= timer.sessionsTarget {
            // All sessions done — end Live Activity
            Task { await LiveActivityManager.shared.endAll() }
            withAnimation(AnimationConstants.springSmooth) {
                timer.phase = .completed
            }
        } else {
            // Start break
            timer.breakTotalSeconds = timer.breakMinutes * 60
            timer.breakRemainingSeconds = timer.breakTotalSeconds
            withAnimation(AnimationConstants.springSmooth) {
                timer.phase = .breakTime
            }
            startTick()
        }
    }
    
    private func breakComplete() {
        tickTimer?.invalidate()
        tickTimer = nil
        HapticService.shared.actionButtonTap()
        SoundService.shared.play(.nudgeKnock)
        showNudgyMessage(String(localized: "Break's over — ready for round \(timer.sessionsCompleted + 1)?"))
    }
    
    private func skipBreak() {
        tickTimer?.invalidate()
        tickTimer = nil
        startNextSession()
    }
    
    private func startNextSession() {
        timer.totalSeconds = timer.focusMinutes * 60
        timer.remainingSeconds = timer.totalSeconds
        withAnimation(AnimationConstants.springSmooth) {
            timer.phase = .focusing
        }
        nudgyExpression = .thinking
        showNudgyMessage(String(localized: "Session \(timer.sessionsCompleted + 1) — let's go."))
        startTick()
    }
    
    private func endSession() {
        // Accumulate current session's elapsed time before recording
        if timer.phase == .focusing || timer.phase == .paused {
            timer.totalFocusedSeconds += timer.elapsedSeconds
        }
        recordFocusTime()
        recordHealthKitMindfulSession()
        tickTimer?.invalidate()
        tickTimer = nil
        
        // End Live Activity
        Task { await LiveActivityManager.shared.endAll() }
        
        // Convert parked distractions to new tasks
        if !timer.distractions.isEmpty {
            let repo = NudgeRepository(modelContext: modelContext)
            for thought in timer.distractions {
                _ = repo.createManual(content: thought)
            }
            NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        }
        
        isPresented = false
    }
    
    private func completeTask() {
        // Accumulate current session's elapsed time before recording
        if timer.phase == .focusing || timer.phase == .paused {
            timer.totalFocusedSeconds += timer.elapsedSeconds
        }
        recordFocusTime()
        recordHealthKitMindfulSession()
        tickTimer?.invalidate()
        tickTimer = nil
        
        // End Live Activity
        Task { await LiveActivityManager.shared.endAll() }
        
        let repo = NudgeRepository(modelContext: modelContext)
        repo.markDone(item)
        
        let isAllClear = repo.activeCount() == 0
        RewardService.shared.recordCompletion(context: modelContext, item: item, isAllClear: isAllClear)
        
        HapticService.shared.completionHaptic(for: item.resolvedCategory)
        SoundService.shared.play(.taskDone)
        SoundService.shared.play(.fishCaught)
        
        // Convert distractions to tasks
        if !timer.distractions.isEmpty {
            for thought in timer.distractions {
                _ = repo.createManual(content: thought)
            }
        }
        
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        isPresented = false
    }
    
    private func recordFocusTime() {
        guard timer.isActive || timer.phase == .completed else { return }
        // Callers must accumulate current session elapsed into totalFocusedSeconds
        // before calling this method (endSession, completeTask, onDisappear all do this).
        let elapsed = timer.totalFocusedSeconds
        if elapsed > 30 {
            item.actualMinutes = (item.actualMinutes ?? 0) + max(1, elapsed / 60)
            item.updatedAt = Date()
            do { try modelContext.save() } catch { Log.ui.error("[FocusTimer] Save failed: \(error, privacy: .public)") }

            // Persist daily focus minutes for the You tab glance card
            let todayKey = "focusMinutesToday_\(Date().formatted(.dateTime.year().month().day()))"
            let existing = UserDefaults.standard.integer(forKey: todayKey)
            UserDefaults.standard.set(existing + max(1, elapsed / 60), forKey: todayKey)
        }
    }
    
    /// Write focus timer session as a Mindful Session to Apple Health.
    private func recordHealthKitMindfulSession() {
        let elapsed = timer.totalFocusedSeconds
        guard elapsed > 60 else { return } // Only record sessions > 1 minute
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(TimeInterval(-elapsed))
        Task {
            await HealthService.shared.recordMindfulSession(
                startDate: startDate,
                endDate: endDate,
                taskContent: item.content
            )
        }
    }
    
    // MARK: - Live Activity
    
    private func startFocusLiveActivity() {
        let emoji = item.emoji ?? "timer"
        let cat = item.resolvedCategory
        Task {
            await LiveActivityManager.shared.start(
                taskContent: "🎯 " + item.content,
                taskEmoji: emoji,
                queuePosition: 1,
                queueTotal: 1,
                accentHex: "5E5CE6",  // Focus purple
                taskID: item.id.uuidString,
                categoryLabel: cat != .general ? "\(cat.emoji) Focusing" : "🎯 Focusing",
                categoryColorHex: cat != .general ? cat.primaryColorHex : "5E5CE6"
            )
        }
    }
    
    // MARK: - Distraction Capture
    
    private func commitDistraction() {
        let text = distractionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        timer.distractions.append(text)
        distractionText = ""
        HapticService.shared.actionButtonTap()
        
        showNudgyMessage(String(localized: "Parked it. Back to focus."))
    }
    
    // MARK: - Nudgy Companion Logic
    
    private func updateNudgyExpression() {
        let progress = timer.progress
        
        if progress > 0.9 {
            nudgyExpression = .celebrating
        } else if progress > 0.75 {
            nudgyExpression = .happy
        } else if progress > 0.5 {
            nudgyExpression = .nudging
        } else {
            nudgyExpression = .thinking
        }
    }
    
    private func showNudgyMessage(_ message: String) {
        nudgyMessage = message
        withAnimation(AnimationConstants.springSmooth) {
            showNudgyBubble = true
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.3)) {
                showNudgyBubble = false
            }
        }
    }
    
    // MARK: - Encouragement System
    
    private let encouragements: [String] = [
        String(localized: "You're doing amazing."),
        String(localized: "One thing at a time. You've got this."),
        String(localized: "Focus looks good on you."),
        String(localized: "Almost there, stay with it."),
        String(localized: "Your future self is thanking you."),
        String(localized: "Breathe. You're exactly where you need to be."),
        String(localized: "Small progress is still progress."),
        String(localized: "The hardest part was starting. Look at you go."),
        String(localized: "Deep breaths. You're doing the thing."),
        String(localized: "Time well spent. Keep it up."),
    ]
    
    private func checkEncouragement() {
        let elapsed = timer.elapsedSeconds
        let interval = 300 // Every 5 minutes
        
        guard elapsed > 0,
              elapsed % interval == 0,
              elapsed != lastEncouragementElapsed else { return }
        
        lastEncouragementElapsed = elapsed
        encouragementText = encouragements.randomElement() ?? ""
        
        withAnimation(.easeOut(duration: 0.5)) {
            showEncouragement = true
        }
        
        // Pulse the play/pause button
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            pulseScale = 1.1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                pulseScale = 1.0
            }
        }
        
        // Auto-hide
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeOut(duration: 0.5)) {
                showEncouragement = false
            }
        }
    }
    
    // MARK: - Ring Breathing Animation
    
    private func startRingBreathingAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
            ringScale = 1.015
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var presented = true
    let item = NudgeItem(content: "Call the dentist about appointment", emoji: "📞", estimatedMinutes: 15)
    FocusTimerView(item: item, isPresented: $presented)
        .environment(PenguinState())
}
