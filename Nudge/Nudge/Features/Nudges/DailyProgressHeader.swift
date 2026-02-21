//
//  DailyProgressHeader.swift
//  Nudge
//
//  Top-of-list progress summary: tasks done today, streak, fish earned.
//  Compact glassmorphic card with animated fish counters.
//

import SwiftUI

// MARK: - Fish Species reference (needed for last-caught display)

struct DailyProgressHeader: View {
    let completedToday: Int
    let totalToday: Int
    let streak: Int
    let fishToday: Int
    let fish: Int
    let lastSpecies: FishSpecies?
    var onFishHUDPosition: ((CGPoint) -> Void)? = nil
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var progress: Double {
        guard totalToday > 0 else { return 0 }
        return Double(completedToday) / Double(totalToday)
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // Progress bar + count
            HStack(spacing: DesignTokens.spacingSM) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            DesignTokens.accentComplete,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? .none : .spring(response: 0.6), value: progress)
                }
                .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completedToday)/\(totalToday) \(String(localized: "today"))")
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    if streak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(DesignTokens.accentStale)
                            Text(String(localized: "\(streak) day streak"))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Fish counters
                HStack(spacing: DesignTokens.spacingMD) {
                    // Fish today
                    HStack(spacing: 3) {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(DesignTokens.accentActive)
                        Text("\(fishToday)")
                            .font(AppTheme.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    .overlay(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                let frame = geo.frame(in: .global)
                                onFishHUDPosition?(CGPoint(x: frame.midX, y: frame.midY))
                            }
                        }
                    )
                    
                    // Total fish
                    HStack(spacing: 3) {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.cyan)
                        Text("\(fish)")
                            .font(AppTheme.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
        .nudgeAccessibility(
            label: String(localized: "\(completedToday) of \(totalToday) tasks done today. \(streak) day streak. \(fish) fish."),
            hint: nil,
            traits: .isHeader
        )
    }
}
