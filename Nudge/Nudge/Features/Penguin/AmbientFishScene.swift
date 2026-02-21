//
//  AmbientFishScene.swift
//  Nudge
//
//  Ambient swimming fish that lazily drift around behind/beside Nudgy
//  on the ice shelf. The fish count matches earned fish today from
//  RewardService. Fish scatter on tap and swim back slowly.
//
//  Uses AnimatedFishView from IntroVectorShapes for the bezier-drawn
//  fish art with smooth tail wag. TimelineView drives 20fps updates.
//

import SwiftUI

// MARK: - Swimming Fish Model

struct SwimmingFish: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var accentColor: Color
    var speed: Double          // seconds per full swim cycle
    var amplitude: CGFloat     // vertical bob amplitude
    var flipped: Bool          // swim direction (true = left-facing)
    var opacity: Double
    var phaseOffset: Double    // unique per-fish for desynchronization
    var scatterOffset: CGSize = .zero
    var isScattering: Bool = false
}

// MARK: - Ambient Fish Scene

/// Overlays small fish lazily swimming around Nudgy.
/// Count is based on earned rewards. Max 6 visible at once for performance.
struct AmbientFishScene: View {
    var fishEarned: Int
    var sceneWidth: CGFloat
    var sceneHeight: CGFloat
    var onTap: (() -> Void)?

    @State private var fish: [SwimmingFish] = []
    @State private var isScattered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Palette — matches intro fish colors
    private static let fishPalette: [(Color, Color)] = [
        (Color(hex: "4FC3F7"), Color(hex: "0288D1")),   // Ocean blue
        (Color(hex: "FF8A65"), Color(hex: "E64A19")),   // Coral orange
        (Color(hex: "81C784"), Color(hex: "388E3C")),   // Sea green
        (Color(hex: "BA68C8"), Color(hex: "7B1FA2")),   // Purple
        (Color(hex: "FFD54F"), Color(hex: "F57F17")),   // Golden
        (Color(hex: "4DD0E1"), Color(hex: "00838F")),   // Teal
    ]

    /// Always show at least 2 fish so the scene feels alive from first launch.
    /// Additional fish appear as the user completes tasks.
    private var visibleCount: Int {
        min(max(fishEarned, 2), 6)
    }

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(fish) { f in
                    fishBody(f, time: time)
                }
            }
        }
        .drawingGroup()  // Flatten fish layers into single GPU texture
        .allowsHitTesting(true)
        .contentShape(Rectangle())
        .onTapGesture {
            scatterFish()
            onTap?()
        }
        .onAppear {
            spawnFish()
        }
        .onChange(of: fishEarned) { _, _ in
            respawnIfNeeded()
        }
    }

    // MARK: - Fish Body

    @ViewBuilder
    private func fishBody(_ f: SwimmingFish, time: Double) -> some View {
        let pos = swimPosition(for: f, time: time)
        let tailWag = tailWagPhase(for: f, time: time)

        AnimatedFishView(
            size: f.size,
            color: f.color,
            accentColor: f.accentColor,
            tailPhase: tailWag
        )
        .scaleEffect(x: f.flipped ? -1 : 1, y: 1)
        .opacity(f.opacity)
        .offset(x: f.scatterOffset.width, y: f.scatterOffset.height)
        .position(x: pos.x, y: pos.y)
    }

    // MARK: - Swim Physics

    private func swimPosition(for f: SwimmingFish, time: Double) -> CGPoint {
        guard !reduceMotion else {
            return CGPoint(x: f.x, y: f.y)
        }

        let phase = time * .pi * 2
        let xPhase = phase / f.speed + f.phaseOffset
        let yPhase = phase / (f.speed * 0.7) + f.phaseOffset

        // Horizontal: sin wave drift + slow cruise
        let cruise = CGFloat(time.truncatingRemainder(dividingBy: f.speed * 14.0) / (f.speed * 14.0))
        let dx = CGFloat(sin(xPhase)) * (sceneWidth * 0.04)
        let cruiseOffset = cruise * sceneWidth * 0.10 * (f.flipped ? -1 : 1)

        // Vertical: gentle bob
        let dy = CGFloat(cos(yPhase)) * f.amplitude

        let baseX = f.x + dx + cruiseOffset
        let baseY = f.y + dy

        // Wrap horizontal — fish swim off one side, reappear on the other
        let wrappedX: CGFloat
        if baseX < -30 {
            wrappedX = baseX + sceneWidth + 60
        } else if baseX > sceneWidth + 30 {
            wrappedX = baseX - sceneWidth - 60
        } else {
            wrappedX = baseX
        }

        return CGPoint(x: wrappedX, y: baseY)
    }

    private func tailWagPhase(for f: SwimmingFish, time: Double) -> CGFloat {
        guard !reduceMotion else { return 0 }
        // Faster fish wag their tails more quickly
        let wagSpeed = 3.0 + (6.0 - f.speed) * 0.6
        return CGFloat(sin(time * wagSpeed + f.phaseOffset))
    }

    // MARK: - Spawning

    private func spawnFish() {
        guard visibleCount > 0 else { return }

        fish = (0..<visibleCount).map { i in
            let palette = Self.fishPalette[i % Self.fishPalette.count]
            let flipped = Bool.random()
            return SwimmingFish(
                x: CGFloat.random(in: sceneWidth * 0.15 ... sceneWidth * 0.85),
                y: sceneHeight * CGFloat.random(in: 0.55 ... 0.72),
                size: CGFloat.random(in: 18...30),
                color: palette.0,
                accentColor: palette.1,
                speed: Double.random(in: 3.0...6.0),
                amplitude: CGFloat.random(in: 4...10),
                flipped: flipped,
                opacity: Double.random(in: 0.5...0.8),
                phaseOffset: Double.random(in: 0...(.pi * 2))
            )
        }
    }

    private func respawnIfNeeded() {
        let target = visibleCount
        if target > fish.count {
            // Add more fish
            for i in fish.count..<target {
                let palette = Self.fishPalette[i % Self.fishPalette.count]
                let newFish = SwimmingFish(
                    x: CGFloat.random(in: sceneWidth * 0.15 ... sceneWidth * 0.85),
                    y: sceneHeight * CGFloat.random(in: 0.55 ... 0.72),
                    size: CGFloat.random(in: 18...30),
                    color: palette.0,
                    accentColor: palette.1,
                    speed: Double.random(in: 3.0...6.0),
                    amplitude: CGFloat.random(in: 4...10),
                    flipped: Bool.random(),
                    opacity: 0,
                    phaseOffset: Double.random(in: 0...(.pi * 2))
                )
                fish.append(newFish)
                // Fade in
                withAnimation(.easeIn(duration: 0.8)) {
                    if let idx = fish.firstIndex(where: { $0.id == newFish.id }) {
                        fish[idx].opacity = Double.random(in: 0.5...0.8)
                    }
                }
            }
        } else if target < fish.count {
            // Remove excess (fade out)
            let excess = fish.count - target
            for i in 0..<excess {
                let idx = fish.count - 1 - i
                guard idx >= 0 else { break }
                withAnimation(.easeOut(duration: 0.5)) {
                    fish[idx].opacity = 0
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                fish = Array(fish.prefix(target))
            }
        }
    }

    // MARK: - Scatter

    private func scatterFish() {
        guard !isScattered else { return }
        isScattered = true
        HapticService.shared.prepare()

        for i in fish.indices {
            fish[i].isScattering = true
            let scatterX = CGFloat.random(in: -60...60)
            let scatterY = CGFloat.random(in: -40...40)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                fish[i].scatterOffset = CGSize(width: scatterX, height: scatterY)
            }
            // Flip some fish on scatter (startled direction change)
            if Bool.random() {
                fish[i].flipped.toggle()
            }
        }

        // Swim back slowly
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            for i in fish.indices {
                fish[i].isScattering = false
                withAnimation(.easeInOut(duration: 2.0)) {
                    fish[i].scatterOffset = .zero
                }
            }
            try? await Task.sleep(for: .seconds(2.0))
            isScattered = false
        }
    }
}

// MARK: - Preview

#Preview("Ambient Fish") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientFishScene(
            fishEarned: 4,
            sceneWidth: 393,
            sceneHeight: 852
        )
    }
}
