//
//  StageUpCelebration.swift
//  Nudge
//
//  Full-screen celebration overlay when the player tiers up to a new stage.
//
//  Sequence:
//    1. Screen dims with a radial vignette
//    2. Confetti / sparkle burst from center
//    3. Stage badge scales in with spring bounce
//    4. "STAGE UP!" text fades in
//    5. New stage name + icon appear
//    6. Nudgy does a happy dance (expression = .celebrating)
//    7. Auto-dismisses after 3.5 seconds, or tap to dismiss
//
//  Triggered by RewardService when lifetimeFish crosses a tier boundary.
//

import SwiftUI

// MARK: - Celebration Particle

private struct CelebrationParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let velocityX: CGFloat
    let velocityY: CGFloat
    let size: CGFloat
    let color: Color
    let rotationSpeed: Double
    var rotation: Double = 0
    var opacity: Double = 1.0
    var life: CGFloat = 0  // 0→1 lifecycle
}

// MARK: - Stage Up Celebration

struct StageUpCelebration: View {
    let newStage: StageTier
    let onDismiss: () -> Void

    @State private var showVignette = false
    @State private var showBurst = false
    @State private var showBadge = false
    @State private var showText = false
    @State private var particles: [CelebrationParticle] = []
    @State private var particleTimer: Timer?
    @State private var badgeScale: CGFloat = 0.3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let celebrationColors: [Color] = [
        Color(hex: "FFD700"),  // Gold
        Color(hex: "FF6B88"),  // Pink
        Color(hex: "00D4FF"),  // Cyan
        Color(hex: "7B61FF"),  // Purple
        Color(hex: "30D158"),  // Green
        Color(hex: "FF9F0A"),  // Orange
        .white,
    ]

    var body: some View {
        ZStack {
            // Layer 1: Vignette overlay
            if showVignette {
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.85),
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 500
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            // Layer 2: Confetti particles
            if showBurst {
                confettiCanvas
            }

            // Layer 3: Center content
            if showBadge {
                VStack(spacing: 16) {
                    // "STAGE UP!" header
                    if showText {
                        Text(String(localized: "STAGE UP!"))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .tracking(4)
                            .transition(.opacity.combined(with: .offset(y: -10)))
                    }

                    // Stage badge — large, centered
                    VStack(spacing: 8) {
                        // Stage icon
                        Image(systemName: stageIcon)
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: stageGradient,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: stageGradient[0].opacity(0.5), radius: 20)

                        // Stage name
                        Text(newStage.displayName.uppercased())
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(2)

                        // Stage number
                        Text(String(localized: "Stage \(newStage.stageNumber)"))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                    )
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
                    .scaleEffect(badgeScale)

                    // Tap to dismiss hint
                    if showText {
                        Text(String(localized: "tap to continue"))
                            .font(.system(size: 11))
                            .foregroundStyle(DesignTokens.textTertiary.opacity(0.5))
                            .transition(.opacity)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismiss()
        }
        .onAppear {
            runCelebrationSequence()
        }
        .onDisappear {
            particleTimer?.invalidate()
        }
    }

    // MARK: - Confetti Canvas

    private var confettiCanvas: some View {
        Canvas { context, size in
            for particle in particles {
                let rect = CGRect(
                    x: particle.x - particle.size / 2,
                    y: particle.y - particle.size / 2,
                    width: particle.size,
                    height: particle.size * 0.6
                )

                context.opacity = particle.opacity

                // Rotate particle
                var transform = CGAffineTransform.identity
                transform = transform.translatedBy(x: particle.x, y: particle.y)
                transform = transform.rotated(by: particle.rotation)
                transform = transform.translatedBy(x: -particle.x, y: -particle.y)

                context.concatenate(transform)
                context.fill(
                    RoundedRectangle(cornerRadius: 1).path(in: rect),
                    with: .color(particle.color)
                )
                // Reset transform
                context.concatenate(transform.inverted())
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: - Celebration Sequence

    private func runCelebrationSequence() {
        if reduceMotion {
            // Accessibility: show badge instantly, no confetti
            showVignette = true
            showBadge = true
            badgeScale = 1.0
            showText = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3.0))
                dismiss()
            }
            return
        }

        // Step 1: Vignette (0ms)
        withAnimation(.easeIn(duration: 0.3)) {
            showVignette = true
        }

        // Steps 2–5 as sequential Task
        Task { @MainActor in
            // Step 2: Particle burst (200ms)
            try? await Task.sleep(for: .seconds(0.2))
            spawnConfetti()
            withAnimation(.spring(response: 0.1)) {
                showBurst = true
            }

            // Step 3: Badge scales in (400ms from start = 200ms after step 2)
            try? await Task.sleep(for: .seconds(0.2))
            showBadge = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                badgeScale = 1.0
            }

            // Step 4: Text fades in (800ms from start = 400ms after step 3)
            try? await Task.sleep(for: .seconds(0.4))
            withAnimation(.easeOut(duration: 0.4)) {
                showText = true
            }

            // Step 5: Auto-dismiss (4s from start = 3.2s after step 4)
            try? await Task.sleep(for: .seconds(3.2))
            dismiss()
        }
    }

    private func dismiss() {
        particleTimer?.invalidate()
        withAnimation(.easeOut(duration: 0.3)) {
            showVignette = false
            showBadge = false
            showBurst = false
            showText = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            onDismiss()
        }
    }

    // MARK: - Confetti System

    private func spawnConfetti() {
        let screenCenter = CGPoint(
            x: UIScreen.current.bounds.midX,
            y: UIScreen.current.bounds.midY - 40
        )

        // Initial burst
        for _ in 0..<60 {
            let angle = CGFloat.random(in: 0 ... .pi * 2)
            let speed = CGFloat.random(in: 150...450)

            particles.append(CelebrationParticle(
                x: screenCenter.x + CGFloat.random(in: -20...20),
                y: screenCenter.y + CGFloat.random(in: -20...20),
                velocityX: cos(angle) * speed,
                velocityY: sin(angle) * speed - 100,  // bias upward
                size: CGFloat.random(in: 4...10),
                color: celebrationColors.randomElement()!,
                rotationSpeed: Double.random(in: -8...8)
            ))
        }

        // Physics timer
        particleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            let dt: CGFloat = 1.0 / 60.0
            let gravity: CGFloat = 400

            for i in particles.indices {
                particles[i].x += particles[i].velocityX * dt
                particles[i].y += particles[i].velocityY * dt + gravity * dt * dt * 0.5
                particles[i].rotation += particles[i].rotationSpeed * Double(dt)
                particles[i].life += dt / 3.0  // 3-second lifespan

                // Fade out in last 30% of life
                if particles[i].life > 0.7 {
                    particles[i].opacity = max(0, Double(1.0 - (particles[i].life - 0.7) / 0.3))
                }
            }

            // Remove dead particles
            particles.removeAll { $0.life >= 1.0 }

            if particles.isEmpty {
                particleTimer?.invalidate()
            }
        }
    }

    // MARK: - Stage Theme

    private var stageIcon: String {
        switch newStage {
        case .bareIce:     return "snowflake"
        case .snowNest:    return "house.fill"
        case .fishingPier: return "fish.fill"
        case .cozyCamp:    return "flame.fill"
        case .summitLodge: return "building.2.fill"
        }
    }

    private var stageGradient: [Color] {
        switch newStage {
        case .bareIce:     return [Color(hex: "A0C8E0"), Color(hex: "7BB8D0")]
        case .snowNest:    return [Color(hex: "E0E8F0"), Color(hex: "B0C0D0")]
        case .fishingPier: return [Color(hex: "FFD700"), Color(hex: "FF8C00")]
        case .cozyCamp:    return [Color(hex: "FF6B35"), Color(hex: "FF453A")]
        case .summitLodge: return [Color(hex: "7B61FF"), Color(hex: "00D4FF")]
        }
    }
}

// MARK: - Stage Up Notification

/// Notification posted when the player reaches a new stage tier.
extension Notification.Name {
    static let nudgeStageUp = Notification.Name("nudgeStageUp")
}

// MARK: - Preview

#Preview("Stage Up — Fishing Pier") {
    StageUpCelebration(newStage: .fishingPier) {}
        .background(Color.black)
}

#Preview("Stage Up — Summit Lodge") {
    StageUpCelebration(newStage: .summitLodge) {}
        .background(Color.black)
}
