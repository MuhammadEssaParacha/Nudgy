//
//  UserPersona.swift
//  Nudge
//
//  Defines the high-level user persona that shapes Nudgy's
//  language, suggestions, and feature emphasis.
//

import Foundation

/// High-level persona describing how the user wants Nudgy to help.
/// Distinct from NudgyPersonalityMode (tone) — this is about *focus area*.
enum UserPersona: String, CaseIterable, Codable, Sendable, Hashable {
    case adhd       = "adhd"
    case student    = "student"
    case creative   = "creative"
    case parent     = "parent"
    case general    = "general"

    var label: String {
        switch self {
        case .adhd:     return String(localized: "ADHD Brain")
        case .student:  return String(localized: "Student Mode")
        case .creative: return String(localized: "Creative Flow")
        case .parent:   return String(localized: "Busy Parent")
        case .general:  return String(localized: "Just Organized")
        }
    }

    var description: String {
        switch self {
        case .adhd:     return String(localized: "Gentle nudges, micro-steps, and understanding for the ADHD brain")
        case .student:  return String(localized: "Study sessions, deadlines, and school-life balance")
        case .creative: return String(localized: "Flexible flow, idea capture, and creative momentum")
        case .parent:   return String(localized: "Family logistics, self-care reminders, and juggling everything")
        case .general:  return String(localized: "Clean task management with a friendly penguin companion")
        }
    }

    var icon: String {
        switch self {
        case .adhd:     return "brain.head.profile.fill"
        case .student:  return "graduationcap.fill"
        case .creative: return "paintpalette.fill"
        case .parent:   return "figure.and.child.holdinghands"
        case .general:  return "checklist"
        }
    }

    var accentColorHex: String {
        switch self {
        case .adhd:     return "#4FC3F7"
        case .student:  return "#FF9F0A"
        case .creative: return "#BF5AF2"
        case .parent:   return "#30D158"
        case .general:  return "#636366"
        }
    }
}
