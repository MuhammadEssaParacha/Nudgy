//
//  AntarcticEnvironment.swift
//  Nudge
//
//  Nudgy's Antarctic home world — "Dreamworks Diorama" style.
//
//  A cinematic, painterly environment inspired by Dreamworks/Pixar background art.
//  Bold mountain silhouettes, volumetric light, atmospheric haze, and a warm
//  storybook feel that reacts to time-of-day and productivity mood.
//
//  Visual layers (back → front):
//    0. Sky gradient (rich, multi-stop, time-driven)
//    1. Celestial bodies (stars, Southern Cross, moon, sun, shooting stars)
//    2. Aurora borealis (night — luminous curtain effect)
//    3. Far mountain range + cloud shadows + fog wisps
//    4. Atmospheric haze band
//    5. Mid mountain range + inter-layer fog
//    6. Volumetric light beams (dawn/dusk god-rays through peaks)
//    7. Cloud bank (bold, fluffy, lit from below)
//    8. Near mountain range (detailed, dramatic, closest)
//    8a. Dark ocean with ice floes
//    9. Ice shelf reflection + platform + footprints + warm light wash
//   10. Cliff props (fish bucket, flag, lantern)
//   11. Stage decorations + wind-blown snow
//   12. Ice crystal sparkles (floating diamonds)
//   13. Snow particles (code-driven)
//   14. Storm overlay (stormy mood)
//
//  Parallax: All layers offset by device tilt via CoreMotion accelerometer.
//  Far layers move barely; near layers move significantly — diorama effect.
//

import SwiftUI
import CoreMotion
import Combine

// MARK: - Time of Day

/// Determines the visual theme for the Antarctic scene based on the current hour.
enum AntarcticTimeOfDay: CaseIterable, Equatable {
    case dawn   // 6am – 10am
    case day    // 10am – 5pm
    case dusk   // 5pm – 8pm
    case night  // 8pm – 6am

    /// Explicit nonisolated == so it can be used in timer/background contexts.
    /// (Synthesised conformance would be @MainActor due to Color properties.)
    nonisolated static func == (lhs: AntarcticTimeOfDay, rhs: AntarcticTimeOfDay) -> Bool {
        switch (lhs, rhs) {
        case (.dawn, .dawn), (.day, .day), (.dusk, .dusk), (.night, .night): return true
        default: return false
        }
    }

    /// Determine from the current device time.
    static var current: AntarcticTimeOfDay {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 6..<10:  return .dawn
        case 10..<17: return .day
        case 17..<20: return .dusk
        default:      return .night
        }
    }

    // MARK: Sky Gradients — Rich multi-stop for cinematic depth

    var skyColors: [Color] {
        switch self {
        case .dawn:
            return [
                Color(hex: "0D0620"),   // Deep cosmic indigo (top)
                Color(hex: "1A0A2E"),   // Rich violet
                Color(hex: "3D1A54"),   // Purple haze
                Color(hex: "7A3068"),   // Warm mauve
                Color(hex: "B8506A"),   // Rose transition
                Color(hex: "D4785A"),   // Warm peach
                Color(hex: "F2A65A"),   // Golden glow
                Color(hex: "FFD4A0"),   // Pale gold horizon
                Color(hex: "FFECD0"),   // Creamy horizon line
            ]
        case .day:
            return [
                Color(hex: "06101E"),   // Deep space (top)
                Color(hex: "0E2240"),   // Rich navy
                Color(hex: "1B3A5C"),   // Ocean blue
                Color(hex: "2E6B9E"),   // Cerulean
                Color(hex: "4A9AC7"),   // Sky blue
                Color(hex: "6BB4D8"),   // Bright sky
                Color(hex: "8ECAE6"),   // Pale blue
                Color(hex: "B8DCF0"),   // Near-white horizon
                Color(hex: "D8ECF8"),   // Horizon glow
            ]
        case .dusk:
            return [
                Color(hex: "08081E"),   // Deep midnight (top)
                Color(hex: "1A1040"),   // Rich indigo
                Color(hex: "2B1B4E"),   // Purple
                Color(hex: "4A2558"),   // Violet transition
                Color(hex: "6A3558"),   // Warm violet
                Color(hex: "8B4A5C"),   // Mauve
                Color(hex: "CC6B3A"),   // Amber blaze
                Color(hex: "E89040"),   // Orange fire
                Color(hex: "F0A850"),   // Golden horizon
            ]
        case .night:
            return [
                Color(hex: "010408"),   // Near-black void (top)
                Color(hex: "030A14"),   // Deep abyss
                Color(hex: "061220"),   // Dark navy
                Color(hex: "0A1A30"),   // Navy
                Color(hex: "0E2240"),   // Lighter navy
                Color(hex: "122A4A"),   // Horizon navy
            ]
        }
    }

    // MARK: Mountain Colors — Multi-band painterly palette

    /// Far mountains — hazy, atmospheric, almost ghost-like.
    var farMountainBase: Color {
        switch self {
        case .dawn:  return Color(hex: "6A4A70")
        case .day:   return Color(hex: "5A7A98")
        case .dusk:  return Color(hex: "5A2848")
        case .night: return Color(hex: "0E1828")
        }
    }

    var farMountainPeak: Color {
        switch self {
        case .dawn:  return Color(hex: "9A6A8A")
        case .day:   return Color(hex: "7A9AB8")
        case .dusk:  return Color(hex: "7A3858")
        case .night: return Color(hex: "1A2838")
        }
    }

    /// Mid mountains — richer, snow visible, painterly bands.
    var midMountainBase: Color {
        switch self {
        case .dawn:  return Color(hex: "5A3058")
        case .day:   return Color(hex: "3A5A78")
        case .dusk:  return Color(hex: "4A1838")
        case .night: return Color(hex: "0A1420")
        }
    }

    var midMountainBody: Color {
        switch self {
        case .dawn:  return Color(hex: "7A4A6A")
        case .day:   return Color(hex: "4A7090")
        case .dusk:  return Color(hex: "6A2848")
        case .night: return Color(hex: "121E30")
        }
    }

    var midMountainUpper: Color {
        switch self {
        case .dawn:  return Color(hex: "9A6A80")
        case .day:   return Color(hex: "6A8AA8")
        case .dusk:  return Color(hex: "8A4058")
        case .night: return Color(hex: "1A2840")
        }
    }

    /// Near mountains — boldest, most saturated, dramatic.
    var nearMountainBase: Color {
        switch self {
        case .dawn:  return Color(hex: "3A1838")
        case .day:   return Color(hex: "1A3A58")
        case .dusk:  return Color(hex: "2A0A28")
        case .night: return Color(hex: "060E18")
        }
    }

    var nearMountainBody: Color {
        switch self {
        case .dawn:  return Color(hex: "5A2850")
        case .day:   return Color(hex: "2A4A68")
        case .dusk:  return Color(hex: "3A1030")
        case .night: return Color(hex: "0A1520")
        }
    }

    /// Snow color — warm-tinted per time of day.
    var snowColor: Color {
        switch self {
        case .dawn:  return Color(hex: "FFE0D0")  // Warm rose snow
        case .day:   return Color(hex: "F0F8FF")  // Crisp blue-white
        case .dusk:  return Color(hex: "FFD0A0")  // Amber-lit snow
        case .night: return Color(hex: "B0C8E0")  // Moonlit blue
        }
    }

    var snowOpacity: Double {
        switch self {
        case .dawn:  return 0.75
        case .day:   return 0.85
        case .dusk:  return 0.65
        case .night: return 0.45
        }
    }

    // MARK: Haze / Atmosphere

    var hazeColor: Color {
        switch self {
        case .dawn:  return Color(hex: "D4785A")
        case .day:   return Color(hex: "8ECAE6")
        case .dusk:  return Color(hex: "8B4A5C")
        case .night: return Color(hex: "0E2240")
        }
    }

    // MARK: Ground / Ice Colors

    var iceShelfTop: Color {
        switch self {
        case .dawn:  return Color(hex: "E8D0D8")
        case .day:   return Color(hex: "D0E8F0")
        case .dusk:  return Color(hex: "C0909A")
        case .night: return Color(hex: "5A7A90")
        }
    }

    var iceShelfBody: Color {
        switch self {
        case .dawn:  return Color(hex: "8A6A7A")
        case .day:   return Color(hex: "6A90A8")
        case .dusk:  return Color(hex: "5A3848")
        case .night: return Color(hex: "1A3048")
        }
    }

    var iceShelfDeep: Color {
        switch self {
        case .dawn:  return Color(hex: "4A2A3A")
        case .day:   return Color(hex: "2A4A68")
        case .dusk:  return Color(hex: "2A1020")
        case .night: return Color(hex: "0A1828")
        }
    }

    var icicleColor: Color {
        switch self {
        case .dawn:  return Color(hex: "D0B0C0")
        case .day:   return Color(hex: "A0D0E8")
        case .dusk:  return Color(hex: "A07080")
        case .night: return Color(hex: "4A6A80")
        }
    }

    // MARK: Volumetric Light

    var lightBeamColor: Color {
        switch self {
        case .dawn:  return Color(hex: "FFD080")
        case .day:   return Color(hex: "FFFFFF")
        case .dusk:  return Color(hex: "FF8040")
        case .night: return Color(hex: "6080B0")
        }
    }

    var showLightBeams: Bool { self == .dawn || self == .dusk }

    // MARK: Celestial

    var showStars: Bool { self == .night || self == .dusk }
    var showMoon: Bool { self == .night }
    var showSunGlow: Bool { self == .dawn || self == .dusk }
    var showAurora: Bool { self == .night }

    // MARK: Cloud Palette

    var cloudColor: Color {
        switch self {
        case .dawn:  return Color(hex: "FFE8D0")
        case .day:   return Color.white
        case .dusk:  return Color(hex: "FFD0A0")
        case .night: return Color(hex: "2A3A4A")
        }
    }

    var cloudUnderlitColor: Color {
        switch self {
        case .dawn:  return Color(hex: "FF9060")
        case .day:   return Color(hex: "E8F0FF")
        case .dusk:  return Color(hex: "FF6030")
        case .night: return Color(hex: "1A2A38")
        }
    }
}

// MARK: - Environment Mood

/// Drives the visual mood of the Antarctic scene based on productivity.
/// Composes WITH TimeOfDay — mood adjusts brightness, particles, aurora.
enum EnvironmentMood: Equatable {
    /// No tasks done today — cold, dark, lonely
    case cold
    /// 1-2 tasks done — dawn breaking, warming up
    case warming
    /// 3+ tasks done — bright day, aurora visible
    case productive
    /// All tasks cleared — golden hour, celebration
    case golden
    /// Overdue tasks (3+ days stale) — storm clouds
    case stormy

    /// Brightness multiplier applied to mountains and ground.
    var brightnessFactor: Double {
        switch self {
        case .cold:        return 0.7
        case .warming:     return 0.85
        case .productive:  return 1.0
        case .golden:      return 1.15
        case .stormy:      return 0.5
        }
    }

    /// Aurora intensity (only visible at night).
    var auroraOpacity: Double {
        switch self {
        case .cold:        return 0
        case .warming:     return 0.15
        case .productive:  return 0.4
        case .golden:      return 0.65
        case .stormy:      return 0
        }
    }

    /// Snow particle density multiplier.
    var snowIntensity: Double {
        switch self {
        case .cold:        return 1.0
        case .warming:     return 0.6
        case .productive:  return 0.3
        case .golden:      return 0.15
        case .stormy:      return 1.5
        }
    }

    /// Light beam intensity multiplier.
    var beamIntensity: Double {
        switch self {
        case .cold:        return 0.3
        case .warming:     return 0.6
        case .productive:  return 1.0
        case .golden:      return 1.3
        case .stormy:      return 0
        }
    }
}

// MARK: - Internal Data Models

private struct SnowParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let opacity: Double
    let speed: CGFloat
    let drift: CGFloat
    let wobbleAmplitude: CGFloat
    let wobbleSpeed: CGFloat
    var wobblePhase: CGFloat
}

private struct Star: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let brightness: Double
    let twinkleSpeed: Double
}

private struct IceCrystal: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let rotationSpeed: CGFloat
    var rotation: CGFloat
    let driftSpeed: CGFloat
    let brightness: Double
}

private struct AntarcticShootingStar: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let angle: CGFloat        // radians, direction of travel
    let speed: CGFloat         // pts/sec
    let length: CGFloat        // tail length
    let brightness: Double
    var life: CGFloat          // 0→1, fades out as it approaches 1
    let maxLife: CGFloat
}

private struct FogWisp: Identifiable {
    let id = UUID()
    var x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let speed: CGFloat         // horizontal drift
    let opacity: Double
}

private struct WindSprite: Identifiable {
    let id = UUID()
    var x: CGFloat
    let y: CGFloat
    let speed: CGFloat
    let size: CGFloat
    let opacity: Double
}

private struct IceFloe: Identifiable {
    let id = UUID()
    var x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let speed: CGFloat
    let opacity: Double
    let cornerRadius: CGFloat
}

// MARK: - Parallax Motion Manager

/// Reads device accelerometer to drive diorama-style parallax.
/// Shared singleton — Apple requires only ONE CMMotionManager per app.
/// Reference-counted start/stop so multiple views can share safely.
final class ParallaxMotionManager {
    static let shared = ParallaxMotionManager()

    /// Raw accumulated offsets — NOT @Observable.
    /// The coalesced timer reads these and copies to @State, so motion
    /// never triggers independent body invalidations.
    private(set) var xOffset: CGFloat = 0
    private(set) var yOffset: CGFloat = 0
    /// True only when accelerometer is actually running (false on Simulator).
    private(set) var isActive: Bool = false

    private let motionManager = CMMotionManager()
    private let sensitivity: CGFloat = 18
    private var refCount = 0

    private init() {}

    func start() {
        refCount += 1
        guard refCount == 1 else { return }
        guard motionManager.isAccelerometerAvailable else { return }
        isActive = true
        motionManager.accelerometerUpdateInterval = 1.0 / 20.0  // Match coalesced timer rate
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let targetX = CGFloat(data.acceleration.x) * self.sensitivity
            let targetY = CGFloat(data.acceleration.y) * self.sensitivity
            // Smooth lerp — values accumulate here silently, no SwiftUI invalidation
            self.xOffset += (targetX - self.xOffset) * 0.12
            self.yOffset += (targetY - self.yOffset) * 0.12
        }
    }

    func stop() {
        refCount = max(0, refCount - 1)
        guard refCount == 0 else { return }
        isActive = false
        motionManager.stopAccelerometerUpdates()
        xOffset = 0
        yOffset = 0
    }
}

// MARK: - Antarctic Environment View

struct AntarcticEnvironment: View {

    let mood: EnvironmentMood
    let unlockedProps: Set<String>

    var fishCount: Int = 0
    var level: Int = 1
    var stage: StageTier = .bareIce

    var sceneWidth: CGFloat = 390
    var sceneHeight: CGFloat = 844

    /// When false, all timers and motion are paused (tab is off-screen).
    var isActive: Bool = true

    /// Override time of day for previews.
    var timeOverride: AntarcticTimeOfDay?

    /// The Y fraction (from top) where the cliff surface sits.
    /// Nudgy should be positioned at or just above this line.
    static let cliffSurfaceY: CGFloat = 0.78

    @State private var snowParticles: [SnowParticle] = []
    @State private var stars: [Star] = []
    @State private var crystals: [IceCrystal] = []
    @State private var auroraPhase: Double = 0
    @State private var twinklePhase: Double = 0
    @State private var windPhase: Double = 0
    @State private var beamPulse: Double = 0

    // New feature state
    @State private var shootingStars: [AntarcticShootingStar] = []
    @State private var fogWisps: [FogWisp] = []
    @State private var windSprites: [WindSprite] = []
    @State private var iceFloes: [IceFloe] = []
    @State private var cloudShadowOffset: CGFloat = -0.3
    
    /// Single coalesced animation timer — replaces 6 independent timers.
    /// One timer = one @State mutation batch per tick = one body invalidation.
    @State private var animationTimer: Timer?

    // Moon animation state (Despicable Me style)
    @State private var moonGlowPulse: Bool = false
    @State private var moonHaloBreath: Bool = false
    @State private var moonDrift: Bool = false

    // Parallax offsets — updated by the coalesced timer from ParallaxMotionManager.
    // NOT @Observable — eliminates independent accelerometer-driven body invalidations.
    @State private var pX: CGFloat = 0
    @State private var pY: CGFloat = 0
    private let parallax = ParallaxMotionManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var time: AntarcticTimeOfDay { timeOverride ?? .current }

    var body: some View {
        ZStack {
            // Layer 0: Rich sky gradient
            skyLayer

            // Layer 0a: Solid ground fill — guarantees the bottom is NEVER transparent.
            // This sits behind mountains, ocean, platform — a safety net.
            groundFill

            // Layer 1: Stars (night/dusk)
            if time.showStars {
                starField
            }

            // Layer 1a: Southern Cross (night)
            if time == .night {
                southernCross
                    .offset(x: pX * 0.05, y: pY * 0.05)
            }

            // Layer 1b: Moon (night) — Despicable Me scale
            if time.showMoon {
                moonLayer
                    .offset(x: pX * 0.06, y: pY * 0.06)
            }

            // Layer 1c: Sun glow (dawn/dusk)
            if time.showSunGlow {
                sunGlowLayer
                    .offset(x: pX * 0.08, y: pY * 0.08)
            }

            // Layer 1d: Shooting stars (night — rare, magical)
            if time == .night && !reduceMotion {
                shootingStarLayer
            }

            // Layer 2: Aurora borealis (night + productive)
            if time.showAurora && mood.auroraOpacity > 0 {
                auroraLayer
            }

            // Layer 3: Far mountains — massive, hazy, atmospheric
            farMountains
                .offset(x: pX * 0.12, y: pY * 0.06)

            // Layer 3a: Cloud shadows sweeping across far mountains
            if !reduceMotion {
                cloudShadowLayer
                    .offset(x: pX * 0.12)
            }

            // Layer 3b: Fog wisps between far and mid mountains
            if !reduceMotion {
                fogWispLayer
                    .offset(x: pX * 0.15)
            }

            // Layer 4: Atmospheric haze band
            hazeLayer
                .offset(x: pX * 0.15)

            // Layer 5: Mid mountains — snow-covered, color-banded
            midMountains
                .offset(x: pX * 0.25, y: pY * 0.10)

            // Layer 5a: Fog wisps between mid and near
            if !reduceMotion {
                fogWispLayerNear
                    .offset(x: pX * 0.28)
            }

            // Layer 6: Volumetric light beams (dawn/dusk god-rays)
            if time.showLightBeams && mood.beamIntensity > 0 {
                volumetricBeams
            }

            // Layer 7: Cloud bank — bold, fluffy, lit from below
            cloudBank
                .offset(x: pX * 0.30, y: pY * 0.12)

            // Layer 8: Near mountains — dramatic, detailed, closest
            nearMountains
                .offset(x: pX * 0.45, y: pY * 0.18)

            // Layer 8a: Dark ocean with ice floes (between near mtns and shelf)
            oceanLayer

            // Layer 9: Ice shelf reflection (sky shimmer on snow surface)
            iceShelfReflection

            // Layer 9: Ice shelf platform (Nudgy's home)
            iceShelfPlatform
                .offset(x: pX * 0.55, y: pY * 0.22)

            // Layer 9a: Nudgy's ground shadow
            nudgyGroundShadow
                .offset(x: pX * 0.55, y: pY * 0.22)

            // Layer 9b: Light pool on snow surface from lantern/campfire
            snowLightPool
                .offset(x: pX * 0.55, y: pY * 0.22)

            // Layer 9c: Warm light wash from props (campfire/lantern glow)
            if stage >= .cozyCamp || time == .night {
                warmLightWash
                    .offset(x: pX * 0.55, y: pY * 0.22)
            }

            // Layer 10: Cliff props
            cliffProps
                .offset(x: pX * 0.55, y: pY * 0.22)

            // Layer 11: Stage decorations
            StageDecorations(stage: stage, time: time, mood: mood)
                .offset(x: pX * 0.55, y: pY * 0.22)

            // Layer 11a: Snow blowing off the shelf edge
            if !reduceMotion {
                windBlownSnow
            }

            // Layer 12: Ice crystal sparkles
            if !reduceMotion {
                crystalSparkles
            }

            // Layer 13: Snow particles
            if !reduceMotion {
                snowLayer
            }

            // Layer 14: Storm overlay
            if mood == .stormy {
                stormOverlay
            }
        }
        .drawingGroup()
        .clipped()
        .onAppear {
            generateStars()
            generateCrystals()
            generateFogWisps()
            generateIceFloes()
            generateWindSprites()
            if isActive {
                startAllTimers()
            }
        }
        .onDisappear {
            stopAllTimers()
        }
        .onChange(of: isActive) { _, active in
            if active {
                startAllTimers()
            } else {
                stopAllTimers()
            }
        }
        .onChange(of: mood) { _, _ in
            initSnowParticles()
        }
    }

    // ═══════════════════════════════════════════════
    //  LAYER 0: SKY
    // ═══════════════════════════════════════════════

    private var skyLayer: some View {
        LinearGradient(
            colors: time.skyColors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 3.0), value: time)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 0a: SOLID GROUND FILL
    // ═══════════════════════════════════════════════
    // Opaque rectangle covering the entire bottom portion of the screen.
    // This is the "nuclear option" — no matter what the mountains, ocean,
    // or platform do with opacity/parallax, the ground is ALWAYS solid.

    private var groundFill: some View {
        let groundTop = sceneHeight * (Self.cliffSurfaceY - 0.12) // start well above cliff line
        let groundHeight = sceneHeight - groundTop + 100 // extend well past bottom

        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        time.iceShelfTop,
                        time.iceShelfBody,
                        time.iceShelfDeep,
                        Color(hex: "06101E"),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: sceneWidth + 200, height: groundHeight)
            .position(x: sceneWidth / 2, y: groundTop + groundHeight / 2)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 1: STAR FIELD
    // ═══════════════════════════════════════════════

    private var starField: some View {
        Canvas { context, size in
            for star in stars {
                let x = star.x * size.width
                let y = star.y * size.height

                let twinkle = sin(twinklePhase * star.twinkleSpeed) * 0.3 + 0.7
                let alpha = star.brightness * twinkle * (time == .night ? 1.0 : 0.35)

                // Soft outer glow for all stars (creates dreamy feel)
                if star.size > 1.5 {
                    let glowSize = star.size * 4
                    let glowRect = CGRect(
                        x: x - glowSize / 2,
                        y: y - glowSize / 2,
                        width: glowSize,
                        height: glowSize
                    )
                    context.opacity = alpha * 0.15
                    context.fill(Circle().path(in: glowRect), with: .color(.white))
                }

                // Star core
                let rect = CGRect(
                    x: x - star.size / 2,
                    y: y - star.size / 2,
                    width: star.size,
                    height: star.size
                )
                context.opacity = alpha
                context.fill(Circle().path(in: rect), with: .color(.white))

                // Cross sparkle on brightest stars (Dreamworks twinkle)
                if star.brightness > 0.85 && star.size > 2.5 {
                    let sparkLen = star.size * 2.5
                    context.opacity = alpha * 0.5
                    let hPath = Path { p in
                        p.move(to: CGPoint(x: x - sparkLen, y: y))
                        p.addLine(to: CGPoint(x: x + sparkLen, y: y))
                    }
                    context.stroke(hPath, with: .color(.white), lineWidth: 0.5)
                    let vPath = Path { p in
                        p.move(to: CGPoint(x: x, y: y - sparkLen))
                        p.addLine(to: CGPoint(x: x, y: y + sparkLen))
                    }
                    context.stroke(vPath, with: .color(.white), lineWidth: 0.5)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 1b: MOON — Despicable Me scale
    //  Massive, luminous, impossibly large moon that
    //  dominates the night sky with animated breathing glow.
    // ═══════════════════════════════════════════════

    private let moonBodySize: CGFloat = 110

    private var moonLayer: some View {
        let bodySize = moonBodySize

        return ZStack {
            // ── Layer 0: Scene-wide moonlight wash ──
            // Bathes the entire upper sky in cool blue light
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "B0D0FF").opacity(moonGlowPulse ? 0.10 : 0.06),
                            Color(hex: "8AB0E0").opacity(0.03),
                            .clear
                        ],
                        center: .center,
                        startRadius: bodySize * 0.5,
                        endRadius: bodySize * 4.0
                    )
                )
                .frame(width: bodySize * 8, height: bodySize * 6)
                .animation(
                    .easeInOut(duration: 6.0).repeatForever(autoreverses: true),
                    value: moonGlowPulse
                )

            // ── Layer 1: Outer atmospheric halo ──
            // The signature "Despicable Me" oversized luminous ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "D0E4FF").opacity(moonHaloBreath ? 0.18 : 0.10),
                            Color(hex: "A0C0F0").opacity(moonHaloBreath ? 0.10 : 0.05),
                            Color(hex: "7098D0").opacity(0.03),
                            Color(hex: "5080B0").opacity(0.01),
                            .clear
                        ],
                        center: .center,
                        startRadius: bodySize * 0.45,
                        endRadius: bodySize * 2.2
                    )
                )
                .frame(width: bodySize * 4.4, height: bodySize * 4.4)
                .scaleEffect(moonHaloBreath ? 1.04 : 0.96)
                .animation(
                    .easeInOut(duration: 5.0).repeatForever(autoreverses: true),
                    value: moonHaloBreath
                )

            // ── Layer 2: Inner corona ──
            // Tight bright ring right around the moon body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "F0F6FF").opacity(0.30),
                            Color(hex: "D8E8FF").opacity(0.15),
                            Color(hex: "B0C8E8").opacity(0.06),
                            .clear
                        ],
                        center: .center,
                        startRadius: bodySize * 0.4,
                        endRadius: bodySize * 1.1
                    )
                )
                .frame(width: bodySize * 2.2, height: bodySize * 2.2)

            // ── Layer 3: Moon body — the main disc ──
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "F8FAFF"),   // Bright center
                            Color(hex: "EDF2FC"),   // Mid body
                            Color(hex: "D8E4F2"),   // Edge gradient
                            Color(hex: "C0D0E4"),   // Limb darkening
                        ],
                        center: UnitPoint(x: 0.38, y: 0.35),
                        startRadius: 0,
                        endRadius: bodySize * 0.55
                    )
                )
                .frame(width: bodySize, height: bodySize)
                .shadow(color: Color(hex: "D0E4FF").opacity(0.6), radius: 20, x: 0, y: 0)
                .shadow(color: Color(hex: "B0C8FF").opacity(0.3), radius: 40, x: 0, y: 0)

            // ── Layer 4: Surface detail — mare (dark seas) ──
            // Mare Imbrium (large dark patch, upper-left)
            Ellipse()
                .fill(Color(hex: "9AAEC4").opacity(0.20))
                .frame(width: bodySize * 0.30, height: bodySize * 0.26)
                .offset(x: -bodySize * 0.10, y: -bodySize * 0.15)
                .blur(radius: 1.5)

            // Mare Serenitatis (medium, upper-right)
            Ellipse()
                .fill(Color(hex: "8A9EB8").opacity(0.18))
                .frame(width: bodySize * 0.22, height: bodySize * 0.19)
                .offset(x: bodySize * 0.12, y: -bodySize * 0.10)
                .blur(radius: 1)

            // Mare Tranquillitatis (medium, center-right)
            Ellipse()
                .fill(Color(hex: "8A9EB8").opacity(0.15))
                .frame(width: bodySize * 0.20, height: bodySize * 0.16)
                .offset(x: bodySize * 0.15, y: bodySize * 0.05)
                .blur(radius: 1)

            // Oceanus Procellarum (large, left side)
            Ellipse()
                .fill(Color(hex: "94A8BC").opacity(0.14))
                .frame(width: bodySize * 0.25, height: bodySize * 0.30)
                .offset(x: -bodySize * 0.18, y: bodySize * 0.05)
                .blur(radius: 1.5)

            // Mare Nubium (small, lower)
            Circle()
                .fill(Color(hex: "8A9EB8").opacity(0.12))
                .frame(width: bodySize * 0.14, height: bodySize * 0.14)
                .offset(x: -bodySize * 0.04, y: bodySize * 0.22)
                .blur(radius: 1)

            // ── Layer 5: Bright crater highlights ──
            // Tycho — bright ray crater, lower region
            Circle()
                .fill(Color.white.opacity(0.20))
                .frame(width: bodySize * 0.06, height: bodySize * 0.06)
                .offset(x: -bodySize * 0.05, y: bodySize * 0.30)

            // Copernicus — bright spot
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: bodySize * 0.05, height: bodySize * 0.05)
                .offset(x: -bodySize * 0.12, y: bodySize * 0.08)

            // Kepler — tiny bright dot
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: bodySize * 0.035, height: bodySize * 0.035)
                .offset(x: -bodySize * 0.22, y: bodySize * 0.02)

            // ── Layer 6: Limb shading ──
            // Subtle shadow on one edge for 3D depth
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .clear,
                            Color(hex: "8098B8").opacity(0.12)
                        ],
                        startPoint: UnitPoint(x: 0.2, y: 0.2),
                        endPoint: UnitPoint(x: 0.95, y: 0.85)
                    )
                )
                .frame(width: bodySize, height: bodySize)

            // ── Layer 7: Specular highlight ──
            // Bright spot at upper-left for that cinematic pop
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: bodySize * 0.25
                    )
                )
                .frame(width: bodySize * 0.5, height: bodySize * 0.5)
                .offset(x: -bodySize * 0.18, y: -bodySize * 0.20)
        }
        // Gentle slow drift up/down
        .offset(y: moonDrift ? -3 : 3)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 8.0).repeatForever(autoreverses: true),
            value: moonDrift
        )
        .position(x: sceneWidth * 0.78, y: sceneHeight * 0.10)
    }

    /// Starts the moon's breathing glow + drift animations.
    private func startMoonAnimations() {
        moonGlowPulse = true
        moonHaloBreath = true
        moonDrift = true
    }

    // ═══════════════════════════════════════════════
    //  LAYER 1c: SUN GLOW
    // ═══════════════════════════════════════════════

    private var sunGlowLayer: some View {
        let yPos = time == .dawn ? sceneHeight * 0.36 : sceneHeight * 0.34
        let xPos = time == .dawn ? sceneWidth * 0.72 : sceneWidth * 0.22

        return ZStack {
            // Massive atmospheric wash (the "Dreamworks glow")
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: time == .dawn ? "FFF0C0" : "FF9050").opacity(0.25),
                            Color(hex: time == .dawn ? "FFD080" : "FF7030").opacity(0.12),
                            Color(hex: time == .dawn ? "FFA050" : "CC5020").opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 280
                    )
                )
                .frame(width: 560, height: 380)

            // Secondary warm bloom
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: time == .dawn ? "FFE8A0" : "FFB060").opacity(0.35),
                            Color(hex: time == .dawn ? "FFD080" : "FF8040").opacity(0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 200)

            // Core sun disc (soft, no hard edges)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: time == .dawn ? "FFFAE0" : "FFD080").opacity(0.7),
                            Color(hex: time == .dawn ? "FFE8B0" : "FFB060").opacity(0.4),
                            Color(hex: time == .dawn ? "FFD080" : "FF8040").opacity(0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
        }
        .position(x: xPos, y: yPos)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 2: AURORA BOREALIS
    // ═══════════════════════════════════════════════

    private var auroraLayer: some View {
        ZStack {
            // Primary curtain — vivid green/cyan
            AuroraCurtain(
                colors: [
                    Color(hex: "00FF88").opacity(0.3),
                    Color(hex: "00DDAA").opacity(0.2),
                    Color(hex: "00AAFF").opacity(0.15),
                ],
                phase: auroraPhase,
                waveCount: 28,
                amplitude: 18
            )
            .offset(y: -sceneHeight * 0.3)

            // Secondary curtain — purple/pink accent
            AuroraCurtain(
                colors: [
                    Color(hex: "AA44FF").opacity(0.15),
                    Color(hex: "FF44AA").opacity(0.08),
                    Color(hex: "00FF88").opacity(0.12),
                ],
                phase: auroraPhase + 2.0,
                waveCount: 22,
                amplitude: 14
            )
            .offset(y: -sceneHeight * 0.22)

            // Tertiary curtain — subtle cyan
            AuroraCurtain(
                colors: [
                    Color(hex: "00CCAA").opacity(0.1),
                    Color(hex: "4488FF").opacity(0.08),
                    .clear
                ],
                phase: auroraPhase + 4.2,
                waveCount: 18,
                amplitude: 10
            )
            .offset(y: -sceneHeight * 0.15)
        }
        .opacity(mood.auroraOpacity)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 3: FAR MOUNTAINS
    // ═══════════════════════════════════════════════
    // Massive, hazy silhouettes. These define the EPIC scale.

    private var farMountains: some View {
        let layerHeight = sceneHeight * 0.55
        let bottomY = sceneHeight * Self.cliffSurfaceY

        // Far range: 2 broad massifs with rolling shoulders — like real Transantarctic Range
        // Each "peak" is actually a wide plateau/dome, not a triangle
        let farRidge: [RidgePoint] = [
            RidgePoint(x: -0.05, height: 0.02),  // Off-screen left
            RidgePoint(x: 0.00,  height: 0.05),
            RidgePoint(x: 0.06,  height: 0.15),
            RidgePoint(x: 0.12,  height: 0.30),  // Rising shoulder
            RidgePoint(x: 0.18,  height: 0.48),  // Approaching summit
            RidgePoint(x: 0.22,  height: 0.58),  // Broad summit plateau start
            RidgePoint(x: 0.28,  height: 0.62),  // Summit dome peak
            RidgePoint(x: 0.34,  height: 0.58),  // Summit plateau end
            RidgePoint(x: 0.38,  height: 0.45),  // Descending shoulder
            RidgePoint(x: 0.42,  height: 0.32),  // Col / saddle
            RidgePoint(x: 0.46,  height: 0.28),  // Deepest saddle point
            RidgePoint(x: 0.50,  height: 0.35),  // Rising into second massif
            RidgePoint(x: 0.55,  height: 0.52),  // Shoulder
            RidgePoint(x: 0.60,  height: 0.68),  // Second massif — the tall one
            RidgePoint(x: 0.65,  height: 0.75),  // Broad peak
            RidgePoint(x: 0.70,  height: 0.72),  // Plateau continuation
            RidgePoint(x: 0.75,  height: 0.60),  // Descending
            RidgePoint(x: 0.80,  height: 0.42),  // Saddle into far ridge
            RidgePoint(x: 0.85,  height: 0.35),
            RidgePoint(x: 0.90,  height: 0.28),
            RidgePoint(x: 0.95,  height: 0.15),
            RidgePoint(x: 1.00,  height: 0.08),
            RidgePoint(x: 1.05,  height: 0.02),  // Off-screen right
        ]

        // Secondary ridge behind — creates depth within the far layer
        let farRidge2: [RidgePoint] = [
            RidgePoint(x: -0.05, height: 0.01),
            RidgePoint(x: 0.00,  height: 0.04),
            RidgePoint(x: 0.08,  height: 0.20),
            RidgePoint(x: 0.15,  height: 0.38),
            RidgePoint(x: 0.20,  height: 0.50),
            RidgePoint(x: 0.25,  height: 0.55),
            RidgePoint(x: 0.32,  height: 0.48),
            RidgePoint(x: 0.40,  height: 0.30),
            RidgePoint(x: 0.48,  height: 0.22),
            RidgePoint(x: 0.55,  height: 0.40),
            RidgePoint(x: 0.62,  height: 0.55),
            RidgePoint(x: 0.68,  height: 0.60),
            RidgePoint(x: 0.73,  height: 0.52),
            RidgePoint(x: 0.80,  height: 0.35),
            RidgePoint(x: 0.88,  height: 0.18),
            RidgePoint(x: 0.95,  height: 0.10),
            RidgePoint(x: 1.05,  height: 0.02),
        ]

        return ZStack(alignment: .top) {
            // Back ridge — even more atmospheric
            CinematicMountainRange(ridgeline: farRidge2, tension: 0.25)
                .fill(
                    LinearGradient(
                        colors: [
                            time.farMountainPeak.opacity(0.40),
                            time.farMountainBase.opacity(0.50),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: sceneWidth, height: layerHeight)

            // Front ridge — main far mountains
            CinematicMountainRange(ridgeline: farRidge, tension: 0.30)
                .fill(
                    LinearGradient(
                        colors: [
                            time.farMountainPeak.opacity(0.65),
                            time.farMountainBase.opacity(0.75),
                            time.farMountainBase.opacity(0.85),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: sceneWidth, height: layerHeight)

            // Flowing snow fields across the broad summits (not tiny caps)
            CinematicSnowBand(
                ridgeline: farRidge,
                snowlineHeight: 0.45, // Snow starts at 45% of max height
                depth: 0.12
            )
            .fill(time.snowColor.opacity(time.snowOpacity * 0.45))
            .frame(width: sceneWidth, height: layerHeight)
        }
        .frame(width: sceneWidth, height: layerHeight)
        .position(x: sceneWidth / 2, y: bottomY - layerHeight / 2)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 4: ATMOSPHERIC HAZE
    // ═══════════════════════════════════════════════

    private var hazeLayer: some View {
        LinearGradient(
            colors: [
                .clear,
                time.hazeColor.opacity(0.12),
                time.hazeColor.opacity(0.20),
                time.hazeColor.opacity(0.12),
                .clear,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: sceneWidth, height: sceneHeight * 0.10)
        .blur(radius: 15)
        .position(x: sceneWidth / 2, y: sceneHeight * Self.cliffSurfaceY - sceneHeight * 0.30)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 5: MID MOUNTAINS
    // ═══════════════════════════════════════════════

    private var midMountains: some View {
        let layerHeight = sceneHeight * 0.45
        let bottomY = sceneHeight * Self.cliffSurfaceY + 10  // Overlap ice shelf slightly

        // Mid range: the "hero" mountains — one dominant massif left-center,
        // a secondary peak right. Broad, weathered, with wide saddles.
        let midRidgeline: [RidgePoint] = [
            RidgePoint(x: -0.05, height: 0.02),
            RidgePoint(x: 0.00,  height: 0.05),
            RidgePoint(x: 0.05,  height: 0.14),
            RidgePoint(x: 0.10,  height: 0.28),  // Left flank rise
            RidgePoint(x: 0.15,  height: 0.48),  // Shoulder
            RidgePoint(x: 0.18,  height: 0.60),  // Approaching hero peak
            RidgePoint(x: 0.22,  height: 0.72),  // Hero peak shoulder
            RidgePoint(x: 0.26,  height: 0.78),  // ★ Hero summit — broad dome
            RidgePoint(x: 0.30,  height: 0.76),  // Still on summit plateau
            RidgePoint(x: 0.34,  height: 0.68),  // Descending
            RidgePoint(x: 0.38,  height: 0.55),  // Ridge shoulder
            RidgePoint(x: 0.42,  height: 0.40),  // Dropping into col
            RidgePoint(x: 0.48,  height: 0.28),  // Deep col / saddle
            RidgePoint(x: 0.52,  height: 0.25),  // Saddle floor
            RidgePoint(x: 0.56,  height: 0.32),  // Rising again
            RidgePoint(x: 0.60,  height: 0.45),
            RidgePoint(x: 0.65,  height: 0.58),  // Secondary peak building
            RidgePoint(x: 0.70,  height: 0.65),  // ★ Secondary peak
            RidgePoint(x: 0.74,  height: 0.62),  // Plateau
            RidgePoint(x: 0.78,  height: 0.52),  // Descending
            RidgePoint(x: 0.82,  height: 0.38),
            RidgePoint(x: 0.88,  height: 0.22),
            RidgePoint(x: 0.94,  height: 0.12),
            RidgePoint(x: 1.00,  height: 0.06),
            RidgePoint(x: 1.05,  height: 0.02),
        ]

        // A secondary sub-ridge for depth
        let midRidge2: [RidgePoint] = [
            RidgePoint(x: -0.05, height: 0.01),
            RidgePoint(x: 0.05,  height: 0.10),
            RidgePoint(x: 0.12,  height: 0.32),
            RidgePoint(x: 0.20,  height: 0.55),
            RidgePoint(x: 0.28,  height: 0.62),
            RidgePoint(x: 0.35,  height: 0.50),
            RidgePoint(x: 0.45,  height: 0.28),
            RidgePoint(x: 0.55,  height: 0.22),
            RidgePoint(x: 0.63,  height: 0.42),
            RidgePoint(x: 0.72,  height: 0.55),
            RidgePoint(x: 0.80,  height: 0.40),
            RidgePoint(x: 0.90,  height: 0.18),
            RidgePoint(x: 1.00,  height: 0.06),
            RidgePoint(x: 1.05,  height: 0.01),
        ]

        return ZStack(alignment: .top) {
            // Back sub-ridge
            CinematicMountainRange(ridgeline: midRidge2, tension: 0.30)
                .fill(
                    LinearGradient(
                        colors: [
                            time.midMountainUpper.opacity(0.55),
                            time.midMountainBody.opacity(0.65),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: sceneWidth, height: layerHeight)

            // Main mid mountain body with rich color banding
            CinematicMountainRange(ridgeline: midRidgeline, tension: 0.30)
                .fill(
                    LinearGradient(
                        colors: [
                            time.midMountainUpper.opacity(0.80),
                            time.midMountainBody.opacity(0.88),
                            time.midMountainBase.opacity(0.92),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: sceneWidth, height: layerHeight)

            // Rock face detail — darker vertical striations on the steep faces
            CinematicRockFace(ridgeline: midRidgeline)
                .fill(time.midMountainBase.opacity(0.25))
                .frame(width: sceneWidth, height: layerHeight)

            // Soft snow rim along the ridgeline
            CinematicMountainRange(ridgeline: midRidgeline, tension: 0.30)
                .stroke(
                    time.snowColor.opacity(time.snowOpacity * 0.50),
                    lineWidth: 2.0
                )
                .frame(width: sceneWidth, height: layerHeight)

            // Flowing snow band across the broad summits
            CinematicSnowBand(
                ridgeline: midRidgeline,
                snowlineHeight: 0.40,
                depth: 0.15
            )
            .fill(time.snowColor.opacity(time.snowOpacity * 0.70))
            .frame(width: sceneWidth, height: layerHeight)
        }
        .frame(width: sceneWidth, height: layerHeight)
        .position(x: sceneWidth / 2, y: bottomY - layerHeight / 2)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 6: VOLUMETRIC LIGHT BEAMS
    // ═══════════════════════════════════════════════

    private var volumetricBeams: some View {
        Canvas { context, size in
            let sunX = time == .dawn ? size.width * 0.72 : size.width * 0.22
            let sunY = time == .dawn ? size.height * 0.30 : size.height * 0.28

            let beamGaps: [(angle: Double, width: Double, length: Double)] = [
                (-15, 35, 0.80),
                (-5,  50, 0.90),
                (8,   40, 0.85),
                (20,  30, 0.75),
                (32,  25, 0.65),
            ]

            let pulseMultiplier = 0.85 + sin(beamPulse) * 0.15

            for beam in beamGaps {
                let angleRad = beam.angle * .pi / 180
                let beamLength = size.height * beam.length

                let halfWidth = beam.width * 0.5
                let endHalfWidth = beam.width * 2.5

                let tipX = sunX
                let tipY = sunY

                let endCenterX = tipX + sin(angleRad) * beamLength
                let endCenterY = tipY + cos(angleRad) * beamLength

                let perpX = cos(angleRad)
                let perpY = -sin(angleRad)

                let beamPath = Path { p in
                    p.move(to: CGPoint(
                        x: tipX - perpX * halfWidth,
                        y: tipY - perpY * halfWidth
                    ))
                    p.addLine(to: CGPoint(
                        x: tipX + perpX * halfWidth,
                        y: tipY + perpY * halfWidth
                    ))
                    p.addLine(to: CGPoint(
                        x: endCenterX + perpX * endHalfWidth,
                        y: endCenterY + perpY * endHalfWidth
                    ))
                    p.addLine(to: CGPoint(
                        x: endCenterX - perpX * endHalfWidth,
                        y: endCenterY - perpY * endHalfWidth
                    ))
                    p.closeSubpath()
                }

                let beamOpacity = 0.06 * mood.beamIntensity * pulseMultiplier
                context.opacity = beamOpacity
                context.fill(beamPath, with: .linearGradient(
                    Gradient(colors: [
                        time.lightBeamColor.opacity(0.8),
                        time.lightBeamColor.opacity(0.4),
                        time.lightBeamColor.opacity(0.1),
                        .clear
                    ]),
                    startPoint: CGPoint(x: tipX, y: tipY),
                    endPoint: CGPoint(x: endCenterX, y: endCenterY)
                ))
            }
        }
        .blur(radius: 20)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 7: CLOUD BANK
    // ═══════════════════════════════════════════════

    private var cloudBank: some View {
        Canvas { context, size in
            let cloudClusters: [(cx: CGFloat, cy: CGFloat, scale: CGFloat)] = [
                (0.08, 0.42, 1.1),
                (0.25, 0.38, 1.3),
                (0.50, 0.40, 1.5),
                (0.72, 0.36, 1.2),
                (0.90, 0.41, 0.9),
            ]

            for cluster in cloudClusters {
                let cx = cluster.cx * size.width + CGFloat(sin(windPhase * 0.2 + cluster.cx * 8)) * 6
                let cy = cluster.cy * size.height
                let s = cluster.scale

                let puffs: [(dx: CGFloat, dy: CGFloat, w: CGFloat, h: CGFloat, alpha: Double)] = [
                    (-20 * s,  8 * s, 80 * s, 30 * s, 0.04),
                    ( 10 * s, 10 * s, 90 * s, 25 * s, 0.03),
                    (-30 * s,  0,     60 * s, 28 * s, 0.07),
                    (  0,      0,     70 * s, 35 * s, 0.09),
                    ( 25 * s, -2 * s, 55 * s, 30 * s, 0.08),
                    (-15 * s, -12 * s, 45 * s, 22 * s, 0.10),
                    ( 12 * s, -10 * s, 50 * s, 25 * s, 0.11),
                    ( 35 * s, -5 * s,  35 * s, 20 * s, 0.07),
                ]

                for (i, puff) in puffs.enumerated() {
                    let rect = CGRect(
                        x: cx + puff.dx - puff.w / 2,
                        y: cy + puff.dy - puff.h / 2,
                        width: puff.w,
                        height: puff.h
                    )
                    let isUnderlit = i < 2
                    let color = isUnderlit ? time.cloudUnderlitColor : time.cloudColor
                    context.opacity = puff.alpha
                    context.fill(
                        Ellipse().path(in: rect),
                        with: .color(color)
                    )
                }
            }
        }
        .blur(radius: 8)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 8: NEAR MOUNTAINS
    // ═══════════════════════════════════════════════

    private var nearMountains: some View {
        let layerHeight = sceneHeight * 0.38
        let bottomY = sceneHeight * Self.cliffSurfaceY + 15  // Overlap ice shelf a bit more

        // Near range: dramatic close-up. One big shoulder on the left,
        // one looming peak right-of-center. Very broad, geological feel.
        let nearRidgeline: [RidgePoint] = [
            RidgePoint(x: -0.05, height: 0.20),  // Off-screen — mountain continues
            RidgePoint(x: 0.00,  height: 0.28),
            RidgePoint(x: 0.05,  height: 0.40),  // Left shoulder mass
            RidgePoint(x: 0.10,  height: 0.52),
            RidgePoint(x: 0.14,  height: 0.58),  // ★ Left peak (massive shoulder)
            RidgePoint(x: 0.18,  height: 0.55),
            RidgePoint(x: 0.22,  height: 0.45),  // Descending
            RidgePoint(x: 0.28,  height: 0.30),  // Valley floor
            RidgePoint(x: 0.34,  height: 0.22),  // Low point — frames Nudgy
            RidgePoint(x: 0.40,  height: 0.18),  // Open space center (so Nudgy is visible)
            RidgePoint(x: 0.46,  height: 0.15),  // ← Lowest point — Nudgy viewport
            RidgePoint(x: 0.52,  height: 0.18),
            RidgePoint(x: 0.58,  height: 0.25),  // Rising into right peak
            RidgePoint(x: 0.64,  height: 0.38),
            RidgePoint(x: 0.70,  height: 0.52),  // Building
            RidgePoint(x: 0.76,  height: 0.62),  // ★ Right peak — dominant
            RidgePoint(x: 0.80,  height: 0.65),  // Broad summit
            RidgePoint(x: 0.84,  height: 0.62),
            RidgePoint(x: 0.88,  height: 0.50),
            RidgePoint(x: 0.92,  height: 0.38),
            RidgePoint(x: 0.96,  height: 0.28),
            RidgePoint(x: 1.00,  height: 0.22),
            RidgePoint(x: 1.05,  height: 0.18),  // Continues off-screen
        ]

        return ZStack(alignment: .top) {
            // Main near mountain body — bold, saturated
            CinematicMountainRange(ridgeline: nearRidgeline, tension: 0.30)
                .fill(
                    LinearGradient(
                        colors: [
                            time.nearMountainBody,
                            time.nearMountainBase,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: sceneWidth, height: layerHeight)

            // Rock face striations on steep sections
            CinematicRockFace(ridgeline: nearRidgeline)
                .fill(time.nearMountainBase.opacity(0.30))
                .frame(width: sceneWidth, height: layerHeight)

            // Snow rim light along ridgeline
            CinematicMountainRange(ridgeline: nearRidgeline, tension: 0.30)
                .stroke(
                    time.snowColor.opacity(time.snowOpacity * 0.35),
                    lineWidth: 1.5
                )
                .frame(width: sceneWidth, height: layerHeight)

            // Snow band — only on the higher sections
            CinematicSnowBand(
                ridgeline: nearRidgeline,
                snowlineHeight: 0.45,
                depth: 0.12
            )
            .fill(time.snowColor.opacity(time.snowOpacity * 0.55))
            .frame(width: sceneWidth, height: layerHeight)
        }
        .frame(width: sceneWidth, height: layerHeight)
        .position(x: sceneWidth / 2, y: bottomY - layerHeight / 2)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 9: ICE SHELF PLATFORM
    // ═══════════════════════════════════════════════

    private var iceShelfPlatform: some View {
        // Generous padding so parallax never reveals gaps
        let parallaxPad: CGFloat = 100
        let platformWidth = sceneWidth + parallaxPad * 2
        let shelfHeight = sceneHeight * (1 - Self.cliffSurfaceY) + 60
        let shelfTopY = sceneHeight * Self.cliffSurfaceY - 16

        return ZStack(alignment: .top) {
            // Solid opaque ice shelf — clean gradient, no noisy overlays
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            time.iceShelfTop,
                            time.iceShelfBody,
                            time.iceShelfDeep,
                            Color(hex: "06101E"),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Subtle snow-bright strip at the very top edge
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 12)
        }
        .frame(width: platformWidth, height: shelfHeight)
        .position(x: sceneWidth / 2, y: shelfTopY + shelfHeight / 2)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 10: CLIFF PROPS
    // ═══════════════════════════════════════════════

    private var cliffProps: some View {
        GeometryReader { geo in
            let surfaceY = geo.size.height * Self.cliffSurfaceY - 8

            FishBucket(fishCount: fishCount, tint: time.icicleColor)
                .frame(width: 58, height: 64)
                .position(x: geo.size.width * 0.12, y: surfaceY - 24)

            LevelFlag(level: level, time: time)
                .frame(width: 44, height: 72)
                .position(x: geo.size.width * 0.88, y: surfaceY - 30)

            if unlockedProps.contains("lantern") || time == .night {
                CliffLantern(time: time)
                    .frame(width: 38, height: 50)
                    .position(x: geo.size.width * 0.75, y: surfaceY - 18)
            }
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 12: ICE CRYSTAL SPARKLES
    // ═══════════════════════════════════════════════

    private var crystalSparkles: some View {
        Canvas { context, size in
            for crystal in crystals {
                let x = crystal.x
                let y = crystal.y

                guard y > 0 && y < size.height else { continue }

                let s = crystal.size
                let angle = crystal.rotation

                let cosA = cos(angle)
                let sinA = sin(angle)

                let points: [CGPoint] = [
                    CGPoint(x: x + 0 * cosA - (-s) * sinA, y: y + 0 * sinA + (-s) * cosA),
                    CGPoint(x: x + s * cosA - 0 * sinA, y: y + s * sinA + 0 * cosA),
                    CGPoint(x: x + 0 * cosA - s * sinA, y: y + 0 * sinA + s * cosA),
                    CGPoint(x: x + (-s) * cosA - 0 * sinA, y: y + (-s) * sinA + 0 * cosA),
                ]

                let diamondPath = Path { p in
                    p.move(to: points[0])
                    for point in points.dropFirst() {
                        p.addLine(to: point)
                    }
                    p.closeSubpath()
                }

                let glowRect = CGRect(x: x - s * 2, y: y - s * 2, width: s * 4, height: s * 4)
                context.opacity = crystal.brightness * 0.15
                context.fill(Circle().path(in: glowRect), with: .color(.white))

                context.opacity = crystal.brightness
                context.fill(diamondPath, with: .color(Color.white.opacity(0.8)))
            }
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 13: SNOW PARTICLES
    // ═══════════════════════════════════════════════

    private var snowLayer: some View {
        Canvas { context, size in
            for flake in snowParticles {
                let wobble = sin(flake.wobblePhase) * flake.wobbleAmplitude
                let x = flake.x + wobble
                let rect = CGRect(
                    x: x - flake.size / 2,
                    y: flake.y - flake.size / 2,
                    width: flake.size,
                    height: flake.size
                )
                context.opacity = flake.opacity
                context.fill(Circle().path(in: rect), with: .color(.white))

                if flake.size > 3.0 {
                    let glowRect = CGRect(
                        x: x - flake.size * 1.5,
                        y: flake.y - flake.size * 1.5,
                        width: flake.size * 3,
                        height: flake.size * 3
                    )
                    context.opacity = flake.opacity * 0.15
                    context.fill(Circle().path(in: glowRect), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  LAYER 14: STORM OVERLAY
    // ═══════════════════════════════════════════════

    private var stormOverlay: some View {
        ZStack {
            Color(hex: "080810").opacity(0.4)

            Canvas { context, size in
                for i in 0..<12 {
                    let y = CGFloat(i) * size.height / 12 + CGFloat.random(in: -20...20)
                    let startX = CGFloat.random(in: -50...size.width * 0.3)
                    let length = CGFloat.random(in: 100...280)
                    let path = Path { p in
                        p.move(to: CGPoint(x: startX, y: y))
                        p.addLine(to: CGPoint(
                            x: startX + length,
                            y: y + CGFloat.random(in: -8...8)
                        ))
                    }
                    context.opacity = 0.06
                    context.stroke(path, with: .color(.white), lineWidth: CGFloat.random(in: 0.5...1.5))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 1: SOUTHERN CROSS CONSTELLATION
    // ═══════════════════════════════════════════════

    /// The Southern Cross (Crux) — authentic Antarctic night sky detail.
    /// Five stars in the iconic cross pattern, positioned in the upper sky.
    private var southernCross: some View {
        Canvas { context, size in
            let cx = size.width * 0.28
            let cy = size.height * 0.08

            // Crux stars — relative positions (real constellation proportions)
            let cruxStars: [(dx: CGFloat, dy: CGFloat, mag: CGFloat, name: String)] = [
                (0, -18, 3.5, "Alpha"),   // Acrux (bottom)
                (0, 18, 3.2, "Gamma"),    // Gacrux (top)
                (-12, 0, 2.8, "Beta"),    // Mimosa (left)
                (10, 2, 2.5, "Delta"),    // (right)
                (2, 5, 1.8, "Epsilon"),   // (center, faintest)
            ]

            let twinkle = sin(twinklePhase * 0.6) * 0.15 + 0.85

            for star in cruxStars {
                let x = cx + star.dx
                let y = cy + star.dy

                // Glow
                let glowSize = star.mag * 3.5
                let glowRect = CGRect(x: x - glowSize, y: y - glowSize, width: glowSize * 2, height: glowSize * 2)
                context.opacity = 0.12 * twinkle
                context.fill(Circle().path(in: glowRect), with: .color(Color(hex: "C0D8FF")))

                // Core
                let coreRect = CGRect(x: x - star.mag / 2, y: y - star.mag / 2, width: star.mag, height: star.mag)
                context.opacity = 0.85 * twinkle
                context.fill(Circle().path(in: coreRect), with: .color(.white))

                // Cross sparkle on the two brightest
                if star.mag >= 3.0 {
                    let sparkLen = star.mag * 1.8
                    context.opacity = 0.3 * twinkle
                    let h = Path { p in p.move(to: CGPoint(x: x - sparkLen, y: y)); p.addLine(to: CGPoint(x: x + sparkLen, y: y)) }
                    let v = Path { p in p.move(to: CGPoint(x: x, y: y - sparkLen)); p.addLine(to: CGPoint(x: x, y: y + sparkLen)) }
                    context.stroke(h, with: .color(.white), lineWidth: 0.4)
                    context.stroke(v, with: .color(.white), lineWidth: 0.4)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 2: SHOOTING STARS
    // ═══════════════════════════════════════════════

    private var shootingStarLayer: some View {
        Canvas { context, size in
            for star in shootingStars {
                let progress = star.life / star.maxLife
                let fadeIn = min(1.0, progress * 5.0)   // Quick fade in
                let fadeOut = max(0.0, 1.0 - progress)  // Gradual fade out
                let alpha = star.brightness * fadeIn * fadeOut

                guard alpha > 0.01 else { continue }

                // Head
                let headRect = CGRect(x: star.x - 1.5, y: star.y - 1.5, width: 3, height: 3)
                context.opacity = alpha
                context.fill(Circle().path(in: headRect), with: .color(.white))

                // Glow around head
                let glowRect = CGRect(x: star.x - 5, y: star.y - 5, width: 10, height: 10)
                context.opacity = alpha * 0.3
                context.fill(Circle().path(in: glowRect), with: .color(Color(hex: "C0E8FF")))

                // Tail — line trailing behind
                let tailX = star.x - cos(star.angle) * star.length * CGFloat(fadeOut)
                let tailY = star.y - sin(star.angle) * star.length * CGFloat(fadeOut)
                let tailPath = Path { p in
                    p.move(to: CGPoint(x: star.x, y: star.y))
                    p.addLine(to: CGPoint(x: tailX, y: tailY))
                }
                context.opacity = alpha * 0.6
                context.stroke(tailPath, with: .linearGradient(
                    Gradient(colors: [.white, .clear]),
                    startPoint: CGPoint(x: star.x, y: star.y),
                    endPoint: CGPoint(x: tailX, y: tailY)
                ), lineWidth: 1.2)
            }
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 3: CLOUD SHADOWS ON MOUNTAINS
    // ═══════════════════════════════════════════════

    /// Subtle dark patches that sweep across the mid/far mountains,
    /// simulating cloud shadows moving in the wind.
    private var cloudShadowLayer: some View {
        Canvas { context, size in
            let shadowPositions: [(cx: CGFloat, width: CGFloat, opacity: Double)] = [
                (cloudShadowOffset, 0.18, 0.06),
                (cloudShadowOffset + 0.35, 0.22, 0.04),
                (cloudShadowOffset + 0.65, 0.15, 0.05),
            ]

            let mountainZoneTop = size.height * 0.25
            let mountainZoneBottom = size.height * Self.cliffSurfaceY

            for shadow in shadowPositions {
                var cx = shadow.cx
                // Wrap around
                if cx > 1.3 { cx -= 1.6 }

                let x = cx * size.width
                let w = shadow.width * size.width
                let h = mountainZoneBottom - mountainZoneTop

                let rect = CGRect(x: x - w / 2, y: mountainZoneTop, width: w, height: h)
                context.opacity = shadow.opacity
                context.fill(
                    Ellipse().path(in: rect),
                    with: .color(Color.black)
                )
            }
        }
        .blur(radius: 30)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 4: FOG WISPS BETWEEN LAYERS
    // ═══════════════════════════════════════════════

    /// Fog wisps drifting between far and mid mountains
    private var fogWispLayer: some View {
        Canvas { context, size in
            let baseY = size.height * 0.42  // Between far and mid

            for wisp in fogWisps.prefix(4) {
                let x = wisp.x
                let y = baseY + wisp.y

                let rect = CGRect(
                    x: x - wisp.width / 2,
                    y: y - wisp.height / 2,
                    width: wisp.width,
                    height: wisp.height
                )

                context.opacity = wisp.opacity * (time == .night ? 0.5 : 1.0)
                context.fill(
                    Ellipse().path(in: rect),
                    with: .color(time.hazeColor)
                )
            }
        }
        .blur(radius: 18)
        .allowsHitTesting(false)
    }

    /// Fog wisps between mid and near mountains
    private var fogWispLayerNear: some View {
        Canvas { context, size in
            let baseY = size.height * 0.55  // Between mid and near

            for wisp in fogWisps.dropFirst(4) {
                let x = wisp.x
                let y = baseY + wisp.y

                let rect = CGRect(
                    x: x - wisp.width / 2,
                    y: y - wisp.height / 2,
                    width: wisp.width,
                    height: wisp.height
                )

                context.opacity = wisp.opacity * (time == .night ? 0.4 : 0.8)
                context.fill(
                    Ellipse().path(in: rect),
                    with: .color(time.hazeColor)
                )
            }
        }
        .blur(radius: 14)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 5: DARK OCEAN WITH ICE FLOES
    // ═══════════════════════════════════════════════

    /// Dark water band between near mountains and ice shelf,
    /// with floating white ice chunks for Antarctic authenticity.
    private var oceanLayer: some View {
        let oceanTop = sceneHeight * (Self.cliffSurfaceY - 0.08)
        let oceanHeight: CGFloat = sceneHeight * 0.12  // taller to bridge gap
        let oceanWidth: CGFloat = sceneWidth + 80 // wider than screen for parallax
        
        let waterColor1 = Color(hex: time == .night ? "020810" : "0A1828")
        let waterColor2 = Color(hex: time == .night ? "061220" : "122A4A")
        let waterColor3 = Color(hex: time == .night ? "0A1A30" : "1A3A58")
        let snowColor = time.snowColor

        return ZStack(alignment: .top) {
            // Solid dark water — no opacity
            LinearGradient(
                colors: [waterColor1, waterColor2, waterColor3],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: oceanWidth, height: oceanHeight)

            // Gentle wave highlights
            oceanWaveCanvas(oceanHeight: oceanHeight, snowColor: snowColor)

            // Floating ice floes
            oceanFloeCanvas(oceanHeight: oceanHeight, snowColor: snowColor)
        }
        .frame(width: oceanWidth, height: oceanHeight)
        .position(x: sceneWidth / 2, y: oceanTop + oceanHeight / 2)
        .allowsHitTesting(false)
    }
    
    private func oceanWaveCanvas(oceanHeight: CGFloat, snowColor: Color) -> some View {
        let wPhase: Double = Double(windPhase)
        return Canvas { context, size in
            let waveCount: Int = 5
            for i in 0..<waveCount {
                let fraction: CGFloat = CGFloat(i + 1) / CGFloat(waveCount + 1)
                let yBase: CGFloat = size.height * fraction
                var path = Path()
                path.move(to: CGPoint(x: 0, y: yBase))
                var xPos: CGFloat = 0
                while xPos <= size.width {
                    let xComponent: Double = Double(xPos) * 0.02
                    let phaseComponent: Double = wPhase * 0.5 + Double(i) * 1.2
                    let sinArg: Double = xComponent + phaseComponent
                    let wave: CGFloat = CGFloat(sin(sinArg) * 1.5)
                    path.addLine(to: CGPoint(x: xPos, y: yBase + wave))
                    xPos += 4
                }
                context.opacity = 0.06
                context.stroke(path, with: .color(snowColor), lineWidth: 0.5)
            }
        }
        .frame(width: sceneWidth, height: oceanHeight)
    }
    
    private func oceanFloeCanvas(oceanHeight: CGFloat, snowColor: Color) -> some View {
        Canvas { context, size in
            for floe in iceFloes {
                let rect = CGRect(
                    x: floe.x - floe.width / 2,
                    y: floe.y,
                    width: floe.width,
                    height: floe.height
                )
                context.opacity = floe.opacity
                context.fill(
                    RoundedRectangle(cornerRadius: floe.cornerRadius).path(in: rect),
                    with: .color(snowColor)
                )

                // Shadow beneath each floe
                let shadowRect = CGRect(
                    x: rect.minX + 1,
                    y: rect.maxY,
                    width: floe.width - 2,
                    height: 2
                )
                context.opacity = 0.08
                context.fill(
                    Ellipse().path(in: shadowRect),
                    with: .color(.black)
                )
            }
        }
        .frame(width: sceneWidth, height: oceanHeight)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 6: WIND-BLOWN SNOW OFF SHELF EDGE
    // ═══════════════════════════════════════════════

    /// White wisps streaming horizontally off the cliff edge.
    /// Sells the Antarctic wind.
    private var windBlownSnow: some View {
        Canvas { context, size in
            let shelfY = size.height * Self.cliffSurfaceY

            for sprite in windSprites {
                let y = shelfY + sprite.y

                // Each sprite is a short horizontal streak
                let path = Path { p in
                    p.move(to: CGPoint(x: sprite.x, y: y))
                    p.addQuadCurve(
                        to: CGPoint(x: sprite.x + sprite.size, y: y + CGFloat.random(in: -2...2)),
                        control: CGPoint(x: sprite.x + sprite.size * 0.5, y: y - 3)
                    )
                }

                context.opacity = sprite.opacity
                context.stroke(path, with: .color(.white), lineWidth: 0.8)

                // Tiny particles at the end
                let dotRect = CGRect(x: sprite.x + sprite.size - 1, y: y - 0.5, width: 1.5, height: 1.5)
                context.opacity = sprite.opacity * 0.6
                context.fill(Circle().path(in: dotRect), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 7: WARM LIGHT WASH FROM PROPS
    // ═══════════════════════════════════════════════

    /// Campfire/lantern casts warm orange glow on the ice shelf surface.
    private var warmLightWash: some View {
        let surfaceY = sceneHeight * Self.cliffSurfaceY

        // Light source position depends on stage
        let lightX: CGFloat = stage >= .cozyCamp ? sceneWidth * 0.45 : sceneWidth * 0.75
        let intensity: Double = time == .night ? 0.18 : 0.08

        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hex: "FFB040").opacity(intensity),
                        Color(hex: "FF8020").opacity(intensity * 0.5),
                        Color(hex: "FF6010").opacity(intensity * 0.2),
                        .clear
                    ],
                    center: .center,
                    startRadius: 5,
                    endRadius: 100
                )
            )
            .frame(width: 200, height: 80)
            .position(x: lightX, y: surfaceY - 5)
            .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 8: ICE SHELF SKY REFLECTION
    // ═══════════════════════════════════════════════

    /// Subtle mirrored shimmer on the flat snow surface reflecting sky color.
    private var iceShelfReflection: some View {
        let surfaceY = sceneHeight * Self.cliffSurfaceY

        return LinearGradient(
            colors: [
                time.skyColors.last?.opacity(0.20) ?? .clear,
                time.skyColors.last?.opacity(0.10) ?? .clear,
                .clear,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: sceneWidth, height: 40)
        .position(x: sceneWidth / 2, y: surfaceY + 8)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 9: PENGUIN FOOTPRINTS IN SNOW
    // ═══════════════════════════════════════════════

    /// Tiny three-toed tracks in the snow near where Nudgy stands.
    private var penguinFootprints: some View {
        Canvas { context, size in
            let surfaceY = size.height * Self.cliffSurfaceY - 4

            // Footprint positions — a trail walking from left toward center
            let prints: [(x: CGFloat, y: CGFloat, angle: CGFloat)] = [
                (0.32, -2, -0.08),
                (0.36, 1, 0.05),
                (0.40, -1, -0.03),
                (0.44, 2, 0.06),
                (0.47, 0, -0.04),
            ]

            for print in prints {
                let px = size.width * print.x
                let py = surfaceY + print.y

                context.opacity = 0.08

                // Three-toed footprint: three small lines fanning out
                let toeLength: CGFloat = 3.0
                let toeSpread: CGFloat = 0.35  // radians

                for t in -1...1 {
                    let angle = print.angle + CGFloat(t) * toeSpread
                    let toePath = Path { p in
                        p.move(to: CGPoint(x: px, y: py))
                        p.addLine(to: CGPoint(
                            x: px + cos(angle - .pi / 2) * toeLength,
                            y: py + sin(angle - .pi / 2) * toeLength
                        ))
                    }
                    context.stroke(toePath, with: .color(time.iceShelfBody), lineWidth: 0.8)
                }

                // Heel pad — tiny circle
                let padRect = CGRect(x: px - 1, y: py + 1, width: 2, height: 2)
                context.fill(Circle().path(in: padRect), with: .color(time.iceShelfBody.opacity(0.5)))
            }
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 10: SNOW SURFACE TEXTURE
    // ═══════════════════════════════════════════════

    /// Fine sparkle grain and subtle noise across the flat snow surface.
    /// Gives the snow a crystalline, granular look rather than flat color.
    private var snowSurfaceTexture: some View {
        let surfaceY: CGFloat = sceneHeight * Self.cliffSurfaceY
        let textureHeight: CGFloat = sceneHeight * (1.0 - Self.cliffSurfaceY) * 0.5
        let baseOpacity: Double = time == .night ? 0.15 : 0.22

        return Canvas { context, size in
            // Scattered sparkle dots across the surface
            let seed: UInt64 = 42
            var rng = SeededRNG(seed: seed)
            let dotCount: Int = 160

            for _ in 0..<dotCount {
                let dx: CGFloat = CGFloat.random(in: 0...size.width, using: &rng)
                let dy: CGFloat = CGFloat.random(in: 0...textureHeight, using: &rng)
                let dotSize: CGFloat = CGFloat.random(in: 1.0...3.5, using: &rng)

                let rect = CGRect(
                    x: dx - dotSize / 2,
                    y: dy - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                let brightness: Double = Double.random(in: 0.4...1.0, using: &rng)
                context.opacity = baseOpacity * brightness
                context.fill(Circle().path(in: rect), with: .color(.white))
            }

            // Horizontal grain lines (wind-polished snow)
            for i in 0..<12 {
                let ly: CGFloat = textureHeight * CGFloat(i + 1) / 13.0
                let startX: CGFloat = CGFloat.random(in: 0...size.width * 0.1, using: &rng)
                let endX: CGFloat = startX + CGFloat.random(in: size.width * 0.3...size.width * 0.7, using: &rng)
                let grainPath = Path { p in
                    p.move(to: CGPoint(x: startX, y: ly))
                    p.addLine(to: CGPoint(x: endX, y: ly + CGFloat.random(in: -0.5...0.5, using: &rng)))
                }
                context.opacity = 0.12
                context.stroke(grainPath, with: .color(.white), lineWidth: 0.8)
            }
        }
        .frame(width: sceneWidth, height: textureHeight)
        .position(x: sceneWidth / 2, y: surfaceY + textureHeight / 2 - 4)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 11: SURFACE ICE CRACKS
    // ═══════════════════════════════════════════════

    /// Branching hairline cracks across the snow/ice surface.
    /// Catches blue-white highlights like real pressure cracks in sea ice.
    private var surfaceIceCracks: some View {
        let surfaceY: CGFloat = sceneHeight * Self.cliffSurfaceY
        let crackColor: Color = time == .night
            ? Color(hex: "4A7A9A").opacity(0.35)
            : Color(hex: "80C0E0").opacity(0.25)
        let highlightColor: Color = Color.white.opacity(time == .night ? 0.15 : 0.20)

        return Canvas { context, size in
            // Main crack network — 4-5 primary cracks with branches
            let cracks: [(start: CGPoint, segments: [(dx: CGFloat, dy: CGFloat)])] = [
                (
                    CGPoint(x: size.width * 0.05, y: 12),
                    [(50, 8), (40, -4), (35, 6), (45, -2), (30, 5)]
                ),
                (
                    CGPoint(x: size.width * 0.35, y: 2),
                    [(30, 10), (25, 5), (40, 12), (20, -3)]
                ),
                (
                    CGPoint(x: size.width * 0.55, y: 8),
                    [(35, -6), (45, 4), (30, -8), (50, 2), (25, 6)]
                ),
                (
                    CGPoint(x: size.width * 0.75, y: 4),
                    [(20, 14), (35, 6), (40, -4), (30, 10)]
                ),
                (
                    CGPoint(x: size.width * 0.15, y: 20),
                    [(60, -4), (45, 8), (50, -2)]
                ),
            ]

            for crack in cracks {
                var path = Path()
                var current = crack.start
                path.move(to: current)

                for seg in crack.segments {
                    let next = CGPoint(x: current.x + seg.dx, y: current.y + seg.dy)
                    let ctrl = CGPoint(
                        x: (current.x + next.x) / 2 + CGFloat.random(in: -3...3),
                        y: (current.y + next.y) / 2 + CGFloat.random(in: -2...2)
                    )
                    path.addQuadCurve(to: next, control: ctrl)
                    current = next
                }

                // Draw crack shadow (darker line)
                context.opacity = 1.0
                context.stroke(path, with: .color(crackColor), lineWidth: 1.5)

                // Draw highlight along the top edge of the crack
                var highlightPath = Path()
                var hCurrent = crack.start
                highlightPath.move(to: CGPoint(x: hCurrent.x, y: hCurrent.y - 0.8))
                for seg in crack.segments {
                    let next = CGPoint(x: hCurrent.x + seg.dx, y: hCurrent.y + seg.dy - 0.8)
                    highlightPath.addLine(to: next)
                    hCurrent = CGPoint(x: hCurrent.x + seg.dx, y: hCurrent.y + seg.dy)
                }
                context.opacity = 1.0
                context.stroke(highlightPath, with: .color(highlightColor), lineWidth: 0.8)

                // Add small branches at random segment junctions
                var branchPt = crack.start
                for (i, seg) in crack.segments.enumerated() {
                    branchPt = CGPoint(x: branchPt.x + seg.dx, y: branchPt.y + seg.dy)
                    if i % 2 == 0 {
                        let branchEnd = CGPoint(
                            x: branchPt.x + CGFloat.random(in: 8...20),
                            y: branchPt.y + CGFloat.random(in: -8...8)
                        )
                        let branchPath = Path { p in
                            p.move(to: branchPt)
                            p.addLine(to: branchEnd)
                        }
                        context.opacity = 0.8
                        context.stroke(branchPath, with: .color(crackColor), lineWidth: 0.8)
                    }
                }
            }
        }
        .frame(width: sceneWidth, height: 60)
        .position(x: sceneWidth / 2, y: surfaceY + 20)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 12: SNOW LIP OVERHANG
    // ═══════════════════════════════════════════════

    /// A curving lip of wind-packed snow that overhangs the cliff edge,
    /// with a subtle blue shadow underneath. Signature Antarctic look.
    private var snowLipOverhang: some View {
        let surfaceY: CGFloat = sceneHeight * Self.cliffSurfaceY
        let lipColor: Color = time.iceShelfTop
        let shadowColor: Color = time == .night
            ? Color(hex: "0A1830").opacity(0.55)
            : Color(hex: "2A4A70").opacity(0.40)

        return Canvas { context, size in
            let w: CGFloat = size.width
            let h: CGFloat = size.height

            // Shadow beneath the lip (drawn first, sits below)
            let shadowPath = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.45))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.15, y: h * 0.55),
                    control: CGPoint(x: w * 0.08, y: h * 0.52)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.40, y: h * 0.48),
                    control: CGPoint(x: w * 0.28, y: h * 0.58)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.60, y: h * 0.55),
                    control: CGPoint(x: w * 0.50, y: h * 0.42)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.80, y: h * 0.50),
                    control: CGPoint(x: w * 0.70, y: h * 0.60)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w, y: h * 0.47),
                    control: CGPoint(x: w * 0.92, y: h * 0.55)
                )
                p.addLine(to: CGPoint(x: w, y: h * 0.65))
                p.addLine(to: CGPoint(x: 0, y: h * 0.65))
                p.closeSubpath()
            }
            context.opacity = 1.0
            context.fill(shadowPath, with: .color(shadowColor))

            // The snow lip itself — a thick curving overhang
            let lipPath = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.10))
                // Top surface (mostly flat with subtle bumps)
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.20, y: h * 0.06),
                    control: CGPoint(x: w * 0.10, y: h * 0.04)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.45, y: h * 0.08),
                    control: CGPoint(x: w * 0.32, y: h * 0.03)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.65, y: h * 0.05),
                    control: CGPoint(x: w * 0.55, y: h * 0.10)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.85, y: h * 0.08),
                    control: CGPoint(x: w * 0.75, y: h * 0.03)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w, y: h * 0.10),
                    control: CGPoint(x: w * 0.93, y: h * 0.05)
                )
                // Bottom edge — curving inward (the overhang)
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.85, y: h * 0.42),
                    control: CGPoint(x: w * 0.95, y: h * 0.38)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.65, y: h * 0.38),
                    control: CGPoint(x: w * 0.75, y: h * 0.46)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.45, y: h * 0.40),
                    control: CGPoint(x: w * 0.55, y: h * 0.34)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.20, y: h * 0.38),
                    control: CGPoint(x: w * 0.32, y: h * 0.46)
                )
                p.addQuadCurve(
                    to: CGPoint(x: 0, y: h * 0.42),
                    control: CGPoint(x: w * 0.08, y: h * 0.35)
                )
                p.closeSubpath()
            }

            // Lip fill — white snow gradient
            context.opacity = 1.0
            context.fill(lipPath, with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.55 * mood.brightnessFactor),
                    lipColor.opacity(0.45 * mood.brightnessFactor),
                    lipColor.opacity(0.30 * mood.brightnessFactor),
                ]),
                startPoint: CGPoint(x: w / 2, y: 0),
                endPoint: CGPoint(x: w / 2, y: h * 0.5)
            ))

            // Highlight line along the top edge of the lip
            let highlightPath = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.08))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.30, y: h * 0.04),
                    control: CGPoint(x: w * 0.15, y: h * 0.03)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.70, y: h * 0.06),
                    control: CGPoint(x: w * 0.50, y: h * 0.02)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w, y: h * 0.08),
                    control: CGPoint(x: w * 0.85, y: h * 0.03)
                )
            }
            context.opacity = 0.35
            context.stroke(highlightPath, with: .color(.white), lineWidth: 1.0)
        }
        .frame(width: sceneWidth, height: 50)
        .position(x: sceneWidth / 2, y: surfaceY + 16)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 13: WIND-SCULPTED SASTRUGI BUMPS
    // ═══════════════════════════════════════════════

    /// Small elongated mound shapes with cast shadows on the surface,
    /// showing prevailing wind direction. Classic Antarctic terrain feature.
    private var sastrugiBumps: some View {
        let surfaceY: CGFloat = sceneHeight * Self.cliffSurfaceY
        let snowWhite: Color = Color.white.opacity(0.45 * mood.brightnessFactor)
        let shadowBlue: Color = time == .night
            ? Color(hex: "0A1830").opacity(0.35)
            : Color(hex: "3A5A80").opacity(0.25)

        return Canvas { context, size in
            // 6 sastrugi ridges at various positions on the surface
            let ridges: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, tilt: CGFloat)] = [
                (0.10, 6, 55, 10, -0.08),    // far left
                (0.28, 14, 48, 8, 0.05),     // left of center
                (0.48, 4, 65, 12, -0.04),    // center
                (0.65, 16, 50, 9, 0.07),     // center right
                (0.80, 8, 42, 7, -0.06),     // right
                (0.92, 12, 45, 8, 0.04),     // far right
            ]

            for ridge in ridges {
                let cx: CGFloat = size.width * ridge.x
                let cy: CGFloat = ridge.y

                // Shadow (offset downwind)
                let shadowRect = CGRect(
                    x: cx - ridge.w / 2 + 2,
                    y: cy + ridge.h * 0.3,
                    width: ridge.w,
                    height: ridge.h * 0.6
                )
                context.opacity = 1.0
                context.fill(
                    Ellipse().path(in: shadowRect),
                    with: .color(shadowBlue)
                )

                // Snow mound
                let moundPath = Path { p in
                    p.move(to: CGPoint(x: cx - ridge.w / 2, y: cy + ridge.h))
                    p.addQuadCurve(
                        to: CGPoint(x: cx - ridge.w * 0.15, y: cy),
                        control: CGPoint(x: cx - ridge.w * 0.35, y: cy + ridge.h * 0.3)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: cx + ridge.w * 0.20, y: cy + ridge.h * 0.2),
                        control: CGPoint(x: cx + ridge.w * 0.05, y: cy - ridge.h * 0.2)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: cx + ridge.w / 2, y: cy + ridge.h),
                        control: CGPoint(x: cx + ridge.w * 0.35, y: cy + ridge.h * 0.4)
                    )
                    p.closeSubpath()
                }
                context.opacity = 1.0
                context.fill(moundPath, with: .color(snowWhite))

                // Top highlight
                let hlPath = Path { p in
                    p.move(to: CGPoint(x: cx - ridge.w * 0.2, y: cy + ridge.h * 0.15))
                    p.addQuadCurve(
                        to: CGPoint(x: cx + ridge.w * 0.1, y: cy + ridge.h * 0.1),
                        control: CGPoint(x: cx, y: cy - ridge.h * 0.1)
                    )
                }
                context.opacity = 0.40
                context.stroke(hlPath, with: .color(.white), lineWidth: 1.0)
            }
        }
        .frame(width: sceneWidth, height: 50)
        .position(x: sceneWidth / 2, y: surfaceY + 14)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 14: FOREGROUND ICE CHUNKS
    // ═══════════════════════════════════════════════

    /// 2-3 irregular ice/snow shapes in the very near foreground,
    /// partially off-screen, creating depth layering.
    private var foregroundIceChunks: some View {
        let surfaceY: CGFloat = sceneHeight * Self.cliffSurfaceY
        let chunkColor: Color = time.iceShelfTop
        let shadowColor: Color = time == .night
            ? Color(hex: "060E1A").opacity(0.4)
            : Color(hex: "1A3050").opacity(0.25)

        return Canvas { context, size in
            // Chunk 1: large, bottom-left, partially off-screen
            let c1Path = Path { p in
                p.move(to: CGPoint(x: -12, y: size.height))
                p.addLine(to: CGPoint(x: -12, y: 18))
                p.addQuadCurve(
                    to: CGPoint(x: 15, y: 6),
                    control: CGPoint(x: 2, y: 8)
                )
                p.addQuadCurve(
                    to: CGPoint(x: 38, y: 14),
                    control: CGPoint(x: 28, y: 2)
                )
                p.addQuadCurve(
                    to: CGPoint(x: 45, y: size.height),
                    control: CGPoint(x: 44, y: 22)
                )
                p.closeSubpath()
            }
            context.opacity = 1.0
            context.fill(c1Path, with: .color(chunkColor.opacity(0.55)))
            // Highlight edge
            let c1hl = Path { p in
                p.move(to: CGPoint(x: -8, y: 18))
                p.addLine(to: CGPoint(x: 15, y: 6))
                p.addLine(to: CGPoint(x: 36, y: 14))
            }
            context.opacity = 0.30
            context.stroke(c1hl, with: .color(.white), lineWidth: 1.0)

            // Chunk 2: bottom-right, angular
            let rightX: CGFloat = size.width - 25
            let c2Path = Path { p in
                p.move(to: CGPoint(x: rightX, y: size.height))
                p.addLine(to: CGPoint(x: rightX + 5, y: 20))
                p.addQuadCurve(
                    to: CGPoint(x: rightX + 28, y: 10),
                    control: CGPoint(x: rightX + 15, y: 8)
                )
                p.addLine(to: CGPoint(x: size.width + 12, y: 14))
                p.addLine(to: CGPoint(x: size.width + 12, y: size.height))
                p.closeSubpath()
            }
            context.opacity = 1.0
            context.fill(c2Path, with: .color(chunkColor.opacity(0.50)))

            // Chunk 3: small center-bottom pebble
            let c3x: CGFloat = size.width * 0.42
            let c3Path = Path { p in
                p.move(to: CGPoint(x: c3x, y: size.height))
                p.addQuadCurve(
                    to: CGPoint(x: c3x + 8, y: size.height - 8),
                    control: CGPoint(x: c3x - 2, y: size.height - 6)
                )
                p.addQuadCurve(
                    to: CGPoint(x: c3x + 22, y: size.height - 5),
                    control: CGPoint(x: c3x + 14, y: size.height - 12)
                )
                p.addQuadCurve(
                    to: CGPoint(x: c3x + 26, y: size.height),
                    control: CGPoint(x: c3x + 25, y: size.height - 3)
                )
                p.closeSubpath()
            }
            // Shadow under pebble
            let c3shadow = Ellipse().path(in: CGRect(x: c3x + 2, y: size.height - 3, width: 24, height: 4))
            context.opacity = 1.0
            context.fill(c3shadow, with: .color(shadowColor))
            context.fill(c3Path, with: .color(chunkColor.opacity(0.45)))
        }
        .frame(width: sceneWidth, height: sceneHeight * 0.18)
        .position(x: sceneWidth / 2, y: surfaceY + sceneHeight * 0.15 / 2 + 10)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 15: NUDGY'S GROUND SHADOW
    // ═══════════════════════════════════════════════

    /// Soft elliptical contact shadow where the penguin stands.
    /// Grounds the character on the surface.
    private var nudgyGroundShadow: some View {
        let surfaceY: CGFloat = sceneHeight * Self.cliffSurfaceY
        let shadowOpacity: Double = time == .night ? 0.30 : 0.25

        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color.black.opacity(shadowOpacity),
                        Color.black.opacity(shadowOpacity * 0.5),
                        .clear
                    ],
                    center: .center,
                    startRadius: 4,
                    endRadius: 40
                )
            )
            .frame(width: 80, height: 22)
            .position(x: sceneWidth / 2, y: surfaceY + 2)
            .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 16: SNOW LIGHT POOL
    // ═══════════════════════════════════════════════

    /// Warm-tinted oval on the ground near the lantern/campfire,
    /// making the light source feel grounded on the snow surface.
    private var snowLightPool: some View {
        let surfaceY: CGFloat = sceneHeight * Self.cliffSurfaceY
        let lightX: CGFloat = stage >= .cozyCamp ? sceneWidth * 0.45 : sceneWidth * 0.75
        let intensity: Double = time == .night ? 0.30 : 0.15

        return Canvas { context, size in
            // Outer soft pool
            let outerRect = CGRect(
                x: lightX - 70,
                y: surfaceY - 8,
                width: 140,
                height: 22
            )
            context.opacity = intensity
            context.fill(
                Ellipse().path(in: outerRect),
                with: .color(Color(hex: "FFD080"))
            )

            // Inner brighter core
            let innerRect = CGRect(
                x: lightX - 30,
                y: surfaceY - 4,
                width: 60,
                height: 12
            )
            context.opacity = intensity * 1.5
            context.fill(
                Ellipse().path(in: innerRect),
                with: .color(Color(hex: "FFB040"))
            )

            // Tiny highlight sparkles in the light pool
            let sparklePositions: [(CGFloat, CGFloat)] = [
                (lightX - 25, surfaceY - 1),
                (lightX + 15, surfaceY + 2),
                (lightX - 8, surfaceY + 4),
                (lightX + 30, surfaceY),
            ]
            for (sx, sy) in sparklePositions {
                let sparkRect = CGRect(x: sx - 0.5, y: sy - 0.5, width: 1, height: 1)
                context.opacity = intensity * 2.0
                context.fill(Circle().path(in: sparkRect), with: .color(.white))
            }
        }
        .frame(width: sceneWidth, height: sceneHeight)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  FEATURE 17: WIND TRAIL STREAKS
    // ═══════════════════════════════════════════════

    /// Ultra-subtle parallel lines across the snow surface,
    /// showing prevailing wind direction.
    private var windTrailStreaks: some View {
        let surfaceY: CGFloat = sceneHeight * Self.cliffSurfaceY
        let streakOpacity: Double = time == .night ? 0.10 : 0.14

        return Canvas { context, size in
            let streakCount: Int = 16
            var rng = SeededRNG(seed: 77)

            for _ in 0..<streakCount {
                let startX: CGFloat = CGFloat.random(in: -20...size.width * 0.3, using: &rng)
                let y: CGFloat = CGFloat.random(in: 2...44, using: &rng)
                let length: CGFloat = CGFloat.random(in: size.width * 0.25...size.width * 0.75, using: &rng)
                let drift: CGFloat = CGFloat.random(in: -3...3, using: &rng)

                let path = Path { p in
                    p.move(to: CGPoint(x: startX, y: y))
                    p.addQuadCurve(
                        to: CGPoint(x: startX + length, y: y + drift),
                        control: CGPoint(x: startX + length / 2, y: y + drift * 1.5)
                    )
                }
                context.opacity = streakOpacity
                context.stroke(path, with: .color(.white), lineWidth: 1.0)
            }
        }
        .frame(width: sceneWidth, height: 50)
        .position(x: sceneWidth / 2, y: surfaceY + 14)
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════
    //  ANIMATION ENGINE
    // ═══════════════════════════════════════════════

    private func generateStars() {
        stars = (0..<80).map { _ in
            Star(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...0.40),
                size: CGFloat.random(in: 0.8...4.0),
                brightness: Double.random(in: 0.3...1.0),
                twinkleSpeed: Double.random(in: 0.3...1.8)
            )
        }
    }

    private func generateCrystals() {
        crystals = (0..<10).map { _ in
            IceCrystal(
                x: CGFloat.random(in: 20...(sceneWidth - 20)),
                y: CGFloat.random(in: sceneHeight * 0.3...sceneHeight * 0.75),
                size: CGFloat.random(in: 2...5),
                rotationSpeed: CGFloat.random(in: 0.3...1.2),
                rotation: CGFloat.random(in: 0...(CGFloat.pi * 2)),
                driftSpeed: CGFloat.random(in: (-8)...(-2)),
                brightness: Double.random(in: 0.25...0.65)
            )
        }
    }

    // MARK: - Bulk Timer Control

    /// Starts the single coalesced animation timer + motion manager.
    private func startAllTimers() {
        startCoalescedTimer()
        initSnowParticles()
        startAnimations()
        if !reduceMotion {
            parallax.start()
            startMoonAnimations()
        }
    }

    /// Stops the coalesced timer + motion manager.
    private func stopAllTimers() {
        animationTimer?.invalidate()
        animationTimer = nil
        parallax.stop()
    }
    
    /// Single 20fps timer that updates ALL particle systems in one batch.
    /// This replaces 6 independent timers, reducing body invalidations from 6/tick to 1/tick.
    private func startCoalescedTimer() {
        guard !reduceMotion else { return }
        animationTimer?.invalidate()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { _ in
            let dt: CGFloat = 1.0 / 20.0
            
            // — Sample parallax from motion manager (batched, not independent) —
            pX = parallax.xOffset
            pY = parallax.yOffset
            
            // — Snow particles (was 30fps, now 20fps — imperceptible) —
            for i in snowParticles.indices {
                snowParticles[i].y += snowParticles[i].speed * dt
                snowParticles[i].x += snowParticles[i].drift * dt
                snowParticles[i].wobblePhase += snowParticles[i].wobbleSpeed * dt
                
                if snowParticles[i].y > sceneHeight + 10 {
                    snowParticles[i].y = CGFloat.random(in: -30 ... -5)
                    snowParticles[i].x = CGFloat.random(in: 0...sceneWidth)
                }
            }
            
            // — Crystal sparkles —
            for i in crystals.indices {
                crystals[i].y += crystals[i].driftSpeed * dt
                crystals[i].rotation += crystals[i].rotationSpeed * dt
                crystals[i].x += sin(crystals[i].rotation * 0.5) * 0.3
                
                if crystals[i].y < sceneHeight * 0.2 {
                    crystals[i].y = sceneHeight * 0.75 + CGFloat.random(in: 0...20)
                    crystals[i].x = CGFloat.random(in: 20...(sceneWidth - 20))
                }
            }
            
            // — Fog wisps + ice floes + cloud shadow —
            for i in fogWisps.indices {
                fogWisps[i].x += fogWisps[i].speed * dt
                if fogWisps[i].speed > 0 && fogWisps[i].x > sceneWidth + 120 {
                    fogWisps[i].x = -120
                } else if fogWisps[i].speed < 0 && fogWisps[i].x < -120 {
                    fogWisps[i].x = sceneWidth + 120
                }
            }
            for i in iceFloes.indices {
                iceFloes[i].x += iceFloes[i].speed * dt
                if iceFloes[i].x > sceneWidth + 30 {
                    iceFloes[i].x = -30
                }
            }
            cloudShadowOffset += 0.0003
            if cloudShadowOffset > 1.3 { cloudShadowOffset = -0.3 }
            
            // — Shooting stars (rare spawn + update) —
            if time == .night && shootingStars.count < 2 && Double.random(in: 0...1) < 0.003 {
                shootingStars.append(AntarcticShootingStar(
                    x: CGFloat.random(in: sceneWidth * 0.1...sceneWidth * 0.9),
                    y: CGFloat.random(in: sceneHeight * 0.02...sceneHeight * 0.18),
                    angle: CGFloat.random(in: 0.3...1.0),
                    speed: CGFloat.random(in: 200...400),
                    length: CGFloat.random(in: 30...60),
                    brightness: Double.random(in: 0.5...0.9),
                    life: 0,
                    maxLife: CGFloat.random(in: 0.4...0.8)
                ))
            }
            for i in shootingStars.indices {
                shootingStars[i].x += cos(shootingStars[i].angle) * shootingStars[i].speed * dt
                shootingStars[i].y += sin(shootingStars[i].angle) * shootingStars[i].speed * dt
                shootingStars[i].life += dt
            }
            shootingStars.removeAll { $0.life >= $0.maxLife }
            
            // — Wind sprites —
            for i in windSprites.indices {
                windSprites[i].x += windSprites[i].speed * dt
                if windSprites[i].x > sceneWidth + 50 {
                    windSprites[i].x = CGFloat.random(in: -40 ... -10)
                }
            }
            
            // — Twinkle phase —
            twinklePhase += 0.05
        }
    }
    
    /// Initialize snow particles for current mood (called on appear and mood change).
    private func initSnowParticles() {
        guard !reduceMotion else { return }
        let baseCount = Int(30 * mood.snowIntensity)
        snowParticles = (0..<baseCount).map { _ in
            SnowParticle(
                x: CGFloat.random(in: 0...sceneWidth),
                y: CGFloat.random(in: -50...sceneHeight),
                size: CGFloat.random(in: 1.0...5.0),
                opacity: Double.random(in: 0.15...0.55),
                speed: CGFloat.random(in: 10...30),
                drift: CGFloat.random(in: -6...6),
                wobbleAmplitude: CGFloat.random(in: 2...10),
                wobbleSpeed: CGFloat.random(in: 1...3),
                wobblePhase: CGFloat.random(in: 0...(CGFloat.pi * 2))
            )
        }
    }

    private func startAnimations() {
        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 12.0).repeatForever(autoreverses: true)) {
            auroraPhase = .pi * 2
        }

        withAnimation(.linear(duration: 25.0).repeatForever(autoreverses: false)) {
            windPhase = .pi * 2
        }

        withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
            beamPulse = .pi * 2
        }
    }

    // ═══════════════════════════════════════════════
    //  NEW GENERATORS & ANIMATION LOOPS
    // ═══════════════════════════════════════════════

    private func generateFogWisps() {
        // 4 wisps for far layer, 4 for near layer = 8 total
        fogWisps = (0..<8).map { i in
            FogWisp(
                x: CGFloat.random(in: -60...sceneWidth + 60),
                y: CGFloat.random(in: -15...15),
                width: CGFloat.random(in: 80...180),
                height: CGFloat.random(in: 15...35),
                speed: CGFloat.random(in: 4...12) * (i % 2 == 0 ? 1 : -1),
                opacity: Double.random(in: 0.04...0.10)
            )
        }
    }

    private func generateIceFloes() {
        let oceanHeight = sceneHeight * 0.06
        iceFloes = (0..<8).map { _ in
            IceFloe(
                x: CGFloat.random(in: 0...sceneWidth),
                y: CGFloat.random(in: oceanHeight * 0.1...oceanHeight * 0.7),
                width: CGFloat.random(in: 6...22),
                height: CGFloat.random(in: 3...8),
                speed: CGFloat.random(in: 1...5),
                opacity: Double.random(in: 0.15...0.35),
                cornerRadius: CGFloat.random(in: 1.5...4)
            )
        }
    }

    private func generateWindSprites() {
        windSprites = (0..<12).map { _ in
            WindSprite(
                x: CGFloat.random(in: 0...sceneWidth),
                y: CGFloat.random(in: -8...8),
                speed: CGFloat.random(in: 40...100),
                size: CGFloat.random(in: 15...40),
                opacity: Double.random(in: 0.06...0.18)
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════
//  SUPPORTING SHAPES
// ═══════════════════════════════════════════════════════════

// MARK: - Ridge Point Data

private struct RidgePoint {
    let x: CGFloat      // 0–1 fraction across width
    let height: CGFloat  // 0–1 fraction of available height
}

// MARK: - Cinematic Mountain Range Shape

/// Disney/Pixar-quality mountain range using Catmull-Rom spline interpolation.
/// Creates broad, majestic, naturally-weathered silhouettes — not pointy zigzags.
/// The Catmull-Rom algorithm guarantees the curve passes through every control point
/// with smooth, organic transitions that mimic real geological erosion patterns.
private struct CinematicMountainRange: Shape {
    let ridgeline: [RidgePoint]
    /// Tension controls curvature: 0 = very smooth/round, 1 = tighter/sharper
    var tension: CGFloat = 0.35

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard ridgeline.count >= 2 else { return path }

        // Convert ridge points to screen coordinates
        let points = ridgeline.map { pt in
            CGPoint(
                x: pt.x * rect.width,
                y: rect.height * (1 - pt.height)
            )
        }

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: points[0])

        // Catmull-Rom spline: each segment uses the surrounding 4 points
        // to compute cubic Bezier control points for glass-smooth curves
        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : CGPoint(x: points[0].x - (points[1].x - points[0].x), y: points[0].y)
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : CGPoint(x: p2.x + (p2.x - p1.x), y: p2.y)

            // Catmull-Rom to cubic Bezier conversion
            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / (6.0 / tension),
                y: p1.y + (p2.y - p0.y) / (6.0 / tension)
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / (6.0 / tension),
                y: p2.y - (p3.y - p1.y) / (6.0 / tension)
            )

            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Cinematic Snow Band

/// Flowing snow coverage that follows the ridgeline naturally.
/// Instead of individual tiny caps on peaks, this creates a continuous
/// snow band that covers everything above the snowline — like real alpine snow.
private struct CinematicSnowBand: Shape {
    let ridgeline: [RidgePoint]
    let snowlineHeight: CGFloat  // Fraction: snow covers peaks above this height
    let depth: CGFloat           // How far below ridgeline the snow extends

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard ridgeline.count >= 2 else { return path }

        // Find points above snowline
        let snowPoints = ridgeline.filter { $0.height >= snowlineHeight }
        guard !snowPoints.isEmpty else { return path }

        // Build snow band as a series of filled regions hugging the ridgeline
        // with an irregular lower edge (melting/dripping effect)
        for i in 0..<ridgeline.count - 1 {
            let curr = ridgeline[i]
            let next = ridgeline[i + 1]

            // Only draw snow where ridgeline is above snowline
            guard curr.height >= snowlineHeight || next.height >= snowlineHeight else { continue }

            let x0 = curr.x * rect.width
            let x1 = next.x * rect.width
            let y0 = rect.height * (1 - curr.height)
            let y1 = rect.height * (1 - next.height)

            // Snow bottom edge — irregular, dripping
            let snowDepthPx = rect.height * depth
            let irregularity = snowDepthPx * 0.3
            let bottomY0 = y0 + snowDepthPx + CGFloat(sin(Double(curr.x) * 15)) * irregularity
            let bottomY1 = y1 + snowDepthPx + CGFloat(sin(Double(next.x) * 15 + 2)) * irregularity

            // Clip bottom to not go past the ridgeline base
            let clippedBottom0 = min(bottomY0, rect.height * (1 - snowlineHeight * 0.5))
            let clippedBottom1 = min(bottomY1, rect.height * (1 - snowlineHeight * 0.5))

            var segment = Path()
            segment.move(to: CGPoint(x: x0, y: y0 - 2))  // Slightly above ridgeline
            segment.addLine(to: CGPoint(x: x1, y: y1 - 2))
            segment.addLine(to: CGPoint(x: x1, y: clippedBottom1))

            // Wavy bottom edge
            let midX = (x0 + x1) / 2
            let midBottomY = (clippedBottom0 + clippedBottom1) / 2 + irregularity * 0.5
            segment.addQuadCurve(
                to: CGPoint(x: x0, y: clippedBottom0),
                control: CGPoint(x: midX, y: midBottomY)
            )
            segment.closeSubpath()

            path.addPath(segment)
        }

        return path
    }
}

// MARK: - Cinematic Rock Face

/// Vertical rock striations on steep mountain faces.
/// Creates the look of exposed dark rock beneath snow —
/// common in Antarctic nunataks and the Transantarctic Range.
private struct CinematicRockFace: Shape {
    let ridgeline: [RidgePoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Draw rock streaks on the steepest sections of the ridgeline
        for i in 0..<ridgeline.count - 1 {
            let curr = ridgeline[i]
            let next = ridgeline[i + 1]

            // Only draw on steep slopes (big height difference over small x distance)
            let dx = next.x - curr.x
            let dy = abs(next.height - curr.height)
            guard dx > 0 && dy / dx > 1.2 else { continue }

            // Draw 2-3 rock streaks on this face
            let streakCount = Int(dy / dx)
            let clampedStreaks = min(3, max(1, streakCount))

            for s in 0..<clampedStreaks {
                let t = CGFloat(s + 1) / CGFloat(clampedStreaks + 1)
                let streakX = (curr.x + t * dx * 0.6) * rect.width
                let streakTopY = rect.height * (1 - max(curr.height, next.height) * 0.85)
                let streakBotY = rect.height * (1 - min(curr.height, next.height) * 0.3)
                let streakWidth: CGFloat = rect.width * dx * 0.08

                var streak = Path()
                streak.move(to: CGPoint(x: streakX, y: streakTopY))
                streak.addQuadCurve(
                    to: CGPoint(x: streakX + streakWidth * 0.3, y: streakBotY),
                    control: CGPoint(x: streakX - streakWidth * 0.5, y: (streakTopY + streakBotY) / 2)
                )
                streak.addQuadCurve(
                    to: CGPoint(x: streakX, y: streakTopY),
                    control: CGPoint(x: streakX + streakWidth, y: (streakTopY + streakBotY) / 2)
                )
                streak.closeSubpath()

                path.addPath(streak)
            }
        }

        return path
    }
}

// MARK: - Cinematic Snow Field

/// Naturalistic snow coverage on mountain peaks — irregular dripping edge.
private struct CinematicSnowField: Shape {
    let ridgeline: [RidgePoint]
    let snowCoverage: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        for peak in ridgeline {
            let peakX = peak.x * rect.width
            let peakY = rect.height * (1 - peak.height)
            let snowBottomY = peakY + rect.height * peak.height * snowCoverage
            let capHalfWidth = rect.width * 0.055

            path.move(to: CGPoint(x: peakX, y: peakY))

            // Right side — jagged snow edge
            path.addCurve(
                to: CGPoint(x: peakX + capHalfWidth * 0.7, y: snowBottomY - 5),
                control1: CGPoint(x: peakX + capHalfWidth * 0.4, y: peakY + (snowBottomY - peakY) * 0.2),
                control2: CGPoint(x: peakX + capHalfWidth * 0.8, y: peakY + (snowBottomY - peakY) * 0.5)
            )
            path.addQuadCurve(
                to: CGPoint(x: peakX + capHalfWidth * 0.5, y: snowBottomY + 3),
                control: CGPoint(x: peakX + capHalfWidth * 0.65, y: snowBottomY + 6)
            )
            path.addQuadCurve(
                to: CGPoint(x: peakX + capHalfWidth * 0.2, y: snowBottomY - 2),
                control: CGPoint(x: peakX + capHalfWidth * 0.35, y: snowBottomY + 4)
            )
            path.addQuadCurve(
                to: CGPoint(x: peakX - capHalfWidth * 0.2, y: snowBottomY + 1),
                control: CGPoint(x: peakX, y: snowBottomY + 5)
            )
            path.addQuadCurve(
                to: CGPoint(x: peakX - capHalfWidth * 0.5, y: snowBottomY - 3),
                control: CGPoint(x: peakX - capHalfWidth * 0.35, y: snowBottomY + 3)
            )
            path.addCurve(
                to: CGPoint(x: peakX, y: peakY),
                control1: CGPoint(x: peakX - capHalfWidth * 0.8, y: peakY + (snowBottomY - peakY) * 0.5),
                control2: CGPoint(x: peakX - capHalfWidth * 0.4, y: peakY + (snowBottomY - peakY) * 0.15)
            )
        }

        return path
    }
}

// MARK: - Cinematic Rock Patches

private struct CinematicRockPatches: Shape {
    let peaks: [RidgePoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()

        for peak in peaks {
            let peakX = peak.x * rect.width
            let peakY = rect.height * (1 - peak.height)
            let patchY = peakY + rect.height * peak.height * 0.25

            let w: CGFloat = 12
            let h: CGFloat = 8

            path.move(to: CGPoint(x: peakX - w * 0.3, y: patchY))
            path.addQuadCurve(
                to: CGPoint(x: peakX + w * 0.4, y: patchY - h * 0.3),
                control: CGPoint(x: peakX + w * 0.1, y: patchY - h * 0.6)
            )
            path.addQuadCurve(
                to: CGPoint(x: peakX + w * 0.5, y: patchY + h * 0.4),
                control: CGPoint(x: peakX + w * 0.6, y: patchY + h * 0.1)
            )
            path.addQuadCurve(
                to: CGPoint(x: peakX - w * 0.3, y: patchY),
                control: CGPoint(x: peakX, y: patchY + h * 0.5)
            )
        }

        return path
    }
}

// MARK: - Aurora Curtain

private struct AuroraCurtain: View {
    let colors: [Color]
    let phase: Double
    let waveCount: Int
    let amplitude: CGFloat

    var body: some View {
        Canvas { context, size in
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: size.height * 0.5))

                for i in 0...waveCount {
                    let x = size.width * CGFloat(i) / CGFloat(waveCount)
                    let wave1 = sin(Double(i) * 0.4 + phase) * Double(amplitude)
                    let wave2 = sin(Double(i) * 0.7 + phase * 0.6) * Double(amplitude) * 0.5
                    let wave3 = sin(Double(i) * 1.1 + phase * 0.3) * Double(amplitude) * 0.25
                    let y = size.height * 0.5 + CGFloat(wave1 + wave2 + wave3)
                    p.addLine(to: CGPoint(x: x, y: y))
                }

                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.addLine(to: CGPoint(x: 0, y: size.height))
                p.closeSubpath()
            }

            let gradient = Gradient(colors: colors + [.clear])
            context.fill(path, with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: size.width * 0.2, y: 0),
                endPoint: CGPoint(x: size.width * 0.8, y: size.height)
            ))
        }
        .frame(height: 100)
        .blur(radius: 30)
    }
}

// MARK: - Seeded RNG

/// Deterministic random number generator so snow texture dots
/// and wind trail streaks stay stable across re-renders.
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Glacial Snow Crust

/// Thick, undulating snow crust on top of the ice shelf.
/// Much more detailed than the old FriendlySnowSurface — multiple bumps
/// with varying heights and soft Bezier curves to feel like wind-sculpted snow.
private struct GlacialSnowCrust: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.height))

        // Wind-sculpted sastrugi pattern — irregular bumps and ridges
        let profile: [(x: CGFloat, y: CGFloat)] = [
            (0.00, 0.55),
            (0.04, 0.42),
            (0.08, 0.30),
            (0.13, 0.22),
            (0.18, 0.35),
            (0.22, 0.18),
            (0.27, 0.25),
            (0.32, 0.12),  // Low point — wind-carved
            (0.38, 0.20),
            (0.42, 0.08),  // Crisp ridge
            (0.48, 0.15),
            (0.53, 0.10),
            (0.58, 0.18),
            (0.63, 0.06),  // Another ridge
            (0.68, 0.14),
            (0.73, 0.22),
            (0.78, 0.10),
            (0.83, 0.20),
            (0.88, 0.15),
            (0.93, 0.28),
            (0.97, 0.40),
            (1.00, 0.50),
        ]

        for (i, pt) in profile.enumerated() {
            let x = pt.x * rect.width
            let y = rect.height * pt.y

            if i == 0 {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                let prev = profile[i - 1]
                let prevX = prev.x * rect.width
                let prevY = rect.height * prev.y
                // Smooth quad curves between each point
                let cpX = (prevX + x) / 2
                let cpY = min(y, prevY) - rect.height * 0.04
                path.addQuadCurve(
                    to: CGPoint(x: x, y: y),
                    control: CGPoint(x: cpX, y: cpY)
                )
            }
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Glacial Cliff Body

/// Thick glacier wall with weathered face, overhangs, and geological character.
/// Replaces the old FriendlyIceBody with much more detail.
private struct GlacialCliffBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Top edge — slightly irregular ice face
        path.move(to: CGPoint(x: 0, y: rect.height * 0.08))

        // Undulating top edge with subtle overhangs
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.04),
            control: CGPoint(x: rect.width * 0.05, y: rect.height * 0.06)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.02),
            control: CGPoint(x: rect.width * 0.16, y: rect.height * 0.00)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.35, y: rect.height * 0.03),
            control: CGPoint(x: rect.width * 0.28, y: rect.height * 0.01)
        )
        // Slight overhang here
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.45, y: rect.height * 0.01),
            control: CGPoint(x: rect.width * 0.40, y: rect.height * 0.04)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.58, y: rect.height * 0.03),
            control: CGPoint(x: rect.width * 0.52, y: rect.height * 0.00)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.70, y: rect.height * 0.02),
            control: CGPoint(x: rect.width * 0.64, y: rect.height * 0.04)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.04),
            control: CGPoint(x: rect.width * 0.76, y: rect.height * 0.01)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.92, y: rect.height * 0.03),
            control: CGPoint(x: rect.width * 0.87, y: rect.height * 0.05)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.06),
            control: CGPoint(x: rect.width * 0.96, y: rect.height * 0.02)
        )

        // Right cliff face — slight inward curve (glacier calving face)
        path.addCurve(
            to: CGPoint(x: rect.width * 0.98, y: rect.height * 0.45),
            control1: CGPoint(x: rect.width * 1.02, y: rect.height * 0.20),
            control2: CGPoint(x: rect.width * 0.96, y: rect.height * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.99, y: rect.height),
            control1: CGPoint(x: rect.width * 1.01, y: rect.height * 0.60),
            control2: CGPoint(x: rect.width * 0.97, y: rect.height * 0.80)
        )

        // Bottom
        path.addLine(to: CGPoint(x: 0, y: rect.height))

        // Left cliff face
        path.addCurve(
            to: CGPoint(x: rect.width * 0.02, y: rect.height * 0.40),
            control1: CGPoint(x: -rect.width * 0.01, y: rect.height * 0.75),
            control2: CGPoint(x: rect.width * 0.03, y: rect.height * 0.55)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: rect.height * 0.08),
            control1: CGPoint(x: -rect.width * 0.01, y: rect.height * 0.25),
            control2: CGPoint(x: rect.width * 0.02, y: rect.height * 0.12)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Glacial Bands

/// Horizontal stratification lines in the ice cliff — shows layers of
/// compressed snow from different years, a signature look of Antarctic glaciers.
private struct GlacialBands: View {
    let time: AntarcticTimeOfDay

    private var bandColor: Color {
        switch time {
        case .dawn:  return Color(hex: "C0A0B0")
        case .day:   return Color(hex: "90B8D0")
        case .dusk:  return Color(hex: "A08090")
        case .night: return Color(hex: "2A4A68")
        }
    }

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // 8-10 horizontal strata lines at varying heights
            let bandPositions: [CGFloat] = [0.10, 0.18, 0.28, 0.35, 0.44, 0.55, 0.64, 0.72, 0.82, 0.90]

            for (i, yFrac) in bandPositions.enumerated() {
                let y = h * yFrac
                let startX = CGFloat(i % 2 == 0 ? 0 : 8)
                let endX = w - CGFloat(i % 3 == 0 ? 0 : 12)

                // Slightly wavy horizontal line
                let path = Path { p in
                    p.move(to: CGPoint(x: startX, y: y))
                    let segments = 6
                    for s in 1...segments {
                        let sx = startX + (endX - startX) * CGFloat(s) / CGFloat(segments)
                        let sy = y + CGFloat(sin(Double(s) * 2.0 + Double(i))) * 2.0
                        p.addLine(to: CGPoint(x: sx, y: sy))
                    }
                }

                // Alternate between lighter and darker bands
                let opacity = i % 2 == 0 ? 0.18 : 0.12
                context.stroke(path, with: .color(bandColor.opacity(opacity)), lineWidth: i % 3 == 0 ? 2.0 : 1.2)

                // Occasional thicker "blue ice" band
                if i == 3 || i == 7 {
                    let thickPath = Path { p in
                        p.move(to: CGPoint(x: 0, y: y + 2))
                        p.addLine(to: CGPoint(x: w, y: y + 2 + CGFloat(sin(Double(i))) * 1.5))
                    }
                    context.stroke(thickPath, with: .color(Color(hex: "4A8AB0").opacity(0.22)), lineWidth: 3.0)
                }
            }
        }
    }
}

// MARK: - Friendly Snow Surface

private struct FriendlySnowSurface: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.height))

        let bumps: [(x: CGFloat, y: CGFloat)] = [
            (0.00, 0.7),
            (0.06, 0.5),
            (0.12, 0.3),
            (0.20, 0.45),
            (0.28, 0.2),
            (0.36, 0.35),
            (0.44, 0.15),
            (0.52, 0.25),
            (0.60, 0.1),
            (0.68, 0.2),
            (0.76, 0.3),
            (0.84, 0.15),
            (0.92, 0.35),
            (1.00, 0.6),
        ]

        for (i, bump) in bumps.enumerated() {
            let x = bump.x * rect.width
            let y = rect.height * bump.y

            if i == 0 {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                let prev = bumps[i - 1]
                let prevX = prev.x * rect.width
                path.addQuadCurve(
                    to: CGPoint(x: x, y: y),
                    control: CGPoint(x: (prevX + x) / 2, y: min(y, rect.height * prev.y) - 2)
                )
            }
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Friendly Ice Body

private struct FriendlyIceBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.height * 0.12))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.06),
            control: CGPoint(x: rect.width * 0.08, y: rect.height * 0.08)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.35, y: rect.height * 0.03),
            control: CGPoint(x: rect.width * 0.25, y: rect.height * 0.01)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.55, y: rect.height * 0.04),
            control: CGPoint(x: rect.width * 0.45, y: rect.height * 0.02)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.05),
            control: CGPoint(x: rect.width * 0.65, y: rect.height * 0.03)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.10),
            control: CGPoint(x: rect.width * 0.90, y: rect.height * 0.04)
        )

        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.50),
            control: CGPoint(x: rect.width * 1.02, y: rect.height * 0.30)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.97, y: rect.height),
            control: CGPoint(x: rect.width * 0.93, y: rect.height * 0.75)
        )

        path.addLine(to: CGPoint(x: 0, y: rect.height))

        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.03, y: rect.height * 0.40),
            control: CGPoint(x: -rect.width * 0.02, y: rect.height * 0.70)
        )
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height * 0.12),
            control: CGPoint(x: rect.width * 0.05, y: rect.height * 0.25)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Ice Veins

private struct IceVeins: View {
    let time: AntarcticTimeOfDay

    private var veinColor: Color {
        switch time {
        case .dawn:  return Color(hex: "B0A0C0")
        case .day:   return Color(hex: "8AB8D0")
        case .dusk:  return Color(hex: "9A7088")
        case .night: return Color(hex: "3A5A78")
        }
    }

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            let veins: [(start: CGPoint, end: CGPoint, ctrl: CGPoint)] = [
                (
                    CGPoint(x: w * 0.10, y: h * 0.10),
                    CGPoint(x: w * 0.25, y: h * 0.65),
                    CGPoint(x: w * 0.18, y: h * 0.35)
                ),
                (
                    CGPoint(x: w * 0.40, y: h * 0.08),
                    CGPoint(x: w * 0.35, y: h * 0.75),
                    CGPoint(x: w * 0.42, y: h * 0.40)
                ),
                (
                    CGPoint(x: w * 0.65, y: h * 0.05),
                    CGPoint(x: w * 0.70, y: h * 0.60),
                    CGPoint(x: w * 0.62, y: h * 0.30)
                ),
                (
                    CGPoint(x: w * 0.85, y: h * 0.12),
                    CGPoint(x: w * 0.80, y: h * 0.70),
                    CGPoint(x: w * 0.88, y: h * 0.38)
                ),
            ]

            for vein in veins {
                let path = Path { p in
                    p.move(to: vein.start)
                    p.addQuadCurve(to: vein.end, control: vein.ctrl)
                }
                context.opacity = 0.22
                context.stroke(path, with: .color(veinColor), lineWidth: 1.8)

                let branchEnd = CGPoint(
                    x: vein.ctrl.x + CGFloat.random(in: -30...30),
                    y: vein.ctrl.y + h * 0.2
                )
                let branchPath = Path { p in
                    p.move(to: vein.ctrl)
                    p.addLine(to: branchEnd)
                }
                context.opacity = 0.14
                context.stroke(branchPath, with: .color(veinColor), lineWidth: 0.8)
            }

            for i in 0..<4 {
                let y = h * CGFloat(i + 1) / 5
                let startX = CGFloat.random(in: 0...w * 0.2)
                let endX = startX + CGFloat.random(in: w * 0.25...w * 0.55)
                let path = Path { p in
                    p.move(to: CGPoint(x: startX, y: y))
                    p.addQuadCurve(
                        to: CGPoint(x: endX, y: y + CGFloat.random(in: -6...6)),
                        control: CGPoint(x: (startX + endX) / 2, y: y + CGFloat.random(in: -4...4))
                    )
                }
                context.opacity = 0.16
                context.stroke(path, with: .color(veinColor), lineWidth: 1.0)
            }
        }
    }
}

// MARK: - Cinematic Icicles

private struct CinematicIcicles: View {
    let count: Int
    let maxLength: CGFloat
    let time: AntarcticTimeOfDay

    var body: some View {
        Canvas { context, size in
            let spacing = size.width / CGFloat(count + 1)

            for i in 1...count {
                let x = spacing * CGFloat(i) + CGFloat.random(in: -6...6)
                let length = CGFloat.random(in: maxLength * 0.2...maxLength)
                let width = CGFloat.random(in: 1.5...4.5)

                let path = Path { p in
                    p.move(to: CGPoint(x: x - width / 2, y: 0))
                    p.addQuadCurve(
                        to: CGPoint(x: x - width * 0.15, y: length * 0.7),
                        control: CGPoint(x: x - width * 0.4, y: length * 0.4)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: x, y: length),
                        control: CGPoint(x: x - width * 0.08, y: length * 0.9)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: x + width * 0.15, y: length * 0.6),
                        control: CGPoint(x: x + width * 0.08, y: length * 0.85)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: x + width / 2, y: 0),
                        control: CGPoint(x: x + width * 0.4, y: length * 0.3)
                    )
                    p.closeSubpath()
                }

                context.opacity = Double.random(in: 0.45...0.80)
                context.fill(path, with: .linearGradient(
                    Gradient(colors: [
                        time.icicleColor.opacity(0.7),
                        time.icicleColor,
                        Color.white.opacity(0.6),
                    ]),
                    startPoint: CGPoint(x: x, y: 0),
                    endPoint: CGPoint(x: x, y: length)
                ))

                if width > 2.5 {
                    let highlight = Path { p in
                        p.move(to: CGPoint(x: x - width * 0.15, y: length * 0.1))
                        p.addLine(to: CGPoint(x: x - width * 0.1, y: length * 0.6))
                    }
                    context.opacity = 0.35
                    context.stroke(highlight, with: .color(.white), lineWidth: 0.8)
                }
            }
        }
    }
}

// MARK: - Fish Bucket Prop

private struct BucketBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            // Top rim
            p.move(to: CGPoint(x: w * 0.18, y: h * 0.28))
            // Left wall — slight outward bow
            p.addCurve(
                to: CGPoint(x: w * 0.10, y: h * 0.95),
                control1: CGPoint(x: w * 0.16, y: h * 0.48),
                control2: CGPoint(x: w * 0.08, y: h * 0.78)
            )
            // Bottom — smooth rounded base
            p.addCurve(
                to: CGPoint(x: w * 0.90, y: h * 0.95),
                control1: CGPoint(x: w * 0.25, y: h * 1.06),
                control2: CGPoint(x: w * 0.75, y: h * 1.06)
            )
            // Right wall — slight outward bow
            p.addCurve(
                to: CGPoint(x: w * 0.82, y: h * 0.28),
                control1: CGPoint(x: w * 0.92, y: h * 0.78),
                control2: CGPoint(x: w * 0.84, y: h * 0.48)
            )
            p.closeSubpath()
        }
    }
}

private struct BucketHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width
            p.addArc(
                center: CGPoint(x: w / 2, y: rect.height * 0.26),
                radius: w * 0.26,
                startAngle: .degrees(185),
                endAngle: .degrees(-5),
                clockwise: false
            )
        }
    }
}

private struct TinyFishShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            let cx = w * 0.5, cy = h * 0.5
            let sz = min(w, h) * 0.4
            // Nose
            p.move(to: CGPoint(x: cx - sz, y: cy))
            // Top body arc — smooth belly
            p.addCurve(
                to: CGPoint(x: cx + sz * 0.6, y: cy),
                control1: CGPoint(x: cx - sz * 0.3, y: cy - sz * 0.62),
                control2: CGPoint(x: cx + sz * 0.25, y: cy - sz * 0.58)
            )
            // Tail fork
            p.addLine(to: CGPoint(x: cx + sz, y: cy - sz * 0.35))
            p.addLine(to: CGPoint(x: cx + sz * 0.6, y: cy))
            p.addLine(to: CGPoint(x: cx + sz, y: cy + sz * 0.35))
            // Bottom body arc — smooth belly
            p.addCurve(
                to: CGPoint(x: cx - sz, y: cy),
                control1: CGPoint(x: cx + sz * 0.25, y: cy + sz * 0.58),
                control2: CGPoint(x: cx - sz * 0.3, y: cy + sz * 0.62)
            )
            p.closeSubpath()
        }
    }
}

private struct FishBucket: View {
    let fishCount: Int
    let tint: Color

    private var fillLevel: CGFloat {
        min(1.0, CGFloat(fishCount) / 50.0)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // ── Dark bucket interior ──
            BucketBodyShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1A1208"), Color(hex: "0E0A04")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w, height: h)

            // ── Fish fill (golden mass — visible inside) ──
            if fishCount > 0 {
                BucketFillShape(fillLevel: fillLevel)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FFD040"), Color(hex: "FFB800"), Color(hex: "E67A00")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w, height: h)
            }

            // ── Bucket walls (thick stroke, not filled — lets interior show) ──
            BucketBodyShape()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "8B6B30"), Color(hex: "6B4A1A"), Color(hex: "3A280A")],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 3.5
                )
                .frame(width: w, height: h)

            // ── Metal bands ──
            ForEach([0.45, 0.70] as [CGFloat], id: \.self) { frac in
                Rectangle()
                    .fill(Color(hex: "888888"))
                    .frame(width: w * 0.72, height: 1.2)
                    .position(x: w * 0.5, y: h * frac)
            }

            // ── Rim ──
            Rectangle()
                .fill(Color(hex: "999999"))
                .frame(width: w * 0.7, height: 2)
                .position(x: w * 0.5, y: h * 0.26)

            // ── Handle ──
            BucketHandleShape()
                .stroke(Color(hex: "808080"), lineWidth: 1.8)
                .frame(width: w, height: h)

            // ── Fish inside ──
            if fishCount > 0 {
                let positions: [(x: CGFloat, y: CGFloat)] = [
                    (0.35, 0.65), (0.55, 0.72), (0.45, 0.82),
                    (0.30, 0.76), (0.62, 0.62), (0.50, 0.55),
                ]
                let visible = min(positions.count, max(1, fishCount / 2))
                ForEach(0..<visible, id: \.self) { i in
                    TinyFishShape()
                        .fill(Color(hex: "FFD700"))
                        .frame(width: 10, height: 8)
                        .position(x: w * positions[i].x, y: h * positions[i].y)
                }
            }
        }
    }
}

/// Fill inside the bucket — clips to bucket walls at the given level.
private struct BucketFillShape: Shape {
    let fillLevel: CGFloat
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            let fillTop = h * (1.0 - fillLevel * 0.58)
            let wallSlope = (h * 0.95 - h * 0.28)
            let topLeft = w * 0.10 + (w * 0.18 - w * 0.10) * ((h * 0.95 - fillTop) / wallSlope)
            let topRight = w * 0.90 - (w * 0.90 - w * 0.82) * ((h * 0.95 - fillTop) / wallSlope)
            p.move(to: CGPoint(x: topLeft, y: fillTop))
            // Left wall to bottom
            p.addCurve(
                to: CGPoint(x: w * 0.10, y: h * 0.95),
                control1: CGPoint(x: topLeft - w * 0.01, y: fillTop + (h * 0.95 - fillTop) * 0.4),
                control2: CGPoint(x: w * 0.08, y: h * 0.82)
            )
            // Rounded bottom — matches bucket body
            p.addCurve(
                to: CGPoint(x: w * 0.90, y: h * 0.95),
                control1: CGPoint(x: w * 0.25, y: h * 1.06),
                control2: CGPoint(x: w * 0.75, y: h * 1.06)
            )
            // Right wall back up
            p.addCurve(
                to: CGPoint(x: topRight, y: fillTop),
                control1: CGPoint(x: w * 0.92, y: h * 0.82),
                control2: CGPoint(x: topRight + w * 0.01, y: fillTop + (h * 0.95 - fillTop) * 0.4)
            )
            p.closeSubpath()
        }
    }
}

// MARK: - Level Flag

private struct FlagPennantShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: 0))
            // Top edge — waves outward
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.35),
                control1: CGPoint(x: w * 0.35, y: -h * 0.08),
                control2: CGPoint(x: w * 0.82, y: h * 0.12)
            )
            // Bottom edge — waves back with taper
            p.addCurve(
                to: CGPoint(x: 0, y: h),
                control1: CGPoint(x: w * 0.88, y: h * 0.52),
                control2: CGPoint(x: w * 0.35, y: h * 0.88)
            )
            p.closeSubpath()
        }
    }
}

private struct LevelFlag: View {
    let level: Int
    let time: AntarcticTimeOfDay

    private var flagColor: Color {
        switch time {
        case .dawn:  return Color(hex: "FF6B88")
        case .day:   return Color(hex: "4A9AC7")
        case .dusk:  return Color(hex: "CC6B3A")
        case .night: return Color(hex: "7B61FF")
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Snow mound base
            SnowMoundBaseShape()
                .fill(Color(hex: "D8E8F4"))
                .frame(width: w * 0.70, height: h * 0.12)
                .position(x: w * 0.5, y: h * 0.92)

            // Pole
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "C0C0C0"), Color(hex: "808080")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: w * 0.08, height: h * 0.92)
                .position(x: w * 0.5, y: h * 0.46)

            // Pole ball top
            Circle()
                .fill(Color(hex: "D0D0D0"))
                .frame(width: w * 0.16, height: w * 0.16)
                .position(x: w * 0.5, y: h * 0.02)

            // Flag pennant
            FlagPennantShape()
                .fill(
                    LinearGradient(
                        colors: [flagColor, flagColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: w * 0.42, height: h * 0.24)
                .position(x: w * 0.75, y: h * 0.18)

            FlagPennantShape()
                .stroke(flagColor, lineWidth: 0.8)
                .frame(width: w * 0.42, height: h * 0.24)
                .position(x: w * 0.75, y: h * 0.18)

            // Level number
            Text("\(level)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .position(x: w * 0.72, y: h * 0.18)
        }
    }
}

/// Flat snow mound base for flag pole.
private struct SnowMoundBaseShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: h))
            // Smooth symmetrical mound
            p.addCurve(
                to: CGPoint(x: w, y: h),
                control1: CGPoint(x: w * 0.12, y: -h * 0.08),
                control2: CGPoint(x: w * 0.88, y: -h * 0.08)
            )
            p.closeSubpath()
        }
    }
}

// MARK: - Cliff Lantern

private struct LanternCapShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: h))
            // Left edge — slight outward bow
            p.addCurve(
                to: CGPoint(x: w * 0.2, y: 0),
                control1: CGPoint(x: w * 0.02, y: h * 0.6),
                control2: CGPoint(x: w * 0.12, y: h * 0.1)
            )
            // Top — gentle crown curve
            p.addCurve(
                to: CGPoint(x: w * 0.8, y: 0),
                control1: CGPoint(x: w * 0.35, y: -h * 0.08),
                control2: CGPoint(x: w * 0.65, y: -h * 0.08)
            )
            // Right edge — slight outward bow
            p.addCurve(
                to: CGPoint(x: w, y: h),
                control1: CGPoint(x: w * 0.88, y: h * 0.1),
                control2: CGPoint(x: w * 0.98, y: h * 0.6)
            )
            p.closeSubpath()
        }
    }
}

private struct LanternBaseShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: 0))
            // Top edge
            p.addCurve(
                to: CGPoint(x: w, y: 0),
                control1: CGPoint(x: w * 0.33, y: -h * 0.06),
                control2: CGPoint(x: w * 0.66, y: -h * 0.06)
            )
            // Right side — tapers inward
            p.addCurve(
                to: CGPoint(x: w * 0.9, y: h),
                control1: CGPoint(x: w * 0.98, y: h * 0.35),
                control2: CGPoint(x: w * 0.94, y: h * 0.7)
            )
            // Bottom
            p.addCurve(
                to: CGPoint(x: w * 0.1, y: h),
                control1: CGPoint(x: w * 0.66, y: h * 1.05),
                control2: CGPoint(x: w * 0.33, y: h * 1.05)
            )
            // Left side
            p.addCurve(
                to: CGPoint(x: 0, y: 0),
                control1: CGPoint(x: w * 0.06, y: h * 0.7),
                control2: CGPoint(x: w * 0.02, y: h * 0.35)
            )
        }
    }
}

private struct LanternHookShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.addArc(
                center: CGPoint(x: rect.width * 0.5, y: rect.height * 0.5),
                radius: rect.width * 0.35,
                startAngle: .degrees(190),
                endAngle: .degrees(-10),
                clockwise: false
            )
        }
    }
}

private struct LanternFlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            let cx = w * 0.5
            // Tip
            p.move(to: CGPoint(x: cx, y: 0))
            // Right side — bulge then taper
            p.addCurve(
                to: CGPoint(x: cx + w * 0.3, y: h * 0.5),
                control1: CGPoint(x: cx + w * 0.04, y: h * 0.04),
                control2: CGPoint(x: cx + w * 0.42, y: h * 0.2)
            )
            // Bottom arc — smooth rounded base
            p.addCurve(
                to: CGPoint(x: cx - w * 0.3, y: h * 0.5),
                control1: CGPoint(x: cx + w * 0.18, y: h * 0.78),
                control2: CGPoint(x: cx - w * 0.18, y: h * 0.78)
            )
            // Left side — back to tip
            p.addCurve(
                to: CGPoint(x: cx, y: 0),
                control1: CGPoint(x: cx - w * 0.42, y: h * 0.2),
                control2: CGPoint(x: cx - w * 0.04, y: h * 0.04)
            )
        }
    }
}

private struct CliffLantern: View {
    let time: AntarcticTimeOfDay

    private var isLit: Bool {
        time == .night || time == .dusk
    }

    private var glowColor: Color {
        isLit ? Color(hex: "FFB800") : Color(hex: "FFD080")
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Ambient glow
            if isLit {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                glowColor.opacity(0.5),
                                glowColor.opacity(0.2),
                                glowColor.opacity(0.05),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 3,
                            endRadius: 28
                        )
                    )
                    .frame(width: 56, height: 56)
                    .position(x: w * 0.5, y: h * 0.45)
            }

            // Hook
            LanternHookShape()
                .stroke(Color(hex: "777777"), lineWidth: 1.5)
                .frame(width: w * 0.5, height: h * 0.18)
                .position(x: w * 0.5, y: h * 0.12)

            // Cap
            LanternCapShape()
                .fill(Color(hex: "555555"))
                .frame(width: w * 0.56, height: h * 0.08)
                .position(x: w * 0.5, y: h * 0.24)

            // Chimney vent
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(hex: "444444"))
                .frame(width: w * 0.16, height: h * 0.06)
                .position(x: w * 0.5, y: h * 0.19)

            // Glass housing body
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "8B6914"), Color(hex: "6B4A0A")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: w * 0.56, height: h * 0.48)
                .position(x: w * 0.5, y: h * 0.50)

            // Glass pane
            RoundedRectangle(cornerRadius: 2)
                .fill(isLit ? Color(hex: "FFD060") : Color(hex: "A0B8CC"))
                .frame(width: w * 0.46, height: h * 0.40)
                .position(x: w * 0.5, y: h * 0.50)

            // Candle flame
            if isLit {
                LanternFlameShape()
                    .fill(
                        LinearGradient(
                            colors: [.white, Color(hex: "FFE066"), Color(hex: "FF8C00")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8, height: 12)
                    .position(x: w * 0.5, y: h * 0.42)
            }

            // Vertical metal frame line
            Rectangle()
                .fill(Color(hex: "666666").opacity(0.5))
                .frame(width: 0.8, height: h * 0.48)
                .position(x: w * 0.5, y: h * 0.50)

            // Bottom base
            LanternBaseShape()
                .fill(Color(hex: "666666"))
                .frame(width: w * 0.64, height: h * 0.08)
                .position(x: w * 0.5, y: h * 0.78)

            // Stand
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(hex: "555555"))
                .frame(width: w * 0.40, height: h * 0.08)
                .position(x: w * 0.5, y: h * 0.86)
        }
    }
}

// MARK: - Previews

#Preview("Dawn — Warming") {
    AntarcticEnvironment(mood: .warming, unlockedProps: [], fishCount: 12, level: 2, stage: .bareIce, timeOverride: .dawn)
        .ignoresSafeArea()
}

#Preview("Day — Productive") {
    AntarcticEnvironment(mood: .productive, unlockedProps: ["igloo"], fishCount: 35, level: 7, stage: .fishingPier, timeOverride: .day)
        .ignoresSafeArea()
}

#Preview("Dusk — Golden") {
    AntarcticEnvironment(mood: .golden, unlockedProps: [], fishCount: 40, level: 10, stage: .cozyCamp, timeOverride: .dusk)
        .ignoresSafeArea()
}

#Preview("Night — Cozy Camp") {
    AntarcticEnvironment(mood: .golden, unlockedProps: ["igloo", "campfire", "lantern"], fishCount: 50, level: 12, stage: .cozyCamp, timeOverride: .night)
        .ignoresSafeArea()
}

#Preview("Night — Summit Lodge") {
    AntarcticEnvironment(mood: .productive, unlockedProps: ["lantern"], fishCount: 80, level: 15, stage: .summitLodge, timeOverride: .night)
        .ignoresSafeArea()
}

#Preview("Storm") {
    AntarcticEnvironment(mood: .stormy, unlockedProps: [], fishCount: 5, level: 3, stage: .bareIce, timeOverride: .day)
        .ignoresSafeArea()
}
