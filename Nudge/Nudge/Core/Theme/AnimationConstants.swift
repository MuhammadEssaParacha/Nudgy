//
//  AnimationConstants.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

// MARK: - Animation Constants

/// Single source of truth for every animation spec in Nudge.
/// Rule: Springs for physical motion, .easeOut for opacity fades.
/// Exception: repeating decorative pulses (glow, stale border) use .easeInOut for smooth looping.
/// Never use .linear. Never use default .easeInOut for one-shot animations.
enum AnimationConstants {
    
    // MARK: Card Swipe Animations
    
    /// Swipe right → Done: card flies right with rotation + momentum
    static let cardSwipeDone: Animation = .interpolatingSpring(stiffness: 200, damping: 18)
    
    /// Swipe left → Snooze: card drifts left slowly, gentle
    static let cardSwipeSnooze: Animation = .spring(response: 0.5, dampingFraction: 0.8)
    
    /// Swipe down → Skip: card drops with gravity feel
    static let cardSwipeSkip: Animation = .interpolatingSpring(stiffness: 150, damping: 20)
    
    /// Card snapping back to center on incomplete swipe
    static let cardSnapBack: Animation = .interpolatingSpring(stiffness: 300, damping: 25)
    
    // MARK: Card Appearance
    
    /// Stagger delay between cards appearing (brain dump results)
    static let cardStaggerDelay: Double = 0.15
    
    /// Individual card slide-in during brain dump results
    static let cardAppear: Animation = .spring(response: 0.4, dampingFraction: 0.75)
    
    /// Offset for card entrance (starts this far below, slides to 0)
    static let cardAppearOffset: CGFloat = 50
    
    // MARK: Card Swipe Values
    
    /// Maximum rotation during swipe-right (Done) in degrees
    static let swipeDoneRotation: Double = 15
    
    /// Threshold to commit a right swipe (Done)
    static let swipeDoneThreshold: CGFloat = 100
    
    /// Threshold to commit a left swipe (Snooze)
    static let swipeSnoozeThreshold: CGFloat = 100
    
    /// Threshold to commit a down swipe (Skip)
    static let swipeSkipThreshold: CGFloat = 80
    
    // MARK: Mic Button
    
    /// Mic tap scale effect: 1.0 → 1.15 → 1.0 over 0.3s
    static let micTapScale: CGFloat = 1.15
    static let micTapAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.5)
    
    /// Glow ring pulse: continuous 2s cycle at 30% opacity
    static let glowPulse: Animation = .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let glowMinOpacity: Double = 0.15
    static let glowMaxOpacity: Double = 0.40
    
    // MARK: Penguin
    
    /// Happy bounce: total 0.6s with overshoot
    static let penguinBounce: Animation = .interpolatingSpring(stiffness: 250, damping: 12)
    static let penguinBounceHeight: CGFloat = 8
    
    /// Idle sway: ±2pt horizontal on 6s loop
    static let penguinSwayDuration: Double = 6.0
    static let penguinSwayAmplitude: CGFloat = 2.0
    
    /// Blink: eyes close 0.15s, stay closed 0.2s, open 0.15s
    static let penguinBlinkClose: Double = 0.15
    static let penguinBlinkHold: Double = 0.20
    static let penguinBlinkOpen: Double = 0.15
    static let penguinBlinkInterval: Double = 3.5 // seconds between blinks (spec says 3.5s)
    
    // MARK: Mascot Idle Animations (Static Icon)
    
    /// Gentle float: vertical offset loop (very subtle)
    static let mascotFloatAmplitude: CGFloat = 3.0
    static let mascotFloatDuration: Double = 3.5
    static let mascotFloat: Animation = .easeInOut(duration: 3.5).repeatForever(autoreverses: true)
    
    /// Idle sway: rotation oscillation ±2° (barely noticeable)
    static let mascotSwayAngle: Double = 2.0
    static let mascotSwayDuration: Double = 4.5
    static let mascotSway: Animation = .easeInOut(duration: 4.5).repeatForever(autoreverses: true)
    
    /// Breathing pulse: very subtle scale loop
    static let mascotBreathMin: CGFloat = 1.0
    static let mascotBreathMax: CGFloat = 1.02
    static let mascotBreath: Animation = .easeInOut(duration: 3.0).repeatForever(autoreverses: true)
    
    /// Happy bounce: single spring settle (not repeating)
    static let mascotBounceDrop: CGFloat = -6.0
    static let mascotBounceSpring: Animation = .interpolatingSpring(stiffness: 200, damping: 14)
    
    /// Wiggle/nudge: quick rotation burst (smaller angle)
    static let mascotWiggleAngle: Double = 4.0
    static let mascotWiggleDuration: Double = 0.1
    static let mascotWiggleCount: Int = 3
    
    /// Thinking tilt: gentle lean (smaller)
    static let mascotThinkTilt: Double = -5.0
    static let mascotThinkAnimation: Animation = .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    
    /// Accent glow: very soft shadow pulse behind mascot
    static let mascotGlowMin: Double = 0.0
    static let mascotGlowMax: Double = 0.2
    static let mascotGlow: Animation = .easeInOut(duration: 2.5).repeatForever(autoreverses: true)
    
    // MARK: Stale Item Pulse
    
    /// Amber border pulse: 3s loop
    static let stalePulse: Animation = .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    
    // MARK: Tab Bar
    
    /// Cross-fade between views
    static let tabTransition: Animation = .easeOut(duration: 0.25)
    
    // MARK: Card Transition (Done → Next Up)
    
    /// Undo toast slide-in
    static let undoToast: Animation = .spring(response: 0.4, dampingFraction: 0.85)
    
    /// Card asymmetric transition: slide up + fade in, fade out on removal
    static var cardTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: cardAppearOffset)).animation(cardAppear),
            removal: .opacity.animation(.easeOut(duration: 0.15))
        )
    }
    
    // MARK: Overlays & Sheets
    
    /// Snooze picker slide-up
    static let sheetPresent: Animation = .spring(response: 0.4, dampingFraction: 0.85)
    
    /// General-purpose smooth spring for UI state toggles
    static let springSmooth: Animation = .spring(response: 0.35, dampingFraction: 0.8)
    
    /// Quick, crisp spring for selection feedback (filter chips, toggles)
    static let springSnappy: Animation = .spring(response: 0.25, dampingFraction: 0.7)

    /// Bouncy spring for micro-interactions (mood picker, icon taps)
    static let springBouncy: Animation = .spring(response: 0.3, dampingFraction: 0.6)

    /// Onboarding page transition
    static let pageTransition: Animation = .spring(response: 0.5, dampingFraction: 0.8)
    
    // MARK: Share Extension
    
    /// Thumbs-up micro-animation total duration
    static let thumbsUpDuration: Double = 0.4
    
    // MARK: Green Flash (Done)
    
    /// Green border flash on completion
    static let greenFlashDuration: Double = 0.15
    
    // MARK: Reduced Motion Support
    
    /// When Reduce Motion is enabled, replace all springs with this
    static let reducedMotionFade: Animation = .easeOut(duration: 0.2)
    
    /// Returns the appropriate animation based on accessibility settings
    static func animation(
        for standard: Animation,
        reduceMotion: Bool
    ) -> Animation {
        reduceMotion ? reducedMotionFade : standard
    }
}
