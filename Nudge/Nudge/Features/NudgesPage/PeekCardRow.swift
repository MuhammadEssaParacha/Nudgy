//
//  PeekCardRow.swift
//  Nudge
//
//  A compact "up next" row showing one upcoming task with its fish bounty.
//  These sit below the hero card as a preview of what's coming.
//  Tappable to promote to hero card.
//

import SwiftUI

struct PeekCardRow: View {
    
    let item: NudgeItem
    let streak: Int
    var onTap: () -> Void = {}
    var onDetail: (() -> Void)?
    var onDone: (() -> Void)?
    var onSnooze: (() -> Void)?
    
    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }
    
    var body: some View {
        SwipeableRow(
            content: {
                cardContent
            },
            onSwipeLeading: { onDone?() },
            leadingLabel: String(localized: "Done"),
            leadingIcon: "checkmark",
            leadingColor: DesignTokens.accentComplete,
            categoryColor: item.resolvedCategory != .general ? item.resolvedCategory.primaryColor : nil,
            onSwipeTrailing: { onSnooze?() },
            trailingLabel: String(localized: "Snooze"),
            trailingIcon: "moon.zzz.fill",
            trailingColor: DesignTokens.accentStale
        )
        .contextMenu {
            Button {
                onDetail?()
            } label: {
                Label(String(localized: "Open Detail"), systemImage: "arrow.up.left.and.arrow.down.right")
            }
            
            Button {
                onTap()
            } label: {
                Label(String(localized: "Make Current"), systemImage: "arrow.up.to.line")
            }
            
            if let onDone {
                Button {
                    onDone()
                } label: {
                    Label(String(localized: "Mark Done"), systemImage: "checkmark.circle.fill")
                }
            }
            
            if let onSnooze {
                Button {
                    onSnooze()
                } label: {
                    Label(String(localized: "Snooze 2h"), systemImage: "moon.zzz.fill")
                }
            }
        }
        .nudgeAccessibility(
            label: item.content,
            hint: String(localized: "Tap to make current. Swipe right for done, left for snooze."),
            traits: .isButton
        )
        .nudgeAccessibilityAction(name: String(localized: "Mark Done")) { onDone?() }
        .nudgeAccessibilityAction(name: String(localized: "Snooze")) { onSnooze?() }
    }
    
    private var cardContent: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.spacingMD) {
                // Task icon
                TaskIconView(
                    emoji: item.emoji,
                    actionType: item.actionType,
                    size: .small,
                    accentColor: accentColor
                )
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.content)
                        .font(AppTheme.footnote.weight(.medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(2)
                    
                    // Subtitle: contact or duration or stale
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(AppTheme.caption)
                            .foregroundStyle(subtitleColor)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Fish bounty (compact)
                FishBountyLabel(item: item, streak: streak, compact: true)
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM + 2)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                    .fill(accentColor.opacity(0.03))
            }
            .overlay(alignment: .leading) {
                // Left-edge accent bar for urgency
                if let edgeColor = leftEdgeColor {
                    UnevenRoundedRectangle(
                        topLeadingRadius: DesignTokens.cornerRadiusChip,
                        bottomLeadingRadius: DesignTokens.cornerRadiusChip,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                    .fill(edgeColor)
                    .frame(width: 3)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Subtitle Logic
    
    /// Left edge accent color for visual urgency: red (overdue) > blue (scheduled now) > amber (stale) > category > nil.
    private var leftEdgeColor: Color? {
        if let dueDate = item.dueDate, dueDate < Date() {
            return DesignTokens.accentOverdue
        }
        // Scheduled within 30 min → blue pulse
        if let scheduled = item.scheduledTime {
            let delta = scheduled.timeIntervalSince(Date())
            if delta >= -1800 && delta <= 1800 {
                return DesignTokens.accentActive
            }
        }
        if item.ageInDays >= 7 {
            return DesignTokens.accentOverdue.opacity(0.8)
        }
        if item.isStale {
            return DesignTokens.accentStale
        }
        if item.actionType != nil {
            return DesignTokens.accentActive
        }
        let cat = item.resolvedCategory
        if cat != .general {
            return cat.primaryColor
        }
        return nil
    }
    
    private var subtitleText: String? {
        // Urgency warnings first — more actionable than contact names
        if let dueDate = item.dueDate, dueDate < Date() {
            return String(localized: "Overdue")
        }
        // Scheduled time (e.g. "at 2:30 PM") — time-sensitive nudges
        if let scheduled = item.scheduledTime {
            let delta = scheduled.timeIntervalSince(Date())
            if delta >= -1800 && delta <= 28800 { // -30min to +8h
                let isNow = abs(delta) < 1800
                let timeStr = scheduled.formatted(.dateTime.hour().minute())
                return isNow ? String(localized: "Now · \(timeStr)") : timeStr
            }
        }
        // Due today label
        if let dueDate = item.dueDate, Calendar.current.isDateInToday(dueDate) {
            // Show countdown if within a few hours
            let hoursLeft = Int(dueDate.timeIntervalSince(Date()) / 3600)
            if hoursLeft > 0 && hoursLeft <= 3 {
                return String(localized: "Due in \(hoursLeft)h")
            }
            return String(localized: "Due today")
        }
        // Due tomorrow
        if let dueDate = item.dueDate, Calendar.current.isDateInTomorrow(dueDate) {
            return String(localized: "Due tomorrow")
        }
        // Due this week (show weekday name)
        if let dueDate = item.dueDate, dueDate > Date() {
            let daysUntil = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
            if daysUntil >= 2 && daysUntil <= 7 {
                return String(localized: "Due \(dueDate.formatted(.dateTime.weekday(.wide)))")
            }
        }
        if item.isStale {
            return String(localized: "\(item.ageInDays) days old")
        }
        if let contact = item.contactName, !contact.isEmpty {
            return contact
        }
        if let label = item.durationLabel {
            return label
        }
        if let actionType = item.actionType {
            return actionType.label
        }
        // Category label for non-action tasks
        if item.actionType == nil {
            let cat = item.resolvedCategory
            if cat != .general {
                return cat.label
            }
        }
        return nil
    }
    
    private var subtitleColor: Color {
        if let dueDate = item.dueDate, dueDate < Date() { return DesignTokens.accentOverdue }
        // Scheduled time approaching → blue accent
        if let scheduled = item.scheduledTime {
            let delta = scheduled.timeIntervalSince(Date())
            if delta >= -1800 && delta <= 3600 { return DesignTokens.accentActive }
        }
        if let dueDate = item.dueDate, Calendar.current.isDateInToday(dueDate) { return DesignTokens.accentStale }
        if item.isStale { return DesignTokens.accentStale }
        return DesignTokens.textTertiary
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 8) {
            PeekCardRow(
                item: NudgeItem(content: "Text Sarah about Saturday plans", emoji: "💬", actionType: .text, contactName: "Sarah", sortOrder: 1),
                streak: 3
            )
            PeekCardRow(
                item: NudgeItem(content: "Buy groceries for the week", emoji: "🛒", sortOrder: 2),
                streak: 0
            )
            PeekCardRow(
                item: {
                    let item = NudgeItem(content: "File expense report from last month", emoji: "📊", sortOrder: 3)
                    // Simulate stale
                    return item
                }(),
                streak: 5
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
