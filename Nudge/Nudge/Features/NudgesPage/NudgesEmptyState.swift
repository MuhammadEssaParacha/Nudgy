//
//  NudgesEmptyState.swift
//  Nudge
//
//  Empty state for the Nudges page.
//  Three variants:
//  1. All clear (🐋 Whale catch!) — last task completed, celebrate
//  2. All snoozed — tasks sleeping, offer to wake one
//  3. Zero tasks — fresh start, invite brain dump or quick add
//
//  ADHD design: never a blank white screen. Nudgy always has something to say.
//

import SwiftUI

struct NudgesEmptyState: View {
    
    let variant: EmptyVariant
    let snoozedCount: Int
    let lastFishEarned: Int
    /// Phase 7: Per-category completion counts for the "all clear" recap
    var categoryRecap: [(icon: String, label: String, color: Color, count: Int)] = []
    /// Callback to wake the oldest snoozed task
    var onWakeSnooze: (() -> Void)?
    
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    enum EmptyVariant {
        case allClear       // Just finished everything
        case allSnoozed     // Tasks exist but all sleeping
        case noTasks        // Nothing at all
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()
            
            Group {
                switch variant {
                case .allClear:
                    allClearView
                case .allSnoozed:
                    allSnoozedView
                case .noTasks:
                    noTasksView
                }
            }
            .animation(reduceMotion ? .none : AnimationConstants.springSmooth, value: snoozedCount)
            
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
    
    // MARK: - All Clear (Whale Catch!)
    
    private var allClearView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            // Whale icon — big celebration
            Image(systemName: "whale.fill")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(DesignTokens.accentComplete)
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text(String(localized: "All clear!"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(String(localized: "You've caught a rare whale"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.goldCurrency)
                
                // Phase 7: Category recap chips
                if !categoryRecap.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(categoryRecap.prefix(5), id: \.label) { cat in
                            HStack(spacing: 2) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                Text("×\(cat.count)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(cat.color.opacity(0.85))
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            // Hint to use the capture bar at the bottom
            Text(String(localized: "Type below to add more"))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.top, DesignTokens.spacingXS)
        }
    }
    
    // MARK: - All Snoozed
    
    private var allSnoozedView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            PenguinSceneView(
                size: .medium,
                expressionOverride: .sleeping,
                accentColorOverride: DesignTokens.textTertiary
            )
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text(String(localized: "Everything's sleeping"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(snoozedCount == 1
                     ? String(localized: "1 task snoozed. Want to wake it up?")
                     : String(localized: "\(snoozedCount) tasks snoozed. Want to wake one up?"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let onWake = onWakeSnooze {
                Button {
                    HapticService.shared.actionButtonTap()
                    onWake()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "alarm.fill")
                        Text(String(localized: "Wake One Up"))
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background {
                        Capsule().fill(DesignTokens.accentStale.opacity(0.25))
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "Wake One Up"),
                    hint: String(localized: "Bring back the oldest snoozed task"),
                    traits: .isButton
                )
            }
        }
    }
    
    // MARK: - No Tasks (Fresh Start)
    
    private var noTasksView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            PenguinSceneView(
                size: .large,
                expressionOverride: emptyViewExpression,
                accentColorOverride: DesignTokens.textTertiary
            )
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text(emptyViewTitle)
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(emptyViewSubtitle)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.spacingXL)
            }
            
            // Hint to use the capture bar at the bottom
            Text(String(localized: "Type below to add your first nudge"))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.top, DesignTokens.spacingXS)
        }
    }
    
    // MARK: - Time-Aware Helpers
    
    private enum DayPeriod {
        case morning, afternoon, evening, night
        
        static var current: DayPeriod {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<12:  return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            default:      return .night
            }
        }
    }
    
    private var emptyViewExpression: PenguinExpression {
        switch DayPeriod.current {
        case .morning:   return .idle
        case .afternoon: return .thinking
        case .evening:   return .idle
        case .night:     return .sleeping
        }
    }
    
    private var emptyViewTitle: String {
        switch DayPeriod.current {
        case .morning:   return String(localized: "Good morning!")
        case .afternoon: return String(localized: "Quiet afternoon")
        case .evening:   return String(localized: "Winding down")
        case .night:     return String(localized: "Nothing on your plate")
        }
    }
    
    private var emptyViewSubtitle: String {
        switch DayPeriod.current {
        case .morning:
            return String(localized: "No nudges yet — tell Nudgy what's on your mind, or add one yourself")
        case .afternoon:
            return String(localized: "Your list is clear. Unload something, or enjoy the quiet")
        case .evening:
            return String(localized: "Nothing pending. Prep tomorrow, or just relax — you've earned it")
        case .night:
            return String(localized: "Nothing pending. Nudgy's here if you remember something")
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        NudgesEmptyState(
            variant: .allClear,
            snoozedCount: 0,
            lastFishEarned: 15
        )
    }
    .preferredColorScheme(.dark)
}
