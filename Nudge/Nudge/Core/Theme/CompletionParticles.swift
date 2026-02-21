//
//  CompletionParticles.swift
//  Nudge
//
//  Green checkmark particle burst effect played when a task is swiped "Done".
//  Small green dots radiate outward from the card center and fade.
//  Respects Reduce Motion — cross-fades a simple checkmark instead.
//

import SwiftUI

// MARK: - Particle Model

private struct Particle: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let delay: Double
    let isSparkle: Bool   // true → 4-point star, false → filled circle
    let colorStyle: Int   // 0 = tint, 1 = gold, 2 = white
}

// MARK: - 4-Point Sparkle Shape (local — distinct from IntroVectorShapes.SparkleShape)

private struct BurstSparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let outer = min(rect.width, rect.height) * 0.5
        let inner = outer * 0.35
        var path = Path()
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4.0 - (.pi / 2.0)
            let r: CGFloat = i.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: cx + CGFloat(cos(angle)) * r,
                             y: cy + CGFloat(sin(angle)) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Completion Particles View

struct CompletionParticles: View {

    @Binding var isActive: Bool
    /// Optional category color — tints particles with the task's category instead of generic green.
    var categoryColor: Color? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var burstPhase  = false
    @State private var wave1       = false
    @State private var wave2       = false
    @State private var checkScale: CGFloat = 0.01
    @State private var checkOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.4
    @State private var ringOpacity: Double = 0

    private var tint: Color { categoryColor ?? DesignTokens.accentComplete }

    // Pre-computed — 20 particles, deterministic (no random re-rolls on re-render)
    private let particles: [Particle] = {
        let count = 20
        return (0..<count).map { i in
            let angle    = (Double(i) / Double(count)) * 2 * .pi + Double(i % 3) * 0.16
            let distance = CGFloat(44 + (i % 5) * 13)
            let size     = CGFloat(3.5 + Double(i % 4) * 1.5)
            let delay    = Double(i) * 0.016
            return Particle(angle: angle, distance: distance, size: size,
                            delay: delay, isSparkle: i % 3 == 0, colorStyle: i % 3)
        }
    }()

    var body: some View {
        ZStack {
            if reduceMotion {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(tint)
                    .opacity(checkOpacity)
                    .scaleEffect(checkScale)
            } else {
                // ── Shockwave ring 1 ──
                Circle()
                    .stroke(tint.opacity(wave1 ? 0 : 0.65), lineWidth: 1.5)
                    .scaleEffect(wave1 ? 3.4 : 0.15)
                    .animation(.easeOut(duration: 0.55), value: wave1)

                // ── Shockwave ring 2 (softer, slightly delayed) ──
                Circle()
                    .stroke(tint.opacity(wave2 ? 0 : 0.28), lineWidth: 1)
                    .scaleEffect(wave2 ? 4.6 : 0.15)
                    .animation(.easeOut(duration: 0.75).delay(0.08), value: wave2)

                // ── Glow halo behind checkmark ──
                Circle()
                    .fill(tint.opacity(0.25))
                    .frame(width: 60, height: 60)
                    .blur(radius: 8)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)
                    .animation(.spring(response: 0.38, dampingFraction: 0.55), value: ringScale)

                // ── Particle burst (circles + sparkle stars) ──
                ForEach(particles) { p in
                    Group {
                        if p.isSparkle {
                            BurstSparkleShape().fill(particleColor(p))
                        } else {
                            Circle().fill(particleColor(p))
                        }
                    }
                    .frame(width: p.size, height: p.size)
                    .offset(
                        x: burstPhase ? CGFloat(cos(p.angle)) * p.distance : 0,
                        y: burstPhase ? CGFloat(sin(p.angle)) * p.distance : 0
                    )
                    .opacity(burstPhase ? 0 : 1)
                    .scaleEffect(burstPhase ? 0.2 : 1.0)
                    .animation(
                        .spring(response: 0.48, dampingFraction: 0.62).delay(p.delay),
                        value: burstPhase
                    )
                }

                // ── Solid checkmark on glowing disc ──
                ZStack {
                    Circle()
                        .fill(tint)
                        .frame(width: 48, height: 48)
                        .shadow(color: tint.opacity(0.6), radius: 14, y: 4)
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .scaleEffect(checkScale)
                .opacity(checkOpacity)
                .animation(.spring(response: 0.28, dampingFraction: 0.48), value: checkScale)
            }
        }
        .onChange(of: isActive) { _, active in
            guard active else { resetAll(); return }
            if reduceMotion { runReducedMotion(); return }
            runBurst()
        }
    }

    // MARK: - Helpers

    private func particleColor(_ p: Particle) -> Color {
        switch p.colorStyle {
        case 0:  return tint
        case 1:  return DesignTokens.goldCurrency
        default: return Color.white.opacity(0.88)
        }
    }

    private func resetAll() {
        burstPhase   = false
        wave1        = false
        wave2        = false
        checkScale   = 0.01
        checkOpacity = 0
        ringScale    = 0.4
        ringOpacity  = 0
    }

    private func runBurst() {
        wave1 = true
        wave2 = true
        withAnimation { ringScale = 1.2; ringOpacity = 1 }
        withAnimation(.spring(response: 0.01)) { burstPhase = true }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.48).delay(0.04)) {
            checkScale = 1.0
            checkOpacity = 1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.65))
            withAnimation(.easeOut(duration: 0.28)) { ringOpacity = 0; ringScale = 1.7 }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeIn(duration: 0.22)) { checkOpacity = 0; checkScale = 0.7 }
            try? await Task.sleep(for: .seconds(0.25))
            isActive = false
        }
    }

    private func runReducedMotion() {
        withAnimation(.easeOut(duration: 0.2)) { checkScale = 1.0; checkOpacity = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation(.easeIn(duration: 0.2)) { checkOpacity = 0 }
            try? await Task.sleep(for: .seconds(0.2))
            isActive = false
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var active = false
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 40) {
                    CompletionParticles(isActive: $active)
                    
                    Button("Trigger") {
                        active = true
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
    return PreviewWrapper()
}
