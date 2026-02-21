//
//  MoodEntry.swift
//  Nudge
//
//  Tracks daily mood check-ins for insight correlation.
//  Nudgy presents a simple mood card; data is stored here
//  and correlated with task completion for insights.
//

import SwiftData
import SwiftUI

// MARK: - Mood Level

enum MoodLevel: Int, Codable, CaseIterable {
    case awful     = 1
    case rough     = 2
    case okay      = 3
    case good      = 4
    case great     = 5
    
    /// SF Symbol icon for mood display.
    var icon: String {
        switch self {
        case .awful: return "cloud.bolt.rain.fill"
        case .rough: return "cloud.drizzle.fill"
        case .okay:  return "cloud.fill"
        case .good:  return "sun.max.fill"
        case .great: return "sparkles"
        }
    }
    
    /// Deprecated — use `icon` + `color` for rendering.
    var emoji: String {
        switch self {
        case .awful: return "😫"
        case .rough: return "😔"
        case .okay:  return "😐"
        case .good:  return "😊"
        case .great: return "🤩"
        }
    }
    
    var label: String {
        switch self {
        case .awful: return String(localized: "Awful")
        case .rough: return String(localized: "Rough")
        case .okay:  return String(localized: "Okay")
        case .good:  return String(localized: "Good")
        case .great: return String(localized: "Great")
        }
    }
    
    var color: Color {
        switch self {
        case .awful: return Color(hex: "FF453A")
        case .rough: return Color(hex: "FF9F0A")
        case .okay:  return Color(hex: "FFD60A")
        case .good:  return Color(hex: "30D158")
        case .great: return Color(hex: "5AC8FA")
        }
    }
}

// MARK: - MoodEntry Model

@Model
final class MoodEntry {
    
    var id: UUID
    
    /// Mood level (1-5)
    var moodLevelRaw: Int
    
    /// Optional note (what's on your mind?)
    var note: String?
    
    /// When the mood was logged
    var loggedAt: Date
    
    /// Number of tasks completed that day (captured at log time for correlation)
    var tasksCompletedThatDay: Int
    
    /// Energy level at time of check-in
    var energyRaw: String?
    
    init(
        mood: MoodLevel,
        note: String? = nil,
        tasksCompleted: Int = 0,
        energy: EnergyLevel? = nil
    ) {
        self.id = UUID()
        self.moodLevelRaw = mood.rawValue
        self.note = note
        self.loggedAt = Date()
        self.tasksCompletedThatDay = tasksCompleted
        self.energyRaw = energy?.rawValue
    }
    
    // MARK: Computed
    
    var moodLevel: MoodLevel {
        get { MoodLevel(rawValue: moodLevelRaw) ?? .okay }
        set { moodLevelRaw = newValue.rawValue }
    }
    
    /// Alias for moodLevel — used by views like MoodInsightsView
    var mood: MoodLevel {
        get { moodLevel }
        set { moodLevel = newValue }
    }
    
    var energy: EnergyLevel? {
        get { energyRaw.flatMap { EnergyLevel(rawValue: $0) } }
        set { energyRaw = newValue?.rawValue }
    }
}
