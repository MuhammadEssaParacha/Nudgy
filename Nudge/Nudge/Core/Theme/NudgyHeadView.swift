//
//  NudgyHeadView.swift
//  Nudge
//
//  Standalone Nudgy penguin head — bezier-drawn face extracted from PenguinMascot.
//  Used in aquarium empty state, badges, and anywhere a small Nudgy icon is needed.
//  Renders: dark plumage head, white face patch, eyes with shine, beak, cheek blush.
//

import SwiftUI

struct NudgyHeadView: View {
    let size: CGFloat
    var accentColor: Color = DesignTokens.accentActive

    private var p: CGFloat { size }

    var body: some View {
        ZStack {
            // Head — dark plumage ellipse
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "2A2A42"), Color(hex: "1A1A2E")],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: p * 0.45
                    )
                )
                .frame(width: p, height: p * 0.92)

            // Rim light
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "6688BB").opacity(0.25),
                            Color(hex: "6688BB").opacity(0.06),
                            Color.clear, Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: p * 0.008
                )
                .frame(width: p, height: p * 0.92)

            // Face patch — white area
            Ellipse()
                .fill(Color.white)
                .frame(width: p * 0.66, height: p * 0.56)
                .offset(y: p * 0.06)

            // Cheek blush
            HStack(spacing: p * 0.30) {
                Circle()
                    .fill(Color(hex: "FF6B8A").opacity(0.30))
                    .frame(width: p * 0.15, height: p * 0.15)
                Circle()
                    .fill(Color(hex: "FF6B8A").opacity(0.30))
                    .frame(width: p * 0.15, height: p * 0.15)
            }
            .offset(y: p * 0.10)

            // Eyes
            HStack(spacing: p * 0.16) {
                // Left eye
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: p * 0.19, height: p * 0.19)
                    Circle()
                        .fill(Color(hex: "0A0A0E"))
                        .frame(width: p * 0.15, height: p * 0.15)
                    // Shine
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: p * 0.06, height: p * 0.06)
                        .offset(x: p * 0.04, y: -p * 0.04)
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: p * 0.03, height: p * 0.03)
                        .offset(x: -p * 0.03, y: p * 0.04)
                }

                // Right eye (slightly larger)
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: p * 0.20, height: p * 0.20)
                    Circle()
                        .fill(Color(hex: "0A0A0E"))
                        .frame(width: p * 0.16, height: p * 0.16)
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: p * 0.065, height: p * 0.065)
                        .offset(x: p * 0.045, y: -p * 0.045)
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: p * 0.032, height: p * 0.032)
                        .offset(x: -p * 0.035, y: p * 0.045)
                }
            }
            .offset(y: -p * 0.02)

            // Beak
            BeakShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "3399FF"), accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: p * 0.14, height: p * 0.12)
                .offset(y: p * 0.16)
        }
        .frame(width: p, height: p)
        .drawingGroup()
    }
}
