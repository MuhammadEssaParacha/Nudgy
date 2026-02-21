//
//  TankDecorationCatalog.swift
//  Nudge
//
//  Buyable tank decorations — coral, shells, treasure chest, castle.
//  Purchase with fish. Stored in NudgyWardrobe as comma-separated
//  IDs. Rendered at bottom of AquariumTankView as vector shapes.
//

import SwiftUI

// MARK: - Tank Decoration

/// A decoration that can be placed in the aquarium tank.
enum TankDecoration: String, CaseIterable, Identifiable, Sendable {
    case coral       = "deco-coral"
    case shell       = "deco-shell"
    case treasure    = "deco-treasure"
    case castle      = "deco-castle"
    case anchor      = "deco-anchor"
    case starfish    = "deco-starfish"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .coral:     return String(localized: "Coral Reef")
        case .shell:     return String(localized: "Sea Shell")
        case .treasure:  return String(localized: "Treasure Chest")
        case .castle:    return String(localized: "Sand Castle")
        case .anchor:    return String(localized: "Anchor")
        case .starfish:  return String(localized: "Starfish")
        }
    }

    /// SF Symbol icon for UI display.
    var icon: String {
        switch self {
        case .coral:     return "leaf.fill"
        case .shell:     return "fossil.shell.fill"
        case .treasure:  return "shippingbox.fill"
        case .castle:    return "building.columns.fill"
        case .anchor:    return "anchor.circle.fill"
        case .starfish:  return "star.fill"
        }
    }
    
    /// Deprecated — use `icon` for rendering.
    var emoji: String {
        switch self {
        case .coral:     return "🪸"
        case .shell:     return "🐚"
        case .treasure:  return "💰"
        case .castle:    return "🏰"
        case .anchor:    return "⚓"
        case .starfish:  return "⭐"
        }
    }

    /// Fish cost to unlock.
    var cost: Int {
        switch self {
        case .coral:     return 8
        case .shell:     return 5
        case .treasure:  return 20
        case .castle:    return 30
        case .anchor:    return 12
        case .starfish:  return 6
        }
    }

    /// Normalized X position in the tank (0…1).
    var tankX: CGFloat {
        switch self {
        case .shell:     return 0.12
        case .coral:     return 0.28
        case .starfish:  return 0.42
        case .anchor:    return 0.58
        case .treasure:  return 0.74
        case .castle:    return 0.88
        }
    }

    /// Size of the decoration (width).
    var decoSize: CGFloat {
        switch self {
        case .coral:     return 32
        case .shell:     return 22
        case .treasure:  return 30
        case .castle:    return 38
        case .anchor:    return 26
        case .starfish:  return 20
        }
    }

    /// Primary color.
    var primaryColor: Color {
        switch self {
        case .coral:     return Color(hex: "FF6B6B")
        case .shell:     return Color(hex: "FFDAB9")
        case .treasure:  return Color(hex: "FFD700")
        case .castle:    return Color(hex: "D2B48C")
        case .anchor:    return Color(hex: "78909C")
        case .starfish:  return Color(hex: "FF8A65")
        }
    }

    /// Accent color.
    var accentColor: Color {
        switch self {
        case .coral:     return Color(hex: "E53935")
        case .shell:     return Color(hex: "BCAAA4")
        case .treasure:  return Color(hex: "8D6E63")
        case .castle:    return Color(hex: "A1887F")
        case .anchor:    return Color(hex: "546E7A")
        case .starfish:  return Color(hex: "E64A19")
        }
    }
}

// MARK: - Decoration Shape Views

/// Renders a single tank decoration as a vector shape.
struct TankDecorationView: View {
    let decoration: TankDecoration
    var size: CGFloat = 32

    var body: some View {
        switch decoration {
        case .coral:     coralView
        case .shell:     shellView
        case .treasure:  treasureView
        case .castle:    castleView
        case .anchor:    anchorView
        case .starfish:  starfishView
        }
    }

    // MARK: - Coral

    private var coralView: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Main branch
            var main = Path()
            main.move(to: CGPoint(x: w * 0.5, y: h))
            main.addCurve(
                to: CGPoint(x: w * 0.45, y: h * 0.15),
                control1: CGPoint(x: w * 0.48, y: h * 0.65),
                control2: CGPoint(x: w * 0.35, y: h * 0.3)
            )
            main.addCurve(
                to: CGPoint(x: w * 0.55, y: h * 0.15),
                control1: CGPoint(x: w * 0.50, y: h * 0.08),
                control2: CGPoint(x: w * 0.55, y: h * 0.08)
            )
            main.addCurve(
                to: CGPoint(x: w * 0.5, y: h),
                control1: CGPoint(x: w * 0.65, y: h * 0.3),
                control2: CGPoint(x: w * 0.52, y: h * 0.65)
            )
            main.closeSubpath()
            context.fill(main, with: .color(decoration.primaryColor))

            // Left branch
            var left = Path()
            left.move(to: CGPoint(x: w * 0.42, y: h * 0.55))
            left.addCurve(
                to: CGPoint(x: w * 0.15, y: h * 0.2),
                control1: CGPoint(x: w * 0.30, y: h * 0.45),
                control2: CGPoint(x: w * 0.15, y: h * 0.3)
            )
            left.addCurve(
                to: CGPoint(x: w * 0.25, y: h * 0.25),
                control1: CGPoint(x: w * 0.15, y: h * 0.12),
                control2: CGPoint(x: w * 0.22, y: h * 0.15)
            )
            left.addLine(to: CGPoint(x: w * 0.46, y: h * 0.5))
            left.closeSubpath()
            context.fill(left, with: .color(decoration.primaryColor.opacity(0.85)))

            // Right branch
            var right = Path()
            right.move(to: CGPoint(x: w * 0.56, y: h * 0.45))
            right.addCurve(
                to: CGPoint(x: w * 0.85, y: h * 0.12),
                control1: CGPoint(x: w * 0.70, y: h * 0.35),
                control2: CGPoint(x: w * 0.85, y: h * 0.22)
            )
            right.addCurve(
                to: CGPoint(x: w * 0.75, y: h * 0.18),
                control1: CGPoint(x: w * 0.88, y: h * 0.05),
                control2: CGPoint(x: w * 0.80, y: h * 0.08)
            )
            right.addLine(to: CGPoint(x: w * 0.54, y: h * 0.42))
            right.closeSubpath()
            context.fill(right, with: .color(decoration.accentColor.opacity(0.7)))

            // Tiny polyps (dots at branch tips)
            let dots: [(CGFloat, CGFloat)] = [
                (0.45, 0.12), (0.55, 0.12), (0.15, 0.18),
                (0.25, 0.22), (0.85, 0.10), (0.75, 0.16)
            ]
            for (dx, dy) in dots {
                var dot = Path()
                dot.addEllipse(in: CGRect(x: w * dx - 2, y: h * dy - 2, width: 4, height: 4))
                context.fill(dot, with: .color(Color.white.opacity(0.35)))
            }
        }
        .frame(width: size, height: size * 1.2)
    }

    // MARK: - Shell

    private var shellView: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Shell body — fan shape
            var shell = Path()
            shell.move(to: CGPoint(x: w * 0.5, y: h * 0.95))
            shell.addCurve(
                to: CGPoint(x: w * 0.05, y: h * 0.35),
                control1: CGPoint(x: w * 0.15, y: h * 0.9),
                control2: CGPoint(x: w * 0.0, y: h * 0.6)
            )
            shell.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.05),
                control1: CGPoint(x: w * 0.10, y: h * 0.12),
                control2: CGPoint(x: w * 0.30, y: h * 0.0)
            )
            shell.addCurve(
                to: CGPoint(x: w * 0.95, y: h * 0.35),
                control1: CGPoint(x: w * 0.70, y: h * 0.0),
                control2: CGPoint(x: w * 1.0, y: h * 0.12)
            )
            shell.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.95),
                control1: CGPoint(x: w * 1.0, y: h * 0.6),
                control2: CGPoint(x: w * 0.85, y: h * 0.9)
            )
            shell.closeSubpath()
            context.fill(shell, with: .linearGradient(
                Gradient(colors: [decoration.primaryColor, decoration.accentColor]),
                startPoint: CGPoint(x: w * 0.5, y: 0),
                endPoint: CGPoint(x: w * 0.5, y: h)
            ))

            // Ridges (lines radiating from base)
            for i in 0..<5 {
                let angle = Double(i) * 0.3 - 0.6
                var ridge = Path()
                ridge.move(to: CGPoint(x: w * 0.5, y: h * 0.9))
                let endX = w * 0.5 + w * 0.35 * CGFloat(sin(angle))
                let endY = h * 0.2 + h * 0.1 * CGFloat(abs(cos(angle)))
                ridge.addLine(to: CGPoint(x: endX, y: endY))
                context.stroke(ridge, with: .color(Color.white.opacity(0.15)), lineWidth: 0.8)
            }

            // Pearl highlight
            var pearl = Path()
            pearl.addEllipse(in: CGRect(x: w * 0.42, y: h * 0.55, width: w * 0.16, height: h * 0.16))
            context.fill(pearl, with: .color(Color.white.opacity(0.5)))
            var pearlGlint = Path()
            pearlGlint.addEllipse(in: CGRect(x: w * 0.46, y: h * 0.57, width: w * 0.05, height: h * 0.05))
            context.fill(pearlGlint, with: .color(Color.white.opacity(0.8)))
        }
        .frame(width: size, height: size * 0.9)
    }

    // MARK: - Treasure Chest

    private var treasureView: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Chest body (bottom half)
            var body = Path()
            body.addRoundedRect(in: CGRect(
                x: w * 0.08, y: h * 0.45,
                width: w * 0.84, height: h * 0.5
            ), cornerSize: CGSize(width: 3, height: 3))
            context.fill(body, with: .color(decoration.accentColor))

            // Chest lid (slightly open — arc)
            var lid = Path()
            lid.move(to: CGPoint(x: w * 0.06, y: h * 0.48))
            lid.addCurve(
                to: CGPoint(x: w * 0.94, y: h * 0.48),
                control1: CGPoint(x: w * 0.06, y: h * 0.18),
                control2: CGPoint(x: w * 0.94, y: h * 0.18)
            )
            lid.addLine(to: CGPoint(x: w * 0.92, y: h * 0.48))
            lid.addCurve(
                to: CGPoint(x: w * 0.08, y: h * 0.48),
                control1: CGPoint(x: w * 0.92, y: h * 0.24),
                control2: CGPoint(x: w * 0.08, y: h * 0.24)
            )
            lid.closeSubpath()
            context.fill(lid, with: .color(decoration.accentColor.opacity(0.8)))

            // Gold glow from inside
            var glow = Path()
            glow.addEllipse(in: CGRect(
                x: w * 0.25, y: h * 0.3,
                width: w * 0.5, height: h * 0.25
            ))
            context.fill(glow, with: .color(decoration.primaryColor.opacity(0.45)))

            // Lock/clasp
            var clasp = Path()
            clasp.addRoundedRect(in: CGRect(
                x: w * 0.42, y: h * 0.44,
                width: w * 0.16, height: h * 0.14
            ), cornerSize: CGSize(width: 2, height: 2))
            context.fill(clasp, with: .color(decoration.primaryColor))

            // Gold coins peeking out
            let coins: [(CGFloat, CGFloat)] = [(0.3, 0.38), (0.5, 0.35), (0.7, 0.38)]
            for (cx, cy) in coins {
                var coin = Path()
                coin.addEllipse(in: CGRect(x: w * cx - 3, y: h * cy - 2, width: 6, height: 5))
                context.fill(coin, with: .color(decoration.primaryColor.opacity(0.8)))
            }

            // Highlight band
            var band = Path()
            band.addRect(CGRect(x: w * 0.08, y: h * 0.6, width: w * 0.84, height: 2))
            context.fill(band, with: .color(decoration.primaryColor.opacity(0.3)))
        }
        .frame(width: size, height: size * 0.85)
    }

    // MARK: - Castle

    private var castleView: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Main tower
            var tower = Path()
            tower.addRect(CGRect(x: w * 0.3, y: h * 0.15, width: w * 0.4, height: h * 0.85))
            context.fill(tower, with: .color(decoration.primaryColor))

            // Left turret
            var leftT = Path()
            leftT.addRect(CGRect(x: w * 0.05, y: h * 0.25, width: w * 0.25, height: h * 0.75))
            context.fill(leftT, with: .color(decoration.primaryColor.opacity(0.85)))

            // Right turret
            var rightT = Path()
            rightT.addRect(CGRect(x: w * 0.70, y: h * 0.25, width: w * 0.25, height: h * 0.75))
            context.fill(rightT, with: .color(decoration.primaryColor.opacity(0.85)))

            // Battlements (crenellations) — main tower
            for i in 0..<3 {
                let bx = w * 0.32 + CGFloat(i) * w * 0.13
                var b = Path()
                b.addRect(CGRect(x: bx, y: h * 0.08, width: w * 0.08, height: h * 0.1))
                context.fill(b, with: .color(decoration.primaryColor))
            }

            // Battlements — turrets
            for i in 0..<2 {
                let lx = w * 0.07 + CGFloat(i) * w * 0.11
                var lb = Path()
                lb.addRect(CGRect(x: lx, y: h * 0.18, width: w * 0.07, height: h * 0.08))
                context.fill(lb, with: .color(decoration.primaryColor.opacity(0.85)))

                let rx = w * 0.72 + CGFloat(i) * w * 0.11
                var rb = Path()
                rb.addRect(CGRect(x: rx, y: h * 0.18, width: w * 0.07, height: h * 0.08))
                context.fill(rb, with: .color(decoration.primaryColor.opacity(0.85)))
            }

            // Gate (arch)
            var gate = Path()
            gate.move(to: CGPoint(x: w * 0.38, y: h))
            gate.addLine(to: CGPoint(x: w * 0.38, y: h * 0.6))
            gate.addCurve(
                to: CGPoint(x: w * 0.62, y: h * 0.6),
                control1: CGPoint(x: w * 0.38, y: h * 0.45),
                control2: CGPoint(x: w * 0.62, y: h * 0.45)
            )
            gate.addLine(to: CGPoint(x: w * 0.62, y: h))
            gate.closeSubpath()
            context.fill(gate, with: .color(Color(hex: "3E2723").opacity(0.7)))

            // Windows on turrets
            let windows: [(CGFloat, CGFloat)] = [(0.15, 0.45), (0.80, 0.45)]
            for (wx, wy) in windows {
                var win = Path()
                win.addEllipse(in: CGRect(x: w * wx - 3, y: h * wy, width: 6, height: 8))
                context.fill(win, with: .color(Color(hex: "3E2723").opacity(0.5)))
            }

            // Shadow lines for texture
            for i in stride(from: 0.35, to: 0.95, by: 0.12) {
                var line = Path()
                line.move(to: CGPoint(x: w * 0.3, y: h * i))
                line.addLine(to: CGPoint(x: w * 0.7, y: h * i))
                context.stroke(line, with: .color(decoration.accentColor.opacity(0.2)), lineWidth: 0.5)
            }
        }
        .frame(width: size, height: size * 1.3)
    }

    // MARK: - Anchor

    private var anchorView: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Ring at top
            var ring = Path()
            ring.addEllipse(in: CGRect(x: w * 0.35, y: h * 0.02, width: w * 0.3, height: h * 0.18))
            context.stroke(ring, with: .color(decoration.primaryColor), lineWidth: 2.5)

            // Vertical shaft
            var shaft = Path()
            shaft.move(to: CGPoint(x: w * 0.5, y: h * 0.18))
            shaft.addLine(to: CGPoint(x: w * 0.5, y: h * 0.85))
            context.stroke(shaft, with: .color(decoration.primaryColor), lineWidth: 3)

            // Cross bar
            var bar = Path()
            bar.move(to: CGPoint(x: w * 0.2, y: h * 0.4))
            bar.addLine(to: CGPoint(x: w * 0.8, y: h * 0.4))
            context.stroke(bar, with: .color(decoration.primaryColor), lineWidth: 2.5)

            // Bottom curve (flukes)
            var flukeL = Path()
            flukeL.move(to: CGPoint(x: w * 0.5, y: h * 0.85))
            flukeL.addCurve(
                to: CGPoint(x: w * 0.12, y: h * 0.6),
                control1: CGPoint(x: w * 0.3, y: h * 0.95),
                control2: CGPoint(x: w * 0.12, y: h * 0.8)
            )
            context.stroke(flukeL, with: .color(decoration.primaryColor), lineWidth: 2.5)

            var flukeR = Path()
            flukeR.move(to: CGPoint(x: w * 0.5, y: h * 0.85))
            flukeR.addCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.6),
                control1: CGPoint(x: w * 0.7, y: h * 0.95),
                control2: CGPoint(x: w * 0.88, y: h * 0.8)
            )
            context.stroke(flukeR, with: .color(decoration.primaryColor), lineWidth: 2.5)

            // Fluke tips (arrowheads)
            var tipL = Path()
            tipL.move(to: CGPoint(x: w * 0.12, y: h * 0.6))
            tipL.addLine(to: CGPoint(x: w * 0.08, y: h * 0.68))
            tipL.addLine(to: CGPoint(x: w * 0.2, y: h * 0.65))
            context.fill(tipL, with: .color(decoration.primaryColor))

            var tipR = Path()
            tipR.move(to: CGPoint(x: w * 0.88, y: h * 0.6))
            tipR.addLine(to: CGPoint(x: w * 0.92, y: h * 0.68))
            tipR.addLine(to: CGPoint(x: w * 0.8, y: h * 0.65))
            context.fill(tipR, with: .color(decoration.primaryColor))
        }
        .frame(width: size, height: size * 1.1)
        .opacity(0.6)
    }

    // MARK: - Starfish

    private var starfishView: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let cx = w / 2
            let cy = h / 2
            let outerR = min(w, h) * 0.48
            let innerR = outerR * 0.38

            // 5-pointed star
            var star = Path()
            for i in 0..<10 {
                let angle = Double(i) * .pi / 5.0 - .pi / 2.0
                let r = i % 2 == 0 ? outerR : innerR
                let px = cx + CGFloat(cos(angle)) * r
                let py = cy + CGFloat(sin(angle)) * r
                if i == 0 {
                    star.move(to: CGPoint(x: px, y: py))
                } else {
                    star.addLine(to: CGPoint(x: px, y: py))
                }
            }
            star.closeSubpath()
            context.fill(star, with: .linearGradient(
                Gradient(colors: [decoration.primaryColor, decoration.accentColor]),
                startPoint: CGPoint(x: cx, y: 0),
                endPoint: CGPoint(x: cx, y: h)
            ))

            // Center dot
            var dot = Path()
            dot.addEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))
            context.fill(dot, with: .color(Color.white.opacity(0.4)))

            // Arm dots
            for i in stride(from: 0, to: 10, by: 2) {
                let angle = Double(i) * .pi / 5.0 - .pi / 2.0
                let dotR = outerR * 0.6
                let dx = cx + CGFloat(cos(angle)) * dotR
                let dy = cy + CGFloat(sin(angle)) * dotR
                var armDot = Path()
                armDot.addEllipse(in: CGRect(x: dx - 1.5, y: dy - 1.5, width: 3, height: 3))
                context.fill(armDot, with: .color(Color.white.opacity(0.3)))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Decoration Shop View

/// Popover/sheet showing available tank decorations with buy/toggle buttons.
struct DecorationShopView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var rewardService = RewardService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.spacingMD) {
                    // Fish balance
                    HStack(spacing: 6) {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "4FC3F7"))
                        Text("\(rewardService.fish)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(DesignTokens.textPrimary)
                        Text(String(localized: "fish"))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.top, DesignTokens.spacingSM)

                    // Decoration grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: DesignTokens.spacingSM),
                        GridItem(.flexible(), spacing: DesignTokens.spacingSM)
                    ], spacing: DesignTokens.spacingSM) {
                        ForEach(TankDecoration.allCases) { deco in
                            decorationCard(deco)
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                }
                .padding(.bottom, DesignTokens.spacingXXL)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "Tank Decor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.accentActive)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func decorationCard(_ deco: TankDecoration) -> some View {
        let isOwned = rewardService.unlockedDecorations.contains(deco.rawValue)
        let isPlaced = rewardService.placedDecorations.contains(deco.rawValue)
        let canAfford = rewardService.fish >= deco.cost

        return VStack(spacing: DesignTokens.spacingSM) {
            // Preview
            TankDecorationView(decoration: deco, size: deco.decoSize * 1.3)
                .frame(height: 56)

            Text(deco.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(1)

            if isOwned {
                // Toggle placement
                Button {
                    rewardService.toggleDecoration(deco.rawValue, context: modelContext)
                    HapticService.shared.actionButtonTap()
                } label: {
                    Text(isPlaced ? String(localized: "Remove") : String(localized: "Place"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isPlaced ? DesignTokens.accentOverdue : DesignTokens.accentComplete)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill((isPlaced ? DesignTokens.accentOverdue : DesignTokens.accentComplete).opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            } else {
                // Buy button
                Button {
                    buyDecoration(deco)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 10))
                        Text("\(deco.cost)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(canAfford ? Color(hex: "4FC3F7") : DesignTokens.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(canAfford ? Color(hex: "4FC3F7").opacity(0.15) : Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canAfford)
            }
        }
        .padding(DesignTokens.spacingSM)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .nudgeAccessibility(
            label: "\(deco.label), \(isOwned ? (isPlaced ? String(localized: "placed") : String(localized: "owned")) : String(localized: "\(deco.cost) fish"))",
            hint: isOwned ? String(localized: "Tap to toggle placement") : String(localized: "Tap to purchase")
        )
    }

    private func buyDecoration(_ deco: TankDecoration) {
        guard rewardService.fish >= deco.cost else { return }
        rewardService.unlockDecoration(deco.rawValue, cost: deco.cost, context: modelContext)
        HapticService.shared.swipeDone()
    }
}
