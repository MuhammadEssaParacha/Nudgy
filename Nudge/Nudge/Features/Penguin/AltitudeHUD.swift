//
//  AltitudeHUD.swift
//  Nudge
//
//  Gamification stats overlay — sits on top of the Antarctic scene.
//  Shows: altitude (level), fish count, streak flame,
//  and level progress arc.
//
//  Inspired by the hand-drawn sketch: top bar with altitude, level,
//  and fish count. Designed to be compact, glassy, and unobtrusive.
//
//  Data source: RewardService.shared (singleton, @Observable).
//

import SwiftUI

// MARK: - Altitude HUD

struct AltitudeHUD: View {

    let level: Int
    let fishCount: Int
    let streak: Int
    let levelProgress: Double
    let tasksToday: Int

    /// Whether sparkles should appear around the fish badge (set on reward earn).
    var showFishSparkle: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Altitude badge (level) with progress ring
            altitudeBadge

            Divider()
                .frame(height: 18)
                .overlay(Color.white.opacity(0.15))

            // Fish count
            fishBadge

            // Streak flame (only visible when streak ≥ 2)
            if streak >= 2 {
                Divider()
                    .frame(height: 18)
                    .overlay(Color.white.opacity(0.15))

                streakBadge
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .glassEffect(.regular.interactive(), in: .capsule)
        .nudgeAccessibility(
            label: String(localized: "Level \(level), \(fishCount) fish, \(streak) day streak"),
            hint: String(localized: "Your progress stats"),
            traits: .updatesFrequently
        )
    }

    // MARK: - Altitude Badge

    private var altitudeBadge: some View {
        HStack(spacing: 5) {
            // Mini progress ring around mountain icon
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 22, height: 22)

                Circle()
                    .trim(from: 0, to: levelProgress)
                    .stroke(
                        AngularGradient(
                            colors: [Color(hex: "00D4FF"), Color(hex: "7B61FF"), Color(hex: "00D4FF")],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("ALT")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "00D4FF").opacity(0.8))
                    .tracking(1.5)

                Text("\(altitudeValue)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Fish Badge

    private var fishBadge: some View {
        ZStack {
            HStack(spacing: 4) {
                // Fish icon (currency)
                Image(systemName: "fish.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FFB800"), Color(hex: "FF8C00")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolRenderingMode(.hierarchical)

                Text("\(fishCount)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            // Sparkle effect when earning fish
            if showFishSparkle {
                HUDSparkleCluster()
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Streak Badge

    private var streakBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FF6B35"), Color(hex: "FF453A")],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )

            Text("\(streak)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Altitude Calculation

    /// Convert level to a fun "altitude" in meters — each level is 100m higher.
    private var altitudeValue: String {
        let meters = level * 100
        if meters >= 1000 {
            let km = Double(meters) / 1000.0
            return String(format: "%.1fk", km)
        }
        return "\(meters)m"
    }
}

// MARK: - HUD Sparkle Cluster

/// Small sparkle particles that orbit the fish badge when fish are earned.
/// Uses SparkleView from IntroVectorShapes.
struct HUDSparkleCluster: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sparkleData: [(size: CGFloat, color: Color, offset: CGSize, delay: Double)] = [
        (8, Color(hex: "FFD700"), CGSize(width: -14, height: -10), 0.0),
        (6, Color(hex: "FFB800"), CGSize(width: 16, height: -6), 0.15),
        (7, Color(hex: "FF8C00"), CGSize(width: -8, height: 12), 0.3),
        (5, .white, CGSize(width: 12, height: 10), 0.1),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<sparkleData.count, id: \.self) { i in
                let data = sparkleData[i]
                SparkleView(size: data.size, color: data.color, delay: data.delay)
                    .offset(data.offset)
                    .opacity(appeared ? 1.0 : 0.0)
                    .scaleEffect(appeared ? 1.0 : 0.3)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                appeared = true
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview("HUD — Level 3") {
    ZStack {
        Color.black
        AltitudeHUD(level: 3, fishCount: 42, streak: 5, levelProgress: 0.65, tasksToday: 4)
    }
}

#Preview("HUD — Level 1 No Streak") {
    ZStack {
        Color.black
        AltitudeHUD(level: 1, fishCount: 8, streak: 0, levelProgress: 0.3, tasksToday: 1)
    }
}

#Preview("HUD — High Level") {
    ZStack {
        Color.black
        AltitudeHUD(level: 12, fishCount: 340, streak: 14, levelProgress: 0.85, tasksToday: 7)
    }
}
