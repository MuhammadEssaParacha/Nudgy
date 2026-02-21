//
//  TomorrowPlanStore.swift
//  Nudge
//
//  Lightweight UserDefaults-backed store for the Plan Tomorrow feature.
//  No SwiftData, no AppSettings coupling — completely standalone.
//
//  Lifecycle:
//    - User completes the Plan Tomorrow ritual tonight → store is written
//    - Tomorrow morning the You page reads it and shows a TomorrowCard
//    - After 2pm the next day, `isFreshForMorning` goes false → card fades
//    - Starting the ritual again clears and rewrites the store
//

import SwiftUI

// MARK: - Energy Mode

/// The energy/pace the user wants for tomorrow.
/// Drives TomorrowCard accent color and Nudgy's framing copy.
enum TomorrowEnergyMode: String, CaseIterable {
    case deepFocus  = "deepFocus"
    case moveFast   = "moveFast"
    case easyStart  = "easyStart"

    var label: String {
        switch self {
        case .deepFocus:  return String(localized: "Deep Focus")
        case .moveFast:   return String(localized: "Move Fast")
        case .easyStart:  return String(localized: "Easy Start")
        }
    }

    var subtitle: String {
        switch self {
        case .deepFocus:  return String(localized: "Long stretches, fewer distractions")
        case .moveFast:   return String(localized: "Lots of small wins, keep the momentum")
        case .easyStart:  return String(localized: "Start gentle, build as you go")
        }
    }

    var icon: String {
        switch self {
        case .deepFocus:  return "brain.head.profile.fill"
        case .moveFast:   return "bolt.fill"
        case .easyStart:  return "leaf.fill"
        }
    }

    /// Accent color for the TomorrowCard
    var accentColor: Color {
        switch self {
        case .deepFocus:  return Color(hex: "5E5CE6")   // indigo — concentration
        case .moveFast:   return Color(hex: "FF9F0A")   // amber — energy
        case .easyStart:  return Color(hex: "30D158")   // green — calm start
        }
    }
}

// MARK: - TomorrowPlanStore

/// Single source of truth for the user's evening plan.
/// Singleton — accessed via `TomorrowPlanStore.shared`.
@MainActor @Observable
final class TomorrowPlanStore {

    static let shared = TomorrowPlanStore()
    private init() { load() }

    // MARK: - Stored State

    /// The one thing the user committed to for tomorrow. nil = no plan set.
    private(set) var intentionText: String = ""

    /// The energy mode chosen for tomorrow.
    private(set) var energyMode: TomorrowEnergyMode = .easyStart

    /// IDs of tasks the user carried forward (max 3).
    private(set) var carryForwardIDs: [String] = []

    /// When the plan was made (nil = never planned).
    private(set) var planDate: Date? = nil

    // MARK: - Computed

    /// True while it's still the same day the plan was made (evening planning window).
    var isPlannedForTonight: Bool {
        guard let planDate else { return false }
        return Calendar.current.isDateInToday(planDate)
    }

    /// True the morning after planning, until 2pm — this is when the TomorrowCard shows.
    var isFreshForMorning: Bool {
        guard let planDate else { return false }
        let cal = Calendar.current
        // Was planned yesterday
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date())),
              cal.isDate(planDate, inSameDayAs: yesterday) else { return false }
        // It's before 2pm today
        let hour = cal.component(.hour, from: Date())
        return hour < 14
    }

    /// True if a valid plan exists (has intention text).
    var hasPlan: Bool {
        !intentionText.trimmingCharacters(in: .whitespaces).isEmpty && planDate != nil
    }

    // MARK: - Write

    func savePlan(intention: String, energy: TomorrowEnergyMode, carryForwardIDs: [String]) {
        self.intentionText   = intention
        self.energyMode      = energy
        self.carryForwardIDs = Array(carryForwardIDs.prefix(3))
        self.planDate        = Date()
        persist()
    }

    func clearPlan() {
        intentionText   = ""
        energyMode      = .easyStart
        carryForwardIDs = []
        planDate        = nil
        persist()
    }

    // MARK: - Persistence

    private enum Keys {
        static let intention     = "tp_intention"
        static let energyMode    = "tp_energyMode"
        static let carryForwards = "tp_carryForwards"
        static let planDate      = "tp_planDate"
    }

    private func persist() {
        let ud = UserDefaults.standard
        ud.set(intentionText, forKey: Keys.intention)
        ud.set(energyMode.rawValue, forKey: Keys.energyMode)
        ud.set(carryForwardIDs, forKey: Keys.carryForwards)
        ud.set(planDate, forKey: Keys.planDate)
    }

    private func load() {
        let ud = UserDefaults.standard
        intentionText   = ud.string(forKey: Keys.intention) ?? ""
        energyMode      = TomorrowEnergyMode(rawValue: ud.string(forKey: Keys.energyMode) ?? "") ?? .easyStart
        carryForwardIDs = ud.stringArray(forKey: Keys.carryForwards) ?? []
        planDate        = ud.object(forKey: Keys.planDate) as? Date
    }
}
