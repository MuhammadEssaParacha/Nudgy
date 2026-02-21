//
//  DoneTodayStrip.swift
//  Nudge
//
//  A "trophy case" showing tasks completed today as tappable cards.
//  Tap any card to open the full swipeable detail popup.
//  No-shame design: only renders when items exist. No empty shaming.
//

import SwiftUI

struct DoneTodayStrip: View {
    
    let items: [NudgeItem]
    var onTapItem: ((NudgeItem) -> Void)?
    
    /// Phase 14: Category summary — grouped counts with colored orbs.
    private var categorySummary: [(category: TaskCategory, count: Int)] {
        var counts: [TaskCategory: Int] = [:]
        for item in items {
            counts[item.resolvedCategory, default: 0] += 1
        }
        return counts
            .map { (category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // Section header
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "trophy.fill")
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.accentComplete)
                    
                    Text(String(localized: "Done today"))
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Text("\(items.count)")
                        .font(AppTheme.rounded(.caption, weight: .bold))
                        .foregroundStyle(DesignTokens.accentComplete)
                }
                .padding(.horizontal, DesignTokens.spacingSM)
                
                // Phase 14: Category summary orbs row
                if categorySummary.count > 1 || (categorySummary.first?.category != .general) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.spacingSM) {
                            ForEach(categorySummary, id: \.category) { stat in
                                categorySummaryOrb(stat.category, count: stat.count)
                            }
                        }
                        .padding(.horizontal, DesignTokens.spacingSM)
                    }
                }
                
                // Tappable completed task cards
                ForEach(items, id: \.id) { item in
                    doneCard(item)
                }
            }
            .padding(.vertical, DesignTokens.spacingMD)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
            .transition(.opacity)
        }
    }
    
    // MARK: - Category Summary Orb (Phase 14)
    
    private func categorySummaryOrb(_ category: TaskCategory, count: Int) -> some View {
        let color = category.primaryColor
        let isHot = count >= 3
        
        return HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(isHot ? 0.25 : 0.12))
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(isHot ? 0.5 : 0.2), lineWidth: 0.5)
                )
        )
        .scaleEffect(isHot ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: count)
        .nudgeAccessibility(
            label: String(localized: "\(category.label): \(count) done"),
            traits: .isStaticText
        )
    }
    
    // MARK: - Done Card (tappable, opens detail popup)
    
    private func doneCard(_ item: NudgeItem) -> some View {
        let cat = item.resolvedCategory
        let cardColor = (cat != .general) ? cat.primaryColor : DesignTokens.accentComplete
        
        return Button {
            HapticService.shared.actionButtonTap()
            onTapItem?(item)
        } label: {
            HStack(spacing: DesignTokens.spacingMD) {
                // Icon
                ZStack {
                    Circle()
                        .fill(cardColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    if cat != .general {
                        Image(systemName: cat.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(cardColor)
                    } else if let emoji = item.emoji, !emoji.isEmpty {
                        Image(systemName: TaskIconResolver.resolveSymbol(for: emoji))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(cardColor)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(cardColor)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.content)
                        .font(AppTheme.footnote.weight(.medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(1)
                        .strikethrough(true, color: DesignTokens.textTertiary)
                    
                    if let completedAt = item.completedAt {
                        Text("\(completedAt, style: .relative) ago")
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Chevron hint
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM + 2)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                    .fill(cardColor.opacity(0.04))
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                    .strokeBorder(cardColor.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignTokens.spacingSM)
        .nudgeAccessibility(
            label: String(localized: "Completed: \(item.content)"),
            hint: String(localized: "Tap to view details"),
            traits: .isButton
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        DoneTodayStrip(items: [
            { let i = NudgeItem(content: "Buy groceries", emoji: "🛒", sortOrder: 1); i.markDone(); return i }(),
            { let i = NudgeItem(content: "Call doctor", emoji: "📞", sortOrder: 2); i.markDone(); return i }(),
            { let i = NudgeItem(content: "File taxes", emoji: "📊", sortOrder: 3); i.markDone(); return i }(),
        ])
        .padding()
    }
    .preferredColorScheme(.dark)
}
