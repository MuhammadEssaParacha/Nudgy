//
//  DailyReviewView.swift
//  Nudge
//
//  Phase 17: Daily Review & Tomorrow Planning.
//  Evening prompt: "Want to review your day?"
//  Shows completed vs planned, mood trend, fish earned, streak.
//  "Plan tomorrow?" → shows tomorrow's tasks, lets you reorder/add.
//

import SwiftUI
import SwiftData

struct DailyReviewView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var phase: ReviewPhase = .summary
    @State private var animateIn = false
    
    // Data
    @State private var completedToday: [NudgeItem] = []
    @State private var remainingActive: [NudgeItem] = []
    @State private var fishCaughtToday: [FishCatch] = []
    @State private var streak: Int = 0
    @State private var fishEarned: Int = 0
    @State private var categoryStreakData: [(category: TaskCategory, days: Int)] = []
    
    enum ReviewPhase {
        case summary
        case fishHighlight
        case tomorrowPlan
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.spacingLG) {
                        // Header
                        headerSection
                        
                        switch phase {
                        case .summary:
                            summarySection
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        case .fishHighlight:
                            fishSection
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        case .tomorrowPlan:
                            tomorrowSection
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                        
                        // Navigation buttons
                        navigationButtons
                        
                        Spacer(minLength: DesignTokens.spacingXXL)
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                }
            }
            .navigationTitle(String(localized: "Daily Review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadData()
            withAnimation(.spring(response: 0.6)) {
                animateIn = true
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.indigo)
                .scaleEffect(animateIn ? 1 : 0.5)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateIn)
            
            Text(greeting)
                .font(AppTheme.title2)
                .foregroundStyle(DesignTokens.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .padding(.top, DesignTokens.spacingLG)
    }
    
    private var greeting: String {
        let name = settings.userName.isEmpty ? "" : ", \(settings.userName)"
        if completedToday.isEmpty {
            return String(localized: "Hey\(name)! Let's look at today.")
        }
        if completedToday.count >= 5 {
            return String(localized: "What a day\(name)! You crushed it! 🐧")
        }
        return String(localized: "Nice work today\(name)!")
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // Stats row
            HStack(spacing: DesignTokens.spacingMD) {
                statCard(
                    value: "\(completedToday.count)",
                    label: String(localized: "Completed"),
                    icon: "checkmark.circle.fill",
                    color: DesignTokens.accentComplete
                )
                statCard(
                    value: "\(remainingActive.count)",
                    label: String(localized: "Remaining"),
                    icon: "clock.fill",
                    color: remainingActive.isEmpty ? DesignTokens.accentComplete : DesignTokens.accentStale
                )
                statCard(
                    value: "\(streak)",
                    label: String(localized: "Day Streak"),
                    icon: "flame.fill",
                    color: .orange
                )
            }
            
            // Completed tasks list
            if !completedToday.isEmpty {
                // Phase 10: Category breakdown row
                categoryBreakdownRow
                
                // Phase 12: Category streaks
                categoryStreaksRow
                
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(String(localized: "What you accomplished"))
                        .font(AppTheme.captionBold)
                        .foregroundStyle(DesignTokens.textSecondary)
                    
                    ForEach(completedToday.prefix(8)) { item in
                        HStack(spacing: DesignTokens.spacingSM) {
                            StepIconView(emoji: item.emoji ?? "checklist", size: 16)
                            Text(item.content)
                                .font(AppTheme.body)
                                .foregroundStyle(DesignTokens.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            let cat = item.resolvedCategory
                            if cat != .general {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(cat.primaryColor)
                            }
                            Image(systemName: "checkmark")
                                .font(.system(size: 11))
                                .foregroundStyle(DesignTokens.accentComplete)
                        }
                        .padding(.vertical, 3)
                    }
                }
                .padding(DesignTokens.spacingMD)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
            }
            
            // Remaining tasks
            if !remainingActive.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(String(localized: "Still on your plate"))
                        .font(AppTheme.captionBold)
                        .foregroundStyle(DesignTokens.textSecondary)
                    
                    ForEach(remainingActive.prefix(5)) { item in
                        HStack(spacing: DesignTokens.spacingSM) {
                            TaskIconView(emoji: item.emoji, size: .small, accentColor: DesignTokens.accentStale)
                            Text(item.content)
                                .font(AppTheme.body)
                                .foregroundStyle(DesignTokens.textSecondary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, 3)
                    }
                    
                    Text(String(localized: "These will be waiting for you tomorrow. No guilt! 🐧"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                        .padding(.top, DesignTokens.spacingXS)
                }
                .padding(DesignTokens.spacingMD)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
            }
        }
    }
    
    // MARK: - Fish Section
    
    private var fishSection: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            Text(String(localized: "Today's Catch"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            if fishCaughtToday.isEmpty {
                VStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(String(localized: "No fish today — that's okay! Tomorrow's a new day."))
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                // Fish count by species
                HStack(spacing: DesignTokens.spacingMD) {
                    ForEach(FishSpecies.allCases, id: \.self) { species in
                        let count = fishCaughtToday.filter { $0.species == species }.count
                        if count > 0 {
                            VStack(spacing: 4) {
                                Image(systemName: species.icon)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color(hex: species.glowColorHex))
                                Text("×\(count)")
                                    .font(AppTheme.captionBold)
                                    .foregroundStyle(DesignTokens.textPrimary)
                            }
                        }
                    }
                }
                
                // Total fish
                HStack(spacing: DesignTokens.spacingXS) {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                    Text("+\(fishEarned)")
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.accentActive)
                    Text(String(localized: "fish earned today"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .padding(.top, DesignTokens.spacingSM)
            }
        }
        .padding(DesignTokens.spacingLG)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
    
    // MARK: - Tomorrow Section
    
    private var tomorrowSection: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            Text(String(localized: "Tomorrow's Focus"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            if remainingActive.isEmpty {
                tomorrowEmptyState
            } else {
                tomorrowTaskList
                
                Text(String(localized: "You can reorder these in the Nudges tab anytime."))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            
            // Good night message
            tomorrowGoodNight
        }
    }
    
    private var tomorrowEmptyState: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.orange)
            Text(String(localized: "Nothing on your plate! Enjoy a fresh start."))
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var tomorrowTaskList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            // Phase 10: Category breakdown for remaining tasks
            let catCounts = Dictionary(grouping: remainingActive, by: { $0.resolvedCategory })
                .mapValues(\.count)
                .sorted { $0.value > $1.value }
                .filter { $0.key != .general }
            
            if !catCounts.isEmpty {
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(catCounts.prefix(4), id: \.key) { cat, count in
                        HStack(spacing: 2) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(hex: cat.primaryColorHex))
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: cat.primaryColorHex))
                        }
                    }
                }
                .padding(.bottom, DesignTokens.spacingXS)
            }
            
            Text(String(localized: "Nudgy recommends starting with:"))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
            
            ForEach(Array(remainingActive.prefix(3).enumerated()), id: \.element.id) { index, item in
                HStack(spacing: DesignTokens.spacingSM) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(DesignTokens.accentActive))
                    
                    TaskIconView(emoji: item.emoji, size: .small, accentColor: DesignTokens.accentActive)
                    Text(item.content)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(DesignTokens.spacingMD)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
    
    private var tomorrowGoodNight: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.indigo.opacity(0.7))
            Text(String(localized: "Rest up! Nudgy will be here in the morning."))
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignTokens.spacingLG)
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            switch phase {
            case .summary:
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        phase = .fishHighlight
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(String(localized: "See Your Catch"))
                        Image(systemName: "chevron.right")
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background(Capsule().fill(DesignTokens.accentActive))
                }
                .buttonStyle(.plain)
                
            case .fishHighlight:
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        phase = .summary
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text(String(localized: "Back"))
                    }
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        phase = .tomorrowPlan
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(String(localized: "Plan Tomorrow"))
                        Image(systemName: "chevron.right")
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background(Capsule().fill(DesignTokens.accentActive))
                }
                .buttonStyle(.plain)
                
            case .tomorrowPlan:
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        phase = .fishHighlight
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text(String(localized: "Back"))
                    }
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    HapticService.shared.actionButtonTap()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Text(String(localized: "Good Night"))
                        Image(systemName: "moon.fill")
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background(Capsule().fill(DesignTokens.accentComplete))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, DesignTokens.spacingMD)
    }
    
    // MARK: - Category Breakdown
    
    /// Phase 15: Category breakdown with completion rates — shows done/total + mini progress.
    private var categoryBreakdownRow: some View {
        // Gather all categories that had tasks today (done + remaining)
        let doneCounts = Dictionary(grouping: completedToday, by: { $0.resolvedCategory })
            .mapValues(\.count)
        let remainingCounts = Dictionary(grouping: remainingActive, by: { $0.resolvedCategory })
            .mapValues(\.count)
        
        // Merge into category stats
        let allCategories = Set(doneCounts.keys).union(remainingCounts.keys).subtracting([.general])
        let catStats: [(cat: TaskCategory, done: Int, total: Int)] = allCategories.map { cat in
            let done = doneCounts[cat] ?? 0
            let remaining = remainingCounts[cat] ?? 0
            return (cat: cat, done: done, total: done + remaining)
        }
        .sorted { $0.done > $1.done }
        
        // Find best category (100% done, at least 1 task)
        let bestCat = catStats.first { $0.done == $0.total && $0.total > 0 }
        // Find needs-attention (0% done, has remaining)
        let needsAttention = catStats.first { $0.done == 0 && $0.total > 0 }
        
        return Group {
            if !catStats.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    // Category completion capsules with progress
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.spacingSM) {
                            ForEach(catStats, id: \.cat) { stat in
                                HStack(spacing: 6) {
                                    Image(systemName: stat.cat.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(hex: stat.cat.primaryColorHex))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(stat.cat.label)")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(DesignTokens.textPrimary)
                                        HStack(spacing: 4) {
                                            // Mini progress bar
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    Capsule()
                                                        .fill(Color.white.opacity(0.08))
                                                    Capsule()
                                                        .fill(stat.done == stat.total
                                                              ? DesignTokens.accentComplete
                                                              : Color(hex: stat.cat.primaryColorHex))
                                                        .frame(width: geo.size.width * CGFloat(stat.done) / CGFloat(max(stat.total, 1)))
                                                }
                                            }
                                            .frame(width: 32, height: 4)
                                            
                                            Text("\(stat.done)/\(stat.total)")
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                                .foregroundStyle(stat.done == stat.total
                                                                 ? DesignTokens.accentComplete
                                                                 : DesignTokens.textTertiary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background {
                                    Capsule()
                                        .fill(Color(hex: stat.cat.primaryColorHex).opacity(0.12))
                                }
                            }
                        }
                    }
                    
                    // Callout badges
                    HStack(spacing: DesignTokens.spacingSM) {
                        if let best = bestCat {
                            Label {
                                Text(String(localized: "\(best.cat.label) — all done!"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DesignTokens.accentComplete)
                            } icon: {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.yellow)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(DesignTokens.accentComplete.opacity(0.12))
                            }
                        }
                        
                        if let needs = needsAttention {
                            Label {
                                Text(String(localized: "\(needs.cat.label) needs love"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DesignTokens.accentOverdue)
                            } icon: {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DesignTokens.accentOverdue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(DesignTokens.accentOverdue.opacity(0.12))
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Category Streaks
    
    /// Phase 12: Category streak badges — consecutive days completing tasks in a category.
    private var categoryStreaksRow: some View {
        Group {
            if !categoryStreakData.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Text(String(localized: "Category Streaks"))
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .textCase(.uppercase)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.spacingSM) {
                            ForEach(categoryStreakData.prefix(3), id: \.category) { streak in
                                HStack(spacing: 6) {
                                    Image(systemName: streak.category.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color(hex: streak.category.primaryColorHex))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(streak.category.label)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(DesignTokens.textPrimary)
                                        HStack(spacing: 3) {
                                            Image(systemName: "flame.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.orange)
                                            Text(String(localized: "\(streak.days) days"))
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(streak.category.primaryColor.opacity(0.10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(streak.category.primaryColor.opacity(0.2), lineWidth: 0.5)
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(.top, DesignTokens.spacingSM)
            }
        }
    }
    
    // MARK: - Stat Card
    
    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: DesignTokens.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(DesignTokens.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingSM)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.06))
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        let repo = NudgeRepository(modelContext: modelContext)
        let grouped = repo.fetchAllGrouped()
        completedToday = grouped.doneToday
        remainingActive = repo.fetchActiveQueue()
        streak = RewardService.shared.currentStreak
        categoryStreakData = repo.categoryStreaks()
        
        // Fish caught today
        let allCatches = RewardService.shared.fishCatches
        let calendar = Calendar.current
        fishCaughtToday = allCatches.filter { calendar.isDateInToday($0.caughtAt) }
        fishEarned = fishCaughtToday.count
    }
}
