//
//  ChallengeProgressBadge.swift
//  Nudge
//
//  Shows in-progress daily challenge as a compact progress bar.
//  Appears below the stats strip when a challenge is partially complete.
//
//  "🏆 Hat Trick: 2/3 done · +3❄️ bonus"
//  ████████░░░░
//

import SwiftUI

struct ChallengeProgressBadge: View {
    
    let challenges: [DailyChallenge]
    
    /// The most relevant challenge to surface (first incomplete one)
    private var activeChallenges: [DailyChallenge] {
        challenges.filter { !$0.isCompleted }
    }
    
    private var hasChallenge: Bool {
        activeChallenges.first != nil
    }
    
    var body: some View {
        Group {
            if let challenge = activeChallenges.first {
                challengeRow(challenge)
            } else {
                // Invisible placeholder for smooth collapse
                Color.clear.frame(height: 0)
            }
        }
        .opacity(hasChallenge ? 1 : 0)
        .frame(maxHeight: hasChallenge ? nil : 0, alignment: .top)
        .clipped()
        .animation(AnimationConstants.springSmooth, value: hasChallenge)
    }
    
    // MARK: - Challenge Row
    
    private func challengeRow(_ challenge: DailyChallenge) -> some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Icon
            Image(systemName: challenge.icon)
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.goldCurrency)
            
            // Title + bonus
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(challenge.title)
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    HStack(spacing: 2) {
                        Text("· +\(challenge.bonusFish)")
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.goldCurrency)
                        Image(systemName: "fish.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DesignTokens.goldCurrency)
                    }
                }
                
                // Progress bar
                progressBar(for: challenge)
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                .fill(DesignTokens.goldCurrency.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                        .strokeBorder(DesignTokens.goldCurrency.opacity(0.1), lineWidth: 0.5)
                )
        }
        .nudgeAccessibility(
            label: String(localized: "Daily challenge: \(challenge.title). Bonus: \(challenge.bonusFish) fish"),
            hint: nil,
            traits: .isStaticText
        )
    }
    
    // MARK: - Progress Bar
    
    private func progressBar(for challenge: DailyChallenge) -> some View {
        let (current, total) = challengeProgress(challenge)
        let fraction = total > 0 ? Double(current) / Double(total) : 0
        
        return HStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.08))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.goldCurrency, DesignTokens.streakOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 4)
            
            if total > 0 {
                Text("\(current)/\(total)")
                    .font(AppTheme.rounded(.caption2, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Progress Logic
    
    private func challengeProgress(_ challenge: DailyChallenge) -> (current: Int, total: Int) {
        switch challenge.requirement {
        case .completeTasks(let count):
            let completed = RewardService.shared.tasksCompletedToday
            return (min(completed, count), count)
        case .clearAll:
            return (0, 1)
        case .brainDump:
            return (0, 1)
        case .maintainStreak:
            return (RewardService.shared.tasksCompletedToday > 0 ? 1 : 0, 1)
        case .completeBeforeNoon:
            return (0, 1)
        case .completeCategory(_, let count):
            return (challenge.isCompleted ? count : 0, count)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            ChallengeProgressBadge(challenges: [
                DailyChallenge(
                    id: "hat_trick",
                    title: "Hat Trick",
                    description: "Complete 3 tasks",
                    icon: "3.circle.fill",
                    bonusFish: 3,
                    requirement: .completeTasks(count: 3),
                    isCompleted: false
                ),
                DailyChallenge(
                    id: "first_catch",
                    title: "First Catch",
                    description: "Complete 1 task",
                    icon: "1.circle.fill",
                    bonusFish: 1,
                    requirement: .completeTasks(count: 1),
                    isCompleted: true
                ),
            ])
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
