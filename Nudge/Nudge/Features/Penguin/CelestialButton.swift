//
//  CelestialButton.swift
//  Nudge
//
//  A living celestial button that doubles as a mini-HUD, plus a
//  full-screen immersive inventory overlay.
//
//  The button is NOT just a decoration — it's a glanceable progress
//  indicator. A thin progress ring wraps the celestial body showing
//  level progress, and a tiny fish badge shows your current count.
//  It breathes, pulses, and invites you to tap.
//
//  The overlay is a hero-driven experience:
//  - Large Nudgy at center with orbiting animated fish
//  - Animated count-up numbers
//  - Floating ambient particles (Antarctic snow)
//  - Visual progress arc that fills on entrance
//  - Cards stagger in with spring physics
//
//  Design language: native iOS 26 glassmorphism, DarkCard glow
//  gradients, Antarctic palette, springs for motion.
//

import SwiftUI

// MARK: - Celestial Phase

private enum CelestialPhase {
    case sun, star, risingSun, settingSun

    init(time: AntarcticTimeOfDay) {
        switch time {
        case .day:   self = .sun
        case .night: self = .star
        case .dawn:  self = .risingSun
        case .dusk:  self = .settingSun
        }
    }

    var bodyColor: Color {
        switch self {
        case .sun:        return Color(hex: "FFE066")
        case .star:       return Color(hex: "E8F0FF")
        case .risingSun:  return Color(hex: "FFCC66")
        case .settingSun: return Color(hex: "FF9955")
        }
    }

    var glowColor: Color {
        switch self {
        case .sun:        return Color(hex: "FFD700")
        case .star:       return Color(hex: "B0C8FF")
        case .risingSun:  return Color(hex: "FFA040")
        case .settingSun: return Color(hex: "FF6B35")
        }
    }

    var ringColor: Color {
        switch self {
        case .sun:        return Color(hex: "FFD700")
        case .star:       return Color(hex: "7BB8FF")
        case .risingSun:  return Color(hex: "FFB040")
        case .settingSun: return Color(hex: "FF7744")
        }
    }
}

// MARK: - CelestialButton

/// A living celestial button — sun by day, star by night — that serves
/// as both a mini progress HUD and the gateway to the full inventory.
///
/// Shows: level progress ring + fish count badge at a glance.
struct CelestialButton: View {

    @Binding var isExpanded: Bool

    /// Current fish count — displayed as a badge
    var fishCount: Int = 0
    /// Level progress 0.0-1.0 — shown as a ring
    var levelProgress: Double = 0.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var glowPulse: Bool = false
    @State private var rotationAngle: Double = 0
    @State private var ringProgress: Double = 0
    @State private var starShimmer: Double = 0.6
    @State private var entranceScale: CGFloat = 0.5
    @State private var entranceOpacity: Double = 0

    private let bodySize: CGFloat = 26
    private let ringSize: CGFloat = 40
    private let hitSize: CGFloat = 56

    private var phase: CelestialPhase { CelestialPhase(time: .current) }

    var body: some View {
        Button {
            HapticService.shared.cardAppear()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isExpanded = true
            }
        } label: {
            ZStack {
                // Outer glow haze
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                phase.glowColor.opacity(0.15),
                                phase.glowColor.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: bodySize * 0.3,
                            endRadius: 36
                        )
                    )
                    .frame(width: 72, height: 72)
                    .scaleEffect(glowPulse ? 1.06 : 0.94)
                    .opacity(glowPulse ? 1.0 : 0.7)

                // Progress ring (level progress)
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 2.5)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                phase.ringColor.opacity(0.3),
                                phase.ringColor,
                                phase.ringColor.opacity(0.3)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))

                // Celestial body at center
                celestialBody

                // Fish badge — bottom-right
                if fishCount > 0 {
                    fishBadge
                        .offset(x: 16, y: 14)
                }
            }
            .frame(width: hitSize, height: hitSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(entranceScale)
        .opacity(isExpanded ? 0 : entranceOpacity)
        .nudgeAccessibility(
            label: accessibilityLabel,
            hint: String(localized: "Tap to open inventory"),
            traits: .isButton
        )
        .onAppear {
            guard !reduceMotion else {
                ringProgress = levelProgress
                entranceScale = 1.0
                entranceOpacity = 1.0
                return
            }
            // Entrance pop
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) {
                entranceScale = 1.0
                entranceOpacity = 1.0
            }
            glowPulse = true
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                ringProgress = levelProgress
            }
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            // Star shimmer (night phase only)
            if phase == .star {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    starShimmer = 1.0
                }
            }
        }
        .onChange(of: levelProgress) { _, new in
            withAnimation(.easeOut(duration: 0.5)) {
                ringProgress = new
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
            value: glowPulse
        )
    }

    // MARK: - Fish Badge

    private var fishBadge: some View {
        HStack(spacing: 1) {
            Image(systemName: "fish.fill")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(Color(hex: "FFB800"))

            Text("\(fishCount)")
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(Color.black.opacity(0.6))
        )
        .overlay(
            Capsule()
                .stroke(Color(hex: "FFB800").opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Celestial Body

    @ViewBuilder
    private var celestialBody: some View {
        switch phase {
        case .sun, .risingSun, .settingSun:
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(phase.bodyColor.opacity(0.2))
                        .frame(width: 1.5, height: 5)
                        .offset(y: -(bodySize * 0.5 + 4))
                        .rotationEffect(.degrees(Double(i) * 45 + rotationAngle))
                }
                .opacity(phase == .settingSun ? 0.4 : phase == .risingSun ? 0.5 : 0.8)

                Circle()
                    .fill(phase.bodyColor)
                    .frame(width: bodySize, height: bodySize)
                    .shadow(color: phase.glowColor.opacity(0.5), radius: 6)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.35), phase.bodyColor, phase.bodyColor.opacity(0.9)],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: bodySize * 0.55
                        )
                    )
                    .frame(width: bodySize, height: bodySize)
            }

        case .star:
            ZStack {
                // Outer shimmer halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "C0D8FF").opacity(0.15 * starShimmer), .clear],
                            center: .center,
                            startRadius: bodySize * 0.2,
                            endRadius: bodySize * 0.6
                        )
                    )
                    .frame(width: bodySize * 1.2, height: bodySize * 1.2)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, Color(hex: "E8F0FF"), Color(hex: "B0C8FF").opacity(0.5)],
                            center: .center,
                            startRadius: 0,
                            endRadius: bodySize * 0.35
                        )
                    )
                    .frame(width: bodySize * 0.5, height: bodySize * 0.5)
                    .shadow(color: Color(hex: "C0D8FF").opacity(0.4 + 0.3 * starShimmer), radius: 8)

                ForEach(0..<4, id: \.self) { i in
                    let rayOpacity = (i % 2 == 0) ? starShimmer : (1.2 - starShimmer)
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(LinearGradient(
                            colors: [.white.opacity(0.6 * rayOpacity), .clear],
                            startPoint: .center,
                            endPoint: .leading
                        ))
                        .frame(width: bodySize * 0.7, height: 1)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
            }
        }
    }

    private var accessibilityLabel: String {
        String(localized: "Level progress \(Int(levelProgress * 100))%, \(fishCount) fish")
    }
}

// MARK: - Overlay Floating Particle

private struct OverlayParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let opacity: Double
    let speed: Double
    let drift: CGFloat
}

// MARK: - Overlay Orbiting Fish

private struct OrbitingFishData: Identifiable {
    let id = UUID()
    let size: CGFloat
    let orbitRadius: CGFloat
    let speed: Double
    let startAngle: Double
    let color: Color
    let accentColor: Color
    let bobAmplitude: CGFloat
}

// MARK: - Animated Counter

private struct AnimatedCounter: View {
    let target: Int
    let duration: Double
    let font: Font
    let color: Color

    @State private var displayed: Int = 0
    @State private var hasAnimated = false

    var body: some View {
        Text("\(displayed)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                let steps = min(target, 30)
                guard steps > 0 else {
                    displayed = target
                    return
                }
                let interval = max(0.016, duration / Double(steps))
                Task { @MainActor in
                    for i in 1...steps {
                        let value = Int(Double(target) * Double(i) / Double(steps))
                        try? await Task.sleep(for: .seconds(interval))
                        withAnimation(.easeOut(duration: 0.08)) {
                            displayed = value
                        }
                    }
                }
            }
    }
}

// MARK: - Expanded Celestial Overlay

struct CelestialExpandedOverlay: View {

    @Binding var isExpanded: Bool

    let level: Int
    let fishCount: Int
    let streak: Int
    let levelProgress: Double
    let tasksToday: Int
    let totalCompleted: Int
    let activeCount: Int
    let stage: StageTier
    let challenges: [DailyChallenge]

    @Environment(PenguinState.self) private var penguinState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showWardrobe = false
    @State private var appeared = false
    @State private var heroAppeared = false
    @State private var statsAppeared = false
    @State private var cardsAppeared = false
    @State private var progressFill: Double = 0
    @State private var orbitAngle: Double = 0
    @State private var particleSeeds: [OverlayParticle] = []
    @State private var particleStartTime: Date = .now
    @State private var sceneSize: CGSize = .zero

    private var phase: CelestialPhase { CelestialPhase(time: .current) }

    private let orbitFish: [OrbitingFishData] = {
        let palette: [(Color, Color)] = [
            (Color(hex: "4FC3F7"), Color(hex: "0288D1")),
            (Color(hex: "FF8A65"), Color(hex: "E64A19")),
            (Color(hex: "81C784"), Color(hex: "388E3C")),
            (Color(hex: "FFD54F"), Color(hex: "F57F17")),
        ]
        return (0..<4).map { i in
            OrbitingFishData(
                size: CGFloat([20, 16, 22, 14][i]),
                orbitRadius: CGFloat([70, 55, 82, 48][i]),
                speed: Double([8, 11, 7, 13][i]),
                startAngle: Double(i) * .pi / 2,
                color: palette[i].0,
                accentColor: palette[i].1,
                bobAmplitude: CGFloat([4, 6, 3, 5][i])
            )
        }
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.92 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .nudgeAccessibility(
                    label: String(localized: "Close inventory"),
                    hint: String(localized: "Tap to dismiss"),
                    traits: .isButton
                )

            // Capture scene size for particles (replaces UIScreen.main.bounds)
            GeometryReader { geo in
                Color.clear.onAppear { sceneSize = geo.size }
            }
            .ignoresSafeArea()

            if appeared && !reduceMotion {
                floatingParticles
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.top, DesignTokens.spacingMD + 4)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: DesignTokens.spacingXL) {
                        heroSection
                            .opacity(heroAppeared ? 1 : 0)
                            .scaleEffect(heroAppeared ? 1 : 0.9)
                            .onTapGesture { dismiss() }

                        statsStrip
                            .opacity(statsAppeared ? 1 : 0)
                            .offset(y: statsAppeared ? 0 : 16)

                        progressSection
                            .opacity(statsAppeared ? 1 : 0)
                            .offset(y: statsAppeared ? 0 : 16)

                        if !challenges.isEmpty {
                            challengesSection
                                .opacity(cardsAppeared ? 1 : 0)
                                .offset(y: cardsAppeared ? 0 : 16)
                        }

                        wardrobeButton
                            .opacity(cardsAppeared ? 1 : 0)
                            .offset(y: cardsAppeared ? 0 : 16)

                        // Tap-to-dismiss zone below content
                        Color.clear
                            .frame(height: 200)
                            .contentShape(Rectangle())
                            .onTapGesture { dismiss() }
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.top, DesignTokens.spacingMD)
                }
            }
            .safeAreaPadding(.top, DesignTokens.spacingSM)
        }
        .ignoresSafeArea()
        .highPriorityGesture(
            DragGesture(minimumDistance: 60)
                .onEnded { value in
                    // Swipe down to dismiss
                    if value.translation.height > 80 {
                        dismiss()
                    }
                }
        )
        .onAppear {
            animateIn()
            seedParticles()
        }
        .sheet(isPresented: $showWardrobe) {
            WardrobeView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(DesignTokens.cardSurface)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Animation Orchestration

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.25)) {
            appeared = true
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.12)) {
            heroAppeared = true
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85).delay(0.25)) {
            statsAppeared = true
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.35)) {
            progressFill = levelProgress
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85).delay(0.4)) {
            cardsAppeared = true
        }
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
            orbitAngle = 360
        }
    }

    private func dismiss() {
        HapticService.shared.cardAppear()
        // Stagger the exit — cards first, then stats, then hero
        withAnimation(.easeOut(duration: 0.15)) {
            cardsAppeared = false
        }
        withAnimation(.easeOut(duration: 0.15).delay(0.04)) {
            statsAppeared = false
            progressFill = 0
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85).delay(0.08)) {
            heroAppeared = false
        }
        withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
            appeared = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            isExpanded = false
        }
    }

    // MARK: - Floating Particles

    /// Seed particles once — positions are computed from elapsed time, no state mutation during animation.
    private func seedParticles() {
        let w = max(sceneSize.width, 390)
        let h = max(sceneSize.height, 844)
        particleStartTime = .now
        particleSeeds = (0..<20).map { _ in
            OverlayParticle(
                x: CGFloat.random(in: 0...w),
                y: CGFloat.random(in: 0...h),
                size: CGFloat.random(in: 1.5...3.5),
                opacity: Double.random(in: 0.08...0.25),
                speed: Double.random(in: 20...50),
                drift: CGFloat.random(in: -0.3...0.3)
            )
        }
    }

    /// TimelineView-driven particles — SwiftUI manages the render cadence,
    /// no @State mutation per frame, no Task loop, no render queue flooding.
    private var floatingParticles: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let elapsed = CGFloat(timeline.date.timeIntervalSince(particleStartTime))
            let w = max(sceneSize.width, 390)
            let h = max(sceneSize.height, 844)

            Canvas { context, size in
                for (index, seed) in particleSeeds.enumerated() {
                    // Compute current Y from elapsed time — drifts downward like snow
                    let yTravel = elapsed * CGFloat(seed.speed) * 0.5
                    var currentY = seed.y + yTravel
                    // Wrap around when off-screen
                    let totalH = h + 20
                    currentY = currentY.truncatingRemainder(dividingBy: totalH)
                    if currentY < -10 { currentY += totalH }

                    // Sinusoidal horizontal drift — like real snowflakes
                    let driftWave = sin(elapsed * Double(0.5 + seed.drift * 0.3) + Double(index) * 1.3)
                    let currentX = seed.x + CGFloat(driftWave) * 15.0
                    // Gentle x-wrap
                    let wrappedX = currentX.truncatingRemainder(dividingBy: w + 40) - 20

                    // Pulsing opacity — twinkle effect
                    let twinkle = sin(elapsed * Double(1.0 + seed.drift * 0.5) + Double(index) * 0.7)
                    let dynamicOpacity = seed.opacity * (0.6 + 0.4 * abs(twinkle))

                    let rect = CGRect(
                        x: wrappedX - seed.size / 2,
                        y: currentY - seed.size / 2,
                        width: seed.size,
                        height: seed.size
                    )
                    context.opacity = dynamicOpacity
                    context.fill(Circle().path(in: rect), with: .color(.white))
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [phase.glowColor.opacity(0.25), .clear],
                                center: .center,
                                startRadius: 2,
                                endRadius: 14
                            )
                        )
                        .frame(width: 28, height: 28)

                    Circle()
                        .fill(phase.bodyColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: phase.glowColor.opacity(0.4), radius: 4)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(stage.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(String(localized: "Level \(level)"))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .tracking(0.5)
                }
            }

            Spacer()

            // Close button — plain Button, no glassEffect (it swallows touches)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .white.opacity(0.08), radius: 4)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .nudgeAccessibility(
                label: String(localized: "Close"),
                hint: String(localized: "Tap to dismiss inventory"),
                traits: .isButton
            )
        }
    }

    // MARK: - Hero Section (Nudgy + Orbiting Fish)

    private var heroSection: some View {
        ZStack {
            // Soft radial glow behind Nudgy
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            penguinState.accentColor.opacity(0.08),
                            penguinState.accentColor.opacity(0.02),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)

            // Orbiting fish around Nudgy
            if !reduceMotion {
                ForEach(orbitFish) { fish in
                    let angle = fish.startAngle + (orbitAngle * .pi / 180.0) / fish.speed * 2
                    let bobOffset = sin(angle * 3) * Double(fish.bobAmplitude)
                    let x = cos(angle) * Double(fish.orbitRadius)
                    let y = sin(angle) * Double(fish.orbitRadius) * 0.4 + bobOffset

                    FishView(
                        size: fish.size,
                        color: fish.color,
                        accentColor: fish.accentColor
                    )
                    .scaleEffect(x: cos(angle) > 0 ? 1 : -1, y: 1)
                    .opacity(heroAppeared ? (0.5 + abs(sin(angle)) * 0.4) : 0)
                    .offset(x: CGFloat(x), y: CGFloat(y))
                }
            }

            NudgySprite(
                expression: penguinState.expression,
                size: DesignTokens.penguinSizeLarge,
                accentColor: penguinState.accentColor
            )
            .shadow(color: penguinState.accentColor.opacity(0.15), radius: 20)
        }
        .frame(height: 200)
        .padding(.top, DesignTokens.spacingSM)
    }

    // MARK: - Stats Strip (Animated Counters)

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statItem(
                icon: "mountain.2.fill",
                gradient: [Color(hex: "00D4FF"), Color(hex: "7B61FF")],
                value: level * 100,
                suffix: "m",
                label: String(localized: "ALTITUDE")
            )

            thinDivider

            statItem(
                icon: "fish.fill",
                gradient: [Color(hex: "FFB800"), Color(hex: "FF8C00")],
                value: fishCount,
                suffix: "",
                label: String(localized: "FISH")
            )

            thinDivider

            statItem(
                icon: "flame.fill",
                gradient: [Color(hex: "FF6B35"), Color(hex: "FF453A")],
                value: streak,
                suffix: streak > 0 ? "d" : "",
                label: String(localized: "STREAK")
            )

            thinDivider

            statItem(
                icon: "checkmark.circle.fill",
                gradient: [DesignTokens.accentComplete, DesignTokens.accentComplete.opacity(0.7)],
                value: tasksToday,
                suffix: "",
                label: String(localized: "TODAY")
            )
        }
        .padding(.vertical, DesignTokens.spacingMD + 2)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.02), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    private func statItem(icon: String, gradient: [Color], value: Int, suffix: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                )
                .symbolRenderingMode(.hierarchical)

            HStack(spacing: 0) {
                if statsAppeared {
                    AnimatedCounter(
                        target: value,
                        duration: 0.6,
                        font: .system(size: 18, weight: .bold, design: .rounded),
                        color: .white
                    )
                } else {
                    Text("0")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }

            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(DesignTokens.textTertiary)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 0.5, height: 36)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Image(systemName: stageIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(stageColor)

                Text(String(localized: "Stage Progress"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.textSecondary)

                Spacer()

                Text(String(format: "%.0f%%", levelProgress * 100))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(stageColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.04))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [stageColor.opacity(0.4), stageColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * progressFill))

                    if progressFill > 0.03 {
                        // Leading-edge glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [stageColor, stageColor.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 12
                                )
                            )
                            .frame(width: 24, height: 24)
                            .offset(x: max(0, geo.size.width * progressFill - 12), y: -8)
                            .allowsHitTesting(false)

                        Circle()
                            .fill(stageColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: stageColor.opacity(0.8), radius: 4)
                            .shadow(color: stageColor.opacity(0.4), radius: 8)
                            .offset(x: max(0, geo.size.width * progressFill - 4))
                    }
                }
            }
            .frame(height: 8)

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .bold))
                Text(String(localized: "\(totalCompleted) tasks completed"))
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(DesignTokens.textTertiary)
        }
        .padding(DesignTokens.spacingLG)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [stageColor.opacity(0.04), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    // MARK: - Challenges Section

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM + 2) {
            HStack {
                Text(String(localized: "DAILY CHALLENGES"))
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .tracking(1.5)

                Spacer()

                let done = challenges.filter(\.isCompleted).count
                HStack(spacing: 3) {
                    Text("\(done)/\(challenges.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    if done == challenges.count {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                    }
                }
                .foregroundStyle(done == challenges.count ? DesignTokens.accentComplete : DesignTokens.textTertiary)
            }

            ForEach(challenges) { challenge in
                HStack(spacing: DesignTokens.spacingSM) {
                    ZStack {
                        Circle()
                            .fill(challenge.isCompleted
                                  ? DesignTokens.accentComplete.opacity(0.15)
                                  : Color.white.opacity(0.03))
                            .frame(width: 26, height: 26)

                        if challenge.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DesignTokens.accentComplete)
                        } else {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                .frame(width: 26, height: 26)
                        }
                    }

                    Text(challenge.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(challenge.isCompleted ? DesignTokens.textTertiary : .white)
                        .strikethrough(challenge.isCompleted)

                    Spacer()

                    if challenge.isCompleted {
                        Text("+\(challenge.bonusFish)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "FFB800"))
                    }
                }
            }
        }
        .padding(DesignTokens.spacingLG)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [DesignTokens.accentComplete.opacity(0.03), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    // MARK: - Wardrobe Button

    private var wardrobeButton: some View {
        Button { showWardrobe = true } label: {
            HStack(spacing: DesignTokens.spacingMD) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFD700").opacity(0.15), Color(hex: "FF8C00").opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Nudgy's Wardrobe"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(String(localized: "Customize your companion"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(DesignTokens.spacingLG)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FFD700").opacity(0.04), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed

    private var stageIcon: String {
        switch stage {
        case .bareIce:     return "snowflake"
        case .snowNest:    return "house.fill"
        case .fishingPier: return "fish.fill"
        case .cozyCamp:    return "flame.fill"
        case .summitLodge: return "building.2.fill"
        }
    }

    private var stageColor: Color {
        switch stage {
        case .bareIce:     return Color(hex: "88CCFF")
        case .snowNest:    return Color(hex: "AAE0FF")
        case .fishingPier: return Color(hex: "FFB800")
        case .cozyCamp:    return Color(hex: "FF8C00")
        case .summitLodge: return Color(hex: "FFD700")
        }
    }
}
