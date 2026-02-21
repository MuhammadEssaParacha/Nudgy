//
//  NudgeIcon.swift
//  Nudge
//
//  A unified icon component that renders SF Symbols inside tinted circles.
//  Replaces ALL emoji text rendering throughout the app with crisp vector icons.
//
//  Usage:
//    NudgeIcon(symbol: category.icon, color: category.primaryColor, size: .medium)
//    NudgeIcon.category(.exercise)           // convenience
//    NudgeIcon.mood(.great)                  // convenience
//    NudgeIcon.fish(.tropical)               // convenience
//
//  3 sizes map to the old TaskIconView sizes but with a unified API.
//

import SwiftUI

// MARK: - NudgeIcon

struct NudgeIcon: View {
    let symbol: String
    var color: Color = DesignTokens.accentActive
    var size: NudgeIconSize = .medium
    var filled: Bool = false       // solid color fill (for selected state)
    var plain: Bool = false        // no circle background (inline)
    
    var body: some View {
        if plain {
            Image(systemName: symbol)
                .font(.system(size: size.iconPt, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: size.iconPt + 4, height: size.iconPt + 4)
        } else {
            Image(systemName: symbol)
                .font(.system(size: size.iconPt, weight: .semibold))
                .foregroundStyle(filled ? .white : color)
                .frame(width: size.framePt, height: size.framePt)
                .background(
                    Circle()
                        .fill(filled ? color : color.opacity(0.12))
                )
        }
    }
    
    // MARK: - Convenience Factories
    
    /// Category icon in a tinted circle.
    static func category(_ cat: TaskCategory, size: NudgeIconSize = .medium) -> NudgeIcon {
        NudgeIcon(symbol: cat.icon, color: cat.primaryColor, size: size)
    }
    
    /// Mood icon in a tinted circle.
    static func mood(_ level: MoodLevel, size: NudgeIconSize = .medium) -> NudgeIcon {
        NudgeIcon(symbol: level.icon, color: level.color, size: size)
    }
    
    /// Fish species icon.
    static func fish(_ species: FishSpecies, size: NudgeIconSize = .medium) -> NudgeIcon {
        NudgeIcon(symbol: species.icon, color: Color(hex: species.glowColorHex), size: size)
    }
    
    /// Tank decoration icon.
    static func decoration(_ deco: TankDecoration, size: NudgeIconSize = .medium) -> NudgeIcon {
        NudgeIcon(symbol: deco.icon, color: deco.primaryColor, size: size)
    }
}

// MARK: - NudgeIconSize

enum NudgeIconSize {
    case micro  // 18pt frame, 9pt icon  — inline chips
    case small  // 28pt frame, 12pt icon — list rows
    case medium // 36pt frame, 16pt icon — standard
    case large  // 48pt frame, 22pt icon — detail headers
    case hero   // 56pt frame, 26pt icon — feature cards
    
    var framePt: CGFloat {
        switch self {
        case .micro:  return 18
        case .small:  return 28
        case .medium: return 36
        case .large:  return 48
        case .hero:   return 56
        }
    }
    
    var iconPt: CGFloat {
        switch self {
        case .micro:  return 9
        case .small:  return 12
        case .medium: return 16
        case .large:  return 22
        case .hero:   return 26
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            // Category icons
            HStack(spacing: 12) {
                NudgeIcon.category(.call, size: .small)
                NudgeIcon.category(.exercise, size: .medium)
                NudgeIcon.category(.cooking, size: .large)
                NudgeIcon.category(.homework, size: .hero)
            }
            // Filled state
            HStack(spacing: 12) {
                NudgeIcon.category(.health, size: .medium).filled(true)
                NudgeIcon.category(.finance, size: .medium).filled(true)
                NudgeIcon.category(.creative, size: .medium).filled(true)
            }
            // Mood icons
            HStack(spacing: 12) {
                ForEach(MoodLevel.allCases, id: \.self) { mood in
                    NudgeIcon.mood(mood, size: .medium)
                }
            }
            // Fish icons
            HStack(spacing: 12) {
                ForEach(FishSpecies.allCases, id: \.self) { species in
                    NudgeIcon.fish(species, size: .medium)
                }
            }
            // Plain (no circle)
            HStack(spacing: 12) {
                NudgeIcon(symbol: "phone.fill", color: .green, size: .medium, plain: true)
                NudgeIcon(symbol: "message.fill", color: .blue, size: .medium, plain: true)
            }
        }
    }
    .preferredColorScheme(.dark)
}

// MARK: - View Modifier for filled

extension NudgeIcon {
    func filled(_ isFilled: Bool) -> NudgeIcon {
        var copy = self
        copy.filled = isFilled
        return copy
    }
}
