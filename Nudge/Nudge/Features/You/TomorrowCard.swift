//
//  TomorrowCard.swift
//  Nudge
//
//  The morning artifact of the Plan Tomorrow ritual.
//  Shows when: planDate was yesterday AND it's before 2pm today.
//
//  Design intent:
//  - Full-width DarkCard — highest visual weight on the You page
//  - Accent color driven by the user's chosen energy mode
//  - ONE intention, prominently typeset — no competing info
//  - Carry-forward count shown as a supporting chip, not a list
//  - Tapping navigates to that task (deep link via ActionService)
//  - Fades gracefully after 2pm — no guilt, no reminder nag
//

import SwiftUI

struct TomorrowCard: View {

    @State private var planStore = TomorrowPlanStore.shared

    /// Called when the user taps the intention to navigate to it
    var onTapIntention: (() -> Void)? = nil

    var body: some View {
        if planStore.isFreshForMorning && planStore.hasPlan {
            cardContent
                .transition(.opacity.combined(with: .offset(y: -8)))
        }
    }

    // MARK: - Card

    private var cardContent: some View {
        let energy = planStore.energyMode
        let accent = energy.accentColor

        return DarkCard(accentColor: accent) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {

                // Header row
                HStack(spacing: DesignTokens.spacingMD) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: energy.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(localized: "Today's intention"))
                            .font(AppTheme.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.textTertiary)
                            .textCase(.uppercase)
                        Text(energy.label)
                            .font(AppTheme.hudFont)
                            .foregroundStyle(accent)
                    }

                    Spacer()

                    // Carry-forward chip
                    if !planStore.carryForwardIDs.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 10, weight: .semibold))
                            Text(String(localized: "+\(planStore.carryForwardIDs.count) tasks"))
                                .font(AppTheme.hudFont)
                        }
                        .foregroundStyle(DesignTokens.textSecondary)
                        .padding(.horizontal, DesignTokens.spacingSM)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.07))
                        )
                    }
                }

                // The intention — the most important text on this card
                Button {
                    HapticService.shared.actionButtonTap()
                    onTapIntention?()
                } label: {
                    HStack(alignment: .top, spacing: DesignTokens.spacingMD) {
                        Text(planStore.intentionText)
                            .font(AppTheme.title3)
                            .foregroundStyle(DesignTokens.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(accent.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)

                // Subtle hairline divider
                Rectangle()
                    .fill(accent.opacity(0.12))
                    .frame(height: 0.5)

                // Morning greeting anchored to time
                Text(morningLabel)
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .nudgeAccessibility(
            label: String(localized: "Today's intention: \(planStore.intentionText). Energy mode: \(planStore.energyMode.label)."),
            hint: String(localized: "Tap to go to this task"),
            traits: .isButton
        )
    }

    // MARK: - Time-aware label

    private var morningLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<9:
            return String(localized: "You planned this last night. You've got it.")
        case 9..<12:
            return String(localized: "Morning. This is your one thing today.")
        default:
            return String(localized: "Still time. Start here.")
        }
    }
}

// MARK: - Preview

#Preview("Fresh morning card") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            TomorrowCard()
                .padding()
        }
    }
    .preferredColorScheme(.dark)
}
