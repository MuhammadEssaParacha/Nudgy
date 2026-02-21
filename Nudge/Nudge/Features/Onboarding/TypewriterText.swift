//
//  TypewriterText.swift
//  Nudge
//
//  Character-by-character text reveal with haptic ticks.
//  Used in the intro journey for Nudgy's dialogue bubbles.
//
//  Features:
//  - Character-by-character reveal with configurable speed
//  - Per-character haptic tick (subtle, grouped)
//  - Tap to instantly reveal full text
//  - Callback when typing completes
//  - Fish emoji gets a special "pop" haptic
//

import SwiftUI

// MARK: - Typewriter Text View

struct TypewriterText: View {
    let fullText: String
    var typingSpeed: TimeInterval = 0.035
    var onComplete: (() -> Void)?
    
    @State private var visibleCount: Int = 0
    @State private var isComplete: Bool = false
    @State private var typingTask: Task<Void, Never>?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var displayedText: String {
        if isComplete || reduceMotion {
            return fullText
        }
        return String(fullText.prefix(visibleCount))
    }
    
    var body: some View {
        Text(displayedText)
            .onAppear {
                if reduceMotion {
                    isComplete = true
                    onComplete?()
                } else {
                    startTyping()
                }
            }
            .onDisappear {
                typingTask?.cancel()
            }
            .onTapGesture {
                completeInstantly()
            }
    }
    
    // MARK: - Typing Engine
    
    private func startTyping() {
        visibleCount = 0
        isComplete = false
        
        typingTask?.cancel()
        typingTask = Task { @MainActor in
            let characters = Array(fullText)
            var tickCounter = 0
            
            for i in 0..<characters.count {
                guard !Task.isCancelled else { return }
                
                // Wait before revealing next character
                try? await Task.sleep(for: .seconds(typingSpeed))
                
                guard !Task.isCancelled else { return }
                visibleCount = i + 1
                
                let char = characters[i]
                
                // Haptic feedback — every 3rd character for subtle typing feel
                tickCounter += 1
                if tickCounter % 3 == 0 {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.impactOccurred(intensity: 0.15)
                }
                
                // Pause at punctuation for natural rhythm
                if char == "." || char == "!" || char == "?" {
                    try? await Task.sleep(for: .seconds(0.3))
                    // Punctuation gets a slightly heavier tick
                    let puncGenerator = UIImpactFeedbackGenerator(style: .light)
                    puncGenerator.impactOccurred(intensity: 0.3)
                } else if char == "," || char == "—" {
                    try? await Task.sleep(for: .seconds(0.15))
                } else if char == "\n" {
                    try? await Task.sleep(for: .seconds(0.2))
                }
            }
            
            guard !Task.isCancelled else { return }
            isComplete = true
            onComplete?()
        }
    }
    
    private func completeInstantly() {
        guard !isComplete else { return }
        typingTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            visibleCount = fullText.count
            isComplete = true
        }
        HapticService.shared.actionButtonTap()
        onComplete?()
    }
}

// MARK: - Intro Dialogue Bubble

/// Speech bubble styled for the intro sequence — dark glass with accent border.
struct IntroDialogueBubble: View {
    let text: String
    var expression: PenguinExpression = .idle
    var typingSpeed: TimeInterval = 0.035
    var maxWidth: CGFloat = 300
    var onTypingComplete: (() -> Void)?
    
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Bubble
            TypewriterText(
                fullText: text,
                typingSpeed: typingSpeed,
                onComplete: onTypingComplete
            )
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, DesignTokens.spacingXL)
            .padding(.vertical, DesignTokens.spacingLG)
            .frame(maxWidth: maxWidth)
            .background(bubbleBackground)
            
            // Tail pointer
            Triangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 16, height: 10)
                .rotationEffect(.degrees(180))
                .offset(y: -1)
        }
        .scaleEffect(appeared ? 1.0 : 0.5)
        .opacity(appeared ? 1.0 : 0.0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
    
    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.3))
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

// MARK: - Intro Prompt Indicator

/// "Tap to continue" indicator that fades in after dialogue completes.
struct TapToContinue: View {
    var visible: Bool = true
    
    @State private var pulse = false
    @State private var tapBounce = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 13))
                .offset(y: tapBounce ? -3 : 0)
                .scaleEffect(tapBounce ? 1.15 : 1.0)
            Text(String(localized: "Tap to continue"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white.opacity(pulse ? 0.45 : 0.2))
        .opacity(visible ? 1.0 : 0.0)
        .scaleEffect(visible ? 1.0 : 0.8)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: visible)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
            withAnimation(
                .spring(response: 0.35, dampingFraction: 0.4)
                .repeatForever(autoreverses: true)
                .delay(0.2)
            ) {
                tapBounce = true
            }
        }
        .nudgeAccessibility(
            label: String(localized: "Tap anywhere to continue"),
            hint: nil,
            traits: .isStaticText
        )
    }
}

// MARK: - Fish Reward Burst

/// Animated fish emoji burst for the "earning fish" scene.
struct FishBurst: View {
    var trigger: Bool = false
    
    @State private var fishParticles: [FishParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(fishParticles) { fish in
                FishView(
                    size: fish.size,
                    color: fish.color,
                    accentColor: fish.accentColor
                )
                .offset(x: fish.offsetX, y: fish.offsetY)
                .opacity(fish.opacity)
                .rotationEffect(.degrees(fish.rotation))
                .scaleEffect(x: fish.flipX ? -1 : 1, y: 1)
            }
        }
        .onChange(of: trigger) { _, newValue in
            if newValue { spawnFish() }
        }
        .allowsHitTesting(false)
    }
    
    private func spawnFish() {
        let fishColors: [(Color, Color)] = [
            (Color(hex: "4FC3F7"), Color(hex: "0288D1")),  // Blue
            (Color(hex: "FF8A65"), Color(hex: "E64A19")),  // Orange
            (Color(hex: "81C784"), Color(hex: "388E3C")),  // Green
            (Color(hex: "CE93D8"), Color(hex: "7B1FA2")),  // Purple
            (Color(hex: "4FC3F7"), Color(hex: "0288D1")),  // Blue
            (Color(hex: "FFD54F"), Color(hex: "F57F17")),  // Gold
            (Color(hex: "FF8A65"), Color(hex: "E64A19")),  // Extra orange
            (Color(hex: "81C784"), Color(hex: "388E3C")),  // Extra green
        ]
        var particles: [FishParticle] = []
        
        for (i, colors) in fishColors.enumerated() {
            // Fan out in a wider arc (full semicircle above)
            let baseAngle = -Double.pi + (Double(i) / Double(fishColors.count)) * Double.pi
            let angle = baseAngle + Double.random(in: -0.2...0.2)
            let distance: CGFloat = CGFloat.random(in: 80...160)
            
            let particle = FishParticle(
                id: UUID(),
                size: CGFloat.random(in: 24...48),
                color: colors.0,
                accentColor: colors.1,
                flipX: Bool.random(),
                offsetX: 0,
                offsetY: 0,
                opacity: 0,
                rotation: 0,
                targetX: cos(angle) * distance,
                targetY: sin(angle) * distance - 20,
                targetRotation: Double.random(in: -35...35)
            )
            particles.append(particle)
            
            // Stagger each fish with varying delay
            let delay = Double(i) * 0.06
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                if let idx = fishParticles.firstIndex(where: { $0.id == particle.id }) {
                    // Pop out with bouncy spring
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        fishParticles[idx].offsetX = particle.targetX
                        fishParticles[idx].offsetY = particle.targetY
                        fishParticles[idx].opacity = 1.0
                        fishParticles[idx].rotation = particle.targetRotation
                    }
                    
                    // Gravity: fish drift downward after peaking
                    try? await Task.sleep(for: .seconds(0.5))
                    withAnimation(.easeIn(duration: 0.8)) {
                        if let idx = fishParticles.firstIndex(where: { $0.id == particle.id }) {
                            fishParticles[idx].offsetY += 60
                            fishParticles[idx].rotation += Double.random(in: -20...20)
                        }
                    }
                    
                    // Fade out
                    try? await Task.sleep(for: .seconds(0.5))
                    withAnimation(.easeOut(duration: 0.4)) {
                        if let idx = fishParticles.firstIndex(where: { $0.id == particle.id }) {
                            fishParticles[idx].opacity = 0
                        }
                    }
                }
            }
        }
        
        fishParticles = particles
        HapticService.shared.swipeDone()
    }
}

// MARK: - Fish Particle Model

private struct FishParticle: Identifiable {
    let id: UUID
    let size: CGFloat
    let color: Color
    let accentColor: Color
    let flipX: Bool
    var offsetX: CGFloat
    var offsetY: CGFloat
    var opacity: Double
    var rotation: Double
    let targetX: CGFloat
    let targetY: CGFloat
    let targetRotation: Double
}

// MARK: - Previews

#Preview("Typewriter") {
    ZStack {
        Color.black.ignoresSafeArea()
        TypewriterText(
            fullText: "Heyy! Nice to see you! I'm Nudgy... welcome to my home!"
        )
        .font(.system(size: 20, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .padding()
    }
}

#Preview("Dialogue Bubble") {
    ZStack {
        Color.black.ignoresSafeArea()
        IntroDialogueBubble(
            text: "I help you do things, and we earn fish together... ooh how exciting!"
        )
    }
}

#Preview("Fish Burst") {
    struct Demo: View {
        @State private var trigger = false
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                FishBurst(trigger: trigger)
                Button("Burst!") { trigger.toggle() }
                    .offset(y: 100)
            }
        }
    }
    return Demo()
}
