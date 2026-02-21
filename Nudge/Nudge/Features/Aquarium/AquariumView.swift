//
//  AquariumView.swift
//  Nudge
//
//  Full-page aquarium view showing your weekly catch collection.
//  Vector fish swim with tail wag animation driven by TimelineView.
//  Weekly progress, species collection, and recent catches.
//

import SwiftUI

// MARK: - Aquarium View

struct AquariumView: View {
    
    let catches: [FishCatch]
    let level: Int
    let streak: Int
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var weeklyCatches: [FishCatch] {
        FishEconomy.thisWeekCatches(from: catches)
    }
    
    private var speciesCounts: [FishSpecies: Int] {
        FishEconomy.weeklySpeciesCount(from: catches)
    }
    
    private var weeklyProgress: Double {
        FishEconomy.weeklyProgress(catches: catches, level: level)
    }
    
    private var weeklyGoal: Int {
        FishEconomy.weeklyGoal(level: level)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingLG) {
                // Full-size aquarium tank
                aquariumTank
                
                // Weekly Progress
                weeklyProgressCard
                
                // Species Collection
                speciesGrid
                
                // Recent Catches
                recentCatchesList
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, DesignTokens.spacingXXL)
        }
        .navigationTitle(String(localized: "Aquarium"))
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Aquarium Tank (Full Size)
    
    private var aquariumTank: some View {
        AquariumTankView(
            catches: catches,
            level: level,
            streak: streak,
            height: 300
        )
    }
    
    // MARK: - Weekly Progress
    
    private var weeklyProgressCard: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            HStack {
                Text(String(localized: "This Week"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                Spacer()
                Text("\(weeklyCatches.count)/\(weeklyGoal)")
                    .font(AppTheme.captionBold)
                    .foregroundStyle(DesignTokens.accentActive)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.accentActive, DesignTokens.accentComplete],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * weeklyProgress)
                }
            }
            .frame(height: 8)
            
            if weeklyProgress >= 1.0 {
                Text(String(localized: "🎉 Weekly goal reached! Nudgy is well-fed!"))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.accentComplete)
            }
        }
        .padding(DesignTokens.spacingMD)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
    
    // MARK: - Species Grid
    
    private var speciesGrid: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(String(localized: "Collection"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(FishSpecies.allCases, id: \.self) { species in
                    speciesCard(species)
                }
            }
        }
    }
    
    private func speciesCard(_ species: FishSpecies) -> some View {
        let count = speciesCounts[species] ?? 0
        return VStack(spacing: DesignTokens.spacingXS) {
            // Vector fish instead of emoji
            FishView(
                size: 28,
                color: species.fishColor,
                accentColor: species.fishAccentColor
            )
            .opacity(count > 0 ? 1 : 0.3)

            Text("\(count)")
                .font(AppTheme.captionBold)
                .foregroundStyle(count > 0 ? DesignTokens.textPrimary : DesignTokens.textTertiary)
            Text(species.label)
                .font(.system(size: 9))
                .foregroundStyle(DesignTokens.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingSM)
        .background {
            if count > 0 {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: species.glowColorHex).opacity(0.08))
            }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
    }
    
    // MARK: - Recent Catches
    
    private var recentCatchesList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(String(localized: "Recent Catches"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            if weeklyCatches.isEmpty {
                Text(String(localized: "No fish caught yet this week. Complete some tasks! 🎣"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .padding(.vertical, DesignTokens.spacingMD)
            } else {
                ForEach(recentFishList) { fish in
                    HStack(spacing: DesignTokens.spacingSM) {
                        FishView(
                            size: 22,
                            color: fish.species.fishColor,
                            accentColor: fish.species.fishAccentColor
                        )
                        .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(fish.taskEmoji) \(fish.taskContent)")
                                .font(AppTheme.body)
                                .foregroundStyle(DesignTokens.textPrimary)
                                .lineLimit(1)
                            Text(fish.caughtAt.formatted(.relative(presentation: .named)))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Text("+\(fish.species.fishValue)")
                            Image(systemName: "fish.fill")
                                .font(.system(size: 8))
                        }
                            .font(AppTheme.captionBold)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    .padding(.vertical, DesignTokens.spacingXS)
                }
            }
        }
    }
    
    private var recentFishList: [FishCatch] {
        Array(weeklyCatches.suffix(10).reversed())
    }
}
