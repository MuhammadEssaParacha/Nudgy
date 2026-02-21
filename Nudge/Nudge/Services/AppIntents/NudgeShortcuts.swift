//
//  NudgeShortcuts.swift
//  Nudge
//
//  AppShortcutsProvider — registers Nudge's intents with the system.
//  This surfaces them in:
//    • Shortcuts app (automations)
//    • Spotlight search
//    • Action Button (iPhone 15 Pro+)
//    • Control Center (iOS 18+)
//
//  Each shortcut has natural-language trigger phrases that
//  make them discoverable without explicit Siri setup.
//

import AppIntents

/// Registers Nudge shortcuts with the system.
/// These appear in Shortcuts app, Spotlight suggestions,
/// and can be assigned to the Action Button.
struct NudgeShortcuts: AppShortcutsProvider {
    
    static var appShortcuts: [AppShortcut] {
        
        // ─── Quick Add (most important — capture from anywhere) ───
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a nudge in \(.applicationName)",
                "Add task to \(.applicationName)",
                "New nudge in \(.applicationName)",
                "Quick add \(.applicationName)",
                "Capture in \(.applicationName)"
            ],
            shortTitle: "Add Nudge",
            systemImageName: "plus.circle.fill"
        )
        
        // ─── Get Next Task (Action Button power use) ───
        AppShortcut(
            intent: GetNextTaskIntent(),
            phrases: [
                "What's next in \(.applicationName)",
                "Next task in \(.applicationName)",
                "Show my next nudge in \(.applicationName)"
            ],
            shortTitle: "Next Nudge",
            systemImageName: "arrow.right.circle.fill"
        )
        
        // ─── Complete a Task ───
        AppShortcut(
            intent: MarkDoneIntent(),
            phrases: [
                "Complete a nudge in \(.applicationName)",
                "Mark done in \(.applicationName)",
                "Finish task in \(.applicationName)"
            ],
            shortTitle: "Complete Nudge",
            systemImageName: "checkmark.circle.fill"
        )
        
        // ─── Count Active Tasks ───
        AppShortcut(
            intent: GetActiveCountIntent(),
            phrases: [
                "How many nudges in \(.applicationName)",
                "Count tasks in \(.applicationName)",
                "How many tasks in \(.applicationName)"
            ],
            shortTitle: "Count Nudges",
            systemImageName: "number.circle.fill"
        )
        
        // ─── Open Brain Dump ───
        AppShortcut(
            intent: OpenNudgeIntent(),
            phrases: [
                "Unload in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: "Open Nudge",
            systemImageName: "brain.head.profile"
        )
        
        // ─── Get Tasks By Category ───
        AppShortcut(
            intent: GetTasksByCategoryIntent(),
            phrases: [
                "Show my \(\.$category) nudges in \(.applicationName)",
                "How many \(\.$category) tasks in \(.applicationName)",
                "\(\.$category) nudges in \(.applicationName)"
            ],
            shortTitle: "Category Nudges",
            systemImageName: "tag.fill"
        )
        
        // ─── Snooze a Task ───
        AppShortcut(
            intent: SnoozeTaskIntent(),
            phrases: [
                "Snooze a nudge in \(.applicationName)",
                "Snooze task in \(.applicationName)",
                "Remind me later in \(.applicationName)"
            ],
            shortTitle: "Snooze Nudge",
            systemImageName: "clock.badge.checkmark.fill"
        )
    }
}
