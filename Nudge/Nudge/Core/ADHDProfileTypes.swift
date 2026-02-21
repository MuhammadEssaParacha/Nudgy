//
//  ADHDProfileTypes.swift
//  Nudge
//
//  ADHD-specific profiling types used to personalize Nudgy's
//  language, suggestions, and behavior across all features.
//
//  All fields are opt-in. Users are never required to disclose
//  anything — every field has a graceful "Not sure / Skip" default.
//

import SwiftUI

// MARK: - ADHD Subtype

/// Self-reported ADHD presentation.
/// Shapes micro-step depth and emotional regulation strategy.
enum ADHDSubtype: String, CaseIterable, Codable, Sendable {
    case inattentive          = "inattentive"
    case hyperactiveImpulsive = "hyperactive_impulsive"
    case combined             = "combined"
    case unsure               = "unsure"

    var label: String {
        switch self {
        case .inattentive:          return String(localized: "Mostly Inattentive")
        case .hyperactiveImpulsive: return String(localized: "Mostly Hyperactive")
        case .combined:             return String(localized: "Both / Combined")
        case .unsure:               return String(localized: "Not Sure")
        }
    }

    var description: String {
        switch self {
        case .inattentive:          return String(localized: "Easily distracted, trouble starting, loses things")
        case .hyperactiveImpulsive: return String(localized: "Restless, acts quickly, hard to wait")
        case .combined:             return String(localized: "A mix of both — most common type")
        case .unsure:               return String(localized: "No need to label — all ADHD is valid")
        }
    }

    var icon: String {
        switch self {
        case .inattentive:          return "cloud.drizzle.fill"
        case .hyperactiveImpulsive: return "bolt.fill"
        case .combined:             return "cloud.bolt.fill"
        case .unsure:               return "questionmark.circle.fill"
        }
    }

    var promptContext: String {
        switch self {
        case .inattentive:
            return "User has inattentive ADHD — struggles to start tasks, easily distracted. Prioritize one thing at a time. Always offer micro-steps. Never flood with information. Gentle reminders, not urgency."
        case .hyperactiveImpulsive:
            return "User has hyperactive/impulsive ADHD — restless, acts fast, gets bored easily. Keep responses punchy. Offer quick wins. Acknowledge their energy as a strength, not a problem."
        case .combined:
            return "User has combined ADHD. Balance gentle patience with quick momentum. Offer micro-steps AND quick wins. Short bursts of focus work best."
        case .unsure:
            return "User is unsure of their ADHD type. Use the full range of ADHD support: patient, flexible, non-judgmental, micro-steps available on request."
        }
    }
}

// MARK: - Age Group

/// Broad age group for language and tone calibration.
enum AgeGroup: String, CaseIterable, Codable, Sendable {
    case child  = "child"   // 6–12
    case teen   = "teen"    // 13–17
    case adult  = "adult"   // 18+

    var label: String {
        switch self {
        case .child: return String(localized: "Child (6–12)")
        case .teen:  return String(localized: "Teen (13–17)")
        case .adult: return String(localized: "Adult (18+)")
        }
    }

    var icon: String {
        switch self {
        case .child: return "figure.child.circle.fill"
        case .teen:  return "figure.stand.line.dotted.figure.stand"
        case .adult: return "person.fill"
        }
    }

    var promptContext: String {
        switch self {
        case .child:
            return "User is a child (6–12). Use very simple short words. More emojis. Big celebrations for small wins. Focus on school, chores, and fun. Never use clinical or adult language. Tasks should feel like adventures."
        case .teen:
            return "User is a teenager (13–17). Use casual, authentic language — not baby talk, not formal. Focus on school, social, and personal goals. Respect their autonomy. No condescending or preachy tone."
        case .adult:
            return ""   // Default Nudgy voice — no modifier needed
        }
    }
}

// MARK: - ADHD Challenge

/// The user's single biggest day-to-day ADHD challenge.
/// Nudgy uses this to proactively offer the most relevant support.
enum ADHDChallenge: String, CaseIterable, Codable, Sendable {
    case starting      = "starting"
    case staying       = "staying"
    case remembering   = "remembering"
    case emotions      = "emotions"
    case timeBlindness = "time_blindness"
    case allOfAbove    = "all"

    var label: String {
        switch self {
        case .starting:      return String(localized: "Starting Tasks")
        case .staying:       return String(localized: "Staying Focused")
        case .remembering:   return String(localized: "Remembering Things")
        case .emotions:      return String(localized: "Managing Emotions")
        case .timeBlindness: return String(localized: "Time Blindness")
        case .allOfAbove:    return String(localized: "All of the Above")
        }
    }

    var emoji: String {
        switch self {
        case .starting:      return "🧊"
        case .staying:       return "🎯"
        case .remembering:   return "🧠"
        case .emotions:      return "💙"
        case .timeBlindness: return "⏰"
        case .allOfAbove:    return "🐧"
        }
    }

    var icon: String {
        switch self {
        case .starting:      return "play.circle.fill"
        case .staying:       return "scope"
        case .remembering:   return "brain.fill"
        case .emotions:      return "heart.circle.fill"
        case .timeBlindness: return "clock.fill"
        case .allOfAbove:    return "circle.grid.3x3.fill"
        }
    }

    var description: String {
        switch self {
        case .starting:      return String(localized: "Getting unstuck when a task feels impossible to begin")
        case .staying:       return String(localized: "Staying with one thing before the brain wanders")
        case .remembering:   return String(localized: "Keeping track of what needs to happen when")
        case .emotions:      return String(localized: "RSD, frustration, overwhelm, emotional flooding")
        case .timeBlindness: return String(localized: "Losing track of time — always 'just one minute'")
        case .allOfAbove:    return String(localized: "A bit of everything — classic ADHD")
        }
    }

    var promptContext: String {
        switch self {
        case .starting:
            return "User's biggest challenge is task initiation. Always offer the tiniest possible first step. Body doubling suggestions are especially valuable. Never jump straight to the full task — ease in from the smallest action."
        case .staying:
            return "User struggles with sustained attention. Break tasks into short sprints. Suggest timers (5–10 min). Check in during longer sessions. Celebrate staying with something — that's genuinely hard."
        case .remembering:
            return "User has working memory challenges. Proactively recap what they were doing. Confirm task details before closing. Suggest externalizing reminders into the app immediately."
        case .emotions:
            return "User struggles with emotional regulation and RSD. Be extra validating. Never use 'should' or 'just'. When they express frustration about themselves, gently push back with warmth. Protect their self-esteem above all."
        case .timeBlindness:
            return "User struggles with time blindness. Add gentle time context to suggestions. Use time anchors ('before lunch', 'after dinner'). Warn softly before deadlines. Never shame lateness — time blindness is neurological."
        case .allOfAbove:
            return "User experiences the full ADHD challenge set. Use the complete support toolkit: micro-steps, emotional validation, time context, memory support, gentle accountability."
        }
    }
}

// MARK: - Nudgy Personality Mode

/// How Nudgy communicates — four distinct voice modes.
enum NudgyPersonalityMode: String, CaseIterable, Codable, Sendable {
    case gentle = "gentle"   // Default — warm, unhurried, Pooh energy
    case coach  = "coach"    // More direct, action-forward
    case silly  = "silly"    // Humor, puns, playful penguin chaos
    case quiet  = "quiet"    // Minimal dialogue — just presence

    var label: String {
        switch self {
        case .gentle: return String(localized: "Gentle Nudgy")
        case .coach:  return String(localized: "Coach Nudgy")
        case .silly:  return String(localized: "Silly Nudgy")
        case .quiet:  return String(localized: "Quiet Nudgy")
        }
    }

    var description: String {
        switch self {
        case .gentle: return String(localized: "Warm and unhurried — never pushes, always there")
        case .coach:  return String(localized: "Direct and action-forward — let's get it done")
        case .silly:  return String(localized: "Puns, humor, and classic penguin chaos energy")
        case .quiet:  return String(localized: "Mostly silent — a presence, not a narrator")
        }
    }

    var icon: String {
        switch self {
        case .gentle: return "heart.fill"
        case .coach:  return "flag.checkered.2.crossed"
        case .silly:  return "face.smiling.fill"
        case .quiet:  return "moon.fill"
        }
    }

    var accentColorHex: String {
        switch self {
        case .gentle: return "#4FC3F7"
        case .coach:  return "#FF9F0A"
        case .silly:  return "#30D158"
        case .quiet:  return "#636366"
        }
    }

    /// Prompt modifier appended to AI system prompt.
    var promptModifier: String {
        switch self {
        case .gentle:
            return ""   // Default voice — no modifier
        case .coach:
            return """
            PERSONALITY MODIFIER — COACH MODE:
            Be slightly more direct and action-oriented. Use gentle urgency: "Let's tackle this.", "What's the first step?", "You've been thinking about it — let's just do the opening move." Still warm and never harsh. But lean toward action.
            """
        case .silly:
            return """
            PERSONALITY MODIFIER — SILLY MODE:
            More penguin humor. Mild puns welcome. Self-aware jokes about being a bird with flippers. "I may be a penguin but I know procrastination when I see it 🐧". Keep it affectionate — humor should never feel mean or dismissive. Warmth is still underneath all the silliness.
            """
        case .quiet:
            return """
            PERSONALITY MODIFIER — QUIET MODE:
            Extremely brief. One sentence maximum — often just an emoji and a fragment. "Here 💙" instead of a full response. "Done. 🐧" instead of celebrating. User prefers to feel accompanied, not narrated. Fewer words = more presence.
            """
        }
    }
}
