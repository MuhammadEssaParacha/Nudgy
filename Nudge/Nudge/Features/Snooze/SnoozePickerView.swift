//
//  SnoozePickerView.swift
//  Nudge
//
//  Time picker overlay — quick presets + custom date/time.
//  Appears when swiping left on a card or from context menu.
//

import SwiftUI

struct SnoozePickerView: View {
    
    let item: NudgeItem
    var onSnooze: (Date) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var customDate = Date.tomorrowMorning
    @State private var showCustomPicker = false
    
    // MARK: - Category
    
    private var category: TaskCategory { item.resolvedCategory }
    
    // MARK: - Category-Smart Suggested Times
    
    /// Category-aware snooze suggestions — contextually relevant times for the task type.
    private var categorySuggestions: [(label: String, icon: String, date: Date)] {
        let cal = Calendar.current
        let now = Date()
        var results: [(label: String, icon: String, date: Date)] = []
        
        switch category {
        case .call, .text, .email:
            // Communication: quick follow-ups
            let in30 = now.addingTimeInterval(30 * 60)
            results.append((String(localized: "In 30 min"), "clock.badge", in30))
            let lunchTime = cal.date(bySettingHour: 12, minute: 30, second: 0, of: now) ?? now
            let afterLunch = lunchTime < now ? cal.date(byAdding: .day, value: 1, to: lunchTime)! : lunchTime
            results.append((String(localized: "After lunch"), "fork.knife", afterLunch))
            
        case .exercise, .health, .selfCare:
            // Wellness: morning slots
            let tomorrowAM = cal.date(bySettingHour: 7, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: now)!) ?? now
            results.append((String(localized: "Tomorrow 7 AM"), "sunrise.fill", tomorrowAM))
            // Weekend morning
            let weekendDate = Date.thisWeekend
            let satAM = cal.date(bySettingHour: 8, minute: 0, second: 0, of: weekendDate) ?? weekendDate
            results.append((String(localized: "Weekend morning"), "sun.max.fill", satAM))
            
        case .cooking:
            // Cooking: evening prep
            let evening5 = cal.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now
            let cookTime = evening5 < now ? cal.date(byAdding: .day, value: 1, to: evening5)! : evening5
            results.append((String(localized: "This evening 5 PM"), "flame.fill", cookTime))
            let weekendNoon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date.thisWeekend) ?? Date.thisWeekend
            results.append((String(localized: "Weekend noon"), "sun.max", weekendNoon))
            
        case .work, .homework, .finance:
            // Productivity: business hours
            let ninAM = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: now)!) ?? now
            results.append((String(localized: "Tomorrow 9 AM"), "briefcase.fill", ninAM))
            let afterWork = cal.date(bySettingHour: 17, minute: 30, second: 0, of: now) ?? now
            let awTime = afterWork < now ? cal.date(byAdding: .day, value: 1, to: afterWork)! : afterWork
            results.append((String(localized: "After work"), "door.left.hand.open", awTime))
            
        case .cleaning, .maintenance:
            // Chores: weekend slots
            let satMorning = cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date.thisWeekend) ?? Date.thisWeekend
            results.append((String(localized: "This weekend"), "house.fill", satMorning))
            let sundayAft = cal.date(byAdding: .day, value: 1, to: satMorning) ?? satMorning
            results.append((String(localized: "Sunday afternoon"), "sun.haze.fill", cal.date(bySettingHour: 14, minute: 0, second: 0, of: sundayAft) ?? sundayAft))
            
        case .shopping, .errand:
            // Errands: lunch or weekend
            let lunchRun = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
            let errandTime = lunchRun < now ? cal.date(byAdding: .day, value: 1, to: lunchRun)! : lunchRun
            results.append((String(localized: "Lunch break"), "bag.fill", errandTime))
            results.append((String(localized: "This weekend"), "cart.fill", Date.thisWeekend))
            
        case .social:
            // Social: evening / weekend
            let evening7 = cal.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
            let socialTime = evening7 < now ? cal.date(byAdding: .day, value: 1, to: evening7)! : evening7
            results.append((String(localized: "This evening"), "person.2.fill", socialTime))
            results.append((String(localized: "This weekend"), "party.popper.fill", Date.thisWeekend))
            
        case .creative:
            // Creative: evening wind-down or weekend
            let evening8 = cal.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
            let creativeTime = evening8 < now ? cal.date(byAdding: .day, value: 1, to: evening8)! : evening8
            results.append((String(localized: "Tonight 8 PM"), "paintbrush.fill", creativeTime))
            results.append((String(localized: "Weekend afternoon"), "sun.max.fill",
                            cal.date(bySettingHour: 14, minute: 0, second: 0, of: Date.thisWeekend) ?? Date.thisWeekend))
            
        case .appointment, .alarm, .link, .general:
            // Generic categories: no special suggestions
            break
        }
        
        // Filter out times in quiet hours
        return results.filter { !settings.isDateInQuietHours($0.date) }
    }
    
    // MARK: - Snooze Options
    
    /// Computed presets that respect quiet hours.
    /// If "Later today" would land during quiet hours, it's replaced with "After quiet hours."
    private var presets: [(label: String, icon: String, date: Date)] {
        var results: [(label: String, icon: String, date: Date)] = []
        
        let laterToday = Date.laterToday
        if settings.isDateInQuietHours(laterToday) {
            // Push to when quiet hours end instead
            let afterQuiet = settings.nextQuietHoursEnd()
            results.append((String(localized: "After quiet hours"), "moon.zzz", afterQuiet))
        } else {
            results.append((String(localized: "Later today"), "clock", laterToday))
        }
        
        results.append((String(localized: "Tomorrow morning"), "sunrise", Date.tomorrowMorning))
        results.append((String(localized: "This weekend"), "sun.max", Date.thisWeekend))
        results.append((String(localized: "Next week"), "calendar", Date.nextWeek))
        
        return results
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.cardSurface.ignoresSafeArea()
                
                VStack(spacing: DesignTokens.spacingLG) {
                    // Task preview
                    HStack(spacing: DesignTokens.spacingSM) {
                        TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .small)
                        Text(item.content)
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(DesignTokens.spacingMD)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .fill(Color.white.opacity(0.03))
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
                    
                    // Category-smart suggestions
                    if !categorySuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                            HStack(spacing: DesignTokens.spacingXS) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(category.primaryColor)
                                Text(String(localized: "Suggested for \(category.label)"))
                                    .font(AppTheme.caption.weight(.semibold))
                                    .foregroundStyle(category.primaryColor)
                            }
                            .padding(.leading, DesignTokens.spacingXS)
                            
                            ForEach(categorySuggestions, id: \.label) { preset in
                                categorySuggestionButton(preset)
                            }
                        }
                        
                        Divider()
                            .background(DesignTokens.cardBorder)
                    }
                    
                    // Quick presets
                    VStack(spacing: DesignTokens.spacingSM) {
                        ForEach(presets, id: \.label) { preset in
                            presetButton(preset)
                        }
                    }
                    
                    // Custom time
                    Divider()
                        .background(DesignTokens.cardBorder)
                    
                    if showCustomPicker {
                        DatePicker(
                            String(localized: "Pick a time"),
                            selection: $customDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .tint(DesignTokens.accentActive)
                        .colorScheme(.dark)
                        
                        Button {
                            HapticService.shared.snoozeTimeSelected()
                            SoundService.shared.playSnooze()
                            onSnooze(customDate)
                        } label: {
                            HStack {
                                Image(systemName: "clock.badge.checkmark")
                                Text(String(localized: "Snooze until \(customDate.friendlySnoozeDescription)"))
                            }
                            .font(AppTheme.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.spacingMD)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                                    .fill(DesignTokens.accentActive)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            withAnimation(AnimationConstants.sheetPresent) {
                                showCustomPicker = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(DesignTokens.accentActive)
                                Text(String(localized: "Custom time..."))
                                    .foregroundStyle(DesignTokens.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(DesignTokens.textTertiary)
                            }
                            .font(AppTheme.body)
                            .padding(DesignTokens.spacingMD)
                            .background {
                                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                    .fill(Color.white.opacity(0.03))
                            }
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }
                .padding(DesignTokens.spacingXL)
            }
            .navigationTitle(String(localized: "Snooze"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Category Suggestion Button
    
    private func categorySuggestionButton(_ preset: (label: String, icon: String, date: Date)) -> some View {
        Button {
            HapticService.shared.snoozeTimeSelected()
            SoundService.shared.playSnooze()
            onSnooze(preset.date)
        } label: {
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: preset.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(category.primaryColor)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.label)
                        .font(AppTheme.body.weight(.medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    Text(preset.date.friendlySnoozeDescription)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(category.primaryColor.opacity(0.6))
            }
            .padding(DesignTokens.spacingMD)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(category.primaryColor.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .strokeBorder(category.primaryColor.opacity(0.15), lineWidth: 0.5)
                    )
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: "\(preset.label), \(preset.date.friendlySnoozeDescription)",
            hint: String(localized: "Suggested based on \(category.label) task type"),
            traits: .isButton
        )
    }
    
    // MARK: - Preset Button
    
    private func presetButton(_ preset: (label: String, icon: String, date: Date)) -> some View {
        Button {
            HapticService.shared.snoozeTimeSelected()
            SoundService.shared.playSnooze()
            onSnooze(preset.date)
        } label: {
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: preset.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(DesignTokens.accentActive)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.label)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    Text(preset.date.friendlySnoozeDescription)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                
                Spacer()
            }
            .padding(DesignTokens.spacingMD)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(Color.white.opacity(0.03))
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: "\(preset.label), \(preset.date.friendlySnoozeDescription)",
            traits: .isButton
        )
    }
}

// MARK: - Identifiable Conformance for sheet(item:)

// NudgeItem is already Identifiable via its id: UUID property from @Model

// MARK: - Preview

#Preview {
    SnoozePickerView(
        item: NudgeItem(content: "Call the dentist", emoji: "📞"),
        onSnooze: { date in print("Snoozed until \(date)") }
    )
    .environment(AppSettings())
}
