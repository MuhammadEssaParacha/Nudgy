//
//  NudgyIntroView.swift
//  Nudge
//
//  Interactive animated intro journey — Nudgy's mountain adventure.
//  7 focused scenes: meet → name → age → challenge → voice → tutorial → ready.
//  ADHD-friendly: skippable, one interaction per screen, teaches the app inline.
//
//  Scene Flow:
//    1. Meet           — Nudgy appears, quick intro
//    2. Your Name      — Name field (interactive)
//    3. Your Age       — Age picker (interactive)
//    4. Your Challenge — ADHD challenge grid (interactive)
//    5. How To Talk    — Personality mode picker (interactive)
//    6. How It Works   — Tutorial: capture, cards, swipe, voice (interactive)
//    7. Ready          — Fish burst + beanie drop + Sign In with Apple
//

import SwiftUI
import AuthenticationServices
import os

// MARK: - Scene Definition

private enum IntroScene: Int, CaseIterable {
    case meet = 0
    case yourName
    case yourAge
    case yourChallenge
    case howToTalk
    case howItWorks
    case ready
    
    /// Whether this scene requires user interaction before advancing.
    var isInteractive: Bool {
        switch self {
        case .yourName, .yourAge, .yourChallenge, .howToTalk, .howItWorks: return true
        default: return false
        }
    }
    
    var mood: LandscapeMood {
        switch self {
        case .meet:          return .night
        case .yourName:      return .night
        case .yourAge:       return .dawn
        case .yourChallenge: return .dawn
        case .howToTalk:     return .dawn
        case .howItWorks:    return .golden
        case .ready:         return .summit
        }
    }
    
    var nudgyExpression: PenguinExpression {
        switch self {
        case .meet:          return .waving
        case .yourName:      return .listening
        case .yourAge:       return .listening
        case .yourChallenge: return .thinking
        case .howToTalk:     return .waving
        case .howItWorks:    return .happy
        case .ready:         return .celebrating
        }
    }
    
    /// Nudgy's position on screen (fraction from left edge).
    var nudgyX: CGFloat { 0.5 }
    
    /// Cinematic scene label shown briefly during transitions.
    var sceneLabel: String? {
        switch self {
        case .meet:          return nil
        case .yourName:      return nil  // flows directly from meet
        case .yourAge:       return String(localized: "About You")
        case .yourChallenge: return nil  // same chapter as yourAge
        case .howToTalk:     return String(localized: "Your Nudgy")
        case .howItWorks:    return String(localized: "How It Works")
        case .ready:         return nil
        }
    }
    
    /// Dialogue line for this scene — personalized versions provided by the view.
    var fallbackDialogue: String {
        switch self {
        case .meet:          return String(localized: "Oh. Hello. …I'm Nudgy. I'm a penguin.")
        case .yourName:      return String(localized: "What should I call you?")
        case .yourAge:       return String(localized: "Hmm. How old are you?")
        case .yourChallenge: return String(localized: "What's the tricky bit?")
        case .howToTalk:     return String(localized: "How should I talk to you?")
        case .howItWorks:    return String(localized: "Here's how we'll do things.")
        case .ready:         return String(localized: "Well, now. …I think we're ready.")
        }
    }
}

// MARK: - NudgyIntroView

struct NudgyIntroView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AuthSession.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var currentScene: IntroScene = .meet
    @State private var dialogueComplete: Bool = false
    @State private var sceneReady: Bool = false
    @State private var nudgyVisible: Bool = false
    @State private var nudgyScale: CGFloat = 0.3
    @State private var landscapeReveal: CGFloat = 0
    @State private var showFishBurst: Bool = false
    @State private var showBeanie: Bool = false
    @State private var showSkip: Bool = false
    @State private var nudgyWalkOffset: CGFloat = 0
    @State private var nudgyBounce: CGFloat = 0
    @State private var isSigningIn: Bool = false
    @State private var breatheScale: CGFloat = 1.0
    @State private var sceneTitle: String = ""
    @State private var showSceneTitle: Bool = false
    @State private var squashStretch: CGSize = CGSize(width: 1.0, height: 1.0)
    @State private var headTilt: Double = 0
    @State private var nudgyY: CGFloat = 0
    @State private var beanieWiggle: Double = 0
    
    // Personalization choices (saved to pending UserDefaults on sign-in)
    @State private var introName: String = ""
    @State private var introAge: AgeGroup = .adult
    @State private var introChallenge: ADHDChallenge = .allOfAbove
    @State private var introMode: NudgyPersonalityMode = .gentle
    @FocusState private var nameFieldFocused: Bool
    
    // Tutorial state
    @State private var tutorialStep: Int = 0
    @State private var tutorialDragOffset: CGFloat = 0
    
    // Animation coordination
    @State private var transitionTask: Task<Void, Never>?
    
    /// The user's display name — empty until they type it.
    /// Used to personalize dialogue after the name scene.
    private var displayName: String {
        let trimmed = introName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }
    
    /// Dynamic Nudgy expression — reacts to user's interaction state.
    private var currentExpression: PenguinExpression {
        switch currentScene {
        case .yourName:
            if !introName.isEmpty { return .happy }
            if nameFieldFocused { return .shy }
            return .listening
        case .yourChallenge:
            if introChallenge != .allOfAbove { return .thumbsUp }
            return .thinking
        case .howToTalk:
            switch introMode {
            case .silly: return .mischievous
            case .coach: return .nudging
            default: return .talking
            }
        case .howItWorks:
            return .nudging
        default:
            return currentScene.nudgyExpression
        }
    }
    
    /// Accent color — shifts to match personality mode during howToTalk.
    private var currentAccentColor: Color {
        if currentScene == .howToTalk {
            return Color(hex: introMode.accentColorHex)
        }
        return DesignTokens.accentActive
    }
    
    /// Dialogue lines for the current scene, personalized with user's name.
    private func dialogueLine(for scene: IntroScene) -> String {
        let name = displayName
        switch scene {
        case .meet:
            return String(localized: "Oh. Hello. *blinks* …I'm Nudgy. I'm a penguin. I live here now.")
        case .yourName:
            return String(localized: "What should I call you? …I'm not very good with names, but I'll try.")
        case .yourAge:
            if name.isEmpty {
                return String(localized: "Hmm. How old are you? …Penguins don't really track these things.")
            } else {
                return String(localized: "Hello, \(name). …How old are you? I'm curious.")
            }
        case .yourChallenge:
            return String(localized: "What's the tricky bit? …Everyone has one. Even penguins.")
        case .howToTalk:
            if name.isEmpty {
                return String(localized: "How should I talk to you? …I want to get it right.")
            } else {
                return String(localized: "How should I talk to you, \(name)? …I want to get it right.")
            }
        case .howItWorks:
            return String(localized: "Here's how we'll do things. …It's quite simple, really.")
        case .ready:
            if name.isEmpty {
                return String(localized: "Well, now. …I think we're ready. Shall we?")
            } else {
                return String(localized: "Well, \(name). …I think we're ready. Shall we?")
            }
        }
    }
    
    /// Pixar-style bouncy spring — snappy with slight overshoot.
    private var springAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.45, dampingFraction: 0.72, blendDuration: 0.1)
    }
    
    /// Heavy spring for character body (more mass = more follow-through).
    private var characterSpring: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.55, dampingFraction: 0.65, blendDuration: 0.15)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 0: Mountain landscape backdrop — tappable to advance scenes
                MountainLandscape(
                    revealProgress: landscapeReveal,
                    mood: currentScene.mood,
                    showGlow: nudgyVisible
                )
                .animation(.easeInOut(duration: 1.2), value: currentScene.mood)
                .contentShape(Rectangle())
                .allowsHitTesting(!(currentScene == .ready && dialogueComplete))
                .onTapGesture { handleTap() }
                
                // Layer 1: Nudgy character
                nudgyCharacter(in: geo)
                    .allowsHitTesting(false) // Taps pass through to backdrop
                
                // Layer 2: Dialogue + UI overlay
                VStack(spacing: 0) {
                    // Skip button
                    topBar
                    
                    Spacer()
                        .contentShape(Rectangle())
                        .allowsHitTesting(!(currentScene == .ready && dialogueComplete))
                        .onTapGesture { handleTap() }
                    
                    // Dialogue bubble — dims when interactive overlay slides up
                    dialogueArea
                        .padding(.bottom, DesignTokens.spacingXL)
                        .opacity(currentScene.isInteractive && dialogueComplete && sceneReady ? 0.4 : 1.0)
                        .animation(.easeOut(duration: 0.3), value: dialogueComplete)
                        .allowsHitTesting(!(currentScene == .ready && dialogueComplete))
                        .onTapGesture { handleTap() }
                    
                    // Bottom area: tap-to-continue indicator (non-ready scenes)
                    bottomArea
                        .padding(.bottom, geo.safeAreaInsets.bottom + DesignTokens.spacingXXL)
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                
                // Layer 3: Fish burst overlay
                if currentScene == .ready {
                    FishBurst(trigger: showFishBurst)
                        .offset(y: -geo.size.height * 0.05)
                        .allowsHitTesting(false)
                }
                
                // Layer 4: Shooting stars (night/dawn moods)
                if currentScene.mood == .night || currentScene.mood == .dawn {
                    Group {
                        ShootingStar(startX: 0.75, startY: 0.08)
                        ShootingStar(startX: 0.55, startY: 0.15)
                    }
                    .allowsHitTesting(false)
                }
                
                // Layer 5: Gentle snowfall — never blocks taps
                SnowfallView(intensity: currentScene == .ready ? 0.7 : 0.3)
                    .opacity(landscapeReveal > 0.5 ? 1 : 0)
                    .animation(.easeIn(duration: 1.0), value: landscapeReveal)
                    .allowsHitTesting(false)
                
                // Layer 5.5: Scene title card (cinematic chapter marker)
                if showSceneTitle {
                    VStack(spacing: 4) {
                        // Decorative line
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.white.opacity(0.15))
                            .frame(width: 32, height: 2)
                        
                        Text(sceneTitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .tracking(4)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.4))
                        
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.white.opacity(0.15))
                            .frame(width: 32, height: 2)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.85)),
                            removal: .opacity.combined(with: .scale(scale: 1.1))
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 110)
                    .allowsHitTesting(false)
                }
                
                // Layer 6: Scene progress dots
                sceneProgressDots
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, geo.safeAreaInsets.bottom + DesignTokens.spacingSM)
                    .allowsHitTesting(false)
                
                // Layer 7: Personalization overlays (interactive scenes)
                if currentScene.isInteractive && dialogueComplete && sceneReady {
                    VStack {
                        Spacer()
                        personalizationOverlay
                            .padding(.horizontal, DesignTokens.spacingLG)
                            .padding(.bottom, geo.safeAreaInsets.bottom + DesignTokens.spacingXXL)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(springAnimation, value: dialogueComplete)
                }
                
                // Layer 8: Sign In with Apple — TOPMOST in Z-order
                // Placed outside all animated containers so the UIKit button
                // has a direct presentation anchor to the window
                if currentScene == .ready && dialogueComplete {
                    VStack {
                        Spacer()
                        launchActions
                            .padding(.bottom, geo.safeAreaInsets.bottom + DesignTokens.spacingXXL)
                            .padding(.horizontal, DesignTokens.spacingLG)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear { beginIntro() }
        .onDisappear {
            transitionTask?.cancel()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Spacer()
            if showSkip {
                Button {
                    if currentScene == .ready {
                        // Already on sign-in scene — fast-forward dialogue so button appears
                        dialogueComplete = true
                        sceneReady = true
                    } else {
                        skipToSignIn()
                    }
                } label: {
                    Text(String(localized: "Skip"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM)
                }
                .transition(.opacity)
            }
        }
        .frame(height: 56)
        .padding(.top, DesignTokens.spacingXXL)
        .animation(.easeOut(duration: 0.3), value: showSkip)
    }
    
    // MARK: - Nudgy Character
    
    private func nudgyCharacter(in geo: GeometryProxy) -> some View {
        // Nudgy moves higher on scenes with tall overlays to avoid crowding
        let yFraction: CGFloat = overlayVisible ? 0.34 : 0.42
        let centerY = geo.size.height * yFraction
        let centerX = geo.size.width * currentScene.nudgyX
        
        return ZStack {
            // Scene-specific floating vector icons (behind Nudgy for depth)
            sceneFloatingIcons
            
            // Nudgy body with squash/stretch deformation
            // showBeanie starts false — green beanie drops on during 'ready' scene
            PenguinMascot(
                expression: currentExpression,
                size: DesignTokens.penguinSizeHero,
                accentColor: currentAccentColor,
                showBeanie: showBeanie
            )
            .scaleEffect(x: squashStretch.width, y: squashStretch.height, anchor: .bottom)
            .rotationEffect(.degrees(headTilt), anchor: .bottom)
        }
        .scaleEffect(nudgyScale * breatheScale)
        .offset(x: nudgyWalkOffset, y: nudgyBounce + nudgyY)
        .opacity(nudgyVisible ? 1.0 : 0.0)
        .position(x: centerX, y: centerY)
        .animation(characterSpring, value: currentScene.nudgyX)
        .animation(characterSpring, value: nudgyScale)
        .animation(characterSpring, value: squashStretch.width)
        .animation(characterSpring, value: squashStretch.height)
        .animation(springAnimation, value: nudgyVisible)
        .animation(.spring(response: 0.5, dampingFraction: 0.55), value: showBeanie)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: headTilt)
        .animation(characterSpring, value: nudgyY)
        .animation(.easeOut(duration: 0.4), value: overlayVisible)
    }
    
    // MARK: - Scene Floating Icons
    
    /// Decorative vector icons that float around Nudgy per scene.
    @ViewBuilder
    private var sceneFloatingIcons: some View {
        switch currentScene {
        case .meet:
            FloatingSceneIcons(icons: [
                (name: "mountain.2.fill", color: Color(hex: "90A8C8")),
                (name: "sparkle", color: .white),
                (name: "moon.stars.fill", color: Color(hex: "C8D8F0")),
            ], spread: 90)
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .yourName:
            FloatingSceneIcons(icons: [
                (name: "person.fill", color: Color(hex: "4FC3F7")),
                (name: "pencil", color: Color(hex: "FFD54F")),
                (name: "sparkle", color: .white),
            ], spread: 80)
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .yourAge:
            FloatingSceneIcons(icons: [
                (name: "figure.child.circle.fill", color: Color(hex: "4FC3F7")),
                (name: "heart.fill", color: Color(hex: "FF6B8A")),
                (name: "sparkle", color: .white),
            ], spread: 80)
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .yourChallenge:
            FloatingSceneIcons(icons: [
                (name: "brain.fill", color: Color(hex: "CE93D8")),
                (name: "puzzlepiece.fill", color: Color(hex: "4FC3F7")),
                (name: "sparkle", color: Color(hex: "FFD54F")),
            ], spread: 85)
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .howToTalk:
            FloatingSceneIcons(icons: [
                (name: "bubble.left.fill", color: Color(hex: "4FC3F7")),
                (name: "face.smiling.fill", color: Color(hex: "30D158")),
                (name: "heart.fill", color: Color(hex: "FF6B8A")),
            ], spread: 80)
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .howItWorks:
            FloatingSceneIcons(icons: [
                (name: "tray.full.fill", color: Color(hex: "FFD54F")),
                (name: "rectangle.portrait.fill", color: Color(hex: "4FC3F7")),
                (name: "hand.draw.fill", color: Color(hex: "30D158")),
            ], spread: 85)
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .ready:
            ZStack {
                SparkleView(size: 18, color: Color(hex: "FFD54F"), delay: 0)
                    .offset(x: -50, y: -40)
                SparkleView(size: 14, color: .white, delay: 0.3)
                    .offset(x: 55, y: -55)
                SparkleView(size: 20, color: Color(hex: "4FC3F7"), delay: 0.6)
                    .offset(x: 40, y: 25)
                SparkleView(size: 12, color: Color(hex: "FF6B8A"), delay: 0.9)
                    .offset(x: -45, y: 30)
            }
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
        }
    }
    
    // MARK: - Dialogue Area
    
    /// Whether an interactive overlay is currently visible.
    private var overlayVisible: Bool {
        currentScene.isInteractive && dialogueComplete && sceneReady
    }
    
    private var dialogueArea: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            if sceneReady {
                IntroDialogueBubble(
                    text: dialogueLine(for: currentScene),
                    expression: currentScene.nudgyExpression,
                    typingSpeed: 0.032,
                    maxWidth: 320,
                    onTypingComplete: {
                        dialogueComplete = true
                    }
                )
                .id("\(currentScene.rawValue)") // Force new bubble per scene
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)),
                    removal: .opacity
                ))
                .scaleEffect(overlayVisible ? 0.85 : 1.0, anchor: .bottom)
            }
        }
        .frame(height: overlayVisible ? 80 : 140) // Compact when overlay shows
        .animation(springAnimation, value: currentScene)
        .animation(.easeOut(duration: 0.3), value: overlayVisible)
    }
    
    // MARK: - Bottom Area
    
    private var bottomArea: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            if currentScene != .ready && !currentScene.isInteractive && dialogueComplete {
                TapToContinue(visible: true)
            }
        }
        .frame(minHeight: 80)
    }
    
    // MARK: - Launch Actions (Sign In with Apple)
    
    private var launchActions: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            // App title reveal
            VStack(spacing: 6) {
                Text("nudge")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1.5)
                
                Text(String(localized: "One small thing at a time"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            
            // Sign In with Apple
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(isSigningIn)
            .overlay {
                if isSigningIn {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                    ProgressView()
                        .tint(.black)
                }
            }
            
            // Privacy reassurance
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                Text(String(localized: "Your data stays with you. …As it should."))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, DesignTokens.spacingXL)
    }
    
    // MARK: - Apple Sign In Handler
    
    private func handleAppleSignIn(result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else {
                Log.auth.warning("Sign In: success but no ASAuthorizationAppleIDCredential")
                return
            }
            Log.auth.debug("Sign In: got credential, user=\(cred.user.prefix(8))...")
            isSigningIn = true
            HapticService.shared.swipeDone()
            
            Task {
                await auth.completeAppleSignIn(with: cred)
                
                // Save personalization choices to pending UserDefaults (non-scoped)
                // — will be applied after user activation sets activeUserID
                savePendingProfile()
                
                // Auth succeeded — mark intro done (triggers routing to main app)
                withAnimation(.easeOut(duration: 0.4)) {
                    settings.hasSeenIntro = true
                }
            }
            
        case .failure(let error):
            Log.auth.error("Sign In FAILED: \(error, privacy: .public)")
            // User cancelled or error — stay on the intro, do nothing
            break
        }
    }
    
    // MARK: - Scene Progress Dots
    
    private var sceneProgressDots: some View {
        HStack(spacing: 6) {
            ForEach(IntroScene.allCases, id: \.rawValue) { scene in
                Capsule()
                    .fill(scene == currentScene ? .white.opacity(0.8) : .white.opacity(0.2))
                    .frame(
                        width: scene == currentScene ? 20 : 6,
                        height: 6
                    )
                    .animation(springAnimation, value: currentScene)
            }
        }
    }
    
    // MARK: - Scene Orchestration
    
    private func beginIntro() {
        showSkip = false
        
        // Start hidden below the snow line
        nudgyY = 40
        squashStretch = CGSize(width: 1.0, height: 0.6) // Pre-squashed
        
        transitionTask = Task { @MainActor in
            // Phase 1: Landscape reveals
            withAnimation(.easeInOut(duration: 2.2)) {
                landscapeReveal = 1.0
            }
            
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            
            // Phase 2: Nudgy pops up — anticipation squash then stretch upward
            nudgyVisible = true
            nudgyScale = 0.5
            
            // Stretch as Nudgy shoots up
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                nudgyScale = 1.05
                nudgyY = -8  // Overshoot above resting position
                squashStretch = CGSize(width: 0.88, height: 1.15) // Stretch tall
            }
            
            HapticService.shared.cardAppear()
            
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            
            // Phase 3: Squash on landing
            withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
                nudgyY = 2  // Compress down past rest
                squashStretch = CGSize(width: 1.12, height: 0.88) // Squash wide
                nudgyScale = 1.0
            }
            
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            
            // Phase 4: Settle to rest with slight tilt (personality!)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                nudgyY = 0
                squashStretch = CGSize(width: 1.0, height: 1.0)
                headTilt = 3 // Slight curious tilt
            }
            
            try? await Task.sleep(for: .seconds(0.25))
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                headTilt = 0 // Straighten up
            }
            
            // Start idle breathing animation
            startBreathingAnimation()
            
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            
            // Start first dialogue
            sceneReady = true
            dialogueComplete = false
            
            // Show skip quickly — ADHD users shouldn't have to wait
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            withAnimation { showSkip = true }
        }
    }
    
    private func handleTap() {
        if !dialogueComplete {
            // Typing is in progress — tap to complete it instantly
            dialogueComplete = true
            return
        }
        
        // Interactive scenes: user must tap Continue in the overlay, not the background
        if currentScene.isInteractive {
            return
        }
        
        // Dialogue is complete — advance to next scene
        advanceScene()
    }
    
    private func advanceScene() {
        guard let nextScene = IntroScene(rawValue: currentScene.rawValue + 1) else {
            // Already at last scene — CTA button handles exit
            return
        }
        
        transitionTask?.cancel()
        transitionTask = Task { @MainActor in
            HapticService.shared.actionButtonTap()
            
            // ── ANTICIPATION: Nudgy dips down (preparing to jump/exit) ──
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                squashStretch = CGSize(width: 1.1, height: 0.85)
                nudgyY = 4
                headTilt = 0
            }
            
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            
            // ── EXIT: Stretch up and shrink away ──
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                nudgyScale = 0.4
                nudgyY = -20
                squashStretch = CGSize(width: 0.8, height: 1.3)
            }
            
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            
            // ── SCENE CHANGE ──
            withAnimation(.easeInOut(duration: 0.5)) {
                currentScene = nextScene
                dialogueComplete = false
                sceneReady = false
            }
            
            // Flash scene title card
            if let label = nextScene.sceneLabel {
                sceneTitle = label
                withAnimation(.easeOut(duration: 0.4)) {
                    showSceneTitle = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.8))
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSceneTitle = false
                    }
                }
            }
            
            // Reset position while invisible/small
            nudgyY = 30
            squashStretch = CGSize(width: 1.0, height: 0.7)
            
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            
            // ── ENTRANCE: Pop in from below with stretch ──
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                nudgyScale = 1.05
                nudgyY = -6
                squashStretch = CGSize(width: 0.88, height: 1.14)
            }
            
            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }
            
            // ── LAND: Squash on arrival ──
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                nudgyY = 2
                squashStretch = CGSize(width: 1.1, height: 0.9)
                nudgyScale = 1.0
            }
            
            try? await Task.sleep(for: .seconds(0.12))
            guard !Task.isCancelled else { return }
            
            // ── SETTLE: Return to neutral with personality tilt ──
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                nudgyY = 0
                squashStretch = CGSize(width: 1.0, height: 1.0)
                headTilt = nextScene == .howToTalk ? -3 : (nextScene == .ready ? 4 : 0)
            }
            
            // Scene-specific effects
            performSceneEffects(nextScene)
            
            try? await Task.sleep(for: .seconds(0.25))
            guard !Task.isCancelled else { return }
            
            // Settle the tilt
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                headTilt = 0
            }
            
            sceneReady = true
            
            // VoiceOver: announce the new scene
            AccessibilityAnnouncer.screenChanged()
            AccessibilityAnnouncer.announce(dialogueLine(for: nextScene))
        }
    }
    
    private func performSceneEffects(_ scene: IntroScene) {
        switch scene {
        case .yourName:
            // Gentle curious head tilt — "tell me about you" energy
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    headTilt = 5
                }
                try? await Task.sleep(for: .seconds(0.4))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    headTilt = 0
                }
            }
            
        case .yourAge:
            // Small nod — "got it, next question"
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    nudgyBounce = -4
                    squashStretch = CGSize(width: 0.96, height: 1.04)
                }
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    nudgyBounce = 0
                    squashStretch = CGSize(width: 1.0, height: 1.0)
                }
            }
            
        case .yourChallenge:
            // Thinking tilt — pondering
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    headTilt = -4
                }
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    headTilt = 0
                }
            }
            
        case .howToTalk:
            // Gentle lean forward — attentive
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    nudgyBounce = -3
                    squashStretch = CGSize(width: 0.97, height: 1.03)
                }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    nudgyBounce = 0
                    squashStretch = CGSize(width: 1.0, height: 1.0)
                }
            }
            
        case .howItWorks:
            // Thinking nod — pondering
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    headTilt = -4
                }
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    headTilt = 0
                }
            }
            
        case .ready:
            // Fish burst + beanie drop celebration
            Task { @MainActor in
                // Excited wiggle before fish burst
                try? await Task.sleep(for: .seconds(0.6))
                guard !Task.isCancelled else { return }
                
                for _ in 0..<2 {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                        nudgyBounce = -6
                        squashStretch = CGSize(width: 0.92, height: 1.08)
                    }
                    try? await Task.sleep(for: .seconds(0.2))
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                        nudgyBounce = 0
                        squashStretch = CGSize(width: 1.04, height: 0.96)
                    }
                    try? await Task.sleep(for: .seconds(0.15))
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        squashStretch = CGSize(width: 1.0, height: 1.0)
                    }
                }
                
                try? await Task.sleep(for: .seconds(0.2))
                guard !Task.isCancelled else { return }
                showFishBurst = true
                
                // Big excited bounce on burst
                withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) {
                    nudgyBounce = -14
                    squashStretch = CGSize(width: 0.85, height: 1.18)
                }
                HapticService.shared.swipeDone()
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    nudgyBounce = 0
                    squashStretch = CGSize(width: 1.06, height: 0.94)
                }
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    squashStretch = CGSize(width: 1.0, height: 1.0)
                }
                
                // Beanie drops after fish excitement settles
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
                
                withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                    showBeanie = true
                }
                HapticService.shared.swipeDone()
                
                // Squash from beanie weight landing on head
                try? await Task.sleep(for: .seconds(0.25))
                withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) {
                    squashStretch = CGSize(width: 1.08, height: 0.92)
                    nudgyBounce = 3
                }
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    squashStretch = CGSize(width: 1.0, height: 1.0)
                    nudgyBounce = 0
                }
                
                // Proud head wiggle with beanie
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    headTilt = 6
                }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    headTilt = -5
                }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    headTilt = 0
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Breathing / Idle Animation
    
    /// Subtle idle "breathing" so Nudgy feels alive between interactions.
    private func startBreathingAnimation() {
        guard !reduceMotion else { return }
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            breatheScale = 1.035
        }
    }
    
    // MARK: - Skip to Sign In
    
    /// Skips the story scenes and jumps directly to the launch scene with Apple Sign In.
    private func skipToSignIn() {
        transitionTask?.cancel()
        HapticService.shared.actionButtonTap()
        
        transitionTask = Task { @MainActor in
            // Quick anticipation dip
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                squashStretch = CGSize(width: 1.08, height: 0.88)
                nudgyBounce = 3
            }
            
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeInOut(duration: 0.45)) {
                currentScene = .ready
                dialogueComplete = false
                sceneReady = false
            }
            
            // Transition bounce
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                nudgyScale = 1.0
                nudgyBounce = -8
                squashStretch = CGSize(width: 0.9, height: 1.12)
            }
            
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            
            // Land
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                nudgyBounce = 2
                squashStretch = CGSize(width: 1.08, height: 0.92)
            }
            
            try? await Task.sleep(for: .seconds(0.12))
            
            // Settle
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                nudgyBounce = 0
                squashStretch = CGSize(width: 1.0, height: 1.0)
            }
            
            performSceneEffects(.ready)
            
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            
            sceneReady = true
            
            // VoiceOver: announce the final scene
            AccessibilityAnnouncer.screenChanged()
            AccessibilityAnnouncer.announce(dialogueLine(for: .ready))
        }
    }
    
    // MARK: - Personalization & Tutorial Overlays
    
    @ViewBuilder
    private var personalizationOverlay: some View {
        switch currentScene {
        case .yourName:      yourNameOverlay
        case .yourAge:       yourAgeOverlay
        case .yourChallenge: yourChallengeOverlay
        case .howToTalk:     howToTalkOverlay
        case .howItWorks:    howItWorksOverlay
        default: EmptyView()
        }
    }
    
    // MARK: Your Name — just a name field
    
    private var yourNameOverlay: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            HStack(spacing: 10) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 20)
                TextField(String(localized: "Your first name"), text: $introName)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(.white)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 0.5)
            )
            
            introContinueButton
        }
        .padding(DesignTokens.spacingLG)
        .background(introOverlayBackground)
        .onAppear {
            // Auto-focus the name field with slight delay for animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                nameFieldFocused = true
            }
        }
    }
    
    // MARK: Your Age — just the age picker
    
    private var yourAgeOverlay: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            HStack(spacing: 8) {
                ForEach(AgeGroup.allCases, id: \.self) { age in
                    Button {
                        HapticService.shared.actionButtonTap()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            introAge = age
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: age.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(introAge == age ? Color(hex: "4FC3F7") : .white.opacity(0.4))
                            Text(age.label.components(separatedBy: " ").first ?? "")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(introAge == age ? .white.opacity(0.9) : .white.opacity(0.35))
                            // Age range (e.g., 6–12)
                            if let open = age.label.firstIndex(of: "("),
                               let close = age.label.firstIndex(of: ")") {
                                Text(age.label[age.label.index(after: open)..<close])
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundStyle(introAge == age ? .white.opacity(0.5) : .white.opacity(0.2))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(introAge == age ? Color(hex: "4FC3F7").opacity(0.2) : .white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(introAge == age ? Color(hex: "4FC3F7").opacity(0.4) : .clear, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(label: age.label, traits: .isButton)
                }
            }
            
            introContinueButton
        }
        .padding(DesignTokens.spacingLG)
        .background(introOverlayBackground)
    }
    
    // MARK: Your Challenge — ADHD challenge grid with SF Symbols
    
    private var yourChallengeOverlay: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // 3×2 vertical tile grid — icon on top, short label below
            let rows: [[ADHDChallenge]] = [
                [.starting, .staying, .remembering],
                [.emotions, .timeBlindness, .allOfAbove]
            ]
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { c in
                        challengeTile(c)
                    }
                }
            }
            
            introContinueButton
        }
        .padding(DesignTokens.spacingLG)
        .background(introOverlayBackground)
    }
    
    /// Short display label for challenge tiles (max 2 words).
    private func challengeShortLabel(_ c: ADHDChallenge) -> String {
        switch c {
        case .starting:      return String(localized: "Starting")
        case .staying:       return String(localized: "Focus")
        case .remembering:   return String(localized: "Memory")
        case .emotions:      return String(localized: "Emotions")
        case .timeBlindness: return String(localized: "Time")
        case .allOfAbove:    return String(localized: "All of it")
        }
    }
    
    /// Individual challenge tile — vertical layout: icon + short label.
    private func challengeTile(_ c: ADHDChallenge) -> some View {
        let isSelected = introChallenge == c
        return Button {
            HapticService.shared.actionButtonTap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                introChallenge = c
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: c.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: "4FC3F7") : .white.opacity(0.4))
                    .frame(height: 24)
                Text(challengeShortLabel(c))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .white.opacity(0.35))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color(hex: "4FC3F7").opacity(0.2) : .white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color(hex: "4FC3F7").opacity(0.4) : .clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(label: c.label, traits: .isButton)
    }
    
    // MARK: How To Talk — personality mode picker
    
    private var howToTalkOverlay: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            HStack(spacing: 8) {
                ForEach(NudgyPersonalityMode.allCases, id: \.self) { mode in
                    Button {
                        HapticService.shared.actionButtonTap()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            introMode = mode
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(introMode == mode ? Color(hex: mode.accentColorHex) : .white.opacity(0.4))
                            Text(mode.label.components(separatedBy: " ").first ?? "")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(introMode == mode ? .white.opacity(0.9) : .white.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(introMode == mode ? Color(hex: mode.accentColorHex).opacity(0.2) : .white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(introMode == mode ? Color(hex: mode.accentColorHex).opacity(0.4) : .clear, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(label: mode.label, traits: .isButton)
                }
            }
            
            // Live demo line — shows how the chosen mode sounds
            Text(modeDemoLine)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .italic()
                .multilineTextAlignment(.center)
                .frame(minHeight: 32)
                .animation(.easeOut(duration: 0.3), value: introMode)
            
            introContinueButton
        }
        .padding(DesignTokens.spacingLG)
        .background(introOverlayBackground)
    }
    
    /// Mode demo line — Nudgy speaks in the chosen voice so the user hears the difference.
    private var modeDemoLine: String {
        switch introMode {
        case .gentle: return String(localized: "\"No rush. …We'll take it one small thing at a time.\"")
        case .coach:  return String(localized: "\"Good. One down. What's next?\"")
        case .silly:  return String(localized: "\"A penguin life coach. I don't even have knees. …Let's do this.\"")
        case .quiet:  return String(localized: "\"…done.\"")
        }
    }
    
    // MARK: How It Works — 4-step tutorial
    
    private var howItWorksOverlay: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // Step indicator dots
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i == tutorialStep ? Color(hex: "4FC3F7") : .white.opacity(0.2))
                        .frame(width: i == tutorialStep ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tutorialStep)
                }
            }
            
            // Tutorial card — swipeable with drag gesture
            tutorialCard
                .frame(height: 120)
                .offset(x: tutorialDragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let tx = value.translation.width
                            let canForward = tutorialStep < 3
                            let canBack = tutorialStep > 0
                            if (tx < 0 && !canForward) || (tx > 0 && !canBack) {
                                tutorialDragOffset = tx * 0.2 // rubber-band at edges
                            } else {
                                tutorialDragOffset = tx
                            }
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            if value.translation.width < -threshold && tutorialStep < 3 {
                                HapticService.shared.actionButtonTap()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    tutorialStep += 1
                                    tutorialDragOffset = 0
                                }
                            } else if value.translation.width > threshold && tutorialStep > 0 {
                                HapticService.shared.actionButtonTap()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    tutorialStep -= 1
                                    tutorialDragOffset = 0
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    tutorialDragOffset = 0
                                }
                            }
                        }
                )
                .id(tutorialStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: tutorialStep)
            
            // Back / Next navigation
            HStack(spacing: 10) {
                // Back button — appears after first step
                if tutorialStep > 0 {
                    Button {
                        HapticService.shared.actionButtonTap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            tutorialStep -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
                
                // Next / Let's Go button
                Button {
                    HapticService.shared.actionButtonTap()
                    if tutorialStep < 3 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            tutorialStep += 1
                        }
                    } else {
                        nameFieldFocused = false
                        HapticService.shared.swipeDone()
                        advanceScene()
                    }
                } label: {
                    Text(tutorialStep < 3 ? String(localized: "Next") : String(localized: "Let's Go"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(hex: "4FC3F7").opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(hex: "4FC3F7").opacity(0.5), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tutorialStep)
        }
        .padding(DesignTokens.spacingLG)
        .background(introOverlayBackground)
    }
    
    @ViewBuilder
    private var tutorialCard: some View {
        switch tutorialStep {
        case 0:
            tutorialStepView(
                icon: "tray.and.arrow.down.fill",
                iconColor: Color(hex: "FFD54F"),
                title: String(localized: "Pour It All Out"),
                subtitle: String(localized: "Tell me every task, thought, and worry. …I'll sort through it. That's what flippers are for.")
            )
        case 1:
            tutorialStepView(
                icon: "mic.fill",
                iconColor: Color(hex: "FF6B8A"),
                title: String(localized: "Speak, Type, or Share"),
                subtitle: String(localized: "Use your voice, your keyboard, or share from any app. …However you think, I'll catch it.")
            )
        case 2:
            tutorialStepView(
                icon: "rectangle.portrait.fill",
                iconColor: Color(hex: "4FC3F7"),
                title: String(localized: "One Thing at a Time"),
                subtitle: String(localized: "No big scary lists. Just one card. …That's all you need to look at.")
            )
        default:
            tutorialStepView(
                icon: "hand.draw.fill",
                iconColor: Color(hex: "30D158"),
                title: String(localized: "Swipe to Act"),
                subtitle: String(localized: "Done, snooze, or skip — just swipe. …Simple things should be simple.")
            )
        }
    }
    
    private func tutorialStepView(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(height: 44)
            
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text(subtitle)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: Shared Overlay Components
    
    private var introContinueButton: some View {
        Button {
            nameFieldFocused = false
            HapticService.shared.swipeDone()
            advanceScene()
        } label: {
            Text(String(localized: "Continue"))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "4FC3F7").opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "4FC3F7").opacity(0.5), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var introOverlayBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.5))
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
    
    // MARK: - Pending Profile
    
    /// Save personalization choices to non-scoped UserDefaults keys.
    /// These will be applied by NudgeApp after user activation sets activeUserID.
    private func savePendingProfile() {
        let defaults = UserDefaults.standard
        let trimmed = introName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            defaults.set(trimmed, forKey: "pendingProfileName")
        }
        defaults.set(introAge.rawValue, forKey: "pendingProfileAge")
        defaults.set(introChallenge.rawValue, forKey: "pendingProfileChallenge")
        defaults.set(introMode.rawValue, forKey: "pendingProfileMode")
        defaults.set(true, forKey: "pendingProfileFromIntro")
    }
    
}

// MARK: - Previews

#Preview("Full Intro") {
    NudgyIntroView()
        .environment(AppSettings())
        .environment(AuthSession())
        .environment(PenguinState())
}
