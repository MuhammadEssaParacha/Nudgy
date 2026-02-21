//
//  TimelineView.swift
//  Nudge
//
//  A vertical visual timeline of today's scheduled tasks.
//  Shows a time axis with task blocks, a "now" indicator,
//  and optional calendar events merged in.
//
//  Inspired by Tiimo's visual timeline — but optimized for
//  ADHD with cleaner contrast and less visual overload.
//

import SwiftUI
import SwiftData

// MARK: - Timeline Entry

/// A unified entry on the timeline (task or calendar event)
struct TimelineEntry: Identifiable {
    enum EntryType { case task, calendarEvent }
    
    let id: UUID
    let type: EntryType
    let title: String
    let emoji: String?
    let startTime: Date
    let durationMinutes: Int
    let colorHex: String?
    let isDone: Bool
    let nudgeItem: NudgeItem?
    
    var endTime: Date {
        startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
    
    var color: Color {
        if let hex = colorHex { return Color(hex: hex) }
        return type == .calendarEvent ? Color(hex: "BF5AF2") : DesignTokens.accentActive
    }
}

// MARK: - Timeline View

struct TimelineView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var entries: [TimelineEntry] = []
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    // External calendar events injected by parent
    var calendarEvents: [TimelineEntry] = []
    
    // Callbacks
    var onTapTask: ((NudgeItem) -> Void)?
    
    // Timeline config
    private let hourHeight: CGFloat = 80
    private let startHour = 6   // 6 AM
    private let endHour = 23    // 11 PM
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid lines
                    hourGrid
                    
                    // Task blocks (column-aware — no overlapping)
                    ForEach(columnLayouts, id: \.entry.id) { layout in
                        timelineBlock(for: layout.entry, column: layout.column, totalColumns: layout.totalColumns)
                    }
                    
                    // "Now" indicator
                    nowIndicator
                }
                .frame(
                    width: nil,
                    height: CGFloat(endHour - startHour) * hourHeight
                )
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.top, DesignTokens.spacingSM)
                .padding(.bottom, 100)
                .id("timeline")
            }
            .onAppear {
                loadEntries()
                startTimer()
                scrollToNow(proxy: proxy)
            }
            .onDisappear { stopTimer() }
            .onReceive(NotificationCenter.default.publisher(for: .nudgeDataChanged)) { _ in
                loadEntries()
            }
        }
    }
    
    // MARK: - Combined Entries
    
    private var allEntries: [TimelineEntry] {
        (entries + calendarEvents).sorted { $0.startTime < $1.startTime }
    }
    
    // MARK: - Column Layout (prevents overlapping events)
    
    /// Assigns each entry a column index and total column count for its group
    /// so concurrent events sit side-by-side instead of overlapping.
    private struct ColumnLayout {
        let entry: TimelineEntry
        let column: Int
        let totalColumns: Int
    }
    
    private var columnLayouts: [ColumnLayout] {
        let sorted = allEntries
        guard !sorted.isEmpty else { return [] }
        
        // Group overlapping entries into clusters
        var layouts: [ColumnLayout] = []
        var activeColumns: [(entry: TimelineEntry, endTime: Date, column: Int)] = []
        
        for entry in sorted {
            // Remove entries that have ended before this one starts
            activeColumns.removeAll { $0.endTime <= entry.startTime }
            
            // Find the first available column
            let usedColumns = Set(activeColumns.map(\.column))
            var col = 0
            while usedColumns.contains(col) {
                col += 1
            }
            
            activeColumns.append((entry: entry, endTime: entry.endTime, column: col))
            layouts.append(ColumnLayout(entry: entry, column: col, totalColumns: 0))
        }
        
        // Second pass: calculate total columns for each cluster
        return layouts.map { layout in
            // Find all entries that overlap with this one
            let overlapping = layouts.filter { other in
                other.entry.startTime < layout.entry.endTime &&
                other.entry.endTime > layout.entry.startTime
            }
            let maxCol = overlapping.map(\.column).max() ?? 0
            return ColumnLayout(
                entry: layout.entry,
                column: layout.column,
                totalColumns: maxCol + 1
            )
        }
    }
    
    // MARK: - Hour Grid
    
    private var hourGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
                    // Hour label
                    Text(formatHour(hour))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 44, alignment: .trailing)
                    
                    // Divider line
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 0.5)
                        .padding(.top, 7)
                }
                .frame(height: hourHeight)
            }
        }
    }
    
    // MARK: - Now Indicator
    
    private var nowIndicator: some View {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let totalMinutes = (hour - startHour) * 60 + minute
        let yOffset = CGFloat(totalMinutes) / 60.0 * hourHeight
        
        return HStack(spacing: 0) {
            Circle()
                .fill(DesignTokens.accentOverdue)
                .frame(width: 8, height: 8)
            
            Rectangle()
                .fill(DesignTokens.accentOverdue)
                .frame(height: 1.5)
        }
        .offset(x: 48, y: yOffset)
        .opacity(hour >= startHour && hour < endHour ? 1 : 0)
    }
    
    // MARK: - Timeline Block
    
    private func timelineBlock(for entry: TimelineEntry, column: Int = 0, totalColumns: Int = 1) -> some View {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: entry.startTime)
        let minute = calendar.component(.minute, from: entry.startTime)
        let totalMinutes = (hour - startHour) * 60 + minute
        let yOffset = CGFloat(totalMinutes) / 60.0 * hourHeight
        let blockHeight = max(CGFloat(entry.durationMinutes) / 60.0 * hourHeight, 36)
        
        // Column-aware horizontal layout
        let labelWidth: CGFloat = 60
        let trailingPad: CGFloat = DesignTokens.spacingLG
        let availableWidth = UIScreen.current.bounds.width - labelWidth - trailingPad - (DesignTokens.spacingLG * 2)
        let columnWidth = availableWidth / CGFloat(totalColumns)
        let columnGap: CGFloat = totalColumns > 1 ? 2 : 0
        let xOffset = labelWidth + CGFloat(column) * columnWidth
        let blockWidth = columnWidth - columnGap
        
        return Button {
            if let item = entry.nudgeItem {
                onTapTask?(item)
            }
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                // Color bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(entry.color)
                    .frame(width: 3)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if let emoji = entry.emoji {
                            StepIconView(emoji: emoji, size: 12)
                        }
                        
                        Text(entry.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(
                                entry.isDone
                                    ? DesignTokens.textTertiary
                                    : DesignTokens.textPrimary
                            )
                            .strikethrough(entry.isDone)
                            .lineLimit(1)
                    }
                    
                    if entry.durationMinutes > 0 {
                        Text(String(localized: "\(entry.durationMinutes) min"))
                            .font(.system(size: 10))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                
                Spacer()
                
                if entry.isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.accentComplete)
                }
            }
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, 4)
            .frame(height: blockHeight, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                    .fill(entry.color.opacity(entry.isDone ? 0.04 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .strokeBorder(entry.color.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(width: blockWidth)
        .offset(x: xOffset, y: yOffset)
    }
    
    // MARK: - Data Loading
    
    private func loadEntries() {
        let repository = NudgeRepository(modelContext: modelContext)
        let active = repository.fetchActiveQueue()
        let done = repository.fetchCompletedToday()
        
        let allItems = (active + done).filter { $0.scheduledTime != nil }
        
        entries = allItems.compactMap { item -> TimelineEntry? in
            guard let scheduledTime = item.scheduledTime else { return nil }
            return TimelineEntry(
                id: item.id,
                type: .task,
                title: item.content,
                emoji: item.emoji,
                startTime: scheduledTime,
                durationMinutes: item.estimatedMinutes ?? 15,
                colorHex: item.categoryColorHex,
                isDone: item.status == .done,
                nudgeItem: item
            )
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                currentTime = Date()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func scrollToNow(proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            proxy.scrollTo("timeline", anchor: .center)
        }
    }
    
    // MARK: - Formatting
    
    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12
        let ampm = hour >= 12 ? "PM" : "AM"
        return "\(h == 0 ? 12 : h) \(ampm)"
    }
}
