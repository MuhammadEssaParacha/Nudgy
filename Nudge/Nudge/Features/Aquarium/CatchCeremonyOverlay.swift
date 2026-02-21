//
//  CatchCeremonyOverlay.swift
//  Nudge
//
//  Fishing ceremony overlay when user completes a task and earns a fish.
//  Fishing line drops, fish wiggles on hook, reels in, splashes into tank
//  with water droplets + sparkle particles. Dismisses after 3.5s or on tap.
//

import SwiftUI

// MARK: - Ceremony Particle

private struct CeremonyParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var opacity: Double
    var color: Color
    var kind: ParticleKind

    enum ParticleKind {
        case droplet, sparkle, bubble
    }
}

struct CatchCeremonyOverlay: View {

    let fishCatch: FishCatch
    let onDismiss: () -> Void

    @State private var phase: CeremonyPhase = .casting
    @State private var lineLength: CGFloat = 0
    @State private var fishWiggle: Double = 0
    @State private var fishScale: CGFloat = 0
    @State private var reelProgress: CGFloat = 0
    @State private var splashScale: CGFloat = 0
    @State private var splashOpacity: Double = 0
    @State private var labelOpacity: Double = 0
    @State private var labelOffset: CGFloat = 20
    @State private var overlayOpacity: Double = 0
    @State private var particles: [CeremonyParticle] = []
    @State private var fishBadgeScale: CGFloat = 0
    @State private var viewSize: CGSize = .init(width: 390, height: 844)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum CeremonyPhase {
        case casting, hooked, reeling, splash, done
    }

    var body: some View {
        GeometryReader { geo in
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: phase == .done || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                // Dim background
                Color.black.opacity(0.45 * overlayOpacity)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(spacing: 0) {
                    fishingLine
                    Spacer()
                }

                // Fish on the line
                fishOnLine(time: time)

                // Particles (droplets, sparkles, bubbles)
                particleLayer

                // Splash ring
                if phase == .splash || phase == .done {
                    splashEffect
                }

                // Reward card
                if phase == .splash || phase == .done {
                    rewardLabel
                }
            }
        }
        .onAppear {
            viewSize = geo.size
            if reduceMotion {
                phase = .done
                overlayOpacity = 1
                labelOpacity = 1
                labelOffset = 0
                autoDismissAfterDelay()
            } else {
                startCeremony()
            }
        }
        .nudgeAccessibility(
            label: String(localized: "You caught a \(fishCatch.species.label)!"),
            hint: String(localized: "Tap to dismiss")
        )
        } // end GeometryReader
    }

    // MARK: - Fishing Line

    private var fishingLine: some View {
        VStack(spacing: 0) {
            // Rod tip
            Circle()
                .fill(Color(hex: "8D6E63"))
                .frame(width: 8, height: 8)

            // Line with slight curve
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1.5, height: lineLength)
        }
        .opacity(phase == .done ? 0 : overlayOpacity)
    }

    // MARK: - Fish on Line (Animated)

    private func fishOnLine(time: Double) -> some View {
        let yOffset: CGFloat
        switch phase {
        case .casting: yOffset = 60 + lineLength
        case .hooked: yOffset = 60 + lineLength
        case .reeling: yOffset = 60 + lineLength * (1 - reelProgress)
        case .splash, .done: yOffset = viewSize.height * 0.5
        }

        // Tail wag while hooked/reeling — faster wag when fighting
        let tailPhase: CGFloat
        if (phase == .hooked || phase == .reeling), !reduceMotion {
            let wagSpeed: Double = phase == .hooked ? 6.0 : 8.0
            tailPhase = CGFloat(sin(time * wagSpeed))
        } else {
            tailPhase = 0
        }

        return AnimatedFishView(
            size: fishCatch.species.displaySize * 1.8,
            color: fishCatch.species.fishColor,
            accentColor: fishCatch.species.fishAccentColor,
            tailPhase: tailPhase
        )
        .rotationEffect(.degrees(fishWiggle))
        .scaleEffect(fishScale)
        .offset(y: yOffset - viewSize.height * 0.5)
        .opacity(phase == .done ? 0 : overlayOpacity)
    }

    // MARK: - Particles

    private var particleLayer: some View {
        ForEach(particles) { p in
            Group {
                switch p.kind {
                case .droplet:
                    Capsule()
                        .fill(Color(hex: "4FC3F7").opacity(p.opacity))
                        .frame(width: p.size * 0.5, height: p.size)
                case .sparkle:
                    SparkleShape()
                        .fill(Color(hex: "FFD54F").opacity(p.opacity))
                        .frame(width: p.size, height: p.size)
                case .bubble:
                    Circle()
                        .stroke(Color.white.opacity(p.opacity), lineWidth: 0.8)
                        .frame(width: p.size, height: p.size)
                }
            }
            .position(x: p.x, y: p.y)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Splash

    private var splashEffect: some View {
        ZStack {
            // Inner ring
            Circle()
                .stroke(
                    fishCatch.species.fishColor.opacity(splashOpacity * 0.6),
                    lineWidth: 2
                )
                .frame(width: 50 * splashScale, height: 50 * splashScale)

            // Outer ring
            Circle()
                .stroke(
                    Color(hex: "4FC3F7").opacity(splashOpacity * 0.4),
                    lineWidth: 2.5
                )
                .frame(width: 90 * splashScale, height: 90 * splashScale)
        }
        .offset(y: viewSize.height * 0.15)
    }

    // MARK: - Reward Label

    private var rewardLabel: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // Species icon large
            Image(systemName: fishCatch.species.icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color(hex: fishCatch.species.glowColorHex))

            Text(String(localized: "You caught a \(fishCatch.species.label)!"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(DesignTokens.textPrimary)

            // Fish reward badge
            HStack(spacing: 6) {
                Image(systemName: "fish.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("+\(fishCatch.species.fishValue)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color(hex: "4FC3F7"))
            .scaleEffect(fishBadgeScale)
        }
        .opacity(labelOpacity)
        .offset(y: labelOffset)
    }

    // MARK: - Ceremony Sequence

    private func startCeremony() {
        // Fade in
        withAnimation(.easeOut(duration: 0.3)) {
            overlayOpacity = 1
        }

        // Phase 1: Cast line down
        phase = .casting
        withAnimation(.easeOut(duration: 0.6)) {
            lineLength = 180
        }

        Task { @MainActor in
            // Phase 2: Fish appears + wiggles
            try? await Task.sleep(for: .seconds(0.7))
            phase = .hooked
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                fishScale = 1.0
            }
            HapticService.shared.actionButtonTap()
            startWiggle()

            // Phase 3: Reel in
            try? await Task.sleep(for: .seconds(0.8))
            phase = .reeling
            withAnimation(.easeInOut(duration: 0.8)) {
                reelProgress = 1.0
            }

            // Phase 4: Splash + particles
            try? await Task.sleep(for: .seconds(0.8))
            phase = .splash
            HapticService.shared.swipeDone()

            // Splash rings
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                splashScale = 1.5
                splashOpacity = 0.8
            }

            // Spawn particles — droplets + sparkles
            spawnSplashParticles()

            // Label slides up
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.15)) {
                labelOpacity = 1
                labelOffset = 0
            }

            // Fish badge pops
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.35)) {
                fishBadgeScale = 1.0
            }

            // Fade splash rings
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                splashOpacity = 0
            }
        }

        autoDismissAfterDelay()
    }

    private func spawnSplashParticles() {
        let center = CGPoint(
            x: viewSize.width * 0.5,
            y: viewSize.height * 0.65
        )
        let fishColor = fishCatch.species.fishColor

        // Water droplets — burst outward
        for i in 0..<8 {
            let angle = Double(i) * .pi * 2.0 / 8.0 + Double.random(in: -0.3...0.3)
            let speed = CGFloat.random(in: 40...80)
            particles.append(CeremonyParticle(
                x: center.x,
                y: center.y,
                vx: CGFloat(cos(angle)) * speed,
                vy: CGFloat(sin(angle)) * speed - 30,  // bias upward
                size: CGFloat.random(in: 4...8),
                opacity: 0.7,
                color: Color(hex: "4FC3F7"),
                kind: .droplet
            ))
        }

        // Sparkles — centered, drift up
        for _ in 0..<5 {
            particles.append(CeremonyParticle(
                x: center.x + CGFloat.random(in: -30...30),
                y: center.y + CGFloat.random(in: -20...20),
                vx: CGFloat.random(in: -10...10),
                vy: CGFloat.random(in: -25...(-10)),
                size: CGFloat.random(in: 8...14),
                opacity: 0.8,
                color: fishColor,
                kind: .sparkle
            ))
        }

        // Tiny bubbles — rise up
        for _ in 0..<4 {
            particles.append(CeremonyParticle(
                x: center.x + CGFloat.random(in: -20...20),
                y: center.y,
                vx: CGFloat.random(in: -5...5),
                vy: CGFloat.random(in: -40...(-15)),
                size: CGFloat.random(in: 4...8),
                opacity: 0.4,
                color: .white,
                kind: .bubble
            ))
        }

        // Animate particles with physics
        animateParticles()
    }

    private func animateParticles() {
        Task { @MainActor in
            for _ in 0..<40 {  // ~1.3 seconds
                try? await Task.sleep(for: .seconds(1.0 / 30.0))

                for i in particles.indices {
                    particles[i].x += particles[i].vx * (1.0 / 30.0)
                    particles[i].y += particles[i].vy * (1.0 / 30.0)
                    particles[i].vy += 30 * (1.0 / 30.0)  // gravity
                    particles[i].opacity *= 0.96  // fade
                }
            }

            withAnimation(.easeOut(duration: 0.2)) {
                for i in particles.indices {
                    particles[i].opacity = 0
                }
            }
            try? await Task.sleep(for: .seconds(0.25))
            particles.removeAll()
        }
    }

    private func startWiggle() {
        guard phase == .hooked || phase == .reeling else { return }

        withAnimation(.easeInOut(duration: 0.12)) {
            fishWiggle = 14
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.12))
            guard self.phase == .hooked || self.phase == .reeling else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                fishWiggle = -14
            }
            try? await Task.sleep(for: .seconds(0.12))
            guard self.phase == .hooked || self.phase == .reeling else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                fishWiggle = 0
            }
            try? await Task.sleep(for: .seconds(0.25))
            startWiggle()
        }
    }

    private func autoDismissAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            overlayOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview("Catch Ceremony") {
    ZStack {
        Color.black.ignoresSafeArea()
        CatchCeremonyOverlay(
            fishCatch: FishCatch(
                species: .tropical,
                taskContent: "Reply to emails",
                taskEmoji: "📧"
            ),
            onDismiss: {}
        )
    }
}
