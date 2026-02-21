//
//  MoodInsightsView.swift
//  Nudge
//
//  Weekly mood + productivity trends.
//  Shows a 7-day mood chart, average tasks completed per mood level,
//  and energy pattern insights.
//

import SwiftUI
import SwiftData

struct MoodInsightsView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoodEntry.loggedAt, order: .reverse) private var allEntries: [MoodEntry]
    
    @State private var selectedRange: InsightRange = .week
    
    private enum InsightRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case all = "All Time"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .all: return 9999
            }
        }
    }
    
    private var filteredEntries: [MoodEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date.distantPast
        return allEntries.filter { $0.loggedAt >= cutoff }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingXL) {
                // Range picker
                rangePicker
                
                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    // Mood chart
                    moodChart
                    
                    // Stats cards
                    statsGrid
                    
                    // Mood-productivity correlation
                    productivityCorrelation
                    
                    // Recent entries
                    recentEntries
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingSM)
            .padding(.bottom, 100)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(String(localized: "Mood Insights"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Range Picker
    
    private var rangePicker: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            ForEach(InsightRange.allCases, id: \.self) { range in
                Button {
                    selectedRange = range
                    HapticService.shared.actionButtonTap()
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            selectedRange == range ? .white : DesignTokens.textSecondary
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    selectedRange == range
                                        ? DesignTokens.accentActive
                                        : DesignTokens.cardSurface.opacity(0.4)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Mood Chart
    
    private var moodChart: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text(String(localized: "Mood Trend"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            // Simple bar chart
            HStack(alignment: .bottom, spacing: DesignTokens.spacingSM) {
                ForEach(lastDays, id: \.self) { date in
                    let entry = entryForDate(date)
                    VStack(spacing: 4) {
                        if let entry {
                            Image(systemName: entry.mood.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(entry.mood.color)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(entry.mood.color)
                                .frame(width: 28, height: CGFloat(entry.mood.rawValue) * 20)
                        } else {
                            Text("–")
                                .font(.system(size: 12))
                                .foregroundStyle(DesignTokens.textTertiary)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 28, height: 10)
                        }
                        
                        Text(dayLabel(date))
                            .font(.system(size: 10))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(DesignTokens.spacingMD)
            .frame(height: 160)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        let avgMood = filteredEntries.isEmpty ? 0.0 : Double(filteredEntries.map(\.mood.rawValue).reduce(0, +)) / Double(filteredEntries.count)
        let avgTasks = filteredEntries.isEmpty ? 0.0 : Double(filteredEntries.map(\.tasksCompletedThatDay).reduce(0, +)) / Double(filteredEntries.count)
        let checkIns = filteredEntries.count
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.spacingMD) {
            statCard(
                title: String(localized: "Avg Mood"),
                value: String(format: "%.1f", avgMood),
                icon: moodForValue(avgMood)?.emoji ?? "😐",
                color: moodForValue(avgMood)?.color ?? DesignTokens.textSecondary
            )
            
            statCard(
                title: String(localized: "Avg Tasks"),
                value: String(format: "%.0f", avgTasks),
                icon: "✅",
                color: DesignTokens.accentComplete
            )
            
            statCard(
                title: String(localized: "Check-ins"),
                value: "\(checkIns)",
                icon: "📊",
                color: DesignTokens.accentActive
            )
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Text(icon)
                .font(.system(size: 24))
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingMD)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
    }
    
    // MARK: - Productivity Correlation
    
    private var productivityCorrelation: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text(String(localized: "Mood × Productivity"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            ForEach(MoodLevel.allCases, id: \.self) { mood in
                let entries = filteredEntries.filter { $0.mood == mood }
                let avgTasks = entries.isEmpty ? 0.0 : Double(entries.map(\.tasksCompletedThatDay).reduce(0, +)) / Double(entries.count)
                let maxTasks = 10.0
                
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: mood.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(mood.color)
                        .frame(width: 28)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.04))
                                .frame(height: 20)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(mood.color.opacity(0.6))
                                .frame(
                                    width: max(geo.size.width * (avgTasks / maxTasks), 4),
                                    height: 20
                                )
                        }
                    }
                    .frame(height: 20)
                    
                    Text(String(format: "%.1f", avgTasks))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .frame(width: 32, alignment: .trailing)
                }
            }
            .padding(DesignTokens.spacingMD)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }
    
    // MARK: - Recent Entries
    
    private var recentEntries: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text(String(localized: "Recent"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            ForEach(Array(filteredEntries.prefix(10))) { entry in
                HStack(spacing: DesignTokens.spacingMD) {
                    Image(systemName: entry.mood.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(entry.mood.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.mood.label)
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textPrimary)
                        
                        HStack(spacing: DesignTokens.spacingSM) {
                            Text(entry.loggedAt.relativeDescription)
                            if entry.tasksCompletedThatDay > 0 {
                                Text("•")
                                Text(String(localized: "\(entry.tasksCompletedThatDay) tasks done"))
                            }
                        }
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                        
                        if let note = entry.note, !note.isEmpty {
                            Text(note)
                                .font(AppTheme.footnote)
                                .foregroundStyle(DesignTokens.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                }
                .padding(DesignTokens.spacingSM)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.accentActive.opacity(0.5))
            
            Text(String(localized: "No check-ins yet"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            Text(String(localized: "After a few mood check-ins, you'll see trends and insights here."))
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignTokens.spacingXXXL)
    }
    
    // MARK: - Helpers
    
    private var lastDays: [Date] {
        let count = min(selectedRange == .week ? 7 : 14, selectedRange.days)
        return (0..<count).reversed().compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: Date())
        }
    }
    
    private func entryForDate(_ date: Date) -> MoodEntry? {
        let calendar = Calendar.current
        return filteredEntries.first { calendar.isDate($0.loggedAt, inSameDayAs: date) }
    }
    
    private func dayLabel(_ date: Date) -> String {
        return String(date.formatted(.dateTime.weekday(.abbreviated)).prefix(2))
    }
    
    private func moodForValue(_ value: Double) -> MoodLevel? {
        MoodLevel.allCases.min(by: { abs(Double($0.rawValue) - value) < abs(Double($1.rawValue) - value) })
    }
}
