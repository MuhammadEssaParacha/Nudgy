//
//  NudgeLiveActivityWidget.swift
//  NudgeWidgetExtension
//
//  ActivityConfiguration that renders the Live Activity on
//  Lock Screen and Dynamic Island. Nudgy-branded experience
//  with ADHD-friendly queue counts instead of anxiety timers.
//

import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes (must match main app)

struct NudgeActivityAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        var taskContent: String
        var taskEmoji: String
        var queuePosition: Int
        var queueTotal: Int
        var accentColorHex: String
        var timeOfDayIndex: Int
        var taskID: String          // Item UUID for deep links
        var startedAt: Date         // When this task became active (for timer)
        var categoryLabel: String?  // Category name for lock screen chip
        var categoryColorHex: String? // Category accent color
    }
    
    var startedAt: Date
}

// MARK: - Time of Day (must match main app)

enum TimeOfDay: Int, CaseIterable {
    case dawn     = 0
    case morning  = 1
    case afternoon = 2
    case sunset   = 3
    case night    = 4
    
    var color: Color {
        switch self {
        case .dawn:      return Color(hex: "5B86E5")
        case .morning:   return Color(hex: "FFD700")
        case .afternoon: return Color(hex: "FF9F0A")
        case .sunset:    return Color(hex: "FF6B35")
        case .night:     return Color(hex: "4A00E0")
        }
    }
}

// MARK: - Color(hex:) Extension (widget-local, no dependency on main app)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 3:
            r = Double((int >> 8) * 17) / 255.0
            g = Double((int >> 4 & 0xF) * 17) / 255.0
            b = Double((int & 0xF) * 17) / 255.0
        case 6:
            r = Double(int >> 16) / 255.0
            g = Double(int >> 8 & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Widget-Side Intents (for Home Screen widgets)

/// Writes the task ID to shared UserDefaults so the main app
/// can process the SwiftData change on foreground.
struct WidgetMarkDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description: IntentDescription = "Mark the current task as done."
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Task ID")
    var taskID: String
    
    init() {}
    init(taskID: String) { self.taskID = taskID }
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.essaparacha.nudge")
        defaults?.set(taskID, forKey: "widget_pendingDoneTaskID")
        defaults?.set(Date().timeIntervalSince1970, forKey: "widget_pendingDoneTimestamp")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct WidgetSkipIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Task"
    static var description: IntentDescription = "Skip to the next task."
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Task ID")
    var taskID: String
    
    init() {}
    init(taskID: String) { self.taskID = taskID }
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.essaparacha.nudge")
        defaults?.set(taskID, forKey: "widget_pendingSkipTaskID")
        defaults?.set(Date().timeIntervalSince1970, forKey: "widget_pendingSkipTimestamp")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Live Activity Widget

struct NudgeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NudgeActivityAttributes.self) { context in
            // Lock Screen / Notification banner presentation
            NudgeLockScreenView(state: context.state)
                .widgetURL(URL(string: "nudge://viewTask?id=\(context.state.taskID)"))
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded Leading: Nudgy icon + queue badge ──
                DynamicIslandExpandedRegion(.leading) {
                    VStack(spacing: 6) {
                        Image(systemName: "bird.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(hex: context.state.accentColorHex))
                            .symbolRenderingMode(.hierarchical)
                        
                        // Queue position badge
                        Text("\(context.state.queuePosition)/\(context.state.queueTotal)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.leading, 2)
                }
                
                // ── Expanded Trailing: Time context ──
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        // Show timer only in focus mode (started < 30 min ago)
                        if isFocusTimerMode(startedAt: context.state.startedAt) {
                            HStack(spacing: 3) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                Text(context.state.startedAt, style: .timer)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(Color(hex: context.state.accentColorHex))
                        } else {
                            // Queue count — less anxiety-inducing than a timer
                            let remaining = context.state.queueTotal - context.state.queuePosition + 1
                            Text("\(remaining) left")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        // Time of day indicator dot
                        let tod = TimeOfDay(rawValue: context.state.timeOfDayIndex) ?? .morning
                        Circle()
                            .fill(tod.color)
                            .frame(width: 6, height: 6)
                    }
                    .padding(.trailing, 2)
                }
                
                // ── Expanded Center: Task + category chip ──
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.taskContent)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(2)
                            .foregroundStyle(.white)
                        
                        if let catLabel = context.state.categoryLabel,
                           let catHex = context.state.categoryColorHex {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: catHex))
                                    .frame(width: 6, height: 6)
                                Text(catLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color(hex: catHex))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color(hex: catHex).opacity(0.12))
                            )
                        }
                    }
                }
                
                // ── Expanded Bottom: Action buttons ──
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        // Done — prominent green
                        Link(destination: URL(string: "nudge://markDone?id=\(context.state.taskID)")!) {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text(String(localized: "Done"))
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "30D158"))
                            )
                        }
                        
                        // Skip — subtle outline
                        Link(destination: URL(string: "nudge://snooze?id=\(context.state.taskID)")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 11, weight: .medium))
                                Text(String(localized: "Skip"))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                            )
                        }
                        
                        // Snooze — clock icon only
                        Link(destination: URL(string: "nudge://snooze?id=\(context.state.taskID)")!) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                }
            } compactLeading: {
                // ── Compact Leading: Nudgy penguin icon ──
                Image(systemName: "bird.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: context.state.accentColorHex))
                    .symbolRenderingMode(.hierarchical)
            } compactTrailing: {
                // ── Compact Trailing: Queue count (ADHD-friendly) or timer in focus mode ──
                if isFocusTimerMode(startedAt: context.state.startedAt) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(minWidth: 32)
                } else {
                    let remaining = context.state.queueTotal - context.state.queuePosition + 1
                    Text("\(remaining) left")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
            } minimal: {
                // ── Minimal: Nudgy bird ──
                Image(systemName: "bird.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: context.state.accentColorHex))
                    .symbolRenderingMode(.hierarchical)
            }
            .widgetURL(URL(string: "nudge://viewTask?id=\(context.state.taskID)"))
        }
    }
    
    /// Focus timer mode: show a running timer only when the task
    /// started very recently (< 30 min). Avoids anxiety for tasks
    /// that have been sitting in the queue.
    private func isFocusTimerMode(startedAt: Date) -> Bool {
        abs(startedAt.timeIntervalSinceNow) < 30 * 60
    }
}

// MARK: - Lock Screen View

struct NudgeLockScreenView: View {
    let state: NudgeActivityAttributes.ContentState
    
    /// Progress fraction: completed / total
    private var progressFraction: CGFloat {
        guard state.queueTotal > 0 else { return 0 }
        return CGFloat(state.queuePosition - 1) / CGFloat(state.queueTotal)
    }
    
    /// Remaining tasks in queue
    private var remainingCount: Int {
        max(0, state.queueTotal - state.queuePosition + 1)
    }
    
    /// Whether this task is in focus timer mode (< 30 min old)
    private var isFocusMode: Bool {
        abs(state.startedAt.timeIntervalSinceNow) < 30 * 60
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Top bar: Nudgy branding + progress ──
            HStack(spacing: 6) {
                // Nudgy brand
                Image(systemName: "bird.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: state.accentColorHex))
                    .symbolRenderingMode(.hierarchical)
                
                Text(String(localized: "Nudge"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                
                Spacer()
                
                // Progress: mini bar + text
                HStack(spacing: 6) {
                    // Mini progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                            Capsule()
                                .fill(Color(hex: state.accentColorHex))
                                .frame(width: max(4, geo.size.width * progressFraction))
                        }
                    }
                    .frame(width: 40, height: 4)
                    
                    Text("\(state.queuePosition) of \(state.queueTotal)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // ── Time-of-day gradient strip ──
            HStack(spacing: 2) {
                ForEach(TimeOfDay.allCases, id: \.rawValue) { timeOfDay in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(timeOfDay.color)
                        .frame(height: 3)
                        .opacity(timeOfDay.rawValue == state.timeOfDayIndex ? 1.0 : 0.15)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            
            // ── Task content ──
            HStack(spacing: 12) {
                // Task icon in accent circle
                ZStack {
                    Circle()
                        .fill(Color(hex: state.accentColorHex).opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: WidgetIconResolver.symbol(for: state.taskEmoji))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: state.accentColorHex))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.taskContent)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        // Category chip
                        if let catLabel = state.categoryLabel,
                           let catHex = state.categoryColorHex {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(hex: catHex))
                                    .frame(width: 5, height: 5)
                                Text(catLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color(hex: catHex))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color(hex: catHex).opacity(0.12))
                            )
                        }
                        
                        // Timer (focus mode only) or queue count
                        if isFocusMode {
                            HStack(spacing: 3) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                Text(state.startedAt, style: .timer)
                                    .font(.system(size: 11, design: .monospaced))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(Color(hex: state.accentColorHex))
                        } else {
                            Text(String(localized: "\(remainingCount) remaining"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // ── Action buttons ──
            HStack(spacing: 10) {
                // Done — prominent, full green
                Link(destination: URL(string: "nudge://markDone?id=\(state.taskID)")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(String(localized: "Done"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "30D158"))
                    )
                }
                
                // Snooze — secondary outline
                Link(destination: URL(string: "nudge://snooze?id=\(state.taskID)")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 13))
                        Text(String(localized: "Snooze"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                            )
                    )
                }
                
                // Skip — tertiary, icon-forward
                Link(destination: URL(string: "nudge://viewTask?id=\(state.taskID)")!) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 44, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .activityBackgroundTint(Color.black)
    }
}

// MARK: - Previews

#Preview("Lock Screen", as: .content, using: NudgeActivityAttributes(startedAt: .now)) {
    NudgeLiveActivityWidget()
} contentStates: {
    NudgeActivityAttributes.ContentState(
        taskContent: "Call the dentist about appointment",
        taskEmoji: "📞",
        queuePosition: 2,
        queueTotal: 5,
        accentColorHex: "007AFF",
        timeOfDayIndex: 2,
        taskID: UUID().uuidString,
        startedAt: .now,
        categoryLabel: "Health",
        categoryColorHex: "FF6B6B"
    )
    
    NudgeActivityAttributes.ContentState(
        taskContent: "Buy groceries for the week",
        taskEmoji: "🛒",
        queuePosition: 4,
        queueTotal: 5,
        accentColorHex: "FF9F0A",
        timeOfDayIndex: 3,
        taskID: UUID().uuidString,
        startedAt: Date(timeIntervalSinceNow: -3600),
        categoryLabel: "Errands",
        categoryColorHex: "FFD60A"
    )
}

// MARK: - Widget-local Emoji → SF Symbol Resolver

private enum WidgetIconResolver {
    static func symbol(for emoji: String) -> String {
        switch emoji {
        case "📞": return "phone.fill"
        case "📱": return "iphone"
        case "💬": return "message.fill"
        case "📧", "✉️": return "envelope.fill"
        case "📬": return "envelope.open.fill"
        case "🎂": return "gift.fill"
        case "💊": return "pills.fill"
        case "🏥": return "cross.case.fill"
        case "🦷": return "mouth.fill"
        case "🧘": return "figure.mind.and.body"
        case "🏋️", "🏋️‍♂️", "🏋️‍♀️": return "dumbbell.fill"
        case "🪴", "🌱": return "leaf.fill"
        case "🧹": return "sparkles"
        case "🐶", "🐕", "🐾": return "pawprint.fill"
        case "📋": return "checklist"
        case "📊": return "chart.bar.fill"
        case "📝": return "doc.text.fill"
        case "✍️": return "pencil.line"
        case "📌": return "pin.fill"
        case "🗓️", "📅": return "calendar"
        case "💰": return "dollarsign.circle.fill"
        case "📖": return "book.fill"
        case "🎬": return "play.rectangle.fill"
        case "🎸": return "guitars.fill"
        case "🎙️": return "mic.fill"
        case "✈️": return "airplane"
        case "🏖️": return "beach.umbrella.fill"
        case "📦": return "shippingbox.fill"
        case "🔍": return "magnifyingglass"
        case "🎯": return "target"
        case "🥗": return "fork.knife"
        case "🛒": return "cart.fill"
        case "💼": return "briefcase.fill"
        case "🧾": return "doc.text.fill"
        default: return "checklist"
        }
    }
}
