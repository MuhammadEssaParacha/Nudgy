//
//  StreakRiskBanner.swift
//  Nudge
//
//  Inline banner shown when the user has a streak ≥ 3 days
//  but hasn't completed any task today yet.
//  Uses loss aversion to motivate without guilt.
//
//  "🔥 5-day streak at risk — complete one task to keep your 2× bonus!"
//

import SwiftUI

struct StreakRiskBanner: View {
    
    let streak: Int
    let completedToday: Int
    
    /// Only show if streak is worth protecting AND user hasn't started today
    private var shouldShow: Bool {
        streak >= 3 && completedToday == 0
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            FlameIcon(size: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "\(streak)-day streak at risk"))
                    .font(AppTheme.footnote.weight(.semibold))
                    .foregroundStyle(DesignTokens.streakOrange)
                
                Text(String(localized: "Complete one task to keep your 2× bonus"))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM + 2)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                .fill(DesignTokens.streakOrange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                        .strokeBorder(DesignTokens.streakOrange.opacity(0.15), lineWidth: 0.5)
                )
        }
        .nudgeAccessibility(
            label: String(localized: "\(streak) day streak at risk. Complete one task to keep double fish."),
            hint: nil,
            traits: .isStaticText
        )
        .opacity(shouldShow ? 1 : 0)
        .frame(maxHeight: shouldShow ? nil : 0, alignment: .top)
        .clipped()
        .animation(AnimationConstants.springSmooth, value: shouldShow)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            StreakRiskBanner(streak: 5, completedToday: 0)
            StreakRiskBanner(streak: 3, completedToday: 0)
            StreakRiskBanner(streak: 2, completedToday: 0)  // Should NOT show
            StreakRiskBanner(streak: 5, completedToday: 1)  // Should NOT show
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
