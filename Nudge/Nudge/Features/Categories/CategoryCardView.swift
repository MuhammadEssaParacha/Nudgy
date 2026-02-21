//
//  CategoryCardView.swift
//  Nudge
//
//  Category-specific expanded card content — the heart of the 20-category system.
//  Renders timer presets, quick action buttons, and Nudgy whisper banks per category.
//
//  Used in both NudgeExpandedCard (inline) and NudgeDetailPopup (full-screen).
//  Falls through to existing action cards for CALL/TEXT/EMAIL/LINK.
//

import SwiftUI

// MARK: - Category Card View

/// Renders category-specific tools and quick presets for a NudgeItem.
/// Designed to be embedded inside NudgeExpandedCard's `primaryActionArea`.
struct CategoryCardView: View {
    
    let item: NudgeItem
    let category: TaskCategory
    var onFocus: (() -> Void)?
    var onAction: (() -> Void)?
    var onTimerStart: ((Int) -> Void)?   // Start a timer with N minutes
    var onOpenMaps: (() -> Void)?
    var onAddCalendar: (() -> Void)?
    
    @State private var selectedTimer: TimerPreset?
    @State private var showAllTimers = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var template: CategoryTemplate {
        CategoryTemplateRegistry.template(for: category)
    }
    
    private var tint: Color {
        category.primaryColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            
            // ─── Category header with icon + gradient ───
            categoryHeader
            
            // ─── Quick preset buttons (category-specific actions) ───
            if !template.quickPresets.isEmpty {
                quickPresetsRow
            }
            
            // ─── Timer presets (for timer-capable categories) ───
            if let timers = template.timerPresets, !timers.isEmpty {
                timerGrid(timers)
            }
            
            // ─── Checklist sections (for shopping, cleaning, etc.) ───
            if let sections = template.checklistSections, !sections.isEmpty {
                checklistHint(sections)
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(cardBackground)
    }
    
    // MARK: - Category Header
    
    private var categoryHeader: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Icon bubble with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: category.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(category.label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignTokens.textPrimary)
                
                if let dur = category.defaultDuration {
                    Text(String(localized: "~\(dur) min"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            
            Spacer()
            
            // Category icon badge
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(category.primaryColor)
        }
    }
    
    // MARK: - Quick Presets
    
    private var quickPresetsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingXS) {
                ForEach(template.quickPresets) { preset in
                    quickPresetChip(preset)
                }
            }
        }
    }
    
    private func quickPresetChip(_ preset: QuickPreset) -> some View {
        Button {
            HapticService.shared.actionButtonTap()
            handlePresetAction(preset.action)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: preset.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(preset.label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
                    .overlay(
                        Capsule()
                            .strokeBorder(tint.opacity(0.20), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: preset.label,
            hint: "",
            traits: .isButton
        )
    }
    
    // MARK: - Timer Grid
    
    private func timerGrid(_ timers: [TimerPreset]) -> some View {
        let visible = showAllTimers ? timers : Array(timers.prefix(4))
        
        return VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            HStack {
                Label(String(localized: "Quick Timer"), systemImage: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                
                Spacer()
                
                if timers.count > 4 {
                    Button {
                        withAnimation(AnimationConstants.springSmooth) {
                            showAllTimers.toggle()
                        }
                    } label: {
                        Text(showAllTimers ? String(localized: "Less") : String(localized: "More"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: DesignTokens.spacingXS) {
                ForEach(visible) { timer in
                    timerButton(timer)
                }
            }
        }
    }
    
    private func timerButton(_ timer: TimerPreset) -> some View {
        let isSelected = selectedTimer?.id == timer.id
        let timerTint = Color(hex: timer.color)
        
        return Button {
            HapticService.shared.actionButtonTap()
            selectedTimer = timer
            onTimerStart?(timer.minutes)
            onFocus?()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: timer.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(timer.label)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : timerTint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? timerTint : timerTint.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(timerTint.opacity(isSelected ? 0 : 0.15), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: String(localized: "\(timer.label) timer"),
            hint: String(localized: "Starts a \(timer.minutes) minute timer"),
            traits: .isButton
        )
    }
    
    // MARK: - Checklist Hint
    
    private func checklistHint(_ sections: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            Label(String(localized: "Checklist Sections"), systemImage: "checklist")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.textSecondary)
            
            FlowLayout(spacing: 6) {
                ForEach(sections, id: \.self) { section in
                    Text(section)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(tint.opacity(0.08))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(tint.opacity(0.12), lineWidth: 0.5)
                                )
                        )
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(tint.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(tint.opacity(0.08), lineWidth: 0.5)
            )
    }
    
    private func handlePresetAction(_ action: QuickPresetAction) {
        switch action {
        case .startTimer(let minutes):
            onTimerStart?(minutes)
        case .addToCalendar:
            onAddCalendar?()
        case .openMaps:
            onOpenMaps?()
        case .startFocus(let focusMinutes, _):
            onTimerStart?(focusMinutes)
        case .setAlarm:
            onAction?()
        case .startBreathing:
            onFocus?()
        case .openURL:
            // Open a relevant URL based on task content
            let query = item.content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "https://www.google.com/search?q=\(query)") {
                UIApplication.shared.open(url)
            }
        case .dial:
            // Dial the contact if available
            if let contact = item.contactName,
               let phone = contact.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "tel://\(phone)") {
                UIApplication.shared.open(url)
            } else {
                onAction?()
            }
        case .compose:
            // Open Messages compose
            if let contact = item.contactName {
                NotificationCenter.default.post(
                    name: .nudgeComposeMessage,
                    object: nil,
                    userInfo: ["recipient": contact, "body": item.aiDraft ?? item.content]
                )
            } else {
                onAction?()
            }
        case .custom:
            onAction?()
        }
    }
}

// MARK: - Flow Layout

/// Simple horizontal flow layout for tags/chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for row in rows {
            height += row.height
        }
        height += CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        var index = 0
        for row in rows {
            var x = bounds.minX
            for _ in 0..<row.count {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += row.height + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [(count: Int, height: CGFloat)] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [(count: Int, height: CGFloat)] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        var currentCount = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && currentCount > 0 {
                rows.append((count: currentCount, height: currentHeight))
                currentWidth = 0
                currentHeight = 0
                currentCount = 0
            }
            currentWidth += size.width + spacing
            currentHeight = max(currentHeight, size.height)
            currentCount += 1
        }
        if currentCount > 0 {
            rows.append((count: currentCount, height: currentHeight))
        }
        return rows
    }
}
