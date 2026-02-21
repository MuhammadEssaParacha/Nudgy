//
//  AquariumTankView.swift
//  Nudge
//
//  Inline interactive fish tank for the You page hero.
//  Vector-rendered fish (AnimatedFishView) swim with sin/cos physics
//  and animated tail wag. TimelineView drives smooth 30fps updates.
//
//  Environment: light rays, swaying seaweed, bubbles, caustics, sand.
//  Interactions: tap water → ripple + scatter, tap fish → info,
//  swipe down → feed.
//
//  Self-contained — manages its own animation state.
//  Max 12 fish visible for performance.
//

import SwiftUI

// MARK: - Tank Fish Model

private struct TankFish: Identifiable {
    let id: UUID
    let catchData: FishCatch
    var x: CGFloat           // 0…1 normalized position
    var y: CGFloat           // 0…1 normalized position
    var speed: Double        // swim cycle seconds
    var amplitude: CGFloat   // vertical bob px
    var flipped: Bool
    var phaseOffset: Double
    var depth: CGFloat       // 0 = front, 1 = back (parallax + opacity)
    var scatterOffset: CGSize = .zero
    var isScattering: Bool = false
    var evolutionStage: FishEvolutionStage = .baby
}

// MARK: - Ripple Model

private struct Ripple: Identifiable {
    let id = UUID()
    let point: CGPoint
    var scale: CGFloat = 0
    var opacity: Double = 0.6
}

// MARK: - Food Particle Model

private struct FoodParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vy: CGFloat = 0
    var vx: CGFloat = 0           // horizontal drift velocity
    var opacity: Double = 1.0
    var consumed: Bool = false
    var rotation: Double = 0      // degrees — for pellet tumble
    var size: CGFloat = 6         // point diameter
}

// MARK: - Seaweed Model

private struct SeaweedPatch: Identifiable {
    let id = UUID()
    let x: CGFloat             // normalized 0…1
    let height: CGFloat        // normalized 0.12…0.30
    let bladeCount: Int        // 2–4
    let color: Color
    let phaseOffset: Double
}

// MARK: - Bubble Particle

private struct BubbleParticle {
    let x: CGFloat
    let radius: CGFloat
    let speed: Double
    let startOffset: Double
    let wobble: Double
}

// MARK: - Jellyfish Model

private struct Jellyfish: Identifiable {
    let id = UUID()
    var x: CGFloat          // 0…1 normalized horizontal position
    var y: CGFloat          // 0…1 normalized vertical position (upper 60% of tank)
    let phaseOffset: Double
    let size: CGFloat       // bell diameter in points
    let color: Color
    let driftSpeed: Double  // vertical bob frequency
}

// MARK: - Aquarium Tank View

struct AquariumTankView: View {
    let catches: [FishCatch]
    let level: Int
    let streak: Int
    var height: CGFloat = 220
    var onFishTap: ((FishCatch) -> Void)? = nil

    @State private var tankFish: [TankFish] = []
    @State private var ripples: [Ripple] = []
    @State private var isScattered = false
    @State private var bubbles: [BubbleParticle] = []
    @State private var foodParticles: [FoodParticle] = []
    @State private var feedsAvailable: Int = 0
    @State private var tankSize: CGSize = .init(width: 350, height: 220)
    @State private var seaweeds: [SeaweedPatch] = []
    @State private var rewardService = RewardService.shared
    @State private var showDecorationShop = false
    @State private var jellyfish: [Jellyfish] = []
    @State private var feedBonusText: String? = nil
    @State private var feedBonusOpacity: Double = 0
    @State private var inspectedFish: FishCatch? = nil
    @State private var feedHintBounce: Bool = false
    @State private var showEvolutionCelebration: Bool = false
    @State private var pendingEvolutionInfo: (species: FishSpecies, stage: FishEvolutionStage)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext

    /// Permanent colony: one representative FishCatch per species (most recent).
    /// Up to 4 fish (one per species), never resets.
    private var colonyFish: [FishCatch] {
        var seen = Set<FishSpecies>()
        var result: [FishCatch] = []
        for catchItem in catches.sorted(by: { $0.caughtAt > $1.caughtAt }) {
            if !seen.contains(catchItem.species) {
                seen.insert(catchItem.species)
                result.append(catchItem)
            }
            if result.count == FishSpecies.allCases.count { break }
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let size = tankSize

                ZStack {
                    // 1. Deep water gradient + depth haze
                    waterBackground

                    // 1.5. Hunger / neglect overlay — water murkies when fish unfed
                    hungerOverlay

                    // 2. Volumetric light rays from surface
                    if !reduceMotion {
                        lightRays(size: size, time: time)
                    }

                    // 3. Floating plankton / dust motes
                    if !reduceMotion {
                        floatingParticles(size: size, time: time)
                    }

                    // 4. Sand dune terrain
                    sandBottom(width: size.width, height: size.height)

                    // 5. Kelp forest (behind fish)
                    seaweedLayer(size: size, time: time)

                    // 5a. Short grass tufts along sand
                    if !reduceMotion {
                        grassTufts(size: size, time: time)
                    }

                    // 5.5. Tank decorations (on the sand)
                    decorationLayer(size: size)

                    // 5.6. Coral formations (growing from sand)
                    coralLayer(size: size, time: time)

                    // 5.7. Jellyfish — slow-drifting mid-water creatures
                    if !reduceMotion {
                        jellyfishLayer(size: size, time: time)
                    }

                    // 6. Bubbles
                    if !reduceMotion {
                        bubblesCanvas(size: size, time: time)
                    }

                    // 7. Fish — back layer then front layer
                    if colonyFish.isEmpty {
                        emptyState
                    } else {
                        backFishLayer(size: size, time: time)
                        frontFishLayer(size: size, time: time)
                    }

                    // 8. Ripples
                    ForEach(ripples) { ripple in
                        Circle()
                            .stroke(Color.white.opacity(ripple.opacity), lineWidth: 1.5)
                            .frame(width: 40 * ripple.scale, height: 40 * ripple.scale)
                            .position(ripple.point)
                    }

                    // 9. Food particles
                    foodParticlesLayer

                    // 10. Caustic light shimmer
                    if !reduceMotion {
                        causticCanvas(size: size, time: time)
                    }

                    // 11. Water surface wave line
                    if !reduceMotion {
                        waterSurface(size: size, time: time)
                    }

                    // 12. Glass border + surface shine
                    glassBorder
                    surfaceShine(width: size.width)

                    // 13. Feed indicator + decor shop button
                    tankOverlayButtons

                    // 14. Happiness indicator (top-left)
                    happinessIndicator

                    // 15. Feed bonus toast
                    if feedBonusText != nil {
                        feedBonusToast
                    }
                }
        }
        .onAppear { tankSize = geo.size }
        .onChange(of: geo.size) { _, newSize in tankSize = newSize }
        } // end GeometryReader
        .drawingGroup()  // Flatten all fish, bubbles, caustics into one GPU texture
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        // Fish inspect card — rendered outside drawingGroup with a backdrop dimmer
        .overlay {
            ZStack(alignment: .bottom) {
                if inspectedFish != nil {
                    Color.black.opacity(0.52)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                inspectedFish = nil
                            }
                        }
                        .transition(.opacity)
                }
                if let fish = inspectedFish {
                    fishInspectCard(for: fish)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 30 && feedsAvailable > 0 {
                        dropFood(at: value.location)
                    }
                }
        )
        .onTapGesture { location in
            handleWaterTap(at: location)
        }
        .sheet(isPresented: $showDecorationShop) {
            DecorationShopView()
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            spawnFish()
            spawnBubbles()
            spawnSeaweed()
            spawnJellyfish()
            feedsAvailable = rewardService.tasksCompletedToday
        }
        .onChange(of: colonyFish.count) { _, _ in
            spawnFish()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeFishEvolved)) { _ in
            if let evo = RewardService.shared.pendingEvolution {
                pendingEvolutionInfo = evo
                withAnimation(.easeIn(duration: 0.2)) {
                    showEvolutionCelebration = true
                }
            }
        }
        .overlay {
            if showEvolutionCelebration, let evo = pendingEvolutionInfo {
                FishEvolutionCelebration(
                    species: evo.species,
                    newStage: evo.stage,
                    onDismiss: {
                        showEvolutionCelebration = false
                        pendingEvolutionInfo = nil
                        RewardService.shared.acknowledgePendingEvolution()
                        spawnFish()
                    }
                )
                .transition(.opacity)
            }
        }
        .nudgeAccessibility(
            label: String(localized: "Aquarium tank with \(colonyFish.count) fish"),
            hint: String(localized: "Tap a fish to see details, swipe down to feed")
        )
    }

    // MARK: - Hunger Overlay

    /// Semi-transparent brownish tint layered over the water when fish are neglected.
    /// At happiness = 1.0 → invisible. At happiness = 0.0 → murky dark-brown.
    @ViewBuilder
    private var hungerOverlay: some View {
        let happiness = rewardService.fishHappiness
        let opacity = (1.0 - happiness) * 0.30
        if opacity > 0.015 {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "2A1A0E").opacity(opacity * 0.55),
                            Color(hex: "3D2B1F").opacity(opacity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        }
    }

    // MARK: - Water Background

    private var waterBackground: some View {
        ZStack {
            // Base water — rich ocean gradient: sun-kissed surface → deep abyss
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "0A3D5C"), location: 0.0),   // Bright teal surface
                            .init(color: Color(hex: "0C4A6E"), location: 0.08),  // Warm cyan
                            .init(color: Color(hex: "0E3A5E"), location: 0.18),  // Transition
                            .init(color: Color(hex: "0A2E4A"), location: 0.30),  // Mid-water blue
                            .init(color: Color(hex: "072340"), location: 0.50),  // Deep blue
                            .init(color: Color(hex: "041B30"), location: 0.70),  // Navy
                            .init(color: Color(hex: "021020"), location: 0.85),  // Near-black
                            .init(color: Color(hex: "010A15"), location: 1.0)    // Abyss
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Warm light zone — golden hour glow near the surface
            VStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "FFD54F").opacity(0.06), location: 0.0),
                        .init(color: Color(hex: "FFAB40").opacity(0.04), location: 0.3),
                        .init(color: Color(hex: "4FC3F7").opacity(0.03), location: 0.6),
                        .init(color: Color.clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Depth fog — deep water haze near the bottom
            VStack {
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color(hex: "0D3B66").opacity(0.08), location: 0.2),
                        .init(color: Color(hex: "0A2540").opacity(0.18), location: 0.5),
                        .init(color: Color(hex: "071C30").opacity(0.25), location: 0.8),
                        .init(color: Color(hex: "051525").opacity(0.30), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Edge vignette — darkens corners for depth framing
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.clear,
                            Color(hex: "010A15").opacity(0.20)
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 250
                    )
                )

            // Subtle underwater light scatter — horizontal band mid-water
            VStack {
                Spacer()
                    .frame(height: 60)
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(hex: "4FC3F7").opacity(0.015),
                        Color(hex: "80DEEA").opacity(0.02),
                        Color(hex: "4FC3F7").opacity(0.01),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 40)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Light Rays (Warm Volumetric God-Rays)

    private func lightRays(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Primary volumetric rays — warm-tinted, wide, visible shafts
            let primaryRays = 6
            for i in 0..<primaryRays {
                let t = Double(i) / Double(primaryRays)
                let sway = sin(time * 0.20 + t * .pi * 2) * 0.07
                let baseX = 0.06 + t * 0.88 + sway
                let topX = w * baseX
                let spreadTop = w * 0.018
                let spreadBottom = w * (0.07 + sin(time * 0.35 + t * 2.0) * 0.025)
                let rayHeight = h * (0.80 + sin(time * 0.30 + t * 1.5) * 0.10)
                let baseOpacity = 0.045 + sin(time * 0.40 + t * 3.0) * 0.022

                var path = Path()
                path.move(to: CGPoint(x: topX - spreadTop, y: 0))
                path.addLine(to: CGPoint(x: topX + spreadTop, y: 0))
                path.addCurve(
                    to: CGPoint(x: topX + spreadBottom, y: rayHeight),
                    control1: CGPoint(x: topX + spreadTop * 2.2, y: rayHeight * 0.25),
                    control2: CGPoint(x: topX + spreadBottom * 0.75, y: rayHeight * 0.55)
                )
                path.addCurve(
                    to: CGPoint(x: topX - spreadBottom, y: rayHeight),
                    control1: CGPoint(x: topX + spreadBottom * 0.15, y: rayHeight * 1.02),
                    control2: CGPoint(x: topX - spreadBottom * 0.15, y: rayHeight * 1.02)
                )
                path.addCurve(
                    to: CGPoint(x: topX - spreadTop, y: 0),
                    control1: CGPoint(x: topX - spreadBottom * 0.75, y: rayHeight * 0.55),
                    control2: CGPoint(x: topX - spreadTop * 2.2, y: rayHeight * 0.25)
                )
                path.closeSubpath()

                // Alternate between warm gold and cool cyan rays
                let isWarm = i % 2 == 0
                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: Color.white.opacity(baseOpacity * 1.3), location: 0),
                            .init(color: (isWarm ? Color(hex: "FFE082") : Color(hex: "4FC3F7")).opacity(baseOpacity * 0.8), location: 0.15),
                            .init(color: (isWarm ? Color(hex: "FFCC02") : Color(hex: "4FC3F7")).opacity(baseOpacity * 0.5), location: 0.35),
                            .init(color: Color(hex: "4FC3F7").opacity(baseOpacity * 0.2), location: 0.6),
                            .init(color: Color.clear, location: 1.0)
                        ]),
                        startPoint: CGPoint(x: topX, y: 0),
                        endPoint: CGPoint(x: topX, y: rayHeight)
                    )
                )
            }

            // Secondary thin flickering beams — sharp accent rays
            let thinRays = 4
            for i in 0..<thinRays {
                let t = Double(i) / Double(thinRays)
                let flicker = sin(time * 1.0 + t * 5.0) * 0.5 + 0.5
                guard flicker > 0.20 else { continue }
                let sway = sin(time * 0.45 + t * .pi * 1.5) * 0.05
                let baseX = 0.15 + t * 0.70 + sway
                let topX = w * baseX
                let rayHeight = h * (0.50 + flicker * 0.15)
                let opacity = 0.028 * flicker

                var path = Path()
                path.move(to: CGPoint(x: topX - 1, y: 0))
                path.addLine(to: CGPoint(x: topX + 1, y: 0))
                path.addLine(to: CGPoint(x: topX + w * 0.03, y: rayHeight))
                path.addLine(to: CGPoint(x: topX - w * 0.03, y: rayHeight))
                path.closeSubpath()

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.white.opacity(opacity * 1.2),
                            Color(hex: "80DEEA").opacity(opacity * 0.6),
                            Color.clear
                        ]),
                        startPoint: CGPoint(x: topX, y: 0),
                        endPoint: CGPoint(x: topX, y: rayHeight)
                    )
                )
            }

            // Ambient glow pool — soft light splash where rays hit sand
            for i in 0..<3 {
                let t = Double(i) / 3.0
                let gx = w * CGFloat(0.20 + t * 0.60 + sin(time * 0.15 + t * 3.0) * 0.06)
                let gy = h * 0.82
                let gw = w * 0.12
                let gh = h * 0.06
                let gOp = 0.015 + sin(time * 0.3 + t * 2.0) * 0.008

                var glow = Path()
                glow.addEllipse(in: CGRect(x: gx - gw / 2, y: gy - gh / 2, width: gw, height: gh))
                context.fill(glow, with: .color(Color(hex: "FFE082").opacity(gOp)))
            }
        }
        .allowsHitTesting(false)
        .blendMode(.screen)
    }

    // MARK: - Sand Bottom (Layered Terrain)

    private func sandBottom(width: CGFloat, height: CGFloat) -> some View {
        VStack {
            Spacer()
            Canvas { context, canvasSize in
                let w = canvasSize.width
                let h = canvasSize.height

                // Layer 1: Deep back-shelf — darkest, creates depth
                var backShelf = Path()
                backShelf.move(to: CGPoint(x: 0, y: h * 0.15))
                backShelf.addCurve(
                    to: CGPoint(x: w * 0.30, y: h * 0.08),
                    control1: CGPoint(x: w * 0.10, y: h * 0.12),
                    control2: CGPoint(x: w * 0.20, y: h * 0.06)
                )
                backShelf.addCurve(
                    to: CGPoint(x: w * 0.60, y: h * 0.14),
                    control1: CGPoint(x: w * 0.40, y: h * 0.10),
                    control2: CGPoint(x: w * 0.50, y: h * 0.16)
                )
                backShelf.addCurve(
                    to: CGPoint(x: w, y: h * 0.10),
                    control1: CGPoint(x: w * 0.75, y: h * 0.11),
                    control2: CGPoint(x: w * 0.90, y: h * 0.08)
                )
                backShelf.addLine(to: CGPoint(x: w, y: h))
                backShelf.addLine(to: CGPoint(x: 0, y: h))
                backShelf.closeSubpath()
                context.fill(backShelf, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(hex: "2E1F14").opacity(0.70), location: 0),
                        .init(color: Color(hex: "3E2723").opacity(0.85), location: 0.3),
                        .init(color: Color(hex: "4E342E").opacity(0.90), location: 0.6),
                        .init(color: Color(hex: "3E2723").opacity(0.95), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: h)
                ))

                // Layer 2: Mid dune — warmer sand, rolling hills
                var midDune = Path()
                midDune.move(to: CGPoint(x: 0, y: h * 0.30))
                midDune.addCurve(
                    to: CGPoint(x: w * 0.18, y: h * 0.22),
                    control1: CGPoint(x: w * 0.06, y: h * 0.28),
                    control2: CGPoint(x: w * 0.12, y: h * 0.20)
                )
                midDune.addCurve(
                    to: CGPoint(x: w * 0.40, y: h * 0.32),
                    control1: CGPoint(x: w * 0.26, y: h * 0.24),
                    control2: CGPoint(x: w * 0.34, y: h * 0.34)
                )
                midDune.addCurve(
                    to: CGPoint(x: w * 0.65, y: h * 0.20),
                    control1: CGPoint(x: w * 0.48, y: h * 0.30),
                    control2: CGPoint(x: w * 0.58, y: h * 0.18)
                )
                midDune.addCurve(
                    to: CGPoint(x: w * 0.85, y: h * 0.28),
                    control1: CGPoint(x: w * 0.72, y: h * 0.22),
                    control2: CGPoint(x: w * 0.78, y: h * 0.30)
                )
                midDune.addCurve(
                    to: CGPoint(x: w, y: h * 0.24),
                    control1: CGPoint(x: w * 0.92, y: h * 0.26),
                    control2: CGPoint(x: w * 0.96, y: h * 0.22)
                )
                midDune.addLine(to: CGPoint(x: w, y: h))
                midDune.addLine(to: CGPoint(x: 0, y: h))
                midDune.closeSubpath()
                context.fill(midDune, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(hex: "5D4037"), location: 0),
                        .init(color: Color(hex: "6D4C41"), location: 0.3),
                        .init(color: Color(hex: "795548"), location: 0.6),
                        .init(color: Color(hex: "6D4C41"), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: h)
                ))

                // Layer 3: Front sand lip — lightest, closest to viewer
                var frontLip = Path()
                frontLip.move(to: CGPoint(x: 0, y: h * 0.52))
                frontLip.addCurve(
                    to: CGPoint(x: w * 0.25, y: h * 0.42),
                    control1: CGPoint(x: w * 0.08, y: h * 0.50),
                    control2: CGPoint(x: w * 0.18, y: h * 0.40)
                )
                frontLip.addCurve(
                    to: CGPoint(x: w * 0.50, y: h * 0.50),
                    control1: CGPoint(x: w * 0.32, y: h * 0.44),
                    control2: CGPoint(x: w * 0.42, y: h * 0.52)
                )
                frontLip.addCurve(
                    to: CGPoint(x: w * 0.75, y: h * 0.40),
                    control1: CGPoint(x: w * 0.58, y: h * 0.48),
                    control2: CGPoint(x: w * 0.68, y: h * 0.38)
                )
                frontLip.addCurve(
                    to: CGPoint(x: w, y: h * 0.46),
                    control1: CGPoint(x: w * 0.84, y: h * 0.42),
                    control2: CGPoint(x: w * 0.94, y: h * 0.44)
                )
                frontLip.addLine(to: CGPoint(x: w, y: h))
                frontLip.addLine(to: CGPoint(x: 0, y: h))
                frontLip.closeSubpath()
                context.fill(frontLip, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(hex: "8D6E63").opacity(0.65), location: 0),
                        .init(color: Color(hex: "A1887F").opacity(0.55), location: 0.4),
                        .init(color: Color(hex: "8D6E63").opacity(0.50), location: 0.7),
                        .init(color: Color(hex: "795548").opacity(0.60), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: h)
                ))

                // Ripple marks — wavy lines in the sand (like real underwater sand)
                for r in 0..<6 {
                    let ry = h * (0.50 + CGFloat(r) * 0.08)
                    var ripplePath = Path()
                    ripplePath.move(to: CGPoint(x: 0, y: ry))
                    let rippleAmplitude = CGFloat(1.2 + Double(r) * 0.3)
                    let rippleFreq = 14.0 + Double(r) * 2.0
                    for s in 0...20 {
                        let t = CGFloat(s) / 20.0
                        let x = w * t
                        let y = ry + sin(Double(t) * rippleFreq + Double(r) * 1.5) * rippleAmplitude
                        ripplePath.addLine(to: CGPoint(x: x, y: y))
                    }
                    context.stroke(
                        ripplePath,
                        with: .color(Color(hex: "D7CCC8").opacity(0.04 + Double(r) * 0.006)),
                        style: StrokeStyle(lineWidth: 0.6, lineCap: .round)
                    )
                }

                // Pebbles — varied sizes, some with shadow
                let pebbles: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, hex: String, op: Double)] = [
                    (0.06, 0.55, 4.0, 2.8, "8D6E63", 0.35), (0.12, 0.65, 3.2, 2.2, "A1887F", 0.30),
                    (0.20, 0.48, 5.5, 3.5, "6D4C41", 0.40), (0.28, 0.72, 2.8, 1.8, "BCAAA4", 0.28),
                    (0.35, 0.58, 3.8, 2.6, "8D6E63", 0.32), (0.44, 0.68, 4.2, 2.8, "795548", 0.35),
                    (0.52, 0.52, 3.0, 2.0, "A1887F", 0.30), (0.60, 0.62, 5.0, 3.2, "6D4C41", 0.38),
                    (0.68, 0.44, 3.5, 2.4, "BCAAA4", 0.28), (0.75, 0.70, 4.5, 3.0, "8D6E63", 0.34),
                    (0.82, 0.56, 2.6, 1.8, "795548", 0.30), (0.90, 0.64, 3.8, 2.6, "A1887F", 0.32),
                    (0.15, 0.78, 2.2, 1.6, "BCAAA4", 0.25), (0.38, 0.82, 1.8, 1.2, "6D4C41", 0.22),
                    (0.55, 0.80, 3.0, 2.0, "8D6E63", 0.28), (0.72, 0.76, 2.4, 1.8, "A1887F", 0.26),
                    (0.88, 0.78, 2.0, 1.4, "795548", 0.24)
                ]
                for p in pebbles {
                    // Shadow under pebble
                    var shadow = Path()
                    shadow.addEllipse(in: CGRect(
                        x: w * p.x - p.w * 0.5 + 1, y: h * p.y - p.h * 0.3 + 1,
                        width: p.w + 1, height: p.h + 0.5
                    ))
                    context.fill(shadow, with: .color(Color.black.opacity(0.08)))
                    // Pebble body
                    var pebblePath = Path()
                    pebblePath.addEllipse(in: CGRect(
                        x: w * p.x - p.w * 0.5, y: h * p.y - p.h * 0.3,
                        width: p.w, height: p.h
                    ))
                    context.fill(pebblePath, with: .color(Color(hex: p.hex).opacity(p.op)))
                    // Highlight on pebble
                    var highlight = Path()
                    highlight.addEllipse(in: CGRect(
                        x: w * p.x - p.w * 0.25, y: h * p.y - p.h * 0.35,
                        width: p.w * 0.4, height: p.h * 0.3
                    ))
                    context.fill(highlight, with: .color(Color.white.opacity(0.04)))
                }

                // Sand grain texture — denser, more visible
                for i in 0..<50 {
                    let seed = Double(i) * 3.77
                    let sx = w * CGFloat((seed * 0.131).truncatingRemainder(dividingBy: 1.0))
                    let sy = h * CGFloat(0.30 + (seed * 0.197).truncatingRemainder(dividingBy: 0.65))
                    let sr = CGFloat(0.4 + (seed * 0.293).truncatingRemainder(dividingBy: 1.0))
                    let tone = (seed * 0.371).truncatingRemainder(dividingBy: 1.0)
                    let color = tone > 0.5
                        ? Color(hex: "D7CCC8").opacity(0.06)
                        : Color(hex: "BCAAA4").opacity(0.05)
                    var speck = Path()
                    speck.addEllipse(in: CGRect(x: sx, y: sy, width: sr, height: sr))
                    context.fill(speck, with: .color(color))
                }
            }
            .frame(height: height * 0.30)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Kelp Forest Layer (Lush Ribbon Blades)

    private func seaweedLayer(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            for weed in seaweeds {
                let baseX = weed.x * w
                let weedHeight = weed.height * h
                let bottomY = h

                for blade in 0..<weed.bladeCount {
                    let bladeOffset = CGFloat(blade - weed.bladeCount / 2) * 9
                    // Multi-frequency organic sway
                    let sway1 = reduceMotion ? 0.0 : sin(time * 0.5 + weed.phaseOffset + Double(blade) * 0.4) * 12.0
                    let sway2 = reduceMotion ? 0.0 : sin(time * 0.9 + weed.phaseOffset + Double(blade) * 0.7) * 6.0
                    let sway3 = reduceMotion ? 0.0 : sin(time * 0.25 + weed.phaseOffset) * 4.0
                    let totalSway = sway1 + sway2 + sway3

                    // Wider, ribbon-like blade — thick at base, tapered tip
                    var bladePath = Path()
                    let tipX = baseX + bladeOffset + CGFloat(totalSway)
                    let tipY = bottomY - weedHeight
                    let baseWidth: CGFloat = 5.5  // Much wider at base
                    let midWidth: CGFloat = 4.0   // Still wide at middle
                    let tipWidth: CGFloat = 1.5   // Tapered tip

                    let midY = bottomY - weedHeight * 0.5
                    let midSway = CGFloat(totalSway) * 0.5

                    // Left edge — organic curve from base to tip
                    bladePath.move(to: CGPoint(x: baseX + bladeOffset - baseWidth, y: bottomY))
                    bladePath.addCurve(
                        to: CGPoint(x: baseX + bladeOffset - midWidth + midSway, y: midY),
                        control1: CGPoint(
                            x: baseX + bladeOffset - baseWidth + CGFloat(totalSway) * 0.15,
                            y: bottomY - weedHeight * 0.20
                        ),
                        control2: CGPoint(
                            x: baseX + bladeOffset - midWidth + midSway * 0.6,
                            y: bottomY - weedHeight * 0.38
                        )
                    )
                    bladePath.addCurve(
                        to: CGPoint(x: tipX - tipWidth, y: tipY),
                        control1: CGPoint(
                            x: baseX + bladeOffset - midWidth * 0.7 + CGFloat(totalSway) * 0.65,
                            y: bottomY - weedHeight * 0.65
                        ),
                        control2: CGPoint(
                            x: tipX - tipWidth * 1.5,
                            y: bottomY - weedHeight * 0.85
                        )
                    )

                    // Leaf tip — rounded
                    bladePath.addCurve(
                        to: CGPoint(x: tipX + tipWidth, y: tipY),
                        control1: CGPoint(x: tipX, y: tipY - 4),
                        control2: CGPoint(x: tipX + tipWidth, y: tipY - 3)
                    )

                    // Right edge back down
                    bladePath.addCurve(
                        to: CGPoint(x: baseX + bladeOffset + midWidth + midSway, y: midY),
                        control1: CGPoint(
                            x: tipX + tipWidth * 1.5,
                            y: bottomY - weedHeight * 0.85
                        ),
                        control2: CGPoint(
                            x: baseX + bladeOffset + midWidth * 0.7 + CGFloat(totalSway) * 0.65,
                            y: bottomY - weedHeight * 0.65
                        )
                    )
                    bladePath.addCurve(
                        to: CGPoint(x: baseX + bladeOffset + baseWidth, y: bottomY),
                        control1: CGPoint(
                            x: baseX + bladeOffset + midWidth + midSway * 0.6,
                            y: bottomY - weedHeight * 0.38
                        ),
                        control2: CGPoint(
                            x: baseX + bladeOffset + baseWidth + CGFloat(totalSway) * 0.15,
                            y: bottomY - weedHeight * 0.20
                        )
                    )
                    bladePath.closeSubpath()

                    // Depth-based opacity — back kelp is dimmer
                    let depthFactor: Double = weed.height < 0.20 ? 0.40 : 0.65

                    // Fill — gradient from dark base to translucent tip
                    context.fill(bladePath, with: .linearGradient(
                        Gradient(stops: [
                            .init(color: weed.color.opacity(depthFactor * 0.4), location: 0.0),
                            .init(color: weed.color.opacity(depthFactor * 0.9), location: 0.2),
                            .init(color: weed.color.opacity(depthFactor), location: 0.5),
                            .init(color: weed.color.opacity(depthFactor * 0.7), location: 0.8),
                            .init(color: weed.color.opacity(depthFactor * 0.4), location: 1.0)
                        ]),
                        startPoint: CGPoint(x: baseX, y: bottomY),
                        endPoint: CGPoint(x: tipX, y: tipY)
                    ))

                    // Translucent edge highlight — rim light on one side
                    context.stroke(bladePath, with: .color(
                        Color(hex: "81C784").opacity(0.06)
                    ), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))

                    // Central vein / midrib — thicker, more visible
                    var midrib = Path()
                    midrib.move(to: CGPoint(x: baseX + bladeOffset, y: bottomY))
                    midrib.addCurve(
                        to: CGPoint(x: baseX + bladeOffset + midSway, y: midY),
                        control1: CGPoint(
                            x: baseX + bladeOffset + CGFloat(totalSway) * 0.15,
                            y: bottomY - weedHeight * 0.25
                        ),
                        control2: CGPoint(
                            x: baseX + bladeOffset + midSway * 0.5,
                            y: bottomY - weedHeight * 0.40
                        )
                    )
                    midrib.addCurve(
                        to: CGPoint(x: tipX, y: tipY + 3),
                        control1: CGPoint(
                            x: baseX + bladeOffset + CGFloat(totalSway) * 0.7,
                            y: bottomY - weedHeight * 0.65
                        ),
                        control2: CGPoint(
                            x: tipX - 1,
                            y: bottomY - weedHeight * 0.88
                        )
                    )
                    context.stroke(
                        midrib,
                        with: .color(Color(hex: "A5D6A7").opacity(0.07)),
                        style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                    )

                    // Secondary veins — branches off the midrib
                    for v in 0..<3 {
                        let vt = CGFloat(v + 1) / 4.0
                        let vy = bottomY - weedHeight * vt
                        let vx = baseX + bladeOffset + CGFloat(totalSway) * vt
                        let vLen = (baseWidth - tipWidth) * (1.0 - vt) * 0.6
                        var vein = Path()
                        vein.move(to: CGPoint(x: vx, y: vy))
                        vein.addLine(to: CGPoint(x: vx + vLen, y: vy - 3))
                        context.stroke(vein, with: .color(Color.white.opacity(0.025)),
                                       style: StrokeStyle(lineWidth: 0.4, lineCap: .round))
                        var veinR = Path()
                        veinR.move(to: CGPoint(x: vx, y: vy))
                        veinR.addLine(to: CGPoint(x: vx - vLen, y: vy - 2))
                        context.stroke(veinR, with: .color(Color.white.opacity(0.02)),
                                       style: StrokeStyle(lineWidth: 0.4, lineCap: .round))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Grass Tufts (Short Sand Vegetation)

    private func grassTufts(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Tuft positions along the sand — (x: normalized, bladeCount, height, phase)
            let tufts: [(x: CGFloat, blades: Int, height: CGFloat, phase: Double)] = [
                (0.05, 3, 14, 0.0), (0.10, 2, 10, 1.2), (0.17, 4, 16, 2.4),
                (0.24, 2, 11, 0.8), (0.32, 3, 13, 3.1), (0.40, 2, 9, 1.6),
                (0.48, 3, 15, 4.0), (0.55, 2, 10, 0.5), (0.63, 4, 17, 2.8),
                (0.70, 2, 11, 1.9), (0.78, 3, 14, 3.5), (0.84, 2, 9, 0.3),
                (0.92, 3, 12, 2.1), (0.97, 2, 10, 4.5),
            ]

            let sandTop = h * 0.72  // Where sand begins

            for tuft in tufts {
                let baseX = tuft.x * w
                let baseY = sandTop + 6  // Slightly into the sand

                for b in 0..<tuft.blades {
                    let spread = CGFloat(b - tuft.blades / 2) * 3.5
                    // Fast sway — grass moves quicker than kelp
                    let sway = sin(time * 1.8 + tuft.phase + Double(b) * 0.6) * 3.5
                    let sway2 = sin(time * 2.8 + tuft.phase + Double(b) * 1.1) * 1.5
                    let tipSway = CGFloat(sway + sway2)

                    let bladeH = tuft.height + CGFloat(b) * 1.5

                    var blade = Path()
                    blade.move(to: CGPoint(x: baseX + spread - 1.2, y: baseY))
                    blade.addCurve(
                        to: CGPoint(x: baseX + spread + tipSway, y: baseY - bladeH),
                        control1: CGPoint(x: baseX + spread - 1 + tipSway * 0.2, y: baseY - bladeH * 0.4),
                        control2: CGPoint(x: baseX + spread + tipSway * 0.6, y: baseY - bladeH * 0.7)
                    )
                    blade.addCurve(
                        to: CGPoint(x: baseX + spread + 1.2, y: baseY),
                        control1: CGPoint(x: baseX + spread + tipSway * 0.6 + 1.5, y: baseY - bladeH * 0.7),
                        control2: CGPoint(x: baseX + spread + 1 + tipSway * 0.2, y: baseY - bladeH * 0.4)
                    )
                    blade.closeSubpath()

                    let grassColor = b % 2 == 0
                        ? Color(hex: "66BB6A").opacity(0.40)
                        : Color(hex: "81C784").opacity(0.35)
                    context.fill(blade, with: .color(grassColor))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Floating Particles (Plankton / Dust Motes)

    private func floatingParticles(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let particleCount = 20

            for i in 0..<particleCount {
                let seed = Double(i) * 2.71828
                let baseX = CGFloat((seed * 0.131).truncatingRemainder(dividingBy: 1.0))
                let baseY = CGFloat((seed * 0.197).truncatingRemainder(dividingBy: 1.0))

                // Slow drifting motion
                let driftX = sin(time * 0.15 + seed * 1.3) * 0.03
                let driftY = cos(time * 0.12 + seed * 0.9) * 0.025
                // Gentle float upward
                let floatUp = (time * 0.008 + seed * 0.5).truncatingRemainder(dividingBy: 1.0)

                let x = w * CGFloat(baseX + driftX)
                let y = h * CGFloat(1.0 - (baseY + floatUp).truncatingRemainder(dividingBy: 1.0) + driftY)

                // Vary size and brightness
                let particleSize = CGFloat(0.6 + (seed * 0.371).truncatingRemainder(dividingBy: 1.2))
                let twinkle = sin(time * 1.5 + seed * 4.0) * 0.3 + 0.7
                let opacity = 0.06 * twinkle

                var mote = Path()
                mote.addEllipse(in: CGRect(
                    x: x - particleSize,
                    y: y - particleSize,
                    width: particleSize * 2,
                    height: particleSize * 2
                ))
                context.fill(mote, with: .color(Color.white.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Water Surface (Meniscus Band)

    private func waterSurface(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let surfaceY: CGFloat = 2
            let bandHeight: CGFloat = 10  // Thicker meniscus band
            let segments = 40

            // Helper: compute wave Y at position t
            func waveY(_ t: Double) -> CGFloat {
                let wave1 = sin(time * 1.3 + t * 8.0) * 2.2
                let wave2 = sin(time * 2.0 + t * 14.0) * 0.9
                let wave3 = sin(time * 0.6 + t * 4.0) * 1.4
                return surfaceY + CGFloat(wave1 + wave2 + wave3)
            }

            // 1. Surface band — thick gradient fill from top to wave line
            var bandPath = Path()
            bandPath.move(to: CGPoint(x: 0, y: 0))
            bandPath.addLine(to: CGPoint(x: w, y: 0))
            for s in stride(from: segments, through: 0, by: -1) {
                let t = CGFloat(s) / CGFloat(segments)
                bandPath.addLine(to: CGPoint(x: w * t, y: waveY(Double(t))))
            }
            bandPath.closeSubpath()
            context.fill(bandPath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color.white.opacity(0.10), location: 0),
                    .init(color: Color(hex: "B3E5FC").opacity(0.06), location: 0.3),
                    .init(color: Color(hex: "4FC3F7").opacity(0.04), location: 0.6),
                    .init(color: Color(hex: "4FC3F7").opacity(0.02), location: 1.0)
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: surfaceY + 6)
            ))

            // 2. Primary wave highlight line — bright
            var highlightPath = Path()
            highlightPath.move(to: CGPoint(x: 0, y: waveY(0)))
            for s in 1...segments {
                let t = Double(s) / Double(segments)
                highlightPath.addLine(to: CGPoint(x: w * CGFloat(t), y: waveY(t)))
            }
            context.stroke(
                highlightPath,
                with: .color(Color.white.opacity(0.16)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )

            // 3. Secondary wave line — offset below, softer
            var secondaryWave = Path()
            let offset: CGFloat = 3
            secondaryWave.move(to: CGPoint(x: 0, y: waveY(0) + offset))
            for s in 1...segments {
                let t = Double(s) / Double(segments)
                secondaryWave.addLine(to: CGPoint(x: w * CGFloat(t), y: waveY(t) + offset))
            }
            context.stroke(
                secondaryWave,
                with: .color(Color.white.opacity(0.06)),
                style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
            )

            // 4. Refraction glow band below wave
            var refractionPath = Path()
            for s in 0...segments {
                let t = Double(s) / Double(segments)
                let x = w * CGFloat(t)
                let y = waveY(t) + 2
                if s == 0 { refractionPath.move(to: CGPoint(x: x, y: y)) }
                else { refractionPath.addLine(to: CGPoint(x: x, y: y)) }
            }
            refractionPath.addLine(to: CGPoint(x: w, y: surfaceY + bandHeight + 6))
            refractionPath.addLine(to: CGPoint(x: 0, y: surfaceY + bandHeight + 6))
            refractionPath.closeSubpath()
            context.fill(refractionPath, with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.025),
                    Color(hex: "4FC3F7").opacity(0.012),
                    Color.clear
                ]),
                startPoint: CGPoint(x: 0, y: surfaceY + 2),
                endPoint: CGPoint(x: 0, y: surfaceY + bandHeight + 6)
            ))

            // 5. Moving specular streaks — bright spots that slide along surface
            for i in 0..<4 {
                let streakT = (time * 0.08 + Double(i) * 0.25).truncatingRemainder(dividingBy: 1.0)
                let sx = w * CGFloat(streakT)
                let sy = waveY(streakT)
                let streakW: CGFloat = w * 0.06
                let bright = sin(time * 1.5 + Double(i) * 2.0) * 0.5 + 0.5

                var streak = Path()
                streak.move(to: CGPoint(x: sx - streakW * 0.5, y: sy))
                streak.addCurve(
                    to: CGPoint(x: sx + streakW * 0.5, y: sy + 0.5),
                    control1: CGPoint(x: sx - streakW * 0.15, y: sy - 1.5),
                    control2: CGPoint(x: sx + streakW * 0.15, y: sy - 1.5)
                )
                context.stroke(streak, with: .color(Color.white.opacity(0.08 * bright)),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }

            // 6. Foam flecks — tiny white dots along the wave crest
            for i in 0..<12 {
                let ft = Double(i) / 12.0
                let fx = w * CGFloat(ft + sin(time * 0.5 + ft * 6.0) * 0.02)
                let fy = waveY(ft) - CGFloat(0.5 + sin(time * 2.0 + ft * 8.0) * 0.5)
                let flicker = sin(time * 3.0 + ft * 10.0) * 0.5 + 0.5
                let fr: CGFloat = CGFloat(0.4 + flicker * 0.6)
                var foam = Path()
                foam.addEllipse(in: CGRect(x: fx - fr, y: fy - fr, width: fr * 2, height: fr * 2))
                context.fill(foam, with: .color(Color.white.opacity(0.07 * flicker)))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Fish Layers (Depth-Sorted)

    /// Back-layer fish (depth 0.5…1.0) — behind, smaller, dimmer.
    private func backFishLayer(size: CGSize, time: Double) -> some View {
        ForEach(Array(tankFish.filter { $0.depth >= 0.5 }), id: \.id) { fish in
            fishBody(fish: fish, size: size, time: time)
        }
    }

    /// Front-layer fish (depth 0.0..<0.5) — in front, full size.
    private func frontFishLayer(size: CGSize, time: Double) -> some View {
        ForEach(Array(tankFish.filter { $0.depth < 0.5 }), id: \.id) { fish in
            fishBody(fish: fish, size: size, time: time)
        }
    }

    @ViewBuilder
    private func fishBody(fish: TankFish, size: CGSize, time: Double) -> some View {
        let pos = swimPosition(for: fish, in: size, time: time)
        let tailWag = tailWagPhase(for: fish, time: time)
        let depthScale = 1.0 - fish.depth * 0.25
        let depthOpacity = 1.0 - Double(fish.depth) * 0.3

        // Health dimming — neglected fish fade to ~50% opacity
        let healthFactor = 0.5 + rewardService.fishHappiness * 0.5
        let finalOpacity = depthOpacity * healthFactor

        // Face the direction of actual horizontal movement so fish always
        // look where they're going instead of having a random flip.
        let xPhase = time * .pi * 2 / fish.speed + fish.phaseOffset
        let movingRight = cos(xPhase) > 0

        // Size scales with evolution stage
        let evolvedSize = fish.catchData.species.evolvedDisplaySize(for: fish.evolutionStage) * depthScale

        ZStack {
            // Elder / Ancient persistent glow halo
            if fish.evolutionStage.glows {
                Circle()
                    .fill(fish.catchData.species.fishColor.opacity(fish.evolutionStage.glowIntensity * 0.45))
                    .frame(width: evolvedSize * 2.0, height: evolvedSize * 2.0)
                    .blur(radius: evolvedSize * 0.55)
                    .allowsHitTesting(false)
            }
            AnimatedFishView(
                size: evolvedSize,
                color: fish.catchData.species.fishColor,
                accentColor: fish.catchData.species.fishAccentColor,
                tailPhase: tailWag,
                stage: fish.evolutionStage
            )
            .scaleEffect(x: movingRight ? 1 : -1, y: 1)
            .opacity(finalOpacity)
        }
        .offset(x: fish.scatterOffset.width, y: fish.scatterOffset.height)
        .position(x: pos.x, y: pos.y)
        .onTapGesture {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                inspectedFish = fish.catchData
            }
            onFishTap?(fish.catchData)
            HapticService.shared.actionButtonTap()
        }
        .allowsHitTesting(true)
    }

    // MARK: - Swim Physics

    private func swimPosition(for fish: TankFish, in size: CGSize, time: Double) -> CGPoint {
        guard !reduceMotion else {
            return CGPoint(x: fish.x * size.width, y: fish.y * size.height)
        }

        let phase = time * .pi * 2
        let xPhase = phase / fish.speed + fish.phaseOffset
        let yPhase = phase / (fish.speed * 0.7) + fish.phaseOffset

        // Horizontal: sin wave drift + slow cruise
        let cruise = CGFloat(time.truncatingRemainder(dividingBy: fish.speed * 12.0) / (fish.speed * 12.0))
        let dx = CGFloat(sin(xPhase)) * (size.width * 0.07)
        let cruiseOffset = cruise * size.width * 0.15 * (fish.flipped ? -1 : 1)

        // Vertical: gentle bob
        let dy = CGFloat(cos(yPhase)) * fish.amplitude

        // Depth parallax — back fish move slower
        let depthDampen = 1.0 - fish.depth * 0.3

        let baseX = fish.x * size.width
        let baseY = fish.y * size.height

        return CGPoint(
            x: baseX + (dx + cruiseOffset) * depthDampen,
            y: baseY + dy * depthDampen
        )
    }

    private func tailWagPhase(for fish: TankFish, time: Double) -> CGFloat {
        guard !reduceMotion else { return 0 }
        // Tail wags faster for smaller/faster fish
        let wagSpeed = 3.0 + (6.0 - fish.speed) * 0.8
        return CGFloat(sin(time * wagSpeed + fish.phaseOffset))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            NudgyHeadView(size: 52)
                .opacity(0.85)
            Text(String(localized: "Feed me to earn fish!"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
            Text(String(localized: "Complete tasks to catch fish 🎣"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.textTertiary)
        }
    }

    // MARK: - Glass Border + Surface Shine

    private var glassBorder: some View {
        ZStack {
            // Outer border — subtle aqua tint
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color(hex: "4FC3F7").opacity(0.08),
                            Color.white.opacity(0.04),
                            Color(hex: "4FC3F7").opacity(0.06),
                            Color.white.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
            // Inner glow
            RoundedRectangle(cornerRadius: 19)
                .strokeBorder(
                    Color.white.opacity(0.03),
                    lineWidth: 0.5
                )
                .padding(1)
        }
    }

    private func surfaceShine(width: CGFloat) -> some View {
        VStack {
            // Water surface band — subtle gradient glow at top
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color(hex: "4FC3F7").opacity(0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 6)
            .padding(.horizontal, 1)

            Spacer()
        }
    }

    // MARK: - Caustic Light Canvas (Diamond Mesh Network)

    private func causticCanvas(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let phase = time * 0.20

            // 1. Diamond mesh network on sand — connected light patterns
            let gridCols = 6
            let gridRows = 3
            let sandZoneTop = h * 0.68
            let sandZoneH = h * 0.28

            for row in 0..<gridRows {
                for col in 0..<gridCols {
                    let t = Double(row * gridCols + col)
                    // Base grid position with drift
                    let driftX = sin(phase * 0.9 + t * 1.7) * w * 0.04
                    let driftY = cos(phase * 0.7 + t * 1.3) * h * 0.02
                    let cx = w * (0.08 + CGFloat(col) * 0.16) + CGFloat(driftX)
                    let cy = sandZoneTop + sandZoneH * (CGFloat(row) + 0.5) / CGFloat(gridRows) + CGFloat(driftY)

                    // Diamond shape that morphs
                    let morph = sin(phase * 0.5 + t * 2.0)
                    let diamondW = w * CGFloat(0.06 + morph * 0.02)
                    let diamondH = h * CGFloat(0.04 + morph * 0.015)
                    let opacity = 0.04 + sin(phase * 0.6 + t * 2.5) * 0.02

                    var diamond = Path()
                    diamond.move(to: CGPoint(x: cx, y: cy - diamondH))
                    diamond.addLine(to: CGPoint(x: cx + diamondW, y: cy))
                    diamond.addLine(to: CGPoint(x: cx, y: cy + diamondH))
                    diamond.addLine(to: CGPoint(x: cx - diamondW, y: cy))
                    diamond.closeSubpath()
                    context.stroke(diamond, with: .color(Color.white.opacity(opacity)),
                                   style: StrokeStyle(lineWidth: 0.7, lineCap: .round, lineJoin: .round))
                    // Soft fill inside
                    context.fill(diamond, with: .color(Color.white.opacity(opacity * 0.3)))

                    // Connect to neighbor with a light line
                    if col < gridCols - 1 {
                        let nx = w * (0.08 + CGFloat(col + 1) * 0.16) +
                            CGFloat(sin(phase * 0.9 + Double(row * gridCols + col + 1) * 1.7) * Double(w) * 0.04)
                        let ny = sandZoneTop + sandZoneH * (CGFloat(row) + 0.5) / CGFloat(gridRows) +
                            CGFloat(cos(phase * 0.7 + Double(row * gridCols + col + 1) * 1.3) * Double(h) * 0.02)
                        var connector = Path()
                        connector.move(to: CGPoint(x: cx + diamondW, y: cy))
                        connector.addCurve(
                            to: CGPoint(x: nx - diamondW, y: ny),
                            control1: CGPoint(x: cx + diamondW + 10, y: cy - 3),
                            control2: CGPoint(x: nx - diamondW - 10, y: ny + 3)
                        )
                        context.stroke(connector, with: .color(Color.white.opacity(opacity * 0.4)),
                                       style: StrokeStyle(lineWidth: 0.4, lineCap: .round))
                    }
                }
            }

            // 2. Bright sparkle nodes at diamond intersections
            for i in 0..<16 {
                let t = Double(i) / 16.0
                let flicker = sin(phase * 2.5 + t * 9.0) * 0.5 + 0.5
                guard flicker > 0.35 else { continue }
                let x = w * CGFloat(0.06 + t * 0.88 + sin(phase * 0.8 + t * 5.0) * 0.04)
                let y = h * CGFloat(0.72 + sin(phase * 0.6 + t * 3.5) * 0.10)
                let r = CGFloat(1.2 + flicker * 1.5)
                var sparkle = Path()
                sparkle.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                context.fill(sparkle, with: .color(Color.white.opacity(0.05 * flicker)))
                // Cross glint for brighter sparkles
                if flicker > 0.7 {
                    var cross = Path()
                    cross.move(to: CGPoint(x: x - r * 1.5, y: y))
                    cross.addLine(to: CGPoint(x: x + r * 1.5, y: y))
                    cross.move(to: CGPoint(x: x, y: y - r * 1.5))
                    cross.addLine(to: CGPoint(x: x, y: y + r * 1.5))
                    context.stroke(cross, with: .color(Color.white.opacity(0.03 * flicker)),
                                   style: StrokeStyle(lineWidth: 0.4, lineCap: .round))
                }
            }

            // 3. Mid-water caustic web — flowing light network
            for i in 0..<8 {
                let t = Double(i) / 8.0
                let x = w * (0.10 + CGFloat(t) * 0.80)
                let y = h * (0.25 + CGFloat(sin(phase * 0.35 + t * 2.5)) * 0.18)
                let lineW = w * CGFloat(0.10 + sin(phase * 0.4 + t * 3.0) * 0.04)
                let opacity = 0.018 + sin(phase * 0.7 + t * 2.0) * 0.010
                guard opacity > 0.010 else { continue }

                var web = Path()
                web.move(to: CGPoint(x: x - lineW * 0.5, y: y))
                web.addCurve(
                    to: CGPoint(x: x + lineW * 0.5, y: y + 4),
                    control1: CGPoint(x: x - lineW * 0.1, y: y - 5),
                    control2: CGPoint(x: x + lineW * 0.1, y: y + 7)
                )
                context.stroke(
                    web,
                    with: .color(Color(hex: "B3E5FC").opacity(opacity)),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.screen)
    }

    // MARK: - Bubbles Canvas (3-Tier System)

    private func bubblesCanvas(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            for bubble in bubbles {
                let speed = bubble.speed
                let t = (time * speed + bubble.startOffset).truncatingRemainder(dividingBy: 1.0)
                let y = h * (1.0 - CGFloat(t))
                // Multi-frequency wobble for natural drift
                let wobble1 = sin(time * 2.0 + bubble.wobble) * 5.0
                let wobble2 = sin(time * 3.5 + bubble.wobble * 1.7) * 2.0
                let wobble3 = sin(time * 0.7 + bubble.wobble * 0.5) * 3.0
                let x = bubble.x * w + CGFloat(wobble1 + wobble2 + wobble3)
                let radius = bubble.radius

                // Fade lifecycle: grow in, peak, fade at surface
                let fadeIn = min(1.0, t * 5.0)
                let fadeOut = min(1.0, (1.0 - t) * 4.0)
                let lifecycle = fadeIn * fadeOut

                // Size grows slightly as bubble rises (pressure change)
                let sizeGrowth: CGFloat = 1.0 + CGFloat(t) * 0.25
                let r = radius * sizeGrowth

                let isMicro = radius < 1.8
                let isLarge = radius > 4.0
                let opacity = (isMicro ? 0.10 : isLarge ? 0.18 : 0.14) * lifecycle

                // Bubble body — glass-like radial gradient fill
                var circle = Path()
                circle.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))

                if isMicro {
                    // Micro bubbles — just tiny bright dots
                    context.fill(circle, with: .color(Color.white.opacity(opacity * 0.7)))
                } else {
                    // Medium + Large bubbles — glass effect
                    context.fill(circle, with: .color(Color.white.opacity(opacity * 0.15)))

                    // Rim stroke — varies by size
                    context.stroke(circle, with: .color(Color.white.opacity(opacity * 0.55)),
                                   style: StrokeStyle(lineWidth: isLarge ? 0.8 : 0.5))

                    // Main specular highlight — upper-left crescent
                    let gr = r * 0.40
                    var glint = Path()
                    glint.addEllipse(in: CGRect(
                        x: x - gr * 0.8,
                        y: y - r * 0.70,
                        width: gr,
                        height: gr * 0.55
                    ))
                    context.fill(glint, with: .color(Color.white.opacity(opacity * 0.9)))

                    // Secondary specular — small dot lower-right
                    var glint2 = Path()
                    let g2r = r * 0.15
                    glint2.addEllipse(in: CGRect(
                        x: x + r * 0.25,
                        y: y + r * 0.20,
                        width: g2r,
                        height: g2r
                    ))
                    context.fill(glint2, with: .color(Color.white.opacity(opacity * 0.5)))

                    // Large bubbles — rainbow iridescence shimmer
                    if isLarge {
                        let iridescentPhase = sin(time * 2.5 + bubble.wobble) * 0.5 + 0.5
                        let iColor = iridescentPhase > 0.6
                            ? Color(hex: "E1BEE7") // lavender
                            : iridescentPhase > 0.3
                                ? Color(hex: "B3E5FC") // cyan
                                : Color(hex: "C8E6C9") // mint
                        var irisArc = Path()
                        irisArc.addEllipse(in: CGRect(
                            x: x - r * 0.6,
                            y: y - r * 0.4,
                            width: r * 1.2,
                            height: r * 0.5
                        ))
                        context.fill(irisArc, with: .color(iColor.opacity(0.05 * lifecycle)))

                        // Internal refraction dot
                        var refract = Path()
                        let rx = x + sin(time * 1.5 + bubble.wobble) * r * 0.2
                        let ry = y + cos(time * 1.2 + bubble.wobble) * r * 0.2
                        refract.addEllipse(in: CGRect(x: rx - 1, y: ry - 1, width: 2, height: 2))
                        context.fill(refract, with: .color(Color.white.opacity(0.04 * lifecycle)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Spawn

    private func spawnFish() {
        tankFish = colonyFish.enumerated().map { index, catchItem in
            let cols = min(colonyFish.count, 4)
            let row = index / cols
            let col = index % cols

            let baseX = 0.12 + (0.76 / Double(cols)) * (Double(col) + 0.5)
            let baseY = 0.25 + Double(row) * 0.18
            let jitterX = Double.random(in: -0.06...0.06)
            let jitterY = Double.random(in: -0.04...0.04)

            let catchCount = rewardService.catchCountsPerSpecies[catchItem.species.rawValue] ?? 1
            let stage = FishEvolutionStage.stage(for: catchItem.species, catchCount: catchCount)

            return TankFish(
                id: catchItem.id,
                catchData: catchItem,
                x: CGFloat(baseX + jitterX),
                y: CGFloat(min(max(baseY + jitterY, 0.18), 0.68)),
                speed: catchItem.species.evolvedSwimSpeed(for: stage) + Double.random(in: -0.5...0.5),
                amplitude: CGFloat.random(in: 5...12),
                flipped: Bool.random(),
                phaseOffset: Double.random(in: 0...(.pi * 2)),
                depth: CGFloat.random(in: 0...1),
                evolutionStage: stage
            )
        }
    }

    private func spawnBubbles() {
        var all: [BubbleParticle] = []

        // Micro bubbles (10) — tiny, fast, clustered near seaweed positions
        let seaweedXPositions: [CGFloat] = [0.04, 0.17, 0.30, 0.43, 0.56, 0.69, 0.82, 0.95]
        for i in 0..<10 {
            let nearWeed = seaweedXPositions[i % seaweedXPositions.count]
            all.append(BubbleParticle(
                x: nearWeed + CGFloat.random(in: -0.03...0.03),
                radius: CGFloat.random(in: 0.6...1.5),
                speed: Double.random(in: 0.04...0.10),
                startOffset: Double.random(in: 0...1),
                wobble: Double.random(in: 0...(.pi * 2))
            ))
        }

        // Medium bubbles (8) — standard, distributed
        for _ in 0..<8 {
            all.append(BubbleParticle(
                x: CGFloat.random(in: 0.08...0.92),
                radius: CGFloat.random(in: 2.0...3.8),
                speed: Double.random(in: 0.03...0.07),
                startOffset: Double.random(in: 0...1),
                wobble: Double.random(in: 0...(.pi * 2))
            ))
        }

        // Large bubbles (3) — rare, slow-rising, dramatic
        for _ in 0..<3 {
            all.append(BubbleParticle(
                x: CGFloat.random(in: 0.15...0.85),
                radius: CGFloat.random(in: 4.5...7.0),
                speed: Double.random(in: 0.015...0.035),
                startOffset: Double.random(in: 0...1),
                wobble: Double.random(in: 0...(.pi * 2))
            ))
        }

        bubbles = all
    }

    private func spawnSeaweed() {
        let colors: [Color] = [
            Color(hex: "1B5E20"),
            Color(hex: "2E7D32"),
            Color(hex: "388E3C"),
            Color(hex: "4CAF50"),
            Color(hex: "1B5E20"),
            Color(hex: "33691E"),
            Color(hex: "558B2F"),
        ]
        // More seaweed patches spread across the tank floor
        seaweeds = (0..<8).map { i in
            SeaweedPatch(
                x: 0.04 + CGFloat(i) * 0.13 + CGFloat.random(in: -0.04...0.04),
                height: CGFloat.random(in: 0.12...0.32),
                bladeCount: Int.random(in: 2...5),
                color: colors[i % colors.count],
                phaseOffset: Double.random(in: 0...(.pi * 2))
            )
        }
    }

    // MARK: - Tap Handling

    private func handleWaterTap(at point: CGPoint) {
        // Dismiss inspect card if open
        if inspectedFish != nil {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                inspectedFish = nil
            }
            return
        }

        let ripple = Ripple(point: point)
        ripples.append(ripple)

        withAnimation(.easeOut(duration: 0.8)) {
            if let idx = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[idx].scale = 3.0
                ripples[idx].opacity = 0
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            ripples.removeAll { $0.id == ripple.id }
        }

        scatterFish()
    }

    private func scatterFish() {
        guard !isScattered else { return }
        isScattered = true

        for i in tankFish.indices {
            tankFish[i].isScattering = true
            let scatterX = CGFloat.random(in: -30...30)
            let scatterY = CGFloat.random(in: -20...20)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                tankFish[i].scatterOffset = CGSize(width: scatterX, height: scatterY)
            }
        }

        // Flip some fish on scatter
        for i in tankFish.indices {
            if Bool.random() {
                tankFish[i].flipped.toggle()
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            for i in tankFish.indices {
                tankFish[i].isScattering = false
                withAnimation(.easeInOut(duration: 1.5)) {
                    tankFish[i].scatterOffset = .zero
                }
            }
            try? await Task.sleep(for: .seconds(1.5))
            isScattered = false
        }
    }

    // MARK: - Fish Inspect Card

    /// Slide-up species card — rendered outside drawingGroup, no emojis, full design system.
    @ViewBuilder
    private func fishInspectCard(for fishCatch: FishCatch) -> some View {
        let species = fishCatch.species

        VStack(spacing: 0) {
            // Pull handle
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 32, height: 3)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Species header row: fish glow icon · name + description · fish value
            HStack(spacing: DesignTokens.spacingMD) {
// Fish rendering with depth glow + gentle idle swim animation
            ZStack {
                Circle()
                    .fill(species.fishColor.opacity(0.13))
                    .frame(width: 66, height: 66)
                    .blur(radius: 10)
                Circle()
                    .strokeBorder(species.fishColor.opacity(0.25), lineWidth: 1)
                    .frame(width: 58, height: 58)
                FishView(
                    size: 36,
                    color: species.fishColor,
                    accentColor: species.fishAccentColor
                )
                .phaseAnimator([false, true]) { fish, phase in
                    fish.offset(x: phase ? 2.5 : -2.5, y: phase ? 1.5 : -0.5)
                } animation: { _ in .easeInOut(duration: 1.3) }
            }
            .shadow(color: species.fishColor.opacity(0.35), radius: 14)

                VStack(alignment: .leading, spacing: 4) {
                    Text(species.label)
                        .font(AppTheme.headline)
                        .foregroundStyle(species.fishColor)
                    Text(species.description)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }

                Spacer()

                // Right column: fish value + total catches of this species
                VStack(spacing: 5) {
                    HStack(spacing: 3) {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignTokens.fishTint)
                        Text("+\(species.fishValue)")
                            .font(AppTheme.captionBold)
                            .foregroundStyle(DesignTokens.textPrimary)
                    }
                    .padding(.horizontal, DesignTokens.spacingSM)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                                    .strokeBorder(DesignTokens.fishTint.opacity(0.18), lineWidth: 0.5)
                            )
                    )
                    let totalCaught = catches.filter { $0.species == species }.count
                    if totalCaught > 1 {
                        Text(String(localized: "\(totalCaught)× caught"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(species.fishColor.opacity(0.85))
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)

            // Species-tinted hairline divider
            LinearGradient(
                colors: [species.fishColor.opacity(0.22), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingMD)

            // Task that earned this fish
            HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.accentComplete.opacity(0.65))
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Earned by completing"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(fishCatch.taskContent)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)

            // Relative date footer
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)
                Text(fishCatch.caughtAt.formatted(.relative(presentation: .named)))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.top, DesignTokens.spacingSM)
            .padding(.bottom, DesignTokens.spacingLG)
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignTokens.cardSurface.opacity(0.96))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [species.fishColor.opacity(0.50), species.fishColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: Color.black.opacity(0.55), radius: 28, y: -6)
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                inspectedFish = nil
            }
        }
        .nudgeAccessibility(
            label: String(localized: "\(species.label). Earned by completing: \(fishCatch.taskContent)"),
            hint: String(localized: "Tap to dismiss"),
            traits: .isButton
        )
    }

    // MARK: - Feed Mechanic

    private var foodParticlesLayer: some View {
        ForEach(foodParticles) { particle in
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFD54F"), Color(hex: "FF7043")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: particle.size, height: particle.size * 0.55)
                .rotationEffect(.degrees(particle.rotation))
                .overlay(
                    Capsule()
                        .strokeBorder(Color(hex: "FFB74D").opacity(0.35), lineWidth: 0.5)
                )
                .shadow(color: Color(hex: "FFB74D").opacity(0.45), radius: 2.5)
                .position(x: particle.x, y: particle.y)
                .opacity(particle.opacity)
        }
    }

    // MARK: - Integrated Stats Overlay

    private var tankOverlayButtons: some View {
        VStack(spacing: 0) {
            // Top bar: streak + fish balance + happiness + decor button
            topStatsBar

            Spacer()

            // Bottom bar: species collection + feed indicator
            bottomStatsBar
        }
    }

    /// Top strip: day streak, fish balance, happiness hearts, decoration shop button
    private var topStatsBar: some View {
        let happiness = rewardService.fishHappiness
        let taskStreak = rewardService.currentStreak

        return HStack(spacing: 6) {
            // Day streak
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(
                        taskStreak >= 7
                            ? Color(hex: "FF6B35")
                            : taskStreak >= 3
                                ? Color(hex: "FFB74D")
                                : DesignTokens.textTertiary
                    )
                Text("\(taskStreak)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignTokens.textPrimary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.50)))

            // Fish balance
            HStack(spacing: 3) {
                Image(systemName: "fish.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: "4FC3F7"))
                Text("\(rewardService.fish)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignTokens.textPrimary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.50)))

            // Fish feeding status — dot progress shows feeds used today
            let fedToday = rewardService.fishFedToday
            if fedToday > 0 || happiness < 0.35 {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < fedToday ? Color(hex: "4FC3F7") : Color.white.opacity(0.18))
                            .frame(width: 5, height: 5)
                    }
                    Text(String(localized: "Fed \(fedToday)/3"))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(fedToday >= 3 ? Color(hex: "4FC3F7") : DesignTokens.textTertiary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.50)))
            }

            Spacer()

            // Level badge
            Text(String(localized: "Lv.\(rewardService.level)"))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "FFD54F"))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.50)))

            // Decor shop button
            Button {
                showDecorationShop = true
                HapticService.shared.actionButtonTap()
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "4FC3F7"))
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.50)))
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Decoration shop"),
                hint: String(localized: "Buy and place tank decorations"),
                traits: .isButton
            )
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    /// Bottom strip: species collection bar + lifetime catch progress + feed indicator
    private var bottomStatsBar: some View {
        let totalCatches = rewardService.catchCountsPerSpecies.values.reduce(0, +)
        let progress = totalCatches > 0 ? Double(totalCatches % 50) / 50.0 : 0.0

        return VStack(spacing: 0) {
            // Species mini-bar — lifetime catch count per species
            HStack(spacing: 0) {
                ForEach(FishSpecies.allCases, id: \.self) { species in
                    let count = rewardService.catchCountsPerSpecies[species.rawValue] ?? 0
                    HStack(spacing: 3) {
                        FishView(
                            size: 14,
                            color: species.fishColor,
                            accentColor: species.fishAccentColor
                        )
                        .opacity(count > 0 ? 1 : 0.3)
                        Text("\(count)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(count > 0 ? DesignTokens.textPrimary : DesignTokens.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Feed indicator (rightmost)
                if feedsAvailable > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 8))
                        Text(feedsAvailable == 1
                            ? String(localized: "1 feed — swipe ↓")
                            : String(localized: "\(feedsAvailable) feeds — swipe ↓"))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "FFB74D"))
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.45))
            )

            // Weekly progress bar (very bottom edge)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4FC3F7"), Color(hex: "00B8D4")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 3)
        }
    }

    /// Happiness indicator — shows a "feed your fish" nudge when happiness < 0.35.
    @ViewBuilder
    private var happinessIndicator: some View {
        let happiness = rewardService.fishHappiness
        if happiness < 0.35 && !colonyFish.isEmpty {
            VStack {
                Spacer()
                VStack(spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "4FC3F7"))
                        Text(String(localized: "Swipe down to feed"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(DesignTokens.textPrimary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "FFB74D"))
                        .offset(y: feedHintBounce ? 3 : 0)
                        .animation(
                            .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                            value: feedHintBounce
                        )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.68))
                        .overlay(Capsule().strokeBorder(Color(hex: "FF6B6B").opacity(0.45), lineWidth: 1))
                )
                .padding(.bottom, 46)
                .allowsHitTesting(false)
                .onAppear { feedHintBounce = true }
            }
        }
    }

    // MARK: - Feed Bonus Toast

    private var feedBonusToast: some View {
        VStack {
            if let text = feedBonusText {
                Text(text)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: "4FC3F7").opacity(0.6), radius: 8)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "4FC3F7").opacity(0.90),
                                        Color(hex: "0288D1").opacity(0.90)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(hex: "4FC3F7").opacity(0.40), radius: 16, y: 4)
                    )
                    .opacity(feedBonusOpacity)
                    .scaleEffect(feedBonusOpacity > 0 ? 1.0 : 0.72)
                    .offset(y: feedBonusOpacity > 0 ? 0 : 8)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 44)
        .allowsHitTesting(false)
    }

    // MARK: - Decoration Layer

    private func decorationLayer(size: CGSize) -> some View {
        ForEach(TankDecoration.allCases) { deco in
            if rewardService.placedDecorations.contains(deco.rawValue) {
                TankDecorationView(decoration: deco, size: deco.decoSize)
                    .position(
                        x: deco.tankX * size.width,
                        y: size.height - deco.decoSize * 0.5 - size.height * 0.06
                    )
            }
        }
    }

    private func dropFood(at location: CGPoint) {
        guard feedsAvailable > 0 else { return }
        feedsAvailable -= 1
        HapticService.shared.actionButtonTap()

        // Persist the feeding via RewardService
        let bonus = rewardService.recordFeeding(context: modelContext)

        // Show bonus toast if fish earned
        if bonus > 0 {
            feedBonusText = "+\(bonus) ❄️"
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                feedBonusOpacity = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeOut(duration: 0.5)) {
                    feedBonusOpacity = 0
                }
                try? await Task.sleep(for: .seconds(0.6))
                feedBonusText = nil
            }
            HapticService.shared.swipeDone()
        }

        // Ripple at the water surface where food enters
        let surfaceY = tankSize.height * 0.07
        addRipple(at: CGPoint(x: location.x, y: surfaceY))

        // Fan 8 pellets from the water surface in a spread pattern
        let centerX = max(40, min(tankSize.width - 40, location.x))
        let newParticles = (0..<8).map { _ in
            FoodParticle(
                x: centerX + CGFloat.random(in: -40...40),
                y: surfaceY + CGFloat.random(in: 2...10),
                vx: CGFloat.random(in: -0.7...0.7),
                rotation: Double.random(in: 0...360),
                size: CGFloat.random(in: 4.5...7.5)
            )
        }
        foodParticles.append(contentsOf: newParticles)
        startFoodPhysics(particleIDs: newParticles.map { $0.id })
    }

    private func startFoodPhysics(particleIDs: [UUID]) {
        Task { @MainActor in
            for _ in 0..<60 {
                try? await Task.sleep(for: .seconds(1.0 / 30.0))
                guard !Task.isCancelled else { break }

                for i in foodParticles.indices {
                    guard particleIDs.contains(foodParticles[i].id),
                          !foodParticles[i].consumed else { continue }

                    foodParticles[i].vy += 0.15
                    foodParticles[i].y += foodParticles[i].vy
                    foodParticles[i].x += foodParticles[i].vx
                    foodParticles[i].vx *= 0.94  // gradual horizontal deceleration
                    foodParticles[i].rotation += Double(foodParticles[i].vx) * 9

                    for fi in tankFish.indices {
                        let fishPos = CGPoint(
                            x: tankFish[fi].x * height * 1.5,
                            y: tankFish[fi].y * height
                        )
                        let dist = hypot(
                            foodParticles[i].x - fishPos.x,
                            foodParticles[i].y - fishPos.y
                        )
                        if dist < 25 {
                            foodParticles[i].consumed = true
                            withAnimation(.easeOut(duration: 0.2)) {
                                foodParticles[i].opacity = 0
                            }
                            let burstX = foodParticles[i].x
                            let burstY = foodParticles[i].y
                            addRipple(at: CGPoint(x: burstX, y: burstY))
                            break
                        }
                    }
                }
            }

            withAnimation(.easeOut(duration: 0.3)) {
                for i in foodParticles.indices where particleIDs.contains(foodParticles[i].id) {
                    foodParticles[i].opacity = 0
                }
            }
            try? await Task.sleep(for: .seconds(0.4))
            foodParticles.removeAll { particleIDs.contains($0.id) }
        }
    }

    private func addRipple(at point: CGPoint) {
        let ripple = Ripple(point: point)
        ripples.append(ripple)
        withAnimation(.easeOut(duration: 0.6)) {
            if let idx = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[idx].scale = 2.0
                ripples[idx].opacity = 0
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            ripples.removeAll { $0.id == ripple.id }
        }
    }

    // MARK: - Spawn Jellyfish

    private func spawnJellyfish() {
        let palette: [(Color, Double)] = [
            (Color(hex: "CE93D8"), 0.28),  // lavender
            (Color(hex: "80DEEA"), 0.33),  // cyan
            (Color(hex: "B39DDB"), 0.22),  // soft purple
        ]
        jellyfish = (0..<2).map { i in
            let (color, speed) = palette[i % palette.count]
            return Jellyfish(
                x: CGFloat(0.20 + Double(i) * 0.55 + Double.random(in: -0.06...0.06)),
                y: CGFloat(0.20 + Double.random(in: 0...0.18)),
                phaseOffset: Double.random(in: 0...(.pi * 2)),
                size: CGFloat(20 + Double.random(in: -3...7)),
                color: color,
                driftSpeed: speed + Double.random(in: -0.05...0.05)
            )
        }
    }

    // MARK: - Coral Layer

    private func coralLayer(size: CGSize, time: Double) -> some View {
        AnyView(
            ZStack {
                fanCoralCanvas(time: time)
                brainCoralCanvas()
                tubeCoralCanvas(time: time)
                branchingCoralCanvas(time: time)
            }
            .allowsHitTesting(false)
        )
    }

    private func fanCoralCanvas(time: Double) -> some View {
        Canvas { ctx, sz in
            let sandLine = sz.height * 0.73
            let fc1X = sz.width * 0.09
            let fc1H = sz.height * 0.115
            for branch in 0..<5 {
                let angle = Double(branch - 2) * 18.0
                let sway = sin(time * 0.38 + Double(branch) * 0.8) * 2.8
                let rad = (angle + sway) * .pi / 180.0
                let tipX = fc1X + CGFloat(sin(rad)) * fc1H * 0.55
                let tipY = sandLine - CGFloat(cos(rad)) * fc1H
                var bp = Path()
                bp.move(to: CGPoint(x: fc1X, y: sandLine))
                bp.addCurve(to: CGPoint(x: tipX, y: tipY),
                            control1: CGPoint(x: fc1X + CGFloat(sin(rad)) * fc1H * 0.20, y: sandLine - fc1H * 0.30),
                            control2: CGPoint(x: tipX - CGFloat(sin(rad)) * fc1H * 0.08, y: tipY + fc1H * 0.22))
                let op = 0.55 - abs(Double(branch) - 2.0) * 0.07
                ctx.stroke(bp, with: .color(Color(hex: "FF7043").opacity(op)),
                           style: StrokeStyle(lineWidth: CGFloat(2.4 - abs(Double(branch) - 2.0) * 0.35), lineCap: .round))
                for sub in 0..<2 {
                    let subT = CGFloat(sub + 1) / 3.0
                    let smX = fc1X + (tipX - fc1X) * subT
                    let smY = sandLine + (tipY - sandLine) * subT
                    let subRad = rad + Double(sub == 0 ? 1 : -1) * 0.45
                    let subLen = fc1H * 0.18
                    var sp = Path()
                    sp.move(to: CGPoint(x: smX, y: smY))
                    sp.addLine(to: CGPoint(x: smX + CGFloat(sin(subRad)) * subLen, y: smY - CGFloat(cos(subRad)) * subLen))
                    ctx.stroke(sp, with: .color(Color(hex: "FF7043").opacity(op * 0.55)),
                               style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
                }
            }
        }
    }

    private func brainCoralCanvas() -> some View {
        Canvas { ctx, sz in
            let sandLine = sz.height * 0.73
            let bcX = sz.width * 0.37
            let bcR = sz.width * 0.037
            let bcY = sandLine - bcR * 0.75
            var brain = Path()
            brain.addEllipse(in: CGRect(x: bcX - bcR, y: bcY - bcR * 0.55, width: bcR * 2, height: bcR * 1.25))
            ctx.fill(brain, with: .color(Color(hex: "D4956A").opacity(0.50)))
            ctx.stroke(brain, with: .color(Color(hex: "C68642").opacity(0.35)), style: StrokeStyle(lineWidth: 0.7))
            for groove in 0..<4 {
                let gy = bcY - bcR * 0.28 + CGFloat(groove) * bcR * 0.24
                var gp = Path()
                gp.move(to: CGPoint(x: bcX - bcR * 0.65, y: gy))
                gp.addCurve(to: CGPoint(x: bcX + bcR * 0.65, y: gy),
                            control1: CGPoint(x: bcX - bcR * 0.25, y: gy - bcR * 0.10),
                            control2: CGPoint(x: bcX + bcR * 0.25, y: gy + bcR * 0.10))
                ctx.stroke(gp, with: .color(Color(hex: "A0522D").opacity(0.18)),
                           style: StrokeStyle(lineWidth: 0.45, lineCap: .round))
            }
        }
    }

    private func tubeCoralCanvas(time: Double) -> some View {
        Canvas { ctx, sz in
            let sandLine = sz.height * 0.73
            let tcX = sz.width * 0.64
            let tubeCounts = [4, 3, 5]
            for clusterI in 0..<3 {
                let clusterX = tcX + CGFloat(clusterI - 1) * 13
                let count = tubeCounts[clusterI]
                for t in 0..<count {
                    let tubeX = clusterX + CGFloat(t - count / 2) * 6.5
                    let tubeH = sz.height * CGFloat(0.052 + sin(Double(t) * 1.4 + Double(clusterI) * 2.1) * 0.016)
                    let sway = CGFloat(sin(time * 0.55 + Double(t) * 1.1 + Double(clusterI) * 2.0) * 1.3)
                    var tube = Path()
                    tube.move(to: CGPoint(x: tubeX - 2.3, y: sandLine))
                    tube.addLine(to: CGPoint(x: tubeX - 1.8 + sway, y: sandLine - tubeH))
                    tube.addLine(to: CGPoint(x: tubeX + 1.8 + sway, y: sandLine - tubeH))
                    tube.addLine(to: CGPoint(x: tubeX + 2.3, y: sandLine))
                    tube.closeSubpath()
                    ctx.fill(tube, with: .linearGradient(
                        Gradient(stops: [
                            .init(color: Color(hex: "9C27B0").opacity(0.22), location: 0),
                            .init(color: Color(hex: "CE93D8").opacity(0.48), location: 0.7),
                            .init(color: Color(hex: "E1BEE7").opacity(0.60), location: 1.0)
                        ]),
                        startPoint: CGPoint(x: tubeX, y: sandLine),
                        endPoint: CGPoint(x: tubeX + sway, y: sandLine - tubeH)))
                    var opening = Path()
                    opening.addEllipse(in: CGRect(x: tubeX - 2.0 + sway, y: sandLine - tubeH - 1.8, width: 4.0, height: 2.8))
                    ctx.fill(opening, with: .color(Color.white.opacity(0.10)))
                    ctx.stroke(opening, with: .color(Color(hex: "CE93D8").opacity(0.45)),
                               style: StrokeStyle(lineWidth: 0.4))
                }
            }
        }
    }

    private func branchingCoralCanvas(time: Double) -> some View {
        Canvas { ctx, sz in
            let sandLine = sz.height * 0.73
            let fc2X = sz.width * 0.87
            let fc2H = sz.height * 0.098
            for branch in 0..<4 {
                let angle = (Double(branch) - 1.5) * 20.0
                let sway = sin(time * 0.32 + Double(branch) * 1.2) * 3.0
                let rad = (angle + sway) * .pi / 180.0
                let tipX = fc2X + CGFloat(sin(rad)) * fc2H * 0.52
                let tipY = sandLine - CGFloat(cos(rad)) * fc2H
                var b = Path()
                b.move(to: CGPoint(x: fc2X, y: sandLine))
                b.addCurve(to: CGPoint(x: tipX, y: tipY),
                           control1: CGPoint(x: fc2X + CGFloat(sin(rad)) * fc2H * 0.14, y: sandLine - fc2H * 0.28),
                           control2: CGPoint(x: tipX - CGFloat(sin(rad)) * 4, y: tipY + fc2H * 0.20))
                ctx.stroke(b, with: .color(Color(hex: "F06292").opacity(0.50 - abs(Double(branch) - 1.5) * 0.06)),
                           style: StrokeStyle(lineWidth: CGFloat(2.1 - abs(Double(branch) - 1.5) * 0.28), lineCap: .round))
            }
        }
    }

    // MARK: - Jellyfish Layer

    /// 2 translucent jellyfish that slowly pulse and drift mid-water.
    private func jellyfishLayer(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            for jelly in jellyfish {
                // Slow vertical bob + gentle horizontal drift
                let vDrift = CGFloat(sin(time * jelly.driftSpeed + jelly.phaseOffset)) * h * 0.07
                let hDrift = CGFloat(cos(time * jelly.driftSpeed * 0.4 + jelly.phaseOffset + 1.0)) * w * 0.04
                let cx = jelly.x * w + hDrift
                let cy = jelly.y * h + vDrift

                // Bell pulsing (contracts/expands like a real jellyfish)
                let pulse = CGFloat(sin(time * 1.3 + jelly.phaseOffset)) // -1…1
                let bellW = jelly.size * (0.90 + pulse * 0.10)
                let bellH = bellW * (0.52 + pulse * 0.06)

                // --- Bell dome ---
                var dome = Path()
                dome.move(to: CGPoint(x: cx - bellW * 0.5, y: cy))
                dome.addCurve(
                    to: CGPoint(x: cx + bellW * 0.5, y: cy),
                    control1: CGPoint(x: cx - bellW * 0.5, y: cy - bellH * 2.1),
                    control2: CGPoint(x: cx + bellW * 0.5, y: cy - bellH * 2.1)
                )
                dome.closeSubpath()

                context.fill(dome, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: jelly.color.opacity(0.55), location: 0.0),
                        .init(color: jelly.color.opacity(0.28), location: 0.55),
                        .init(color: jelly.color.opacity(0.08), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: cx, y: cy - bellH * 2.1),
                    endPoint: CGPoint(x: cx, y: cy)
                ))
                context.stroke(dome, with: .color(jelly.color.opacity(0.75)),
                               style: StrokeStyle(lineWidth: 0.7, lineCap: .round))

                // Ribs inside the bell
                for rib in 0..<3 {
                    let rt = CGFloat(rib + 1) / 4.0
                    var ribPath = Path()
                    ribPath.move(to: CGPoint(x: cx - bellW * 0.5 * rt, y: cy))
                    ribPath.addCurve(
                        to: CGPoint(x: cx + bellW * 0.5 * rt, y: cy),
                        control1: CGPoint(x: cx - bellW * 0.5 * rt, y: cy - bellH * 2.1 * rt),
                        control2: CGPoint(x: cx + bellW * 0.5 * rt, y: cy - bellH * 2.1 * rt)
                    )
                    context.stroke(ribPath, with: .color(jelly.color.opacity(0.10)),
                                   style: StrokeStyle(lineWidth: 0.4))
                }

                // Bioluminescent core glow
                var core = Path()
                core.addEllipse(in: CGRect(x: cx - bellW * 0.12, y: cy - bellH * 1.30,
                                           width: bellW * 0.24, height: bellH * 0.48))
                context.fill(core, with: .color(Color.white.opacity(0.13)))

                // Velum fringe at bell opening
                let velumCount = 8
                for v in 0..<velumCount {
                    let vt = CGFloat(v) / CGFloat(velumCount)
                    let vx = cx - bellW * 0.48 + vt * bellW * 0.96
                    let vLen = bellH * 0.38
                    let vSway = CGFloat(sin(time * 2.2 + jelly.phaseOffset + Double(v) * 0.75)) * 2.2
                    var velum = Path()
                    velum.move(to: CGPoint(x: vx, y: cy))
                    velum.addCurve(
                        to: CGPoint(x: vx + vSway, y: cy + vLen),
                        control1: CGPoint(x: vx + vSway * 0.3, y: cy + vLen * 0.45),
                        control2: CGPoint(x: vx + vSway * 0.75, y: cy + vLen * 0.80)
                    )
                    context.stroke(velum, with: .color(jelly.color.opacity(0.32)),
                                   style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
                }

                // Long trailing tentacles
                let tentacleCount = 5
                for t in 0..<tentacleCount {
                    let tt = CGFloat(t) / CGFloat(tentacleCount - 1)
                    let tx = cx - bellW * 0.38 + tt * bellW * 0.76
                    let tLen = bellW * CGFloat(1.15 + Double(t % 2) * 0.55)
                    let sway1 = CGFloat(sin(time * 0.55 + jelly.phaseOffset + Double(t) * 1.25)) * 5.0
                    let sway2 = CGFloat(cos(time * 0.85 + jelly.phaseOffset + Double(t) * 0.90)) * 2.8
                    var tentacle = Path()
                    tentacle.move(to: CGPoint(x: tx, y: cy))
                    tentacle.addCurve(
                        to: CGPoint(x: tx + sway1, y: cy + tLen * 0.5),
                        control1: CGPoint(x: tx + sway1 * 0.18, y: cy + tLen * 0.18),
                        control2: CGPoint(x: tx + sway1 * 0.72, y: cy + tLen * 0.34)
                    )
                    tentacle.addCurve(
                        to: CGPoint(x: tx + sway1 + sway2, y: cy + tLen),
                        control1: CGPoint(x: tx + sway1 + sway2 * 0.22, y: cy + tLen * 0.64),
                        control2: CGPoint(x: tx + sway1 + sway2 * 0.80, y: cy + tLen * 0.84)
                    )
                    context.stroke(tentacle, with: .color(jelly.color.opacity(0.22)),
                                   style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
                }
            }
        }
        .allowsHitTesting(false)
        .blendMode(.screen)
    }
}

// MARK: - Preview

#Preview("Aquarium Tank") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            AquariumTankView(
                catches: [
                    FishCatch(species: .catfish, taskContent: "Reply to emails", taskEmoji: "📧"),
                    FishCatch(species: .tropical, taskContent: "Clean the kitchen", taskEmoji: "🧹"),
                    FishCatch(species: .swordfish, taskContent: "Finish report", taskEmoji: "📄"),
                    FishCatch(species: .catfish, taskContent: "Buy groceries", taskEmoji: "🛒"),
                    FishCatch(species: .tropical, taskContent: "Call mom", taskEmoji: "📞"),
                    FishCatch(species: .whale, taskContent: "Ship feature", taskEmoji: "🚀"),
                ],
                level: 3,
                streak: 5
            )
            .padding(.horizontal)

            AquariumTankView(
                catches: [],
                level: 1,
                streak: 0,
                height: 160
            )
            .padding(.horizontal)
        }
    }
}
