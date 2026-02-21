//
//  NudgeHomeScreenWidgets.swift
//  NudgeWidgetExtension
//
//  Home Screen and Lock Screen widgets for Nudge.
//  Reads task data from the shared App Group store.
//
//  Widget families:
//    • .systemSmall        — Next task card (one card at a time, ADHD-friendly)
//    • .systemMedium       — Next task + daily progress ring
//    • .systemLarge        — Queue stack of tasks
//    • .accessoryCircular  — Progress ring for Lock Screen
//    • .accessoryRectangular — Next task + count for Lock Screen
//    • .accessoryInline    — Inline count for Lock Screen
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Queue Task Model

/// Lightweight task representation for the large widget queue.
/// Uses a struct instead of tuple for Codable compliance.
struct WidgetQueueTask: Codable, Identifiable {
    let id: String
    let content: String
    let emoji: String
    let categoryColorHex: String?
    let categoryLabel: String?
    
    enum CodingKeys: String, CodingKey {
        case id, content, emoji
        case categoryColorHex = "catColor"
        case categoryLabel = "catLabel"
    }
}

// MARK: - Widget Data

/// Shared data structure for widget timeline entries.
struct NudgeWidgetEntry: TimelineEntry {
    let date: Date
    let nextTask: String?
    let nextTaskEmoji: String
    let nextTaskID: String?
    let activeCount: Int
    let completedToday: Int
    let totalToday: Int
    let isPlaceholder: Bool
    /// Category color hex for the next task (e.g. "#FF6B6B")
    let nextTaskCategoryColorHex: String?
    /// Category label (e.g. "Household")
    let nextTaskCategoryLabel: String?
    /// Category breakdown for medium widget (icon SF Symbol, count, colorHex)
    let categoryBreakdown: [(icon: String, count: Int, colorHex: String)]
    
    // Gamification data for large widget
    let streakDays: Int
    let totalFish: Int
    let level: Int
    let queueTasks: [WidgetQueueTask]
    
    static var placeholder: NudgeWidgetEntry {
        NudgeWidgetEntry(
            date: .now,
            nextTask: "Call the dentist",
            nextTaskEmoji: "phone.fill",
            nextTaskID: nil,
            activeCount: 3,
            completedToday: 2,
            totalToday: 5,
            isPlaceholder: true,
            nextTaskCategoryColorHex: nil,
            nextTaskCategoryLabel: nil,
            categoryBreakdown: [],
            streakDays: 5,
            totalFish: 42,
            level: 3,
            queueTasks: [
                WidgetQueueTask(id: "1", content: "Call the dentist", emoji: "phone.fill", categoryColorHex: "FF6B6B", categoryLabel: "Health"),
                WidgetQueueTask(id: "2", content: "Buy groceries", emoji: "cart.fill", categoryColorHex: "30D158", categoryLabel: "Errands"),
                WidgetQueueTask(id: "3", content: "Review PR", emoji: "laptopcomputer", categoryColorHex: "0A84FF", categoryLabel: "Work")
            ]
        )
    }
    
    static var empty: NudgeWidgetEntry {
        NudgeWidgetEntry(
            date: .now,
            nextTask: nil,
            nextTaskEmoji: "pawprint.fill",
            nextTaskID: nil,
            activeCount: 0,
            completedToday: 0,
            totalToday: 0,
            isPlaceholder: false,
            nextTaskCategoryColorHex: nil,
            nextTaskCategoryLabel: nil,
            categoryBreakdown: [],
            streakDays: 0,
            totalFish: 0,
            level: 1,
            queueTasks: []
        )
    }
}

// MARK: - Timeline Provider

struct NudgeWidgetProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> NudgeWidgetEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NudgeWidgetEntry) -> Void) {
        completion(readCurrentEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NudgeWidgetEntry>) -> Void) {
        let entry = readCurrentEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    /// Read task data from the shared App Group UserDefaults.
    /// The main app writes this data on every refresh via `syncWidgetData()`.
    private func readCurrentEntry() -> NudgeWidgetEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.tarsitgroup.nudge") else {
            return .empty
        }
        
        let nextTask = defaults.string(forKey: "widget_nextTask")
        let nextTaskEmoji = defaults.string(forKey: "widget_nextTaskEmoji") ?? "pawprint.fill"
        let nextTaskID = defaults.string(forKey: "widget_nextTaskID")
        let activeCount = defaults.integer(forKey: "widget_activeCount")
        let completedToday = defaults.integer(forKey: "widget_completedToday")
        let totalToday = defaults.integer(forKey: "widget_totalToday")
        let categoryColorHex = defaults.string(forKey: "widget_nextTaskCategoryColor")
        let categoryLabel = defaults.string(forKey: "widget_nextTaskCategoryLabel")
        
        // Category breakdown (format: "emoji:count:hex,emoji:count:hex,...")
        var breakdown: [(icon: String, count: Int, colorHex: String)] = []
        if let raw = defaults.string(forKey: "widget_categoryBreakdown"), !raw.isEmpty {
            for entry in raw.split(separator: ",") {
                let parts = entry.split(separator: ":")
                if parts.count == 3,
                   let count = Int(parts[1]) {
                    breakdown.append((icon: String(parts[0]), count: count, colorHex: String(parts[2])))
                }
            }
        }
        
        // Gamification data
        let streakDays = defaults.integer(forKey: "widget_streakDays")
        let totalFish = defaults.integer(forKey: "widget_totalFish")
        let level = max(1, defaults.integer(forKey: "widget_level"))
        
        // Queue tasks for large widget (JSON array)
        var queueTasks: [WidgetQueueTask] = []
        if let jsonString = defaults.string(forKey: "widget_queueTasks"),
           let data = jsonString.data(using: .utf8) {
            queueTasks = (try? JSONDecoder().decode([WidgetQueueTask].self, from: data)) ?? []
        }
        
        return NudgeWidgetEntry(
            date: .now,
            nextTask: nextTask,
            nextTaskEmoji: nextTaskEmoji,
            nextTaskID: nextTaskID,
            activeCount: activeCount,
            completedToday: completedToday,
            totalToday: totalToday,
            isPlaceholder: false,
            nextTaskCategoryColorHex: categoryColorHex,
            nextTaskCategoryLabel: categoryLabel,
            categoryBreakdown: breakdown,
            streakDays: streakDays,
            totalFish: totalFish,
            level: level,
            queueTasks: queueTasks
        )
    }
}

// MARK: - Home Screen Widget (Small)

/// Shows the next task — one card at a time, true to Nudge's ADHD philosophy.
struct NudgeSmallWidgetView: View {
    let entry: NudgeWidgetEntry
    
    /// Category accent or default blue
    private var accentColor: Color {
        if let hex = entry.nextTaskCategoryColorHex {
            return Color(hex: hex)
        }
        return Color(hex: "0A84FF")
    }
    
    var body: some View {
        if let task = entry.nextTask {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: entry.nextTaskEmoji)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accentColor)
                        Spacer()
                        Text("\(entry.activeCount)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    
                    Spacer()
                    
                    Text(task)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                    
                    // Category label or "up next"
                    if let catLabel = entry.nextTaskCategoryLabel {
                        Text(catLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(accentColor.opacity(0.8))
                    } else {
                        Text("up next")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                
                // Interactive done button
                Button(intent: WidgetMarkDoneIntent(taskID: entry.nextTaskID ?? "")) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .padding(14)
            }
            .background(Color.black)
            .widgetURL(URL(string: "nudge://viewTask?id=\(entry.nextTaskID ?? "")"))
        } else {
            // Empty state — all clear
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.green)
                Text("all clear")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .widgetURL(URL(string: "nudge://allItems"))
        }
    }
}

// MARK: - Home Screen Widget (Medium)

/// Shows next task + daily progress ring.
struct NudgeMediumWidgetView: View {
    let entry: NudgeWidgetEntry
    
    private var progress: Double {
        guard entry.totalToday > 0 else { return 0 }
        return Double(entry.completedToday) / Double(entry.totalToday)
    }
    
    /// Category accent or default green
    private var accentColor: Color {
        if let hex = entry.nextTaskCategoryColorHex {
            return Color(hex: hex)
        }
        return Color(hex: "30D158")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Next task
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: entry.nextTaskEmoji)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text("up next")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let task = entry.nextTask {
                    Text(task)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                } else {
                    Text("queue clear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                // Category label or remaining count
                if let catLabel = entry.nextTaskCategoryLabel {
                    Text(catLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accentColor.opacity(0.8))
                } else if entry.activeCount > 0 {
                    Text("\(entry.activeCount) remaining")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Middle: Interactive done button (when there's a task)
            if entry.nextTask != nil {
                Button(intent: WidgetMarkDoneIntent(taskID: entry.nextTaskID ?? "")) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
            
            // Right: Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(entry.completedToday)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/\(entry.totalToday)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            
            // Category breakdown dots
            if !entry.categoryBreakdown.isEmpty {
                VStack(spacing: 3) {
                    ForEach(Array(entry.categoryBreakdown.prefix(3).enumerated()), id: \.offset) { _, cat in
                        HStack(spacing: 2) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color(hex: cat.colorHex))
                            Text("\(cat.count)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: cat.colorHex))
                        }
                    }
                }
                .frame(width: 30)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .widgetURL(URL(string: "nudge://allItems"))
    }
}

// MARK: - Home Screen Widget (Large)

/// Queue stack showing up to 4 tasks with interactive done buttons.
struct NudgeLargeWidgetView: View {
    let entry: NudgeWidgetEntry
    
    private var progress: Double {
        guard entry.totalToday > 0 else { return 0 }
        return Double(entry.completedToday) / Double(entry.totalToday)
    }
    
    var body: some View {
        if entry.queueTasks.isEmpty && entry.nextTask == nil {
            // Empty / all-clear state
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.green)
                Text("you're done for today! 🐧")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("all clear")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .widgetURL(URL(string: "nudge://allItems"))
        } else {
            VStack(spacing: 0) {
                // Top: Branding + stats
                HStack(spacing: 0) {
                    Text("nudge")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        if entry.streakDays > 0 {
                            HStack(spacing: 2) {
                                Text("🔥")
                                    .font(.system(size: 11))
                                Text("\(entry.streakDays)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        HStack(spacing: 2) {
                            Text("🐟")
                                .font(.system(size: 11))
                            Text("\(entry.totalFish)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "5AC8FA"))
                        }
                        
                        Text("Lv.\(entry.level)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                // Middle: Task queue cards
                VStack(spacing: 0) {
                    let tasks = Array(entry.queueTasks.prefix(4))
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        NudgeLargeTaskRow(task: task)
                        
                        if index < tasks.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.08))
                                .padding(.horizontal, 16)
                        }
                    }
                }
                
                Spacer(minLength: 6)
                
                // Bottom: Progress bar + count
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(Color(hex: "30D158"))
                                .frame(width: max(4, geo.size.width * progress), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 16)
                    
                    Text("\(entry.completedToday) of \(entry.totalToday) done today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .widgetURL(URL(string: "nudge://allItems"))
        }
    }
}

/// A single task row in the large widget queue.
private struct NudgeLargeTaskRow: View {
    let task: WidgetQueueTask
    
    private var categoryColor: Color {
        if let hex = task.categoryColorHex {
            return Color(hex: hex)
        }
        return Color(hex: "0A84FF")
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.emoji)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(categoryColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(task.content)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if let catLabel = task.categoryLabel {
                    Text(catLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(categoryColor.opacity(0.7))
                }
            }
            
            Spacer()
            
            Button(intent: WidgetMarkDoneIntent(taskID: task.id)) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Lock Screen Widget (Circular)

/// Progress ring for the Lock Screen.
struct NudgeCircularWidgetView: View {
    let entry: NudgeWidgetEntry
    
    private var progress: Double {
        guard entry.totalToday > 0 else { return 0 }
        return Double(entry.completedToday) / Double(entry.totalToday)
    }
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            Gauge(value: progress) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 12))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.green)
        }
        .widgetURL(URL(string: "nudge://allItems"))
    }
}

// MARK: - Lock Screen Widget (Rectangular)

/// Next task + count for the Lock Screen.
struct NudgeRectangularWidgetView: View {
    let entry: NudgeWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                // Phase 16: Show category icon when available, paw fallback
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("NUDGE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.activeCount) left")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            if let task = entry.nextTask {
                Text(task)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
            } else {
                Text("all clear")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "nudge://allItems"))
    }
}

// MARK: - Lock Screen Widget (Inline)

/// Inline widget showing task count for the Lock Screen.
struct NudgeInlineWidgetView: View {
    let entry: NudgeWidgetEntry
    
    var body: some View {
        if entry.activeCount > 0 {
            Label("\(entry.activeCount) nudge\(entry.activeCount == 1 ? "" : "s") left", systemImage: "bird.fill")
        } else {
            Label("all clear", systemImage: "checkmark.circle.fill")
        }
    }
}

// MARK: - Widget Configurations

struct NudgeHomeWidget: Widget {
    let kind: String = "NudgeHomeWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NudgeWidgetProvider()) { entry in
            NudgeHomeWidgetEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Nudge")
        .description("Your next task at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct NudgeHomeWidgetEntryView: View {
    let entry: NudgeWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            NudgeSmallWidgetView(entry: entry)
        case .systemMedium:
            NudgeMediumWidgetView(entry: entry)
        case .systemLarge:
            NudgeLargeWidgetView(entry: entry)
        default:
            NudgeSmallWidgetView(entry: entry)
        }
    }
}

struct NudgeLockScreenWidget: Widget {
    let kind: String = "NudgeLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NudgeWidgetProvider()) { entry in
            NudgeLockScreenWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Nudge")
        .description("Task progress on your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct NudgeLockScreenWidgetEntryView: View {
    let entry: NudgeWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            NudgeCircularWidgetView(entry: entry)
        case .accessoryRectangular:
            NudgeRectangularWidgetView(entry: entry)
        case .accessoryInline:
            NudgeInlineWidgetView(entry: entry)
        default:
            NudgeCircularWidgetView(entry: entry)
        }
    }
}