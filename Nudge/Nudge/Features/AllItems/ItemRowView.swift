//
//  ItemRowView.swift
//  Nudge
//
//  Row component for the All Items list. Dark translucent card with accent dot.
//

import SwiftUI

struct ItemRowView: View {
    
    let item: NudgeItem
    var onTap: () -> Void = {}
    
    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.spacingMD) {
                // Accent dot
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                
                // Icon
                TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .small)
                
                // Content
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(item.content)
                        .font(AppTheme.body)
                        .foregroundStyle(
                            item.status == .done
                                ? DesignTokens.textTertiary
                                : DesignTokens.textPrimary
                        )
                        .strikethrough(item.status == .done)
                        .lineLimit(2)
                    
                    HStack(spacing: DesignTokens.spacingSM) {
                        // Source icon
                        Image(systemName: item.sourceType.icon)
                            .font(.system(size: 10))
                        
                        // Timestamp
                        if item.status == .snoozed, let until = item.snoozedUntil {
                            Text(until.friendlySnoozeDescription)
                        } else if item.status == .done, let completedAt = item.completedAt {
                            Text(completedAt.relativeDescription)
                        } else {
                            Text(item.createdAt.relativeDescription)
                        }
                        
                        // Action indicator
                        if let actionType = item.actionType {
                            Image(systemName: actionType.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                        
                        // Scheduled time
                        if item.status == .active, let scheduled = item.scheduledTime {
                            let delta = scheduled.timeIntervalSince(Date())
                            if delta >= -1800 && delta <= 28800 {
                                HStack(spacing: 2) {
                                    Image(systemName: abs(delta) < 1800 ? "bell.fill" : "clock.fill")
                                        .font(.system(size: 9))
                                    Text(scheduled.formatted(.dateTime.hour().minute()))
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(abs(delta) < 1800 ? DesignTokens.accentActive : DesignTokens.textSecondary)
                            }
                        }
                        
                        // Due date (compact)
                        if item.status == .active, let dueDate = item.dueDate {
                            if dueDate < Date() {
                                Text(String(localized: "Overdue"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(DesignTokens.accentOverdue)
                            } else if Calendar.current.isDateInToday(dueDate) {
                                Text(String(localized: "Today"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(DesignTokens.accentStale)
                            } else if Calendar.current.isDateInTomorrow(dueDate) {
                                Text(String(localized: "Tomorrow"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                        }
                        
                        // Stale badge
                        if item.isStale {
                            Text(String(localized: "\(item.ageInDays)d"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(DesignTokens.accentStale)
                        }
                        
                        // Category label
                        if item.actionType == nil {
                            let cat = item.resolvedCategory
                            if cat != .general {
                                HStack(spacing: 3) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 9, weight: .semibold))
                                    Text(cat.label)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(cat.primaryColor)
                            }
                        }
                    }
                    .font(AppTheme.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(DesignTokens.spacingMD)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: itemAccessibilityLabel,
            hint: String(localized: "Double tap to edit"),
            traits: .isButton
        )
    }
    
    private var itemAccessibilityLabel: String {
        var parts = [item.content]
        if item.isStale { parts.append(String(localized: "stale")) }
        if item.status == .snoozed, let until = item.snoozedUntil {
            parts.append(String(localized: "snoozed until \(until.friendlySnoozeDescription)"))
        }
        if item.status == .done { parts.append(String(localized: "completed")) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 8) {
            ItemRowView(item: NudgeItem(content: "Call the dentist", emoji: "📞", actionType: .call, contactName: "Dr. Chen"))
            ItemRowView(item: {
                let item = NudgeItem(content: "Buy dog food", emoji: "🐶")
                return item
            }())
            ItemRowView(item: {
                let item = NudgeItem(content: "Reply to Sarah", emoji: "💬", actionType: .text)
                item.markDone()
                return item
            }())
        }
        .padding()
    }
}
