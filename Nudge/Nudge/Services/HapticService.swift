//
//  HapticService.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import UIKit

/// Centralized haptic engine. Pre-warms generators for zero-latency feedback.
/// Maps every PRD-defined interaction to its haptic pattern.
final class HapticService {
    
    static let shared = HapticService()
    
    // Pre-warmed generators (call prepare() to reduce first-fire latency)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    private init() {}
    
    /// Call on app launch to pre-warm all generators
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        softImpact.prepare()
        rigidImpact.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    // MARK: - Mapped Interactions (from PRD Haptic Design System)
    
    /// Swipe Done — satisfying "done" thud
    func swipeDone() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    /// Category-specific completion haptic.
    /// Each category group gets a distinct tactile feel.
    func completionHaptic(for category: TaskCategory) {
        switch category {
        // Physical / active categories → heavy satisfying thud
        case .exercise, .cleaning, .maintenance:
            heavyImpact.impactOccurred(intensity: 1.0)
            heavyImpact.prepare()
            
        // Communication → double-tap (sent!)
        case .call, .text, .email, .social:
            Task { @MainActor in
                mediumImpact.impactOccurred(intensity: 0.8)
                mediumImpact.prepare()
                try? await Task.sleep(for: .milliseconds(80))
                lightImpact.impactOccurred(intensity: 0.6)
                lightImpact.prepare()
            }
            
        // Mindful / self-care → soft gentle pulse
        case .selfCare, .health:
            softImpact.impactOccurred(intensity: 0.7)
            softImpact.prepare()
            
        // Focus / study → crisp rigid snap
        case .homework, .work, .finance:
            rigidImpact.impactOccurred(intensity: 0.9)
            rigidImpact.prepare()
            
        // Creative → playful triple-tap
        case .creative, .cooking:
            Task { @MainActor in
                lightImpact.impactOccurred(intensity: 0.5)
                try? await Task.sleep(for: .milliseconds(60))
                lightImpact.impactOccurred(intensity: 0.7)
                try? await Task.sleep(for: .milliseconds(60))
                mediumImpact.impactOccurred(intensity: 0.9)
                mediumImpact.prepare()
            }
            
        // Errands / quick tasks → standard success
        case .errand, .shopping, .appointment, .alarm, .link, .general:
            notificationGenerator.notificationOccurred(.success)
            notificationGenerator.prepare()
        }
    }
    
    /// Swipe Snooze — soft caution
    func swipeSnooze() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
    
    /// Swipe Skip — quick, weightless tap
    func swipeSkip() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }
    
    /// Mic tap (start recording) — firm press
    func micStart() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }
    
    /// Mic tap (stop recording) — gentle release
    func micStop() {
        softImpact.impactOccurred()
        softImpact.prepare()
    }
    
    /// Card appears — subtle arrival
    func cardAppear() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }
    
    /// Snooze time selected — picker tick
    func snoozeTimeSelected() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
    
    /// Share saved — confirmed
    func shareSaved() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    /// Action button tap — intentional press
    func actionButtonTap() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }
    
    /// Error or limit hit — something's wrong
    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
}
