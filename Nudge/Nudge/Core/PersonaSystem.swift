//
//  PersonaSystem.swift
//  Nudge
//
//  Persona Adapter — translates ADHD profile settings into
//  AI prompt context. Called by NudgyEngine.syncADHDProfile().
//

import SwiftUI

// MARK: - Persona Adapter

/// Adapts Nudgy's behavior based on the active ADHD profile.
enum PersonaAdapter {
    
    // MARK: - ADHD Profile Context (feature set A–F)

    /// Builds a combined ADHD profile context string for AI prompts.
    /// Called by NudgyEngine.syncADHDProfile() on bootstrap and settings change.
    static func adhdProfileContext(
        ageGroup: AgeGroup,
        subtype: ADHDSubtype,
        challenge: ADHDChallenge,
        personalityMode: NudgyPersonalityMode
    ) -> String {
        var parts: [String] = []
        // Age group always included — shapes vocabulary and tone
        parts.append(ageGroup.promptContext)
        // Subtype only if user specified something meaningful
        if subtype != .unsure {
            parts.append(subtype.promptContext)
        }
        // Challenge only if more specific than "all of above"
        if challenge != .allOfAbove {
            parts.append(challenge.promptContext)
        }
        // Personality mode modifier (empty for .gentle — that's the default voice)
        if !personalityMode.promptModifier.isEmpty {
            parts.append(personalityMode.promptModifier)
        }
        return parts.joined(separator: "\n\n")
    }
}
