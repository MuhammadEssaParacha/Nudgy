//
//  VoiceOverHelpers.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

// MARK: - VoiceOver Convenience Extensions

extension View {
    
    /// Combined accessibility label + hint in one call.
    /// Every custom view in Nudge must call this.
    func nudgeAccessibility(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map { Text($0) } ?? Text(""))
            .accessibilityAddTraits(traits)
    }
    
    /// Add a custom VoiceOver action (replaces swipe gestures for accessibility).
    /// Cards use this for Done/Snooze/Skip actions.
    func nudgeAccessibilityAction(
        name: String,
        action: @escaping () -> Void
    ) -> some View {
        self.accessibilityAction(named: Text(name), action)
    }
    
    /// Mark this view as an accessibility element (container).
    /// Use on cards so VoiceOver treats the entire card as one unit.
    func nudgeAccessibilityElement(
        label: String,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map { Text($0) } ?? Text(""))
            .accessibilityValue(value.map { Text($0) } ?? Text(""))
    }
    
    /// Announce a state change to VoiceOver (e.g., "Task completed", "Recording started").
    func nudgeAnnouncement(_ message: String) -> some View {
        self.onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                UIAccessibility.post(
                    notification: .announcement,
                    argument: message
                )
            }
        }
    }
}

// MARK: - Accessibility Announcement Helper

enum AccessibilityAnnouncer {
    /// Post an announcement to VoiceOver at any time
    static func announce(_ message: String) {
        UIAccessibility.post(
            notification: .announcement,
            argument: message
        )
    }
    
    /// Notify VoiceOver that the screen layout has changed
    static func screenChanged() {
        UIAccessibility.post(
            notification: .screenChanged,
            argument: nil
        )
    }
    
    /// Notify VoiceOver that a specific layout region changed
    static func layoutChanged(focus: Any? = nil) {
        UIAccessibility.post(
            notification: .layoutChanged,
            argument: focus
        )
    }
}
