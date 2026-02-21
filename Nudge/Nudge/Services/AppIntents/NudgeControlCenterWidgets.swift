//
//  NudgeControlCenterWidgets.swift
//  Nudge
//
//  iOS 18+ Control Center controls.
//  Quick-add button & task count toggle for Control Center.
//
//  Users can add these in Settings → Control Center → Add Controls → Nudge.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Quick Add Control

/// A Control Center button that opens Nudge's quick-add flow.
@available(iOS 18.0, *)
struct NudgeQuickAddControl: ControlWidget {
    static let kind = "com.tarsitgroup.nudge.control.quickAdd"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuickAddControlIntent()) {
                Label("Add Nudge", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Nudge")
        .description("Quickly add a new task to Nudge.")
    }
}

/// Intent that opens the quick-add sheet via deep link.
@available(iOS 18.0, *)
struct QuickAddControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Add Nudge"
    static var isDiscoverable = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Open the app's quick-add screen via deep link
        let url = URL(string: "nudge://quickAdd")!
        await UIApplication.shared.open(url)
        return .result()
    }
}

// MARK: - Task Count Control

/// A Control Center button that shows active task count and opens Nudge.
@available(iOS 18.0, *)
struct NudgeTaskCountControl: ControlWidget {
    static let kind = "com.tarsitgroup.nudge.control.taskCount"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenNudgesControlIntent()) {
                let count = Self.readActiveCount()
                Label("\(count) Nudge\(count == 1 ? "" : "s")", systemImage: "checklist")
            }
        }
        .displayName("Nudge Count")
        .description("See how many tasks remain and open Nudge.")
    }
    
    private static func readActiveCount() -> Int {
        let defaults = UserDefaults(suiteName: "group.com.tarsitgroup.nudge")
        return defaults?.integer(forKey: "widget_activeCount") ?? 0
    }
}

/// Intent that opens the Nudges tab.
@available(iOS 18.0, *)
struct OpenNudgesControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Open Nudges"
    static var isDiscoverable = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let url = URL(string: "nudge://nudges")!
        await UIApplication.shared.open(url)
        return .result()
    }
}

// MARK: - Brain Dump Control

/// A Control Center button that opens brain dump.
@available(iOS 18.0, *)
struct NudgeBrainDumpControl: ControlWidget {
    static let kind = "com.tarsitgroup.nudge.control.brainDump"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: BrainDumpControlIntent()) {
                Label("Unload", systemImage: "tray.and.arrow.down.fill")
            }
        }
        .displayName("Unload")
        .description("Unload everything on your mind into Nudgy.")
    }
}

/// Intent that opens brain dump via deep link.
@available(iOS 18.0, *)
struct BrainDumpControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Unload"
    static var isDiscoverable = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let url = URL(string: "nudge://brainDump")!
        await UIApplication.shared.open(url)
        return .result()
    }
}
