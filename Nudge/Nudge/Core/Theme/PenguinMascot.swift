//
//  PenguinMascot.swift
//  Nudge
//
//  Character mascot drawn with SwiftUI bezier Path curves.
//  Matches the app icon penguin (generate_app_icon_v2.py) exactly.
//  See nudge-penguin-spec.md for the full character specification.
//
//  6 expression states: idle, happy, thinking, sleeping, celebrating, thumbsUp.
//  Adapts accent color via accentColor parameter.
//  All animations respect @Environment(\.accessibilityReduceMotion).
//

import SwiftUI

// MARK: - Penguin Expression State

enum PenguinExpression: String, CaseIterable {
    // Original states (rendering preserved)
    case idle         // Neutral — slow blink + gentle sway
    case happy        // Task done — crescent eyes, bounce
    case thinking     // Brain dump processing — tilted head, dots
    case sleeping     // Empty state — closed eyes, content
    case celebrating  // All clear — arms up, sparkles
    case thumbsUp     // Share saved — one arm raised
    
    // New interactive states (will get unique rendering in new penguin)
    // For now they fall through to closest existing expression in PenguinMascot
    case listening    // Brain dump — mic active, leaning forward
    case talking      // Speaking via speech bubble — beak open
    case waving       // Greeting on app open
    case nudging      // Tapping watch, pointing at a task
    case confused     // Voice input unclear / error state
    case typing       // Quick-add mode — pecking motion
    case shy          // Overwhelmed or complimented — extra blush, looking down
    case mischievous  // Playful mood — asymmetric smirk, one eyebrow raised
}

// MARK: - Color Constants (matches icon generator palette)

private enum PenguinColors {
    static let plumageDark = Color(hex: "1A1A2E")
    static let plumageHighlight = Color(hex: "2A2A42")
    static let bellyTop = Color(hex: "F5F5F7")
    static let bellyBottom = Color(hex: "E8E8EC")
    static let eyeBlack = Color(hex: "0A0A0E")
    static let blush = Color(hex: "FF6B8A")
}

// MARK: - Penguin Mascot View

struct PenguinMascot: View {
    let expression: PenguinExpression
    let size: CGFloat
    var accentColor: Color = DesignTokens.accentActive
    var showBeanie: Bool = true
    
    @State private var blinkPhase = false
    @State private var swayOffset: CGFloat = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var dotPhase = 0
    @State private var breatheScale: CGFloat = 1.0
    @State private var zzzOpacity: [Double] = [0.6, 0.4, 0.2]
    @State private var zzzOffset: [CGFloat] = [0, 0, 0]
    @State private var flipperSway: CGFloat = 0
    @State private var microRotation: Double = 0
    
    // Cancellable animation tasks (prevents leaked recursive asyncAfter chains)
    @State private var blinkTask: Task<Void, Never>?
    @State private var dotCycleTask: Task<Void, Never>?
    @State private var talkingBobTask: Task<Void, Never>?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Reference size — all proportions are fractions of `p`
    // Matches generate_app_icon_v2.py psize exactly.
    private var p: CGFloat { size }
    
    var body: some View {
        ZStack {
            // Ground contact shadow — elliptical shadow under the feet
            // (Pixar always grounds characters with a soft contact shadow)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.22),
                            Color.black.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: p * 0.21
                    )
                )
                .frame(width: p * 0.40, height: p * 0.06)
                .offset(y: p * 0.54)
            
            penguinFeet
            penguinBody
            penguinBelly
            
            // Ambient occlusion — soft shadow under chin where head meets body
            // (creates depth at the junction — Pixar lighting principle)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.14),
                            Color.black.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: p * 0.15
                    )
                )
                .frame(width: p * 0.32, height: p * 0.065)
                .offset(y: p * 0.005)
            
            penguinWings
            penguinHead
            penguinFacePatch
            if showBeanie {
                penguinBeanie
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.05, anchor: .bottom)
                                .combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
            penguinCheekBlush
            penguinEyes
            penguinEyebrows
            penguinBeak
            penguinAccessories
        }
        .frame(width: size, height: size * 1.15)
        .drawingGroup()  // Flatten 15+ gradient layers into a single GPU texture
        .scaleEffect(breatheScale)
        .rotationEffect(.degrees(reduceMotion ? 0 : microRotation))
        .offset(x: reduceMotion ? 0 : swayOffset, y: bounceOffset)
        .onAppear { startAnimations() }
        .onDisappear {
            blinkTask?.cancel()
            dotCycleTask?.cancel()
            talkingBobTask?.cancel()
        }
        .nudgeAccessibility(
            label: penguinAccessibilityLabel,
            traits: .isImage
        )
    }
    
    // ┌────────────────────────────────────────────────────────────┐
    // │  All proportions below are direct ports from the Cairo    │
    // │  icon generator (generate_app_icon_v2.py). The `p`       │
    // │  variable equals `psize` in the Python code.             │
    // │  cx,cy in Python → center of the frame here.             │
    // │  Offsets are relative to frame center (0,0).              │
    // └────────────────────────────────────────────────────────────┘
    
    // MARK: - Body (slightly slimmed snowball — 10% less round)
    //  Slimmed: body_w = 0.79p, body_h = 0.94p, offset +7%
    //  Still huggable, but a touch more character definition.
    
    private var penguinBody: some View {
        ZStack {
            PenguinBodyShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "343450"), // PLUMAGE_EDGE equivalent
                            PenguinColors.plumageDark,
                            PenguinColors.plumageDark,
                            Color(hex: "343450"),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Radial gradient overlay for 3D depth
            PenguinBodyShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.clear,
                            Color.black.opacity(0.10)
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: p * 0.43
                    )
                )
            
            // Pixar rim light — subtle edge highlight on the left side
            PenguinBodyShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "6688BB").opacity(0.35),
                            Color(hex: "6688BB").opacity(0.12),
                            Color.clear,
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: p * 0.008
                )
            
            // Feather texture hint — barely visible curved lines
            Path { path in
                // Left shoulder feather arc
                path.move(to: CGPoint(x: p * 0.79 * 0.16, y: p * 0.94 * 0.32))
                path.addCurve(
                    to: CGPoint(x: p * 0.79 * 0.22, y: p * 0.94 * 0.52),
                    control1: CGPoint(x: p * 0.79 * 0.10, y: p * 0.94 * 0.39),
                    control2: CGPoint(x: p * 0.79 * 0.16, y: p * 0.94 * 0.47)
                )
                // Right shoulder feather arc
                path.move(to: CGPoint(x: p * 0.79 * 0.84, y: p * 0.94 * 0.32))
                path.addCurve(
                    to: CGPoint(x: p * 0.79 * 0.78, y: p * 0.94 * 0.52),
                    control1: CGPoint(x: p * 0.79 * 0.90, y: p * 0.94 * 0.39),
                    control2: CGPoint(x: p * 0.79 * 0.84, y: p * 0.94 * 0.47)
                )
            }
            .stroke(Color.white.opacity(0.04), lineWidth: p * 0.004)

        }
        .frame(width: p * 0.79, height: p * 0.94)
        .offset(y: p * 0.07)
        .shadow(color: Color.black.opacity(0.25), radius: p * 0.04, y: p * 0.03)
    }
    
    // MARK: - Belly (proportional to slimmed body)
    //  Slimmed: belly_w = 0.58p, belly_h = 0.76p, offset +13%
    
    private var penguinBelly: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "FFE066"), location: 0.0),
                            .init(color: Color(hex: "FFF0B0"), location: 0.30),
                            .init(color: Color(hex: "F5F5F7"), location: 0.65),
                            .init(color: Color(hex: "F5F5F7"), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Subsurface scattering — warm pinkish glow from within
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            PenguinColors.blush.opacity(0.06),
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        center: .init(x: 0.5, y: 0.45),
                        startRadius: 0,
                        endRadius: p * 0.22
                    )
                )
            
            // Specular highlight — top-left sheen (key light reflection)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06),
                            Color.clear
                        ],
                        center: .init(x: 0.35, y: 0.28),
                        startRadius: 0,
                        endRadius: p * 0.13
                    )
                )

            // Belly button — ∩ shape (upside-down U navel)
            Path { path in
                let bw = p * 0.58
                let bh = p * 0.76
                let cx = bw * 0.50
                let cy = bh * 0.70
                let r  = p * 0.028
                // Start bottom-left, arc UPWARD to bottom-right → ∩
                path.move(to: CGPoint(x: cx - r, y: cy))
                path.addCurve(
                    to:       CGPoint(x: cx + r, y: cy),
                    control1: CGPoint(x: cx - r * 0.6, y: cy - r * 1.3),
                    control2: CGPoint(x: cx + r * 0.6, y: cy - r * 1.3)
                )
            }
            .stroke(
                Color.black.opacity(0.20),
                style: StrokeStyle(lineWidth: p * 0.007, lineCap: .round)
            )
        }
        .frame(width: p * 0.58, height: p * 0.76)
        .offset(y: p * 0.13)
    }
    
    // MARK: - Head (same size, sunk into chubby body)
    //  Size unchanged: 0.605p × 0.56p. Offset -19% (was -22%)
    //  Head sinks 3% deeper to merge with wider body — no neck gap.
    
    private var penguinHead: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [PenguinColors.plumageHighlight, PenguinColors.plumageDark],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: p * 0.34
                    )
                )
            
            // Rim light on head — matches body rim for consistent lighting
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "6688BB").opacity(0.30),
                            Color(hex: "6688BB").opacity(0.08),
                            Color.clear,
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: p * 0.006
                )
        }
        .frame(width: p * 0.605, height: p * 0.56)
        .rotationEffect(.degrees(headTilt))
        .offset(y: -p * 0.19)
    }
    
    // MARK: - Face Patch (white area — follows head offset)
    //  Same size, offset cascades with head: -15% (was -18%)
    
    private var penguinFacePatch: some View {
        Ellipse()
            .fill(Color.white)
            .frame(width: p * 0.40, height: p * 0.34)
            .rotationEffect(.degrees(headTilt))
            .offset(y: -p * 0.15)
    }
    
    // MARK: - Eyes (follow head offset)
    //  Same size, offset cascades with head: -18% (was -21%)
    
    private var penguinEyes: some View {
        HStack(spacing: p * 0.095) {
            eyeView(isRight: false)
            eyeView(isRight: true)
        }
        .rotationEffect(.degrees(headTilt))
        .offset(y: -p * 0.18)
    }
    
    @ViewBuilder
    private func eyeView(isRight: Bool) -> some View {
        // Python: base_r = psize * 0.042, er = base_r * (1.05 if right else 1.0)
        // Diameter = 0.084 (left) / 0.0882 (right)
        let eyeSize = p * (isRight ? 0.088 : 0.084)
        
        switch expression {
        case .idle, .listening, .waving, .nudging, .typing:
            // Round eyes with shine — blink animates height
            ZStack {
                // Eye white ring
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize * 1.15, height: blinkPhase ? p * 0.008 : eyeSize * 1.15)
                
                // Pupil
                Circle()
                    .fill(PenguinColors.eyeBlack)
                    .frame(width: eyeSize, height: blinkPhase ? p * 0.006 : eyeSize)
                
                if !blinkPhase {
                    // Main shine (top-right)
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: eyeSize * 0.38, height: eyeSize * 0.38)
                        .offset(x: eyeSize * 0.28, y: -eyeSize * 0.30)
                    
                    // Secondary shine (bottom-left)
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: eyeSize * 0.18, height: eyeSize * 0.18)
                        .offset(x: -eyeSize * 0.22, y: eyeSize * 0.28)
                }
            }
            
        case .happy, .talking:
            // Crescent "smile" eyes — upward arcs
            CrescentEye()
                .fill(PenguinColors.eyeBlack)
                .frame(width: eyeSize * 1.1, height: eyeSize * 0.45)
            
        case .celebrating:
            // ★ Star eyes — pure excitement!
            ZStack {
                StarEye()
                    .fill(accentColor)
                    .frame(width: eyeSize * 1.4, height: eyeSize * 1.4)
                StarEye()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: eyeSize * 0.7, height: eyeSize * 0.7)
            }
            
        case .sleeping:
            // Closed — gentle downward arcs with lash
            SleepingEye()
                .stroke(PenguinColors.eyeBlack, style: StrokeStyle(lineWidth: p * 0.008, lineCap: .round))
                .frame(width: eyeSize * 0.9, height: eyeSize * 0.35)
            
        case .thinking, .confused:
            // Wide open, looking up-right
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize * 1.2, height: eyeSize * 1.2)
                Circle()
                    .fill(PenguinColors.eyeBlack)
                    .frame(width: eyeSize * 1.05, height: eyeSize * 1.05)
                    .offset(x: p * 0.006, y: -p * 0.008)
                // Shine
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: eyeSize * 0.38, height: eyeSize * 0.38)
                    .offset(x: eyeSize * 0.18, y: -eyeSize * 0.20)
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: eyeSize * 0.18, height: eyeSize * 0.18)
                    .offset(x: -eyeSize * 0.12, y: eyeSize * 0.18)
            }
            
        case .thumbsUp:
            // Warm, normal, with wink on right eye
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize * 1.15, height: eyeSize * 1.15)
                Circle()
                    .fill(PenguinColors.eyeBlack)
                    .frame(width: eyeSize, height: isRight ? eyeSize * 0.25 : eyeSize)
                if !isRight {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: eyeSize * 0.38, height: eyeSize * 0.38)
                        .offset(x: eyeSize * 0.28, y: -eyeSize * 0.30)
                }
            }
            
        case .shy:
            // Looking-down eyes with droopy half-lid
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize * 1.1, height: eyeSize * 1.1)
                Circle()
                    .fill(PenguinColors.eyeBlack)
                    .frame(width: eyeSize * 0.85, height: eyeSize * 0.85)
                    .offset(y: eyeSize * 0.18)
                Ellipse()
                    .fill(PenguinColors.plumageDark)
                    .frame(width: eyeSize * 1.3, height: eyeSize * 0.7)
                    .offset(y: -eyeSize * 0.4)
                Circle()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: eyeSize * 0.25, height: eyeSize * 0.25)
                    .offset(x: eyeSize * 0.12, y: eyeSize * 0.08)
            }
            
        case .mischievous:
            // Asymmetric — left squinted, right wide with gleam
            if isRight {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: eyeSize * 1.25, height: eyeSize * 1.25)
                    Circle()
                        .fill(PenguinColors.eyeBlack)
                        .frame(width: eyeSize * 1.05, height: eyeSize * 1.05)
                        .offset(x: -eyeSize * 0.06)
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: eyeSize * 0.4, height: eyeSize * 0.4)
                        .offset(x: eyeSize * 0.18, y: -eyeSize * 0.22)
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: eyeSize * 0.2, height: eyeSize * 0.2)
                        .offset(x: -eyeSize * 0.15, y: eyeSize * 0.15)
                }
            } else {
                CrescentEye()
                    .fill(PenguinColors.eyeBlack)
                    .frame(width: eyeSize * 0.9, height: eyeSize * 0.5)
                    .offset(y: eyeSize * 0.05)
            }
        }
    }
    
    // MARK: - Beak (follows head offset)
    //  Same size, offset cascades with head: -9.5% (was -12.5%)
    
    private var penguinBeak: some View {
        BeakShape()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "3399FF"), accentColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: p * 0.084, height: p * 0.07)
            .rotationEffect(.degrees(headTilt))
            .offset(y: -p * 0.095)
    }
    
    // MARK: - Cheek Blush
    
    /// Blush intensity increases on happy/celebrating expressions
    private var blushIntensity: Double {
        switch expression {
        case .shy:                             return 0.55
        case .happy, .celebrating, .talking:   return 0.35
        case .thumbsUp, .mischievous:          return 0.28
        default:                               return 0.18
        }
    }
    
    //  Larger, softer cheek blush — Pixar-style warmth.
    //  Radius increased 50% for that soft, glowing warmth.
    private var penguinCheekBlush: some View {
        HStack(spacing: p * 0.20) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            PenguinColors.blush.opacity(blushIntensity),
                            PenguinColors.blush.opacity(blushIntensity * 0.4),
                            PenguinColors.blush.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: p * 0.055
                    )
                )
                .frame(width: p * 0.10, height: p * 0.10)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            PenguinColors.blush.opacity(blushIntensity),
                            PenguinColors.blush.opacity(blushIntensity * 0.4),
                            PenguinColors.blush.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: p * 0.055
                    )
                )
                .frame(width: p * 0.10, height: p * 0.10)
        }
        .rotationEffect(.degrees(headTilt))
        .offset(y: -p * 0.14)
    }
    
    // MARK: - Eyebrows (expression-specific)
    
    private var penguinEyebrows: some View {
        Group {
            switch expression {
            case .confused:
                HStack(spacing: p * 0.095) {
                    Capsule()
                        .fill(PenguinColors.plumageDark)
                        .frame(width: p * 0.04, height: p * 0.008)
                        .rotationEffect(.degrees(-12))
                    Capsule()
                        .fill(PenguinColors.plumageDark)
                        .frame(width: p * 0.04, height: p * 0.008)
                        .rotationEffect(.degrees(8))
                }
                .offset(y: -p * 0.26)
                
            case .listening:
                HStack(spacing: p * 0.095) {
                    Capsule()
                        .fill(PenguinColors.plumageDark.opacity(0.6))
                        .frame(width: p * 0.035, height: p * 0.007)
                        .rotationEffect(.degrees(-5))
                    Capsule()
                        .fill(PenguinColors.plumageDark.opacity(0.6))
                        .frame(width: p * 0.035, height: p * 0.007)
                        .rotationEffect(.degrees(5))
                }
                .offset(y: -p * 0.26)
                
            case .nudging:
                HStack(spacing: p * 0.095) {
                    Capsule()
                        .fill(PenguinColors.plumageDark)
                        .frame(width: p * 0.038, height: p * 0.008)
                        .rotationEffect(.degrees(8))
                    Capsule()
                        .fill(PenguinColors.plumageDark)
                        .frame(width: p * 0.038, height: p * 0.008)
                        .rotationEffect(.degrees(-8))
                }
                .offset(y: -p * 0.26)
                
            case .mischievous:
                // One raised, one flat — cocky look
                HStack(spacing: p * 0.095) {
                    Capsule()
                        .fill(PenguinColors.plumageDark)
                        .frame(width: p * 0.04, height: p * 0.008)
                        .rotationEffect(.degrees(-15))
                        .offset(y: -p * 0.01)
                    Capsule()
                        .fill(PenguinColors.plumageDark)
                        .frame(width: p * 0.04, height: p * 0.008)
                        .rotationEffect(.degrees(3))
                }
                .offset(y: -p * 0.26)
                
            case .shy:
                // Worried upward eyebrows
                HStack(spacing: p * 0.095) {
                    Capsule()
                        .fill(PenguinColors.plumageDark.opacity(0.5))
                        .frame(width: p * 0.032, height: p * 0.006)
                        .rotationEffect(.degrees(8))
                    Capsule()
                        .fill(PenguinColors.plumageDark.opacity(0.5))
                        .frame(width: p * 0.032, height: p * 0.006)
                        .rotationEffect(.degrees(-8))
                }
                .offset(y: -p * 0.26)
                
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Wings (bezier flippers)
    //  Slightly oversized for character appeal — Pixar style.
    //  Sway independently with overlapping action.
    
    private var penguinWings: some View {
        HStack(spacing: p * 0.48) {
            // Left wing — wider spacing to sit on chubby shoulders
            WingShape()
                .fill(
                    LinearGradient(
                        colors: [PenguinColors.plumageDark, PenguinColors.plumageHighlight],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: p * 0.14, height: p * 0.28)
                .rotationEffect(.degrees(leftWingAngle + (reduceMotion ? 0 : Double(flipperSway))), anchor: .top)
            
            // Right wing
            WingShape()
                .fill(
                    LinearGradient(
                        colors: [PenguinColors.plumageHighlight, PenguinColors.plumageDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: p * 0.14, height: p * 0.28)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(rightWingAngle - (reduceMotion ? 0 : Double(flipperSway))), anchor: .top)
        }
        .offset(y: p * 0.01)
    }
    
    // MARK: - Feet (proportional stance for slimmed body)
    //  Slimmed: spacing 0.045p, size 0.16p, splayed ±10°.
    
    private var penguinFeet: some View {
        HStack(spacing: p * 0.045) {
            WebFootView(size: p * 0.16, color: Color(hex: "FF8C42"))
                .rotationEffect(.degrees(-10))
                .offset(x: -p * 0.018)
            
            WebFootView(size: p * 0.16, color: Color(hex: "FF8C42"))
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(10))
                .offset(x: p * 0.018)
        }
        .offset(y: p * 0.48)
    }
    
    // MARK: - Green Beanie
    //  Nudgy's signature forest-green knit beanie.
    //  Drawn entirely with bezier paths — no images, no transparency issues.
    //  Follows headTilt rotation and sits naturally on the crown of the head.
    
    private var penguinBeanie: some View {
        let bw = p * 0.52   // beanie dome width
        let bh = p * 0.24   // beanie dome height
        
        return ZStack {
            // Main dome — rich forest green
            BeanieShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "66BB6A"),
                            Color(hex: "4CAF50"),
                            Color(hex: "388E3C"),
                            Color(hex: "2E7D32"),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: bw, height: bh)
            
            // 3D depth — radial highlight for dome curvature
            BeanieShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.04),
                            Color.clear,
                        ],
                        center: .init(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: p * 0.22
                    )
                )
                .frame(width: bw, height: bh)
            
            // Knit ribbing texture — vertical lines across dome
            Path { path in
                let ribs = 9
                for i in 1..<ribs {
                    let frac = CGFloat(i) / CGFloat(ribs)
                    let x = bw * (0.12 + frac * 0.76)
                    // Arc from mid-dome to brim, following curve
                    path.move(to: CGPoint(x: x, y: bh * 0.18))
                    path.addCurve(
                        to: CGPoint(x: x, y: bh * 0.92),
                        control1: CGPoint(x: x + bw * 0.01, y: bh * 0.45),
                        control2: CGPoint(x: x - bw * 0.01, y: bh * 0.70)
                    )
                }
            }
            .stroke(Color.black.opacity(0.06), lineWidth: p * 0.003)
            .frame(width: bw, height: bh)
            .clipShape(BeanieShape())
            
            // Horizontal knit band — cream accent stripe across dome
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "E8E0D0").opacity(0.0),
                            Color(hex: "F5F0E8").opacity(0.35),
                            Color(hex: "F5F0E8").opacity(0.40),
                            Color(hex: "E8E0D0").opacity(0.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: bw * 0.88, height: p * 0.018)
                .offset(y: bh * 0.15)
                .clipShape(BeanieShape())
            
            // Subtle inner shadow at brim edge (depth under fold)
            BeanieShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.10),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: p * 0.008
                )
                .frame(width: bw * 0.97, height: bh * 0.97)
            
            // Rim light (left edge catch)
            BeanieShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06),
                            Color.clear,
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: p * 0.005
                )
                .frame(width: bw, height: bh)
            
            // Folded brim / cuff — double-layer knit look
            ZStack {
                // Cuff body
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "1B5E20"),
                                Color(hex: "2E7D32"),
                                Color(hex: "338833"),
                                Color(hex: "2E7D32"),
                                Color(hex: "1B5E20"),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: p * 0.55, height: p * 0.062)
                
                // Cuff top highlight (folded edge catches light)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.14),
                                Color.white.opacity(0.0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: p * 0.48, height: p * 0.012)
                    .offset(y: -p * 0.022)
                
                // Cuff knit rib marks
                HStack(spacing: p * 0.028) {
                    ForEach(0..<7, id: \.self) { _ in
                        Capsule()
                            .fill(Color.black.opacity(0.05))
                            .frame(width: p * 0.004, height: p * 0.04)
                    }
                }
            }
            .offset(y: p * 0.098)
            
            // Brim fold shadow (cast by the cuff)
            Capsule()
                .fill(Color.black.opacity(0.14))
                .frame(width: p * 0.50, height: p * 0.008)
                .offset(y: p * 0.128)
            
            // Pom-pom — fluffy yarn ball with texture
            ZStack {
                // Soft shadow underneath
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: p * 0.10, height: p * 0.06)
                    .offset(y: p * 0.008)
                
                // Base pom shape
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "FFF8F0"),
                                Color(hex: "F5F0E8"),
                                Color(hex: "E0D8C8"),
                            ],
                            center: .init(x: 0.38, y: 0.32),
                            startRadius: 0,
                            endRadius: p * 0.055
                        )
                    )
                    .frame(width: p * 0.10, height: p * 0.10)
                
                // Yarn texture — tiny overlapping circles for fluffiness
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) * .pi / 3.0
                    let r = p * 0.022
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.08...0.18)))
                        .frame(width: p * 0.035, height: p * 0.035)
                        .offset(
                            x: CGFloat(cos(angle)) * r,
                            y: CGFloat(sin(angle)) * r
                        )
                }
                
                // Specular highlight on pom
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.40), Color.clear],
                            center: .init(x: 0.35, y: 0.25),
                            startRadius: 0,
                            endRadius: p * 0.035
                        )
                    )
                    .frame(width: p * 0.08, height: p * 0.08)
                    .offset(x: -p * 0.005, y: -p * 0.008)
            }
            .offset(x: p * 0.012, y: -p * 0.14)
        }
        .rotationEffect(.degrees(headTilt))
        .offset(y: -p * 0.39)
    }
    
    // MARK: - Expression-Driven Properties
    
    private var headTilt: Double {
        switch expression {
        case .idle, .waving:   return 3
        case .happy, .talking: return 0
        case .thinking:        return -10
        case .sleeping:        return 6
        case .celebrating:     return 0
        case .thumbsUp:        return -3
        case .listening:       return -5
        case .nudging:         return -8
        case .confused:        return 12
        case .typing:          return -3
        case .shy:             return -6
        case .mischievous:     return 8
        }
    }
    
    private var leftWingAngle: Double {
        switch expression {
        case .celebrating:      return -25
        case .thumbsUp:         return 0
        case .waving:           return -20
        case .nudging:          return -15
        default:                return 8
        }
    }
    
    private var rightWingAngle: Double {
        switch expression {
        case .celebrating:      return 25
        case .thumbsUp:         return -35
        case .waving:           return 30
        case .nudging:          return -20
        default:                return -8
        }
    }
    
    // MARK: - Accessories (expression-dependent overlays)
    
    @ViewBuilder
    private var penguinAccessories: some View {
        switch expression {
        case .thinking:
            // Animated thought dots
            HStack(spacing: p * 0.025) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(accentColor)
                        .frame(width: p * 0.022 + CGFloat(i) * p * 0.005)
                        .opacity(dotPhase == i ? 1.0 : 0.25)
                }
            }
            .offset(x: p * 0.22, y: -p * 0.35)
            
        case .celebrating:
            // Confetti sparkles
            let sparkles: [(CGFloat, CGFloat, Color)] = [
                (-p * 0.28, -p * 0.39, accentColor),
                (p * 0.24, -p * 0.35, DesignTokens.accentComplete),
                (-p * 0.08, -p * 0.47, DesignTokens.accentStale),
                (p * 0.32, -p * 0.25, accentColor),
            ]
            ForEach(0..<sparkles.count, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: p * 0.045, weight: .semibold))
                    .foregroundStyle(sparkles[i].2)
                    .offset(x: sparkles[i].0, y: sparkles[i].1)
                    .opacity(0.85)
            }
            
        case .sleeping:
            // Floating zzz
            ForEach(0..<3, id: \.self) { i in
                Text("z")
                    .font(.system(size: p * (0.045 + CGFloat(i) * 0.010), weight: .medium, design: .rounded))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .opacity(zzzOpacity[i])
                    .offset(
                        x: p * (0.22 + CGFloat(i) * 0.04),
                        y: -p * (0.27 + CGFloat(i) * 0.08) + zzzOffset[i]
                    )
            }
            
        case .thumbsUp:
            // Small heart floating up from right wing
            Image(systemName: "heart.fill")
                .font(.system(size: p * 0.035))
                .foregroundStyle(accentColor)
                .offset(x: p * 0.30, y: -p * 0.05)
                .opacity(0.8)
            
        case .shy:
            // Tiny sweat drop
            Image(systemName: "drop.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.cyan.opacity(0.6))
                .font(.system(size: p * 0.03))
                .offset(x: p * 0.22, y: -p * 0.28)
                .opacity(0.7)
        
        case .mischievous:
            // Small tongue peeking out below beak
            Ellipse()
                .fill(Color(hex: "FF7B9C"))
                .frame(width: p * 0.035, height: p * 0.025)
                .rotationEffect(.degrees(headTilt))
                .offset(x: p * 0.015, y: -p * 0.065)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        guard !reduceMotion else { return }
        
        // Universal micro-life: subtle breathing on ALL expressions
        // (sleeping overrides with bigger breath below)
        if expression != .sleeping {
            withAnimation(
                .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
            ) {
                breatheScale = 1.008
            }
        }
        
        // Universal: very subtle micro-rotation (alive feel)
        withAnimation(
            .easeInOut(duration: 5.0)
            .repeatForever(autoreverses: true)
        ) {
            microRotation = 0.8
        }
        
        // Universal: flipper idle sway (±5° gentle oscillation)
        if [.idle, .listening, .talking, .nudging, .typing, .thinking, .confused, .waving].contains(expression) {
            withAnimation(
                .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
            ) {
                flipperSway = 5
            }
        }
        
        switch expression {
        case .idle, .listening, .nudging, .typing:
            startBlinkLoop()
            // Body sway
            withAnimation(
                .easeInOut(duration: AnimationConstants.penguinSwayDuration / 2)
                .repeatForever(autoreverses: true)
            ) {
                swayOffset = AnimationConstants.penguinSwayAmplitude
            }
            // Scarf counter-sway (secondary motion, phase offset)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(
                    .easeInOut(duration: AnimationConstants.penguinSwayDuration / 2)
                    .repeatForever(autoreverses: true)
                ) {
                }
            }
            
        case .happy:
            withAnimation(AnimationConstants.penguinBounce) {
                bounceOffset = -AnimationConstants.penguinBounceHeight
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(AnimationConstants.penguinBounce) {
                    bounceOffset = 0
                }
            }
            
        case .celebrating, .waving:
            // Double bounce
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                bounceOffset = -AnimationConstants.penguinBounceHeight * 1.5
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                    bounceOffset = 0
                }
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                    bounceOffset = -AnimationConstants.penguinBounceHeight
                }
                try? await Task.sleep(for: .seconds(0.25))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                    bounceOffset = 0
                }
            }
            // Excited rapid flap (±15°, 4 cycles)
            startExcitedFlap()
            
        case .thinking, .confused:
            startDotCycle()
            
        case .sleeping:
            // Override breathing to bigger, slower
            breatheScale = 1.0
            withAnimation(
                .easeInOut(duration: 4.0)
                .repeatForever(autoreverses: true)
            ) {
                breatheScale = 1.015
            }
            startZzzAnimation()
            
        case .thumbsUp:
            // Quick nod-like bounce
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                bounceOffset = -4
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    bounceOffset = 0
                }
            }
            
        case .talking:
            // Rhythmic head bob — penguin "talks" with body language
            startTalkingBob()
            // Subtle sway while talking
            withAnimation(
                .easeInOut(duration: 1.8)
                .repeatForever(autoreverses: true)
            ) {
                swayOffset = AnimationConstants.penguinSwayAmplitude * 0.6
            }
            
        case .shy:
            startBlinkLoop()
            // Shy body language — slight shrink
            withAnimation(.easeInOut(duration: 2.0)) {
                breatheScale = 0.965
            }
            withAnimation(
                .easeInOut(duration: 4.0)
                .repeatForever(autoreverses: true)
            ) {
                swayOffset = AnimationConstants.penguinSwayAmplitude * 0.3
            }
            
        case .mischievous:
            startBlinkLoop()
            // Playful bouncy sway
            withAnimation(
                .easeInOut(duration: 1.6)
                .repeatForever(autoreverses: true)
            ) {
                swayOffset = AnimationConstants.penguinSwayAmplitude * 1.3
            }

        }
    }
    
    private func startBlinkLoop() {
        // Blink for any expression with round open eyes
        let blinkExpressions: [PenguinExpression] = [.idle, .listening, .waving, .nudging, .typing, .thumbsUp, .shy, .mischievous]
        guard blinkExpressions.contains(expression), !reduceMotion else { return }
        
        blinkTask?.cancel()
        blinkTask = Task { @MainActor in
            while !Task.isCancelled {
                // Add randomness to blink interval (±1.5s) for lifelike feel
                let interval = AnimationConstants.penguinBlinkInterval + Double.random(in: -1.5...1.5)
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                
                withAnimation(.easeOut(duration: AnimationConstants.penguinBlinkClose)) { blinkPhase = true }
                try? await Task.sleep(for: .seconds(AnimationConstants.penguinBlinkClose + AnimationConstants.penguinBlinkHold))
                guard !Task.isCancelled else { break }
                
                withAnimation(.easeOut(duration: AnimationConstants.penguinBlinkOpen)) { blinkPhase = false }
                
                // Occasionally do a double-blink (20% chance) for extra life
                if Bool.random() && Int.random(in: 0...4) == 0 {
                    try? await Task.sleep(for: .seconds(0.15))
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeOut(duration: 0.08)) { blinkPhase = true }
                    try? await Task.sleep(for: .seconds(0.12))
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeOut(duration: 0.1)) { blinkPhase = false }
                }
            }
        }
    }
    
    private func startDotCycle() {
        guard (expression == .thinking || expression == .confused), !reduceMotion else { return }
        dotCycleTask?.cancel()
        dotCycleTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { break }
                withAnimation(.easeOut(duration: 0.2)) {
                    dotPhase = (dotPhase + 1) % 3
                }
            }
        }
    }
    
    private func startZzzAnimation() {
        guard expression == .sleeping, !reduceMotion else { return }
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            zzzOffset = [-p * 0.02, -p * 0.03, -p * 0.04]
            zzzOpacity = [0.7, 0.5, 0.3]
        }
    }
    
    /// Rhythmic head bob while the penguin "talks"
    private func startTalkingBob() {
        guard expression == .talking, !reduceMotion else { return }
        
        // Small rapid bobs — 3 quick nods with decreasing amplitude
        let bobSequence: [(offset: CGFloat, duration: TimeInterval)] = [
            (-5, 0.15),
            (0, 0.15),
            (-3.5, 0.12),
            (0, 0.10),
            (-2, 0.10),
            (0, 0.58),  // Pause at rest before next cycle
        ]
        
        talkingBobTask?.cancel()
        talkingBobTask = Task { @MainActor in
            while !Task.isCancelled {
                for (offset, duration) in bobSequence {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                        self.bounceOffset = offset
                    }
                    try? await Task.sleep(for: .seconds(duration))
                    guard !Task.isCancelled else { return }
                }
            }
        }
    }
    
    /// Excited rapid wing flap for celebrating/happy expressions
    private func startExcitedFlap() {
        guard [.celebrating, .waving, .happy].contains(expression), !reduceMotion else { return }
        
        // 4 rapid flaps: ±15° at 0.15s period
        let flapSequence: [(angle: CGFloat, delay: TimeInterval)] = [
            (15, 0.0), (-15, 0.15), (15, 0.15), (-15, 0.15),
            (10, 0.15), (-10, 0.15), (5, 0.10), (0, 0.10),
        ]
        
        Task { @MainActor in
            for (angle, delay) in flapSequence {
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                    self.flipperSway = angle
                }
            }
        }
    }
    
    // MARK: - Accessibility
    
    private var penguinAccessibilityLabel: String {
        switch expression {
        case .idle:        return String(localized: "Nudgy the penguin, relaxing")
        case .happy:       return String(localized: "Nudgy celebrating your progress")
        case .thinking:    return String(localized: "Nudgy thinking about what you said")
        case .sleeping:    return String(localized: "Nudgy resting, all tasks done")
        case .celebrating: return String(localized: "Nudgy celebrating, all tasks complete!")
        case .thumbsUp:    return String(localized: "Nudgy giving a thumbs up, item saved")
        case .listening:   return String(localized: "Nudgy listening to you")
        case .talking:     return String(localized: "Nudgy talking to you")
        case .waving:      return String(localized: "Nudgy waving hello")
        case .nudging:     return String(localized: "Nudgy reminding you about a task")
        case .confused:    return String(localized: "Nudgy looking confused")
        case .typing:      return String(localized: "Nudgy helping you type")
        case .shy:         return String(localized: "Nudgy feeling shy")
        case .mischievous: return String(localized: "Nudgy feeling mischievous")
        }
    }
}

// MARK: - Custom Shapes (Bezier Paths — matches icon generator)

/// Plump snowball body — chubby plushy proportions, rounder than the pear.
/// Widest at ~52% height with pillowy uniform curvature throughout.
/// Inspired by Pixar character appeal: round = friendly = huggable.
struct PenguinBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        
        return Path { p in
            p.move(to: CGPoint(x: cx, y: 0))
            // Right side — pillowy outward bulge
            p.addCurve(
                to: CGPoint(x: cx + w * 0.49, y: h * 0.52),
                control1: CGPoint(x: cx + w * 0.32, y: 0),
                control2: CGPoint(x: cx + w * 0.52, y: h * 0.22)
            )
            // Right bottom — full round sweep to base
            p.addCurve(
                to: CGPoint(x: cx, y: h * 0.96),
                control1: CGPoint(x: cx + w * 0.48, y: h * 0.80),
                control2: CGPoint(x: cx + w * 0.22, y: h * 0.99)
            )
            // Left bottom — mirror
            p.addCurve(
                to: CGPoint(x: cx - w * 0.49, y: h * 0.52),
                control1: CGPoint(x: cx - w * 0.22, y: h * 0.99),
                control2: CGPoint(x: cx - w * 0.48, y: h * 0.80)
            )
            // Left side — taper back to top
            p.addCurve(
                to: CGPoint(x: cx, y: 0),
                control1: CGPoint(x: cx - w * 0.52, y: h * 0.22),
                control2: CGPoint(x: cx - w * 0.32, y: 0)
            )
            p.closeSubpath()
        }
    }
}

/// Rounded triangular beak
struct BeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        
        return Path { p in
            // Bottom point
            p.move(to: CGPoint(x: cx, y: h))
            // Curve to top-left
            p.addCurve(
                to: CGPoint(x: cx - w * 0.4, y: h * 0.1),
                control1: CGPoint(x: cx - w * 0.15, y: h * 0.4),
                control2: CGPoint(x: cx - w * 0.45, y: h * 0.3)
            )
            // Top arc
            p.addCurve(
                to: CGPoint(x: cx + w * 0.4, y: h * 0.1),
                control1: CGPoint(x: cx - w * 0.2, y: -h * 0.15),
                control2: CGPoint(x: cx + w * 0.2, y: -h * 0.15)
            )
            // Curve back to bottom
            p.addCurve(
                to: CGPoint(x: cx, y: h),
                control1: CGPoint(x: cx + w * 0.45, y: h * 0.3),
                control2: CGPoint(x: cx + w * 0.15, y: h * 0.4)
            )
            p.closeSubpath()
        }
    }
}

/// Crescent "happy" eye — upward curve
struct CrescentEye: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            p.move(to: CGPoint(x: 0, y: h * 0.7))
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.7),
                control1: CGPoint(x: w * 0.2, y: -h * 0.3),
                control2: CGPoint(x: w * 0.8, y: -h * 0.3)
            )
            p.addCurve(
                to: CGPoint(x: 0, y: h * 0.7),
                control1: CGPoint(x: w * 0.75, y: h * 0.35),
                control2: CGPoint(x: w * 0.25, y: h * 0.35)
            )
            p.closeSubpath()
        }
    }
}

/// Sleeping eye — gentle closed arc with tiny lash mark
struct SleepingEye: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            // Main closed curve
            p.move(to: CGPoint(x: 0, y: h * 0.5))
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.5),
                control1: CGPoint(x: w * 0.3, y: h * 1.2),
                control2: CGPoint(x: w * 0.7, y: h * 1.2)
            )
            // Tiny lash at outer edge
            p.move(to: CGPoint(x: w * 0.9, y: h * 0.6))
            p.addLine(to: CGPoint(x: w, y: h * 0.85))
        }
    }
}

/// Wing/flipper shape — teardrop
struct WingShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            p.move(to: CGPoint(x: w * 0.5, y: 0))
            // Outer curve
            p.addCurve(
                to: CGPoint(x: w * 0.7, y: h),
                control1: CGPoint(x: w * 1.1, y: h * 0.15),
                control2: CGPoint(x: w * 1.2, y: h * 0.7)
            )
            // Rounded tip
            p.addCurve(
                to: CGPoint(x: w * 0.3, y: h * 0.92),
                control1: CGPoint(x: w * 0.55, y: h * 1.08),
                control2: CGPoint(x: w * 0.35, y: h * 1.05)
            )
            // Inner curve back to top
            p.addCurve(
                to: CGPoint(x: w * 0.5, y: 0),
                control1: CGPoint(x: w * 0.15, y: h * 0.5),
                control2: CGPoint(x: w * 0.1, y: h * 0.1)
            )
            p.closeSubpath()
        }
    }
}

/// Triangle beak (legacy — kept for backward compatibility)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Webbed Penguin Foot

/// A cute webbed penguin foot with 3 rounded toes splayed out.
/// Drawn with bezier curves for a soft, cartoon look.
struct WebFootView: View {
    var size: CGFloat = 24
    var color: Color = Color(hex: "FF8C42")  // Penguin orange
    
    var body: some View {
        ZStack {
            // Foot body with webbing
            WebFootShape()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // 3D highlight (top surface catches light)
            WebFootShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.4, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
            
            // Subtle outline
            WebFootShape()
                .stroke(color.opacity(0.4), lineWidth: 0.5)
            
            // Toe separation lines (webbing detail)
            Path { p in
                // Left web line
                p.move(to: CGPoint(x: size * 0.42, y: size * 0.22))
                p.addCurve(
                    to: CGPoint(x: size * 0.22, y: size * 0.72),
                    control1: CGPoint(x: size * 0.34, y: size * 0.42),
                    control2: CGPoint(x: size * 0.24, y: size * 0.58)
                )
                // Right web line
                p.move(to: CGPoint(x: size * 0.58, y: size * 0.22))
                p.addCurve(
                    to: CGPoint(x: size * 0.78, y: size * 0.72),
                    control1: CGPoint(x: size * 0.66, y: size * 0.42),
                    control2: CGPoint(x: size * 0.76, y: size * 0.58)
                )
            }
            .stroke(color.opacity(0.25), lineWidth: 0.8)
        }
        .frame(width: size, height: size * 0.8)
    }
}

/// Webbed foot outline — 3 rounded toes connected by webbing.
struct WebFootShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            // Start at ankle (top center)
            p.move(to: CGPoint(x: w * 0.38, y: h * 0.05))
            
            // Ankle connects to foot pad (narrower at top)
            p.addCurve(
                to: CGPoint(x: w * 0.62, y: h * 0.05),
                control1: CGPoint(x: w * 0.42, y: 0),
                control2: CGPoint(x: w * 0.58, y: 0)
            )
            
            // Right side down to outer toe
            p.addCurve(
                to: CGPoint(x: w * 0.92, y: h * 0.65),
                control1: CGPoint(x: w * 0.72, y: h * 0.12),
                control2: CGPoint(x: w * 0.90, y: h * 0.40)
            )
            
            // Right toe tip (rounded)
            p.addCurve(
                to: CGPoint(x: w * 0.78, y: h * 0.82),
                control1: CGPoint(x: w * 0.96, y: h * 0.75),
                control2: CGPoint(x: w * 0.88, y: h * 0.85)
            )
            
            // Webbing dip between right and center toe
            p.addCurve(
                to: CGPoint(x: w * 0.62, y: h * 0.68),
                control1: CGPoint(x: w * 0.72, y: h * 0.76),
                control2: CGPoint(x: w * 0.66, y: h * 0.70)
            )
            
            // Center toe (middle, points forward)
            p.addCurve(
                to: CGPoint(x: w * 0.50, y: h * 0.95),
                control1: CGPoint(x: w * 0.58, y: h * 0.78),
                control2: CGPoint(x: w * 0.55, y: h * 0.92)
            )
            
            // Center toe tip (rounded)
            p.addCurve(
                to: CGPoint(x: w * 0.38, y: h * 0.68),
                control1: CGPoint(x: w * 0.45, y: h * 0.92),
                control2: CGPoint(x: w * 0.42, y: h * 0.78)
            )
            
            // Webbing dip between center and left toe
            p.addCurve(
                to: CGPoint(x: w * 0.22, y: h * 0.82),
                control1: CGPoint(x: w * 0.34, y: h * 0.70),
                control2: CGPoint(x: w * 0.28, y: h * 0.76)
            )
            
            // Left toe tip (rounded)
            p.addCurve(
                to: CGPoint(x: w * 0.08, y: h * 0.65),
                control1: CGPoint(x: w * 0.12, y: h * 0.85),
                control2: CGPoint(x: w * 0.04, y: h * 0.75)
            )
            
            // Left side back up to ankle
            p.addCurve(
                to: CGPoint(x: w * 0.38, y: h * 0.05),
                control1: CGPoint(x: w * 0.10, y: h * 0.40),
                control2: CGPoint(x: w * 0.28, y: h * 0.12)
            )
            
            p.closeSubpath()
        }
    }
}

/// Knit beanie dome — wide at brim, tapers to rounded crown.
struct BeanieShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            p.move(to: CGPoint(x: w * 0.02, y: h))
            p.addCurve(
                to: CGPoint(x: w * 0.18, y: h * 0.10),
                control1: CGPoint(x: -w * 0.01, y: h * 0.55),
                control2: CGPoint(x: w * 0.06, y: h * 0.18)
            )
            p.addCurve(
                to: CGPoint(x: w * 0.82, y: h * 0.10),
                control1: CGPoint(x: w * 0.32, y: -h * 0.10),
                control2: CGPoint(x: w * 0.68, y: -h * 0.10)
            )
            p.addCurve(
                to: CGPoint(x: w * 0.98, y: h),
                control1: CGPoint(x: w * 0.94, y: h * 0.18),
                control2: CGPoint(x: w * 1.01, y: h * 0.55)
            )
            p.closeSubpath()
        }
    }
}

/// 5-pointed star eye shape for excited/celebrating expression.
struct StarEye: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * 0.38
        let points = 5
        
        return Path { p in
            for i in 0..<(points * 2) {
                let angle = (Double(i) * .pi / Double(points)) - .pi / 2
                let r = (i % 2 == 0) ? outerR : innerR
                let pt = CGPoint(
                    x: cx + CGFloat(cos(angle)) * r,
                    y: cy + CGFloat(sin(angle)) * r
                )
                if i == 0 { p.move(to: pt) }
                else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }
}

// MARK: - Previews

#Preview("All Expressions") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        LazyVGrid(columns: [.init(), .init(), .init()], spacing: 32) {
            ForEach(PenguinExpression.allCases, id: \.rawValue) { expr in
                VStack(spacing: 8) {
                    PenguinMascot(expression: expr, size: 80)
                    Text(expr.rawValue)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
    }
}

#Preview("Large Idle") {
    ZStack {
        Color.black.ignoresSafeArea()
        PenguinMascot(expression: .idle, size: 200)
    }
}

/// Interactive preview — tap to cycle through every expression at hero size.
/// Use this to test all animations in real time.
#Preview("🎬 Animation Tester") {
    struct AnimationTester: View {
        @State private var current = 0
        private let expressions = PenguinExpression.allCases
        
        private let descriptions: [PenguinExpression: String] = [
            .idle:        "Gentle sway · blink every ~3.5s · occasional double-blink",
            .happy:       "Single bounce · crescent smile eyes · warm blush",
            .thinking:    "Head tilted left · cycling thought dots · wide eyes",
            .sleeping:    "Slow breathing scale · floating zzz · closed lash eyes",
            .celebrating: "Double bounce · ★ star eyes · sparkle accessories",
            .thumbsUp:    "Quick nod · right wink · floating heart",
            .listening:   "Sway + blink · attentive eyebrows · head tilt left",
            .talking:     "Rhythmic head bob (3 nods) · sway · crescent eyes · extra blush",
            .waving:      "Double bounce + blink · arms spread · head tilted right",
            .nudging:     "Stern eyebrows · sway + blink · arms pointing",
            .confused:    "Asymmetric eyebrows · cycling dots · head tilted right 12°",
            .typing:      "Sway + blink · head tilt left · arms at rest",
            .shy:         "Half-lid eyes · extra blush · subtle shrink · gentle sway",
            .mischievous: "One squint one wide · raised eyebrow · tongue peek · bouncy sway",
        ]
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Tap Nudgy to cycle expressions")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Spacer()
                    
                    // Expression name
                    Text(expressions[current].rawValue.uppercased())
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    
                    // The penguin at hero size
                    PenguinMascot(
                        expression: expressions[current],
                        size: 240,
                        accentColor: DesignTokens.accentActive
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            current = (current + 1) % expressions.count
                        }
                    }
                    .id(current) // Force re-create to restart animations
                    
                    Spacer()
                    
                    // Animation description
                    Text(descriptions[expressions[current]] ?? "")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // Expression counter
                    Text("\(current + 1) / \(expressions.count)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.bottom, 20)
                }
            }
        }
    }
    
    return AnimationTester()
}

// MARK: - Scarf / Asset Dev Previews
// Open PenguinMascot.swift in Xcode → press ⌥⌘↩ to show canvas.
// Changes to penguinScarf update in the canvas within ~1 second — no build needed.

#Preview("Nudgy — idle", traits: .fixedLayout(width: 300, height: 345)) {
    PenguinMascot(expression: .idle, size: 200, showBeanie: false)
        .padding(50)
        .background(Color(hex: "111111"))
        .preferredColorScheme(.dark)
}

#Preview("Nudgy — all expressions", traits: .fixedLayout(width: 680, height: 220)) {
    HStack(spacing: 24) {
        ForEach([PenguinExpression.idle, .happy, .waving, .celebrating], id: \.rawValue) { expr in
            VStack(spacing: 6) {
                PenguinMascot(expression: expr, size: 120, showBeanie: false)
                Text(expr.rawValue).font(.caption2).foregroundStyle(.gray)
            }
        }
    }
    .padding(20)
    .background(Color(hex: "111111"))
    .preferredColorScheme(.dark)
}
