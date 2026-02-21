//
//  DailyChallenges.swift
//  Nudge
//
//  Daily challenge / mini-quest system for ADHD-friendly micro-goals.
//
//  Each day generates 2–3 small challenges based on the player's current
//  level and streak. Completing them awards bonus fish.
//
//  Challenges are intentionally tiny and achievable:
//    - "Complete 1 task"                     (always available)
//    - "Complete 3 tasks"                    (level 2+)
//    - "Brain dump something"               (level 3+)
//    - "Clear all tasks"                    (level 4+)
//    - "Complete a task before noon"         (level 5+)
//    - "Maintain your streak"               (when streak ≥ 2)
//
//  Stored in RewardService (no persistence needed — regenerate daily).
//

import SwiftUI

// MARK: - Challenge Definition

struct DailyChallenge: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let bonusFish: Int
    let requirement: ChallengeRequirement
    var isCompleted: Bool = false

    enum ChallengeRequirement: Equatable {
        case completeTasks(count: Int)
        case clearAll
        case brainDump
        case maintainStreak
        case completeBeforeNoon
        case completeCategory(rawValue: String, count: Int)
    }
}

// MARK: - Challenge Generator

enum ChallengeGenerator {

    /// Generate today's challenges based on player state.
    static func generateDaily(level: Int, streak: Int, topCategory: TaskCategory? = nil) -> [DailyChallenge] {
        var challenges: [DailyChallenge] = []

        // Always: Complete 1 task (easy win)
        challenges.append(DailyChallenge(
            id: "complete-1",
            title: String(localized: "First Catch"),
            description: String(localized: "Complete 1 task"),
            icon: "fish.fill",
            bonusFish: 1,
            requirement: .completeTasks(count: 1)
        ))

        // Level 2+: Complete 3 tasks
        if level >= 2 {
            challenges.append(DailyChallenge(
                id: "complete-3",
                title: String(localized: "Hat Trick"),
                description: String(localized: "Complete 3 tasks"),
                icon: "star.fill",
                bonusFish: 3,
                requirement: .completeTasks(count: 3)
            ))
        }

        // Level 3+: Brain dump (voice or typed)
        if level >= 3 {
            challenges.append(DailyChallenge(
                id: "brain-dump",
                title: String(localized: "Mind Sweep"),
                description: String(localized: "Do a brain unload"),
                icon: "brain.fill",
                bonusFish: 2,
                requirement: .brainDump
            ))
        }

        // Level 4+: Clear all
        if level >= 4 {
            challenges.append(DailyChallenge(
                id: "clear-all",
                title: String(localized: "Clean Slate"),
                description: String(localized: "Clear all tasks"),
                icon: "checkmark.seal.fill",
                bonusFish: 5,
                requirement: .clearAll
            ))
        }

        // Level 5+: Before noon
        if level >= 5 {
            challenges.append(DailyChallenge(
                id: "before-noon",
                title: String(localized: "Early Bird"),
                description: String(localized: "Complete a task before noon"),
                icon: "sunrise.fill",
                bonusFish: 2,
                requirement: .completeBeforeNoon
            ))
        }

        // Streak challenge (when streak ≥ 2)
        if streak >= 2 {
            challenges.append(DailyChallenge(
                id: "streak",
                title: String(localized: "Keep It Going"),
                description: String(localized: "Maintain your \(streak)-day streak"),
                icon: "flame.fill",
                bonusFish: streak,
                requirement: .maintainStreak
            ))
        }

        // Phase 10: Category-specific challenge (level 3+ and when user has a dominant category)
        if level >= 3, let cat = topCategory, cat != .general {
            challenges.append(DailyChallenge(
                id: "category-\(cat.rawValue)",
                title: String(localized: "\(cat.emoji) \(cat.label) Focus"),
                description: String(localized: "Complete a \(cat.label.lowercased()) task"),
                icon: "tag.fill",
                bonusFish: 2,
                requirement: .completeCategory(rawValue: cat.rawValue, count: 1)
            ))
        }

        // Limit to 3 challenges per day (pick the first 3 based on level gating)
        return Array(challenges.prefix(3))
    }
}

// MARK: - Daily Challenge Card

struct DailyChallengeCard: View {
    let challenge: DailyChallenge
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(challenge.isCompleted
                          ? DesignTokens.accentComplete.opacity(0.15)
                          : Color.white.opacity(0.06))
                    .frame(width: 32, height: 32)

                Image(systemName: challenge.isCompleted ? "checkmark" : challenge.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(challenge.isCompleted
                                    ? DesignTokens.accentComplete
                                    : Color(hex: "FFD700"))
            }

            // Text
            VStack(alignment: .leading, spacing: 1) {
                Text(challenge.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(challenge.isCompleted
                                    ? DesignTokens.textTertiary
                                    : .white)
                    .strikethrough(challenge.isCompleted)

                Text(challenge.description)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)
            }

            Spacer()

            // Reward
            HStack(spacing: 2) {
                Image(systemName: "fish.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: "FFD700").opacity(challenge.isCompleted ? 0.3 : 0.8))

                Text("+\(challenge.bonusFish)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(challenge.isCompleted
                                    ? DesignTokens.textTertiary
                                    : Color(hex: "FFD700"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            challenge.isCompleted
                                ? DesignTokens.accentComplete.opacity(0.15)
                                : Color.white.opacity(0.05),
                            lineWidth: 0.5
                        )
                )
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        .opacity(challenge.isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Daily Challenges HUD

/// Expandable panel showing today's challenges. Sits below the AltitudeHUD.
struct DailyChallengesPanel: View {
    let challenges: [DailyChallenge]
    @State private var isExpanded = false

    private var completedCount: Int {
        challenges.filter(\.isCompleted).count
    }

    private var totalBonusFish: Int {
        challenges.filter(\.isCompleted).reduce(0) { $0 + $1.bonusFish }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Collapsed: mini summary bar
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "FFD700"))

                    Text(String(localized: "\(completedCount)/\(challenges.count) Quests"))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    if totalBonusFish > 0 {
                        HStack(spacing: 1) {
                            Image(systemName: "fish.fill")
                                .font(.system(size: 7))
                            Text("+\(totalBonusFish)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(DesignTokens.accentComplete)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)

            // Expanded: challenge cards
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(challenges) { challenge in
                        DailyChallengeCard(challenge: challenge)
                    }
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Preview

#Preview("Challenges Panel") {
    let challenges = ChallengeGenerator.generateDaily(level: 5, streak: 3)

    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            DailyChallengesPanel(challenges: challenges)
                .padding()
            Spacer()
        }
    }
}

#Preview("Challenge Card — Completed") {
    ZStack {
        Color.black
        DailyChallengeCard(challenge: DailyChallenge(
            id: "test",
            title: "First Catch",
            description: "Complete 1 task",
            icon: "fish.fill",
            bonusFish: 1,
            requirement: .completeTasks(count: 1),
            isCompleted: true
        ))
        .padding()
    }
}
