//
//  FishBountyLabel.swift
//  Nudge
//
//  Shows the fish species + fish reward a task will earn.
//  Displays bounty BEFORE completion to motivate action.
//
//  Usage:
//    FishBountyLabel(item: nudgeItem, streak: 5)
//

import SwiftUI

struct FishBountyLabel: View {
    
    let item: NudgeItem
    let streak: Int
    var compact: Bool = false
    
    private var species: FishSpecies {
        FishEconomy.speciesForTask(item)
    }
    
    private var baseValue: Int {
        species.fishValue
    }
    
    private var hasMultiplier: Bool {
        streak >= 3
    }
    
    private var totalValue: Int {
        FishEconomy.fishForCatch(species: species, streak: streak, isAllClear: false)
    }
    
    var body: some View {
        HStack(spacing: compact ? 3 : 5) {
            // Species icon (vector)
            MiniFishIcon(size: compact ? 12 : 16, species: species)
            
            if !compact {
                // Species name
                Text(species.label)
                    .font(AppTheme.caption)
                    .foregroundStyle(speciesColor.opacity(0.9))
            }
            
            // Separator
            Text("·")
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
            
            // Fish value
            HStack(spacing: 2) {
                Text("\(totalValue)")
                    .font(compact ? AppTheme.captionBold : .system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.goldCurrency)
                
                Image(systemName: "fish.fill")
                    .font(.system(size: compact ? 10 : 12))
                    .foregroundStyle(DesignTokens.goldCurrency)
            }
            
            // Streak multiplier badge
            if hasMultiplier {
                HStack(spacing: 1) {
                    FlameIcon(size: 8)
                    Text("×2")
                        .font(AppTheme.rounded(.caption2, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.streakOrange, DesignTokens.streakDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background {
            Capsule()
                .fill(speciesColor.opacity(0.08))
                .overlay(
                    Capsule()
                        .strokeBorder(speciesColor.opacity(0.15), lineWidth: 0.5)
                )
        }
        .nudgeAccessibility(
            label: String(localized: "\(species.label) catch worth \(totalValue) fish"),
            hint: hasMultiplier
                ? String(localized: "Streak multiplier active")
                : String(localized: "Complete this task to earn fish"),
            traits: .isStaticText
        )
    }
    
    // MARK: - Species Color
    
    private var speciesColor: Color {
        switch species {
        case .catfish:   return DesignTokens.textSecondary
        case .tropical:  return DesignTokens.speciesTropical
        case .swordfish: return DesignTokens.goldCurrency
        case .whale:     return DesignTokens.speciesRare
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            // Low-value task
            FishBountyLabel(
                item: NudgeItem(content: "Buy milk", emoji: "🥛", sortOrder: 1),
                streak: 0
            )
            
            // Mid-value with streak
            FishBountyLabel(
                item: NudgeItem(content: "Email landlord", emoji: "📧", actionType: .email, sortOrder: 2),
                streak: 5
            )
            
            // Compact variant
            FishBountyLabel(
                item: NudgeItem(content: "Buy milk", emoji: "🥛", sortOrder: 3),
                streak: 3,
                compact: true
            )
        }
    }
    .preferredColorScheme(.dark)
}
