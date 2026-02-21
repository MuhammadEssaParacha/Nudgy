//
//  StatsStripView.swift
//  Nudge
//
//  Compressed stats bar below the action zone on the Nudges page.
//  Shows: fish caught today, streak (with multiplier), fish balance, tasks done.
//
//  Replaces the larger DailyProgressHeader with a compact,
//  information-dense strip that doesn't steal focus from the hero card.
//

import SwiftUI

struct StatsStripView: View {
    
    let completedToday: Int
    let totalToday: Int
    let streak: Int
    let fishToday: Int
    let fish: Int
    let lastSpecies: FishSpecies?
    var onFishHUDPosition: ((CGPoint) -> Void)? = nil
    
    @State private var fishBounce = false
    @State private var previousFishCount = 0
    
    private var hasStreakMultiplier: Bool {
        streak >= 3
    }
    
    private var progressFraction: Double {
        guard totalToday > 0 else { return 0 }
        return Double(completedToday) / Double(totalToday)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Fish today
            fishPill
            
            Spacer(minLength: 4)
            
            // Streak
            streakPill
            
            Spacer(minLength: 4)
            
            // Fish balance
            fishBalancePill
            
            Spacer(minLength: 4)
            
            // Progress
            progressPill
        }
        .padding(.horizontal, DesignTokens.spacingSM)
        .padding(.vertical, DesignTokens.spacingSM)
        .onChange(of: fishToday) { oldValue, newValue in
            if newValue > oldValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    fishBounce = true
                }
                // Reset bounce
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.4))
                    fishBounce = false
                }
            }
        }
    }
    
    // MARK: - Fish Pill
    
    private var fishPill: some View {
        HStack(spacing: 4) {
            MiniFishIcon(size: 14, species: lastSpecies)
            
            Text("\(fishToday)")
                .font(AppTheme.rounded(.caption, weight: .bold))
                .foregroundStyle(DesignTokens.goldCurrency)
                .scaleEffect(fishBounce ? 1.3 : 1.0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(DesignTokens.goldCurrency.opacity(0.08))
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .background {
            // Report position for fish arc target
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let frame = geo.frame(in: .global)
                        onFishHUDPosition?(CGPoint(x: frame.midX, y: frame.midY))
                    }
                    .onChange(of: geo.frame(in: .global).midY) { _, _ in
                        let frame = geo.frame(in: .global)
                        onFishHUDPosition?(CGPoint(x: frame.midX, y: frame.midY))
                    }
            }
        }
        .nudgeAccessibility(
            label: String(localized: "\(fishToday) fish caught today"),
            hint: String(localized: "Fish earned from completed tasks"),
            traits: .isStaticText
        )
    }
    
    // MARK: - Streak Pill
    
    private var streakPill: some View {
        HStack(spacing: 3) {
            FlameIcon(size: 12)
            
            Text("\(streak)")
                .font(AppTheme.rounded(.caption, weight: .bold))
                .foregroundStyle(hasStreakMultiplier ? DesignTokens.streakOrange : DesignTokens.textSecondary)
            
            if hasStreakMultiplier {
                HStack(spacing: 1) {
                    FlameIcon(size: 7)
                    Text("2×")
                        .font(AppTheme.rounded(.caption2, weight: .heavy))
                        .foregroundStyle(.white)
                }
                    .padding(.horizontal, 3)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(
                    hasStreakMultiplier
                        ? DesignTokens.streakOrange.opacity(0.08)
                        : Color.white.opacity(0.04)
                )
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .nudgeAccessibility(
            label: String(localized: "\(streak) day streak"),
            hint: hasStreakMultiplier
                ? String(localized: "Double fish active")
                : String(localized: "Complete tasks 3 days in a row for double fish"),
            traits: .isStaticText
        )
    }
    
    // MARK: - Fish Balance Pill
    
    private var fishBalancePill: some View {
        HStack(spacing: 3) {
            Image(systemName: "fish.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.goldCurrency)
            
            Text("\(fish)")
                .font(AppTheme.rounded(.caption, weight: .bold))
                .foregroundStyle(DesignTokens.fishTint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(DesignTokens.fishTint.opacity(0.06))
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .nudgeAccessibility(
            label: String(localized: "\(fish) fish"),
            hint: String(localized: "Spend fish on penguin accessories"),
            traits: .isStaticText
        )
    }
    
    // MARK: - Progress Pill
    
    private var progressPill: some View {
        HStack(spacing: 4) {
            // Mini progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                
                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(DesignTokens.accentComplete, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(AnimationConstants.springSmooth, value: progressFraction)
            }
            .frame(width: 14, height: 14)
            
            Text("\(completedToday)/\(totalToday)")
                .font(AppTheme.rounded(.caption, weight: .bold))
                .foregroundStyle(
                    completedToday == totalToday && totalToday > 0
                        ? DesignTokens.accentComplete
                        : DesignTokens.textPrimary
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(
                    completedToday == totalToday && totalToday > 0
                        ? DesignTokens.accentComplete.opacity(0.08)
                        : Color.white.opacity(0.04)
                )
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .nudgeAccessibility(
            label: String(localized: "\(completedToday) of \(totalToday) tasks done today"),
            hint: nil,
            traits: .isStaticText
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            StatsStripView(
                completedToday: 2,
                totalToday: 5,
                streak: 5,
                fishToday: 3,
                fish: 47,
                lastSpecies: .tropical
            )
            
            StatsStripView(
                completedToday: 5,
                totalToday: 5,
                streak: 1,
                fishToday: 5,
                fish: 120,
                lastSpecies: .swordfish
            )
            
            StatsStripView(
                completedToday: 0,
                totalToday: 3,
                streak: 0,
                fishToday: 0,
                fish: 8,
                lastSpecies: nil
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
