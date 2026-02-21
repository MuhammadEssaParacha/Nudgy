//
//  PileCountRow.swift
//  Nudge
//
//  Shows the count of remaining tasks beyond what's visible (hero + up next).
//  Tappable to expand an inline list of all remaining items.
//
//  "12 more in your pile" → tap → inline expansion of compact rows
//  At no point does the user leave the page.
//

import SwiftUI

struct PileCountRow: View {
    
    let items: [NudgeItem]
    let streak: Int
    let onDone: (NudgeItem) -> Void
    let onSnooze: (NudgeItem) -> Void
    var onDetail: ((NudgeItem) -> Void)?
    
    @State private var isExpanded = false
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Tap target — pile count
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                    HapticService.shared.prepare()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: isExpanded ? "tray.full.fill" : "tray.fill")
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textTertiary)
                        
                        Text(pileLabel)
                            .font(AppTheme.footnote.weight(.medium))
                            .foregroundStyle(DesignTokens.textSecondary)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(AppTheme.captionBold)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM + 2)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .fill(Color.white.opacity(0.03))
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: pileLabel,
                    hint: String(localized: "Tap to see all remaining tasks"),
                    traits: .isButton
                )
                
                // Expanded inline list
                if isExpanded {
                    VStack(spacing: DesignTokens.spacingXS) {
                        ForEach(sortedPileItems, id: \.id) { item in
                            pileItemRow(item)
                        }
                    }
                    .padding(.top, DesignTokens.spacingSM)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
        }
    }
    
    // MARK: - Pile Label
    
    private var pileLabel: String {
        let overdueCount = items.filter { item in
            guard let due = item.dueDate else { return false }
            return due < Date()
        }.count
        
        let base: String
        if items.count == 1 {
            base = String(localized: "1 more in your pile")
        } else {
            base = String(localized: "\(items.count) more in your pile")
        }
        
        if overdueCount > 0 {
            return base + String(localized: " · \(overdueCount) overdue")
        }
        return base
    }
    
    /// Items sorted by urgency: overdue → stale → due soon → rest.
    private var sortedPileItems: [NudgeItem] {
        items.sorted { a, b in
            pileUrgency(a) > pileUrgency(b)
        }
    }
    
    private func pileUrgency(_ item: NudgeItem) -> Int {
        var score = 0
        if let due = item.dueDate, due < Date() { score += 100 }
        if item.isStale { score += 50 }
        if let due = item.dueDate, Calendar.current.isDateInToday(due) { score += 30 }
        if item.scheduledTime != nil { score += 20 }
        return score
    }
    
    // MARK: - Pile Item Row
    
    private func pileItemRow(_ item: NudgeItem) -> some View {
        let accentColor = AccentColorSystem.shared.color(for: item.accentStatus)
        
        return SwipeableRow(
            content: {
                HStack(spacing: DesignTokens.spacingSM) {
                    TaskIconView(
                        emoji: item.emoji,
                        actionType: item.actionType,
                        size: .small,
                        accentColor: accentColor
                    )
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.content)
                            .font(AppTheme.footnote.weight(.medium))
                            .foregroundStyle(DesignTokens.textPrimary)
                            .lineLimit(1)
                        
                        if item.actionType == nil {
                            let cat = item.resolvedCategory
                            if cat != .general {
                                HStack(spacing: 3) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 9, weight: .semibold))
                                    Text(cat.label)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(DesignTokens.textTertiary)
                            }
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Compact bounty
                    FishBountyLabel(item: item, streak: streak, compact: true)
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .background {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                        .fill(Color.white.opacity(0.02))
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
                .contextMenu {
                    Button {
                        onDetail?(item)
                    } label: {
                        Label(String(localized: "Open Detail"), systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    
                    Button {
                        onDone(item)
                    } label: {
                        Label(String(localized: "Mark Done"), systemImage: "checkmark.circle.fill")
                    }
                    
                    Button {
                        onSnooze(item)
                    } label: {
                        Label(String(localized: "Snooze"), systemImage: "moon.zzz.fill")
                    }
                }
            },
            onSwipeLeading: { onDone(item) },
            leadingLabel: String(localized: "Done"),
            leadingIcon: "checkmark",
            leadingColor: DesignTokens.accentComplete,
            categoryColor: item.resolvedCategory != .general ? item.resolvedCategory.primaryColor : nil,
            onSwipeTrailing: { onSnooze(item) },
            trailingLabel: String(localized: "Snooze"),
            trailingIcon: "moon.zzz.fill",
            trailingColor: DesignTokens.accentStale
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PileCountRow(
            items: [
                NudgeItem(content: "Clean the bathroom", emoji: "🧹", sortOrder: 5),
                NudgeItem(content: "Schedule dentist appointment", emoji: "🦷", sortOrder: 6),
                NudgeItem(content: "Research vacation spots", emoji: "✈️", sortOrder: 7),
                NudgeItem(content: "Return library books", emoji: "📚", sortOrder: 8),
            ],
            streak: 3,
            onDone: { _ in },
            onSnooze: { _ in }
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
