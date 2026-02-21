//
//  FishEvolutionCelebration.swift
//  Nudge
//
//  Full-screen celebration when a fish evolves to a new stage.
//  Fish glows, grows in place, particles burst, label fades in.
//  Dismisses after ~4s or on tap.
//

import SwiftUI

// MARK: - Evolution Particle

private struct EvoParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var opacity: Double
    var color: Color
}

// MARK: - FishEvolutionCelebration

struct FishEvolutionCelebration: View {

    let species: FishSpecies
    let newStage: FishEvolutionStage
    let onDismiss: () -> Void

    @State private var phase: Phase = .grow
    @State private var fishScale: CGFloat = 1.0
    @State private var glowRadius: CGFloat = 0
    @State private var glowOpacity: Double = 0
    @State private var labelOpacity: Double = 0
    @State private var labelOffset: CGFloat = 24
    @State private var overlayOpacity: Double = 0
    @State private var particles: [EvoParticle] = []
    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase {
        case grow, burst, show, done
    }

    private var accentColor: Color { species.fishColor }
    private var displaySize: CGFloat { species.evolvedDisplaySize(for: newStage) }

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(overlayOpacity * 0.72)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Ring burst
            Circle()
                .strokeBorder(accentColor.opacity(ringOpacity), lineWidth: 3)
                .frame(width: 180 * ringScale, height: 180 * ringScale)
                .blur(radius: 2)

            // Particles
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .opacity(p.opacity)
                    .offset(x: p.x, y: p.y)
            }

            VStack(spacing: 28) {
                // Fish with glow
                ZStack {
                    // Glow halo
                    Circle()
                        .fill(accentColor.opacity(glowOpacity * 0.25))
                        .frame(width: displaySize * 2.2, height: displaySize * 2.2)
                        .blur(radius: glowRadius)

                    FishView(
                        size: displaySize,
                        color: species.fishColor,
                        accentColor: species.fishAccentColor
                    )
                    .scaleEffect(fishScale)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.55),
                        value: fishScale
                    )
                }

                // Stage label
                VStack(spacing: 8) {
                    Text(String(localized: "\(species.label) evolved!"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(newStage.label.uppercased())
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(accentColor.opacity(0.18))
                        )

                    let count = RewardService.shared.catchCountsPerSpecies[species.rawValue] ?? 0
                    Text(String(localized: "\(count) tasks completed"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .opacity(labelOpacity)
                .offset(y: labelOffset)
            }
        }
        .opacity(1)
        .onAppear { animate() }
    }

    // MARK: - Animation Sequence

    private func animate() {
        guard !reduceMotion else {
            overlayOpacity = 0.9
            fishScale = 1.0
            glowOpacity = newStage.glowIntensity
            glowRadius = 30
            labelOpacity = 1
            labelOffset = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { dismiss() }
            return
        }

        // 1. Fade in overlay
        withAnimation(.easeIn(duration: 0.25)) {
            overlayOpacity = 0.9
        }

        // 2. Fish pulses out then settles at new size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            fishScale = 1.35
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) {
                fishScale = 1.35
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                    fishScale = 1.0
                }
            }
        }

        // 3. Glow expands
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.6)) {
                glowOpacity = newStage.glowIntensity + 0.3
                glowRadius = displaySize * 1.1
            }
            withAnimation(.easeInOut(duration: 1.2).delay(0.5)) {
                glowOpacity = newStage.glowIntensity
            }
        }

        // 4. Ring burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.7)) {
                ringScale = 2.8
                ringOpacity = 0.7
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                ringOpacity = 0
            }
        }

        // 5. Spawn particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            spawnParticles()
        }

        // 6. Label rises in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                labelOpacity = 1
                labelOffset = 0
            }
        }

        // 7. Auto-dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) { dismiss() }
    }

    private func spawnParticles() {
        let colors: [Color] = [accentColor, accentColor.opacity(0.6), .white.opacity(0.8), species.fishAccentColor]
        particles = (0..<28).map { _ in
            let angle = Double.random(in: 0 ..< .pi * 2)
            let speed = CGFloat.random(in: 60 ... 160)
            return EvoParticle(
                x: 0, y: 0,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                size: CGFloat.random(in: 4...10),
                opacity: Double.random(in: 0.7...1.0),
                color: colors.randomElement()!
            )
        }

        // Drive particles outward
        withAnimation(.easeOut(duration: 1.1)) {
            for i in particles.indices {
                particles[i].x = particles[i].vx
                particles[i].y = particles[i].vy
                particles[i].opacity = 0
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            overlayOpacity = 0
            labelOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismiss()
        }
    }
}
