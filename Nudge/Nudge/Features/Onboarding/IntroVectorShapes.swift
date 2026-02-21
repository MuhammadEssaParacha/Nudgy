//
//  IntroVectorShapes.swift
//  Nudge
//
//  Bezier-drawn vector shapes for the intro sequence.
//  Replaces all emoji usage with real vector art that matches
//  the PenguinMascot bezier style. Every shape is drawn from
//  pure SwiftUI Path curves — no image assets needed.
//

import SwiftUI

// MARK: - Fish Shape (Bezier)

/// A cute fish drawn with bezier curves — rounded body, flowing tail,
/// little eye, and dorsal fin. Matches the app's hand-drawn mascot style.
struct FishShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            // Body — egg/oval shape, slightly pointed at the mouth
            p.move(to: CGPoint(x: w * 0.72, y: h * 0.5))
            
            // Top curve of body (mouth → dorsal → back)
            p.addCurve(
                to: CGPoint(x: w * 0.32, y: h * 0.18),
                control1: CGPoint(x: w * 0.72, y: h * 0.25),
                control2: CGPoint(x: w * 0.55, y: h * 0.15)
            )
            
            // Connect to tail (top)
            p.addCurve(
                to: CGPoint(x: w * 0.08, y: h * 0.12),
                control1: CGPoint(x: w * 0.20, y: h * 0.20),
                control2: CGPoint(x: w * 0.12, y: h * 0.15)
            )
            
            // Tail fork top
            p.addCurve(
                to: CGPoint(x: w * 0.18, y: h * 0.42),
                control1: CGPoint(x: w * 0.02, y: h * 0.22),
                control2: CGPoint(x: w * 0.10, y: h * 0.38)
            )
            
            // Tail center notch
            p.addCurve(
                to: CGPoint(x: w * 0.18, y: h * 0.58),
                control1: CGPoint(x: w * 0.15, y: h * 0.48),
                control2: CGPoint(x: w * 0.15, y: h * 0.52)
            )
            
            // Tail fork bottom
            p.addCurve(
                to: CGPoint(x: w * 0.08, y: h * 0.88),
                control1: CGPoint(x: w * 0.10, y: h * 0.62),
                control2: CGPoint(x: w * 0.02, y: h * 0.78)
            )
            
            // Connect from tail → bottom of body
            p.addCurve(
                to: CGPoint(x: w * 0.32, y: h * 0.82),
                control1: CGPoint(x: w * 0.12, y: h * 0.85),
                control2: CGPoint(x: w * 0.20, y: h * 0.80)
            )
            
            // Bottom curve of body (back → belly → mouth)
            p.addCurve(
                to: CGPoint(x: w * 0.72, y: h * 0.5),
                control1: CGPoint(x: w * 0.55, y: h * 0.85),
                control2: CGPoint(x: w * 0.72, y: h * 0.75)
            )
            
            p.closeSubpath()
        }
    }
}

/// Complete fish view with body, eye, fin detail, and gill accent.
struct FishView: View {
    var size: CGFloat = 32
    var color: Color = Color(hex: "4FC3F7")  // Light ocean blue
    var accentColor: Color = Color(hex: "0288D1")  // Deeper blue for fin
    
    var body: some View {
        ZStack {
            // Body fill
            FishShape()
                .fill(
                    LinearGradient(
                        colors: [color, accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Sheen highlight
            FishShape()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        center: UnitPoint(x: 0.55, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
            
            // Dorsal fin
            DorsalFinShape()
                .fill(accentColor.opacity(0.7))
                .frame(width: size * 0.25, height: size * 0.2)
                .offset(x: size * 0.02, y: -size * 0.25)
            
            // Eye
            Circle()
                .fill(Color(hex: "0A0A0E"))
                .frame(width: size * 0.13, height: size * 0.13)
                .offset(x: size * 0.17, y: -size * 0.04)
            
            // Eye glint
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.05, height: size * 0.05)
                .offset(x: size * 0.19, y: -size * 0.06)
            
            // Gill mark
            GillMarkShape()
                .stroke(accentColor.opacity(0.5), lineWidth: 1)
                .frame(width: size * 0.08, height: size * 0.15)
                .offset(x: size * 0.08, y: size * 0.02)
        }
        .frame(width: size, height: size * 0.65)
    }
}

// MARK: - Animated Fish Shape (Tail Wag, Stage-Aware)

/// Fish body with animatable tail wag via `tailPhase`.
/// Body proportions shift with evolution `stage`:
///   baby     → round, compact, stubby forked tail
///   juvenile → baseline streamlined body (original silhouette)
///   adult    → elongated snout, deeper fork spread
///   elder    → wide sweeping fan tail, deeper body
///   ancient  → dramatic full-width fan tail with swept-back arms
struct AnimatedFishShape: Shape {
    var tailPhase: CGFloat          // -1…1 range, 0 = centred
    var stage: FishEvolutionStage = .juvenile

    var animatableData: CGFloat {
        get { tailPhase }
        set { tailPhase = newValue }
    }

    // Per-stage normalised geometry (all values 0…1 within the bounding rect)
    private struct StageGeom {
        let mouthX:   CGFloat   // rightmost point (mouth tip)
        let dorsalX:  CGFloat   // dorsal-ridge peak X (controls top-back bulge)
        let backX:    CGFloat   // body ↔ tail junction X
        let tailTipX: CGFloat   // leftmost tail-tip extent
        let tailTopY: CGFloat   // top fork-tip Y fraction (above centre)
        let tailBotY: CGFloat   // bottom fork-tip Y fraction (below centre)
        let notchX:   CGFloat   // tail-centre concave notch X
        let wagAmp:   CGFloat   // tail deflection amplitude (mul of height)
    }

    private var geom: StageGeom {
        switch stage {
        case .baby:
            return StageGeom(mouthX: 0.70, dorsalX: 0.52, backX: 0.32,
                             tailTipX: 0.10, tailTopY: 0.18, tailBotY: 0.82,
                             notchX: 0.19, wagAmp: 0.05)
        case .juvenile:
            return StageGeom(mouthX: 0.72, dorsalX: 0.55, backX: 0.32,
                             tailTipX: 0.08, tailTopY: 0.12, tailBotY: 0.88,
                             notchX: 0.18, wagAmp: 0.06)
        case .adult:
            return StageGeom(mouthX: 0.75, dorsalX: 0.57, backX: 0.30,
                             tailTipX: 0.04, tailTopY: 0.07, tailBotY: 0.93,
                             notchX: 0.16, wagAmp: 0.07)
        case .elder:
            return StageGeom(mouthX: 0.78, dorsalX: 0.59, backX: 0.27,
                             tailTipX: 0.01, tailTopY: 0.03, tailBotY: 0.97,
                             notchX: 0.15, wagAmp: 0.09)
        case .ancient:
            return StageGeom(mouthX: 0.80, dorsalX: 0.61, backX: 0.22,
                             tailTipX: -0.02, tailTopY: 0.00, tailBotY: 1.00,
                             notchX: 0.16, wagAmp: 0.12)
        }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let g = geom
        let d = h * g.wagAmp * tailPhase   // vertical tail deflection

        return Path { p in
            // ── Mouth (rightmost, vertical centre) ────────────────────
            p.move(to: CGPoint(x: w * g.mouthX, y: h * 0.50))

            // ── Top body: mouth → dorsal ridge peak → body/tail junction
            p.addCurve(
                to: CGPoint(x: w * g.backX, y: h * 0.18),
                control1: CGPoint(x: w * g.mouthX,          y: h * 0.24),
                control2: CGPoint(x: w * (g.dorsalX + 0.05), y: h * 0.14)
            )

            // ── Top tail arm: junction → top fork tip (wag deflects here)
            p.addCurve(
                to: CGPoint(x: w * g.tailTipX, y: h * g.tailTopY + d),
                control1: CGPoint(x: w * (g.backX - 0.05),    y: h * 0.18),
                control2: CGPoint(x: w * (g.tailTipX + 0.07), y: h * g.tailTopY + d * 0.5)
            )

            // ── Top fork → centre notch ────────────────────────────────
            p.addCurve(
                to: CGPoint(x: w * g.notchX, y: h * 0.42),
                control1: CGPoint(x: w * (g.tailTipX + 0.02), y: h * (g.tailTopY + 0.09) + d),
                control2: CGPoint(x: w * (g.notchX - 0.02),   y: h * 0.38)
            )

            // ── Notch (tight concave indent) ──────────────────────────
            p.addCurve(
                to: CGPoint(x: w * g.notchX, y: h * 0.58),
                control1: CGPoint(x: w * (g.notchX - 0.03), y: h * 0.47),
                control2: CGPoint(x: w * (g.notchX - 0.03), y: h * 0.53)
            )

            // ── Centre notch → bottom fork tip ────────────────────────
            p.addCurve(
                to: CGPoint(x: w * g.tailTipX, y: h * g.tailBotY + d),
                control1: CGPoint(x: w * (g.notchX - 0.02),   y: h * 0.62),
                control2: CGPoint(x: w * (g.tailTipX + 0.02), y: h * (g.tailBotY - 0.09) + d)
            )

            // ── Bottom tail arm: fork tip → body/tail junction ────────
            p.addCurve(
                to: CGPoint(x: w * g.backX, y: h * 0.82),
                control1: CGPoint(x: w * (g.tailTipX + 0.07), y: h * g.tailBotY + d * 0.5),
                control2: CGPoint(x: w * (g.backX - 0.05),    y: h * 0.82)
            )

            // ── Bottom body: junction → belly → mouth ─────────────────
            p.addCurve(
                to: CGPoint(x: w * g.mouthX, y: h * 0.50),
                control1: CGPoint(x: w * (g.dorsalX + 0.05), y: h * 0.86),
                control2: CGPoint(x: w * g.mouthX,           y: h * 0.76)
            )

            p.closeSubpath()
        }
    }
}

/// Fish view with animated tail wag driven by a phase value.
/// Use inside aquarium/tank for lively swimming animation.
///
/// `stage` controls body silhouette AND visual complexity:
///  - baby     → proportionally large eye, simple fins, stubby body
///  - juvenile → baseline streamlined body (original look)
///  - adult    → second dorsal fin + second pectoral fin, taller primary dorsal
///  - elder    → wide fan tail, scale-mark arcs on body, broader proportions
///  - ancient  → dramatic fan tail with glowing filament rays, crown dorsal
struct AnimatedFishView: View {
    var size: CGFloat = 32
    var color: Color = Color(hex: "4FC3F7")
    var accentColor: Color = Color(hex: "0288D1")
    /// Tail wag phase — expected range -1…1, oscillates via sin wave.
    var tailPhase: CGFloat = 0
    /// Evolution stage — drives body silhouette and layered fin detail.
    var stage: FishEvolutionStage = .juvenile

    // Eye diameter: baby has a proportionally larger "cute" eye
    private var eyeSize: CGFloat {
        switch stage {
        case .baby:    return size * 0.17
        case .juvenile: return size * 0.13
        case .adult:   return size * 0.12
        case .elder:   return size * 0.12
        case .ancient: return size * 0.11
        }
    }

    // Eye X offset tracks the mouth position per stage
    private var eyeOffsetX: CGFloat {
        switch stage {
        case .baby:    return size * 0.10
        case .juvenile: return size * 0.17
        case .adult:   return size * 0.19
        case .elder:   return size * 0.21
        case .ancient: return size * 0.23
        }
    }

    var body: some View {
        ZStack {
            // ── Body fill — stage-parametrised silhouette ──────────────
            AnimatedFishShape(tailPhase: tailPhase, stage: stage)
                .fill(
                    LinearGradient(
                        colors: [color, accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // ── Sheen highlight ────────────────────────────────────────
            AnimatedFishShape(tailPhase: tailPhase, stage: stage)
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        center: UnitPoint(x: 0.55, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )

            // ── Elder / Ancient: scale-mark arcs on body ──────────────
            if stage >= .elder {
                let scaleOpacity: CGFloat = stage == .ancient ? 0.25 : 0.18
                ForEach(0..<3, id: \.self) { i in
                    let yFrac = CGFloat(i) * 0.14 + 0.30   // 0.30, 0.44, 0.58
                    Path { path in
                        path.addArc(
                            center: CGPoint(x: size * 0.32, y: size * 0.65 * yFrac),
                            radius: size * 0.10,
                            startAngle: .degrees(-50),
                            endAngle: .degrees(50),
                            clockwise: false
                        )
                    }
                    .stroke(accentColor.opacity(scaleOpacity), lineWidth: max(0.5, size * 0.018))
                }
            }

            // ── Ancient: glowing tail-ray filaments ───────────────────
            if stage == .ancient {
                // Top filament — sweeps from body/tail junction to top fork tip
                Path { p in
                    p.move(to: CGPoint(x: size * 0.22,  y: size * 0.65 * 0.38))
                    p.addCurve(
                        to: CGPoint(x: size * 0.00,  y: size * 0.65 * 0.02),
                        control1: CGPoint(x: size * 0.14, y: size * 0.65 * 0.22),
                        control2: CGPoint(x: size * 0.06, y: size * 0.65 * 0.10)
                    )
                }
                .stroke(color.opacity(0.50), lineWidth: max(0.8, size * 0.022))

                // Bottom filament
                Path { p in
                    p.move(to: CGPoint(x: size * 0.22,  y: size * 0.65 * 0.62))
                    p.addCurve(
                        to: CGPoint(x: size * 0.00,  y: size * 0.65 * 0.98),
                        control1: CGPoint(x: size * 0.14, y: size * 0.65 * 0.78),
                        control2: CGPoint(x: size * 0.06, y: size * 0.65 * 0.90)
                    )
                }
                .stroke(color.opacity(0.50), lineWidth: max(0.8, size * 0.022))
            }

            // ── Primary dorsal fin (taller from adult+) ────────────────
            DorsalFinShape()
                .fill(accentColor.opacity(0.7))
                .frame(
                    width: size * (stage >= .adult ? 0.28 : 0.25),
                    height: size * (stage >= .adult ? 0.22 : 0.20)
                )
                .rotationEffect(.degrees(Double(tailPhase) * -3))
                .offset(x: size * 0.02, y: -size * (stage >= .adult ? 0.27 : 0.25))

            // ── Secondary dorsal fin (adult+) ──────────────────────────
            if stage >= .adult {
                DorsalFinShape()
                    .fill(accentColor.opacity(0.35))
                    .frame(width: size * 0.15, height: size * 0.12)
                    .rotationEffect(.degrees(Double(tailPhase) * -2))
                    .offset(x: -size * 0.06, y: -size * 0.20)
            }

            // ── Primary pectoral fin ───────────────────────────────────
            PectoralFinShape()
                .fill(accentColor.opacity(0.4))
                .frame(width: size * 0.15, height: size * 0.12)
                .rotationEffect(.degrees(Double(tailPhase) * 8))
                .offset(x: size * 0.06, y: size * 0.12)

            // ── Second pectoral fin (adult+) ───────────────────────────
            if stage >= .adult {
                PectoralFinShape()
                    .fill(accentColor.opacity(0.20))
                    .frame(width: size * 0.10, height: size * 0.08)
                    .rotationEffect(.degrees(Double(tailPhase) * -5))
                    .offset(x: -size * 0.02, y: size * 0.17)
            }

            // ── Eye ───────────────────────────────────────────────────
            Circle()
                .fill(Color(hex: "0A0A0E"))
                .frame(width: eyeSize, height: eyeSize)
                .offset(x: eyeOffsetX, y: -size * 0.04)

            // Eye glint
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: eyeSize * 0.40, height: eyeSize * 0.40)
                .offset(x: eyeOffsetX + size * 0.02, y: -size * 0.06)

            // ── Gill mark ─────────────────────────────────────────────
            GillMarkShape()
                .stroke(accentColor.opacity(0.5), lineWidth: max(1, size * 0.03))
                .frame(width: size * 0.08, height: size * 0.15)
                .offset(x: eyeOffsetX - size * 0.09, y: size * 0.02)
        }
        .frame(width: size, height: size * 0.65)
    }
}

/// Small pectoral fin curve (bottom of fish body).
private struct PectoralFinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addCurve(
                to: CGPoint(x: w * 0.8, y: h),
                control1: CGPoint(x: w * 0.4, y: 0),
                control2: CGPoint(x: w * 0.7, y: h * 0.5)
            )
            p.addCurve(
                to: CGPoint(x: 0, y: 0),
                control1: CGPoint(x: w * 0.3, y: h * 0.8),
                control2: CGPoint(x: 0, y: h * 0.4)
            )
            p.closeSubpath()
        }
    }
}

/// Small dorsal fin curve.
private struct DorsalFinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            p.move(to: CGPoint(x: 0, y: h))
            p.addCurve(
                to: CGPoint(x: w * 0.6, y: 0),
                control1: CGPoint(x: w * 0.1, y: h * 0.4),
                control2: CGPoint(x: w * 0.35, y: 0)
            )
            p.addCurve(
                to: CGPoint(x: w, y: h),
                control1: CGPoint(x: w * 0.85, y: 0),
                control2: CGPoint(x: w * 0.9, y: h * 0.5)
            )
            p.closeSubpath()
        }
    }
}

/// Curved gill line on the fish's body.
private struct GillMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            p.move(to: CGPoint(x: w * 0.3, y: 0))
            p.addCurve(
                to: CGPoint(x: w * 0.3, y: h),
                control1: CGPoint(x: w, y: h * 0.35),
                control2: CGPoint(x: w, y: h * 0.65)
            )
        }
    }
}

// MARK: - Beanie Shape (Bezier)

/// A cute knit beanie drawn with bezier curves, shaped to hug
/// PenguinMascot's elliptical head (0.605p × 0.56p).
/// The brim curves match the head's top curvature so it sits snugly.
struct BeanieView: View {
    var size: CGFloat = 44
    var color: Color = Color(hex: "FF6B8A")      // Warm pink
    var stripeColor: Color = Color(hex: "E8E8EC") // Off-white stripe
    
    var body: some View {
        ZStack {
            // Main beanie dome — conforms to round head
            BeanieDomeShape()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.95), color, color.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Subtle 3D shading (light from top-left)
            BeanieDomeShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.25),
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
            
            // Knit ribbing lines (follow dome curve)
            ForEach(0..<4, id: \.self) { i in
                BeanieRibLine(yFraction: 0.28 + CGFloat(i) * 0.12)
                    .stroke(stripeColor.opacity(0.12), lineWidth: 1.0)
            }
            
            // Folded brim/cuff at bottom — hugs the head curvature
            BeanieCuffShape()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Cuff top highlight
            BeanieCuffTopEdge()
                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
            
            // Cuff knit texture (horizontal ribs)
            ForEach(0..<3, id: \.self) { i in
                let yPos = size * (0.62 + CGFloat(i) * 0.06)
                Path { p in
                    p.move(to: CGPoint(x: size * 0.18, y: yPos))
                    p.addCurve(
                        to: CGPoint(x: size * 0.82, y: yPos),
                        control1: CGPoint(x: size * 0.35, y: yPos + 1.5),
                        control2: CGPoint(x: size * 0.65, y: yPos + 1.5)
                    )
                }
                .stroke(stripeColor.opacity(0.08), lineWidth: 0.8)
            }
            
            // Pom-pom on top — fluffy ball
            ZStack {
                // Pom shadow
                Circle()
                    .fill(color.opacity(0.4))
                    .frame(width: size * 0.25, height: size * 0.22)
                    .offset(y: 1)
                
                // Pom body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [stripeColor.opacity(0.95), color.opacity(0.5)],
                            center: UnitPoint(x: 0.38, y: 0.32),
                            startRadius: 0,
                            endRadius: size * 0.12
                        )
                    )
                    .frame(width: size * 0.24, height: size * 0.24)
                
                // Pom highlight
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: size * 0.10, height: size * 0.08)
                    .offset(x: -size * 0.03, y: -size * 0.04)
            }
            .offset(y: -size * 0.36)
            
            // Overall dome outline
            BeanieDomeShape()
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        }
        .frame(width: size, height: size * 0.8)
    }
}

/// Dome shape that matches the top of PenguinMascot's elliptical head.
/// Bottom edge is a concave arc (hugs the round skull).
private struct BeanieDomeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            // Start at bottom-left (on the head surface)
            p.move(to: CGPoint(x: w * 0.10, y: h * 0.80))
            
            // Left side curves up — follows head curvature then lifts off
            p.addCurve(
                to: CGPoint(x: w * 0.28, y: h * 0.18),
                control1: CGPoint(x: w * 0.04, y: h * 0.55),
                control2: CGPoint(x: w * 0.12, y: h * 0.22)
            )
            
            // Top dome — nice rounded crown
            p.addCurve(
                to: CGPoint(x: w * 0.72, y: h * 0.18),
                control1: CGPoint(x: w * 0.38, y: h * 0.02),
                control2: CGPoint(x: w * 0.62, y: h * 0.02)
            )
            
            // Right side curves down
            p.addCurve(
                to: CGPoint(x: w * 0.90, y: h * 0.80),
                control1: CGPoint(x: w * 0.88, y: h * 0.22),
                control2: CGPoint(x: w * 0.96, y: h * 0.55)
            )
            
            // Bottom edge — concave arc that hugs the round head
            p.addCurve(
                to: CGPoint(x: w * 0.10, y: h * 0.80),
                control1: CGPoint(x: w * 0.72, y: h * 0.68),
                control2: CGPoint(x: w * 0.28, y: h * 0.68)
            )
            
            p.closeSubpath()
        }
    }
}

/// Folded cuff/brim at bottom of beanie — sits on the head.
private struct BeanieCuffShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            // Top edge of cuff (follows dome bottom)
            p.move(to: CGPoint(x: w * 0.10, y: h * 0.58))
            p.addCurve(
                to: CGPoint(x: w * 0.90, y: h * 0.58),
                control1: CGPoint(x: w * 0.28, y: h * 0.50),
                control2: CGPoint(x: w * 0.72, y: h * 0.50)
            )
            
            // Right side down
            p.addCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.85),
                control1: CGPoint(x: w * 0.94, y: h * 0.65),
                control2: CGPoint(x: w * 0.94, y: h * 0.78)
            )
            
            // Bottom edge — hugs head (convex outward = concave to viewer)
            p.addCurve(
                to: CGPoint(x: w * 0.12, y: h * 0.85),
                control1: CGPoint(x: w * 0.70, y: h * 0.94),
                control2: CGPoint(x: w * 0.30, y: h * 0.94)
            )
            
            // Left side up
            p.addCurve(
                to: CGPoint(x: w * 0.10, y: h * 0.58),
                control1: CGPoint(x: w * 0.06, y: h * 0.78),
                control2: CGPoint(x: w * 0.06, y: h * 0.65)
            )
            
            p.closeSubpath()
        }
    }
}

/// Top edge line of the cuff for highlight
private struct BeanieCuffTopEdge: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            p.move(to: CGPoint(x: w * 0.12, y: h * 0.58))
            p.addCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.58),
                control1: CGPoint(x: w * 0.30, y: h * 0.50),
                control2: CGPoint(x: w * 0.70, y: h * 0.50)
            )
        }
    }
}

/// Curved rib line that follows the dome shape at a given y fraction
private struct BeanieRibLine: Shape {
    let yFraction: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let y = h * yFraction
        // Narrower at top (follows dome taper)
        let inset = w * (0.22 - yFraction * 0.12)
        return Path { p in
            p.move(to: CGPoint(x: inset, y: y))
            p.addCurve(
                to: CGPoint(x: w - inset, y: y),
                control1: CGPoint(x: w * 0.35, y: y - h * 0.02),
                control2: CGPoint(x: w * 0.65, y: y - h * 0.02)
            )
        }
    }
}

// MARK: - Mountain Icon (Bezier)

/// A small mountain icon with snow cap for use in dialogue accents.
struct MountainIconView: View {
    var size: CGFloat = 24
    var color: Color = Color(hex: "90A8C8")
    
    var body: some View {
        ZStack {
            // Mountain body
            MountainIconShape()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Snow cap
            MountainSnowCapShape()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: size, height: size * 0.85)
    }
}

private struct MountainIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            p.move(to: CGPoint(x: 0, y: h))
            p.addLine(to: CGPoint(x: w * 0.5, y: 0))
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
            
            // Secondary smaller peak
            p.move(to: CGPoint(x: w * 0.55, y: h))
            p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.35))
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
        }
    }
}

private struct MountainSnowCapShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            // Snow on main peak
            p.move(to: CGPoint(x: w * 0.5, y: 0))
            p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.28))
            
            // Jagged snow line
            p.addCurve(
                to: CGPoint(x: w * 0.45, y: h * 0.22),
                control1: CGPoint(x: w * 0.38, y: h * 0.24),
                control2: CGPoint(x: w * 0.42, y: h * 0.26)
            )
            p.addCurve(
                to: CGPoint(x: w * 0.55, y: h * 0.25),
                control1: CGPoint(x: w * 0.48, y: h * 0.18),
                control2: CGPoint(x: w * 0.52, y: h * 0.22)
            )
            p.addCurve(
                to: CGPoint(x: w * 0.65, y: h * 0.28),
                control1: CGPoint(x: w * 0.58, y: h * 0.20),
                control2: CGPoint(x: w * 0.62, y: h * 0.25)
            )
            
            p.addLine(to: CGPoint(x: w * 0.5, y: 0))
            p.closeSubpath()
        }
    }
}

// MARK: - Sparkle Shape (Bezier)

/// A four-pointed sparkle/star drawn with bezier curves.
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = w * 0.5
        let cy = h * 0.5
        
        return Path { p in
            // Top point
            p.move(to: CGPoint(x: cx, y: 0))
            p.addCurve(
                to: CGPoint(x: w, y: cy),
                control1: CGPoint(x: cx + w * 0.08, y: cy - h * 0.08),
                control2: CGPoint(x: w - w * 0.08, y: cy - h * 0.08)
            )
            // Right point → bottom
            p.addCurve(
                to: CGPoint(x: cx, y: h),
                control1: CGPoint(x: w - w * 0.08, y: cy + h * 0.08),
                control2: CGPoint(x: cx + w * 0.08, y: h - h * 0.08)
            )
            // Bottom → left
            p.addCurve(
                to: CGPoint(x: 0, y: cy),
                control1: CGPoint(x: cx - w * 0.08, y: h - h * 0.08),
                control2: CGPoint(x: w * 0.08, y: cy + h * 0.08)
            )
            // Left → top
            p.addCurve(
                to: CGPoint(x: cx, y: 0),
                control1: CGPoint(x: w * 0.08, y: cy - h * 0.08),
                control2: CGPoint(x: cx - w * 0.08, y: h * 0.08)
            )
            p.closeSubpath()
        }
    }
}

/// A glowing sparkle with animated pulse.
struct SparkleView: View {
    var size: CGFloat = 16
    var color: Color = .white
    var delay: Double = 0
    
    @State private var glowing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        SparkleShape()
            .fill(color.opacity(glowing ? 0.9 : 0.3))
            .frame(width: size, height: size)
            .blur(radius: size * 0.05)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    glowing = true
                }
            }
    }
}

// MARK: - Shooting Star

/// A quick streak of light across the sky.
struct ShootingStar: View {
    var startX: CGFloat = 0.8
    var startY: CGFloat = 0.1
    
    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let sx = w * startX
            let sy = h * startY
            
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.0), Color.white.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 35, height: 1.5)
                .rotationEffect(.degrees(-35))
                .position(
                    x: sx - progress * w * 0.35,
                    y: sy + progress * h * 0.2
                )
                .opacity(opacity)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            scheduleShootingStar()
        }
    }
    
    private func scheduleShootingStar() {
        let initialDelay = Double.random(in: 2...6)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(initialDelay))
            fireShootingStar()
        }
    }
    
    private func fireShootingStar() {
        progress = 0
        opacity = 0
        
        // Fade in
        withAnimation(.easeIn(duration: 0.1)) {
            opacity = 1.0
        }
        
        // Streak across
        withAnimation(.easeOut(duration: 0.6)) {
            progress = 1.0
        }
        
        // Fade out, then schedule next one
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeOut(duration: 0.2)) {
                opacity = 0
            }
            
            let nextDelay = Double.random(in: 5...12)
            try? await Task.sleep(for: .seconds(nextDelay))
            fireShootingStar()
        }
    }
}

// MARK: - Snowfall Particles

/// Gentle falling snow particles for the mountain scene.
struct SnowfallView: View {
    var intensity: Double = 0.5  // 0.0 – 1.0
    
    @State private var particles: [SnowParticle] = []
    @State private var isActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { flake in
                Circle()
                    .fill(Color.white.opacity(flake.opacity))
                    .frame(width: flake.size, height: flake.size)
                    .blur(radius: flake.size * 0.3)
                    .position(x: flake.x, y: flake.y)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            isActive = true
            startSnowfall()
        }
        .onDisappear {
            isActive = false
        }
    }
    
    private func startSnowfall() {
        Task { @MainActor in
            while isActive {
                // Spawn a flake
                spawnFlake()
                let interval = 0.15 / max(intensity, 0.1)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }
    
    private func spawnFlake() {
        let flake = SnowParticle(
            id: UUID(),
            x: CGFloat.random(in: 0...UIScreen.current.bounds.width),
            y: -10,
            size: CGFloat.random(in: 2...5),
            opacity: Double.random(in: 0.15...0.4),
            speed: Double.random(in: 3...7)
        )
        particles.append(flake)
        
        let drift = CGFloat.random(in: -30...30)
        
        withAnimation(.linear(duration: flake.speed)) {
            if let idx = particles.firstIndex(where: { $0.id == flake.id }) {
                particles[idx].y = UIScreen.current.bounds.height + 20
                particles[idx].x += drift
            }
        }
        
        // Clean up after animation
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(flake.speed + 0.5))
            particles.removeAll { $0.id == flake.id }
        }
    }
}

private struct SnowParticle: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let opacity: Double
    let speed: Double
}

// MARK: - Scene Icon Cluster

/// Decorative floating icons that drift around Nudgy during specific scenes.
/// Uses SF Symbols as small accent icons (not emoji).
struct FloatingSceneIcons: View {
    let icons: [(name: String, color: Color)]
    var spread: CGFloat = 80
    
    @State private var offsets: [CGSize] = []
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            ForEach(0..<icons.count, id: \.self) { i in
                iconView(at: i)
            }
        }
        .onAppear {
            setupPositions()
        }
    }
    
    private func iconView(at index: Int) -> some View {
        let icon = icons[index]
        let offset = index < offsets.count ? offsets[index] : .zero
        return Image(systemName: icon.name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(icon.color.opacity(appeared ? 0.7 : 0))
            .offset(offset)
            .scaleEffect(appeared ? 1.0 : 0.3)
    }
    
    private func setupPositions() {
        var positions: [CGSize] = []
        for i in 0..<icons.count {
            let angle = (Double(i) / Double(icons.count)) * .pi * 2
                + Double.random(in: -0.3...0.3)
            let dist = spread * CGFloat.random(in: 0.6...1.0)
            let w = cos(angle) * dist
            let h = sin(angle) * dist
            positions.append(CGSize(width: w, height: h))
        }
        offsets = positions
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            appeared = true
        }
        
        guard !reduceMotion else { return }
        // Gentle float
        startFloating(from: positions)
    }
    
    private func startFloating(from positions: [CGSize]) {
        let drifted = positions.map { pos in
            CGSize(
                width: pos.width + CGFloat.random(in: -8...8),
                height: pos.height + CGFloat.random(in: -8...8)
            )
        }
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            offsets = drifted
        }
    }
}

// MARK: - Previews

#Preview("Fish") {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 24) {
            FishView(size: 40, color: Color(hex: "4FC3F7"))
            FishView(size: 32, color: Color(hex: "FF8A65"))
            FishView(size: 48, color: Color(hex: "81C784"))
        }
    }
}

#Preview("Beanie") {
    ZStack {
        Color.black.ignoresSafeArea()
        BeanieView(size: 60)
    }
}

#Preview("Mountain Icon") {
    ZStack {
        Color.black.ignoresSafeArea()
        MountainIconView(size: 48)
    }
}

#Preview("Sparkles") {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 24) {
            SparkleView(size: 20, color: .yellow, delay: 0)
            SparkleView(size: 14, color: .white, delay: 0.3)
            SparkleView(size: 24, color: Color(hex: "4FC3F7"), delay: 0.6)
        }
    }
}
