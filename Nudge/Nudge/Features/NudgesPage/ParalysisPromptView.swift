//
//  ParalysisPromptView.swift
//  Nudge
//
//  Shown after 3+ skips — detects decision paralysis.
//  Offers "Quick Catch 🐟" (lowest-effort task) or "Brain Dump 🧠".
//
//  ADHD insight: Breaking paralysis by lowering the bar.
//  Reddit: "rolling dice for to-do list" (255 upvotes)
//

import SwiftUI

struct ParalysisPromptView: View {
    
    let skipCount: Int
    let onQuickCatch: () -> Void
    let onBrainDump: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // Nudgy message
            HStack(spacing: DesignTokens.spacingSM) {
                Image("NudgyMascot")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "You've been browsing the ocean"))
                        .font(AppTheme.footnote.weight(.semibold))
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    Text(String(localized: "but not catching anything. Want me to pick the easiest catch?"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(AppTheme.captionBold)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(label: String(localized: "Dismiss"), hint: nil, traits: .isButton)
            }
            
            // Action buttons
            HStack(spacing: DesignTokens.spacingSM) {
                // Quick catch — easiest task
                Button {
                    HapticService.shared.actionButtonTap()
                    onQuickCatch()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        MiniFishIcon(size: 14)
                        Text(String(localized: "Quick Catch"))
                            .font(AppTheme.footnote.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingSM + 2)
                    .background(
                        Capsule().fill(DesignTokens.accentActive)
                    )
                }
                .buttonStyle(.plain)
                
                // Brain dump — unload your mind
                Button {
                    HapticService.shared.actionButtonTap()
                    onBrainDump()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignTokens.textPrimary)
                        Text(String(localized: "Unload"))
                            .font(AppTheme.footnote.weight(.semibold))
                    }
                    .foregroundStyle(DesignTokens.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingSM + 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(DesignTokens.accentActive.opacity(0.04))
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .nudgeAccessibility(
            label: String(localized: "You've skipped \(skipCount) tasks. Would you like the easiest catch or an unload?"),
            hint: nil,
            traits: .isStaticText
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ParalysisPromptView(
            skipCount: 3,
            onQuickCatch: {},
            onBrainDump: {},
            onDismiss: {}
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
