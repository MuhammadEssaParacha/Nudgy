//
//  IconVectorShapes.swift
//  Nudge
//
//  Bezier-drawn vector icons for stats, counters, and bounty labels.
//  Matches the hand-drawn FishShape style from IntroVectorShapes.
//  Never use emoji for these — vectors stay crisp at any size and
//  render consistently against the dark Antarctic glass background.
//
//  Icons:
//  - FlameShape / FlameIcon     — streak fire
//  - MiniFishIcon               — compact fish for counters (reuses FishShape)
//

import SwiftUI

// MARK: - Flame Shape (Streak)

/// A warm, organic flame drawn with bezier curves.
/// Slightly asymmetric for character — not a generic icon.
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            // Start at bottom center
            p.move(to: CGPoint(x: w * 0.50, y: h))
            
            // Left base curve outward
            p.addCurve(
                to: CGPoint(x: w * 0.12, y: h * 0.55),
                control1: CGPoint(x: w * 0.22, y: h * 0.95),
                control2: CGPoint(x: w * 0.08, y: h * 0.75)
            )
            
            // Left side up to tip
            p.addCurve(
                to: CGPoint(x: w * 0.38, y: h * 0.05),
                control1: CGPoint(x: w * 0.16, y: h * 0.35),
                control2: CGPoint(x: w * 0.22, y: h * 0.12)
            )
            
            // Tip — slight asymmetric lean right
            p.addCurve(
                to: CGPoint(x: w * 0.55, y: h * 0.00),
                control1: CGPoint(x: w * 0.44, y: h * 0.01),
                control2: CGPoint(x: w * 0.50, y: h * 0.00)
            )
            
            // Right side from tip down
            p.addCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.52),
                control1: CGPoint(x: w * 0.78, y: h * 0.10),
                control2: CGPoint(x: w * 0.92, y: h * 0.32)
            )
            
            // Right base curve back to center
            p.addCurve(
                to: CGPoint(x: w * 0.50, y: h),
                control1: CGPoint(x: w * 0.85, y: h * 0.72),
                control2: CGPoint(x: w * 0.72, y: h * 0.95)
            )
            
            p.closeSubpath()
        }
    }
}

/// Inner flame highlight shape — the bright core.
private struct FlameInnerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            p.move(to: CGPoint(x: w * 0.50, y: h))
            
            p.addCurve(
                to: CGPoint(x: w * 0.25, y: h * 0.55),
                control1: CGPoint(x: w * 0.30, y: h * 0.92),
                control2: CGPoint(x: w * 0.20, y: h * 0.72)
            )
            
            p.addCurve(
                to: CGPoint(x: w * 0.48, y: h * 0.25),
                control1: CGPoint(x: w * 0.30, y: h * 0.38),
                control2: CGPoint(x: w * 0.38, y: h * 0.28)
            )
            
            p.addCurve(
                to: CGPoint(x: w * 0.75, y: h * 0.52),
                control1: CGPoint(x: w * 0.62, y: h * 0.22),
                control2: CGPoint(x: w * 0.78, y: h * 0.35)
            )
            
            p.addCurve(
                to: CGPoint(x: w * 0.50, y: h),
                control1: CGPoint(x: w * 0.72, y: h * 0.70),
                control2: CGPoint(x: w * 0.65, y: h * 0.92)
            )
            
            p.closeSubpath()
        }
    }
}

/// Complete flame icon with gradient fill, inner glow, and highlight.
struct FlameIcon: View {
    var size: CGFloat = 16
    
    var body: some View {
        ZStack {
            // Outer flame — warm orange-to-red gradient
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.streakOrange,
                            DesignTokens.streakDeep
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Inner flame — bright yellow core
            FlameInnerShape()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.goldCurrency,
                            DesignTokens.streakOrange
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Sheen highlight — top-left catch
            FlameShape()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        center: UnitPoint(x: 0.4, y: 0.2),
                        startRadius: 0,
                        endRadius: size * 0.3
                    )
                )
        }
        .frame(width: size, height: size * 1.25)
    }
}

// MARK: - Mini Fish Icon (for counters)

/// Compact fish icon for stats pills and counters.
/// Reuses FishShape from IntroVectorShapes with the correct colors.
struct MiniFishIcon: View {
    var size: CGFloat = 14
    var species: FishSpecies? = nil
    
    private var bodyColor: Color {
        switch species {
        case .tropical:  return DesignTokens.speciesTropical
        case .swordfish: return DesignTokens.goldCurrency
        case .whale:     return DesignTokens.speciesRare
        case .catfish, .none: return Color(hex: "4FC3F7")
        }
    }
    
    private var accentColor: Color {
        switch species {
        case .tropical:  return Color(hex: "00897B")
        case .swordfish: return DesignTokens.streakOrange
        case .whale:     return Color(hex: "6A1B9A")
        case .catfish, .none: return Color(hex: "0288D1")
        }
    }
    
    var body: some View {
        ZStack {
            // Body gradient
            FishShape()
                .fill(
                    LinearGradient(
                        colors: [bodyColor, accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Sheen
            FishShape()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        center: UnitPoint(x: 0.55, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.3
                    )
                )
            
            // Eye
            Circle()
                .fill(Color(hex: "0A0A0E"))
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: size * 0.15, y: -size * 0.03)
            
            // Eye glint
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.06, height: size * 0.06)
                .offset(x: size * 0.17, y: -size * 0.05)
        }
        .frame(width: size, height: size * 0.65)
    }
}

// MARK: - Previews

#Preview("All Icons") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 32) {
            // Flame sizes
            HStack(spacing: 24) {
                FlameIcon(size: 12)
                FlameIcon(size: 16)
                FlameIcon(size: 24)
                FlameIcon(size: 32)
            }
            
            // Mini fish species
            HStack(spacing: 16) {
                MiniFishIcon(size: 14, species: nil)
                MiniFishIcon(size: 14, species: .tropical)
                MiniFishIcon(size: 14, species: .swordfish)
                MiniFishIcon(size: 14, species: .whale)
                MiniFishIcon(size: 20)
            }
            
            // Stat pill mockup
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    MiniFishIcon(size: 14)
                    Text("3")
                        .font(AppTheme.rounded(.caption, weight: .bold))
                        .foregroundStyle(DesignTokens.goldCurrency)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(DesignTokens.goldCurrency.opacity(0.08)))
                
                HStack(spacing: 4) {
                    FlameIcon(size: 12)
                    Text("5")
                        .font(AppTheme.rounded(.caption, weight: .bold))
                        .foregroundStyle(DesignTokens.streakOrange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(DesignTokens.streakOrange.opacity(0.08)))
            }
        }
    }
    .preferredColorScheme(.dark)
}
