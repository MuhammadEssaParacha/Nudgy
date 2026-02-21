//
//  UpNextSection.swift
//  Nudge
//
//  Shows 2 "up next" peek cards below the hero card.
//  These preview upcoming tasks with their fish bounties,
//  creating a "what's next" pull that motivates completing the current card.
//
//  Tap any card to promote it to hero position.
//

import SwiftUI

struct UpNextSection: View {
    
    let items: [NudgeItem]
    let streak: Int
    let onPromote: (NudgeItem) -> Void
    var onDetail: ((NudgeItem) -> Void)?
    var onDone: ((NudgeItem) -> Void)?
    var onSnooze: ((NudgeItem) -> Void)?
    
    /// Show at most 2 peek cards to reduce choice paralysis
    private var visibleItems: [NudgeItem] {
        Array(items.prefix(2))
    }
    
    var body: some View {
        if !visibleItems.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // Section header
                HStack(spacing: DesignTokens.spacingSM) {
                    Text(String(localized: "Up next"))
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    if items.count > 2 {
                        Text(String(localized: "+\(items.count - 2) more"))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingXS)
                
                // Peek cards (swipeable)
                ForEach(visibleItems, id: \.id) { item in
                    PeekCardRow(
                        item: item,
                        streak: streak,
                        onTap: { onPromote(item) },
                        onDetail: { onDetail?(item) },
                        onDone: { onDone?(item) },
                        onSnooze: { onSnooze?(item) }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            .transition(.opacity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "Up next: \(visibleItems.count) tasks"))
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        UpNextSection(
            items: [
                NudgeItem(content: "Text Sarah about Saturday", emoji: "💬", actionType: .text, contactName: "Sarah", sortOrder: 1),
                NudgeItem(content: "Buy dog food", emoji: "🐶", sortOrder: 2),
                NudgeItem(content: "Email landlord about lease", emoji: "📧", actionType: .email, sortOrder: 3),
                NudgeItem(content: "Clean kitchen", emoji: "🧹", sortOrder: 4),
            ],
            streak: 3,
            onPromote: { _ in }
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
