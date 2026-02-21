//
//  CompletionFishBurst.swift
//  Nudge
//
//  Celebratory fish burst animation that triggers when a task is completed.
//  Ported from the intro sequence's 8-fish semicircular burst:
//    spring pop → gravity drift → fade out
//  Then golden fish fly to the AltitudeHUD (via FishRewardEngine).
//
//  Two-stage celebration:
//    1. Burst — 8 colorful FishView particles explode outward (0.6s)
//    2. Fly   — golden fish arc toward the HUD fish counter (0.6s)
//

import SwiftUI

// MARK: - Burst Fish Particle

struct BurstFishParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let targetX: CGFloat
    let targetY: CGFloat
    let driftX: CGFloat
    let driftY: CGFloat
    var size: CGFloat
    let color: Color
    let accentColor: Color
    var opacity: Double = 0
    var scale: CGFloat = 0.1
    let rotation: Double
    let delay: Double
}

// MARK: - Completion Fish Burst View

/// Full-screen overlay that shows the celebratory fish burst.
/// Call `trigger(from:hudPosition:fishCount:)` to fire.
struct CompletionFishBurst: View {
    @State private var particles: [BurstFishParticle] = []
    @State private var isActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Burst color palette — default (used when no category provided)
    private static let defaultBurstColors: [(Color, Color)] = [
        (Color(hex: "4FC3F7"), Color(hex: "0288D1")),   // Blue
        (Color(hex: "FF8A65"), Color(hex: "E64A19")),   // Orange
        (Color(hex: "81C784"), Color(hex: "388E3C")),   // Green
        (Color(hex: "BA68C8"), Color(hex: "7B1FA2")),   // Purple
        (Color(hex: "FFD54F"), Color(hex: "F57F17")),   // Gold
        (Color(hex: "4FC3F7"), Color(hex: "0288D1")),   // Blue (repeat)
        (Color(hex: "FF8A65"), Color(hex: "E64A19")),   // Orange (repeat)
        (Color(hex: "81C784"), Color(hex: "388E3C")),   // Green (repeat)
    ]
    
    /// Generate a burst palette from a TaskCategory's gradient colors.
    /// Creates variations by adjusting brightness and saturation for visual variety.
    private static func categoryBurstColors(for category: TaskCategory) -> [(Color, Color)] {
        guard category != .general else { return defaultBurstColors }
        let primary = category.gradientColors[0]
        let secondary = category.gradientColors.count > 1 ? category.gradientColors[1] : primary
        
        // Generate 8 color pairs by varying the category colors
        return [
            (primary, secondary),
            (secondary, primary),
            (primary.opacity(0.9), secondary),
            (Color(hex: "FFD54F"), Color(hex: "F57F17")),   // Gold accent for celebration
            (primary, secondary.opacity(0.8)),
            (secondary.opacity(0.9), primary),
            (primary.opacity(0.85), secondary),
            (Color(hex: "FFD54F"), primary),                 // Gold + category blend
        ]
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                FishView(size: p.size, color: p.color, accentColor: p.accentColor)
                    .rotationEffect(.degrees(p.rotation))
                    .scaleEffect(p.scale)
                    .opacity(p.opacity)
                    .position(x: p.x, y: p.y)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: .nudgeFishBurst)) { notification in
            guard let info = notification.userInfo,
                  let origin = info["origin"] as? CGPoint,
                  let hudPos = info["hudPosition"] as? CGPoint,
                  let count = info["fishCount"] as? Int else { return }
            let categoryRaw = info["categoryRaw"] as? String
            let category = categoryRaw.flatMap { TaskCategory(rawValue: $0) }
            trigger(from: origin, hudPosition: hudPos, fishCount: count, category: category)
        }
    }

    // MARK: - Trigger Burst

    func trigger(from origin: CGPoint, hudPosition: CGPoint, fishCount: Int, category: TaskCategory? = nil) {
        guard !isActive else { return }
        guard !reduceMotion else {
            // Still spawn flying fish for the reward, just skip the burst
            FishRewardEngine.shared.spawnFish(
                count: min(fishCount, 8),
                from: origin,
                to: hudPosition
            )
            return
        }

        isActive = true
        HapticService.shared.swipeDone()
        
        // Use category-specific burst colors when available
        let burstPalette: [(Color, Color)] = if let category {
            Self.categoryBurstColors(for: category)
        } else {
            Self.defaultBurstColors
        }

        // Stage 1: Create 8 burst particles in a semicircular arc
        let burstCount = 8
        var newParticles: [BurstFishParticle] = []

        for i in 0..<burstCount {
            let angle = -Double.pi + (Double(i) / Double(burstCount)) * Double.pi
            let radius: CGFloat = CGFloat.random(in: 80...140)
            let targetX = origin.x + cos(angle) * radius
            let targetY = origin.y + sin(angle) * radius
            let colors = burstPalette[i % burstPalette.count]

            newParticles.append(BurstFishParticle(
                x: origin.x,
                y: origin.y,
                targetX: targetX,
                targetY: targetY,
                driftX: CGFloat.random(in: -15...15),
                driftY: CGFloat.random(in: 30...60), // gravity drift down
                size: CGFloat.random(in: 24...42),
                color: colors.0,
                accentColor: colors.1,
                rotation: Double.random(in: -30...30),
                delay: Double(i) * 0.06
            ))
        }

        particles = newParticles

        // Stage 1: Spring pop outward
        for i in particles.indices {
            let delay = particles[i].delay
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    particles[i].x = particles[i].targetX
                    particles[i].y = particles[i].targetY
                    particles[i].opacity = 1.0
                    particles[i].scale = 1.0
                }
            }
        }

        // Stage 1b → Stage 2 → Cleanup as sequential Task
        Task { @MainActor in
            // Stage 1b: Gravity drift + fade
            try? await Task.sleep(for: .seconds(0.5))
            for i in particles.indices {
                withAnimation(.easeIn(duration: 0.5)) {
                    particles[i].x += particles[i].driftX
                    particles[i].y += particles[i].driftY
                    particles[i].opacity = 0
                    particles[i].scale = 0.6
                }
            }

            // Stage 2: After burst clears, spawn golden fly-to-HUD fish
            try? await Task.sleep(for: .seconds(0.3))
            FishRewardEngine.shared.spawnFish(
                count: min(fishCount, 8),
                from: origin,
                to: hudPosition
            )

            // Cleanup
            try? await Task.sleep(for: .seconds(0.7))
            particles.removeAll()
            isActive = false
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Post this notification to trigger the celebratory fish burst.
    /// userInfo: ["origin": CGPoint, "hudPosition": CGPoint, "fishCount": Int]
    static let nudgeFishBurst = Notification.Name("nudgeFishBurst")
}

// MARK: - Preview

#Preview("Fish Burst") {
    ZStack {
        Color.black.ignoresSafeArea()
        CompletionFishBurst()

        Button("Burst!") {
            NotificationCenter.default.post(
                name: .nudgeFishBurst,
                object: nil,
                userInfo: [
                    "origin": CGPoint(x: 200, y: 400),
                    "hudPosition": CGPoint(x: 200, y: 80),
                    "fishCount": 5
                ]
            )
        }
        .foregroundStyle(.white)
    }
}
