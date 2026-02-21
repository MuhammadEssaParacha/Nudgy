//
//  NudgyWardrobe.swift
//  Nudge
//
//  SwiftData model for tracking unlocked and equipped accessories.
//  Also tracks fish (reward currency), streaks, and level.
//
//  One instance per user (singleton-style, fetched with a descriptor).
//  Created automatically on first app launch by RewardService.
//

import SwiftData
import SwiftUI

// MARK: - NudgyWardrobe Model

@Model
final class NudgyWardrobe {
    
    // MARK: Identity
    
    var id: UUID = UUID()
    
    // MARK: Reward Currency
    
    /// Fish — earned by completing tasks, spent on accessories.
    var fish: Int = 0
    
    /// Total fish earned all-time (never decremented — for level calculation).
    var lifetimeFish: Int = 0
    
    // MARK: Streaks
    
    /// Current consecutive-day streak.
    var currentStreak: Int = 0
    
    /// Longest streak ever achieved.
    var longestStreak: Int = 0
    
    /// The last date a task was completed (for streak calculation).
    var lastCompletionDateRaw: Date?
    
    // MARK: Unlocked Accessories
    
    /// Comma-separated IDs of unlocked accessories (SwiftData-safe string storage).
    /// e.g. "scarf-blue,beanie-red,sunglasses"
    var unlockedAccessoriesRaw: String = ""
    
    // MARK: Equipped Accessories
    
    /// Comma-separated IDs of currently equipped accessories.
    /// Max one per slot enforced by RewardService.
    var equippedAccessoriesRaw: String = ""
    
    // MARK: Unlocked Props
    
    /// Comma-separated IDs of environment props unlocked.
    /// e.g. "igloo,campfire"
    var unlockedPropsRaw: String = ""
    
    // MARK: Tank Decorations
    
    /// Comma-separated IDs of unlocked tank decorations.
    /// e.g. "deco-coral,deco-shell"
    var unlockedDecorationsRaw: String = ""
    
    /// Comma-separated IDs of currently placed (visible) tank decorations.
    var placedDecorationsRaw: String = ""
    
    // MARK: Stats
    
    /// Total tasks completed all-time.
    var totalTasksCompleted: Int = 0
    
    /// Tasks completed today (reset daily).
    var tasksCompletedToday: Int = 0
    
    /// Date of last daily reset.
    var lastDailyResetRaw: Date?
    
    // MARK: Streak Freeze
    
    /// Number of streak freezes available (earned from weekly all-clear)
    var streakFreezes: Int = 0
    
    /// Whether a freeze was used today (prevents double-use)
    var freezeUsedToday: Bool = false
    
    /// Last date a weekly freeze was earned
    var lastFreezeEarnedDate: Date?
    
    // MARK: Feeding
    
    /// Number of times fish were fed today.
    var fishFedToday: Int = 0
    
    /// Last date fish were fed (for daily reset).
    var lastFedDateRaw: Date?
    
    /// Consecutive days the user has fed fish (feeding streak).
    var feedingStreak: Int = 0
    
    /// Longest feeding streak ever.
    var longestFeedingStreak: Int = 0
    
    // MARK: Milestones
    
    /// Comma-separated milestone IDs already celebrated (e.g. "10,25,50,100")
    var celebratedMilestonesRaw: String = ""
    
    // MARK: Fish Economy
    
    /// JSON-encoded array of FishCatch records.
    var fishCatchesJSON: String = ""

    /// JSON-encoded [String: Int] mapping species rawValue → total catch count.
    var catchCountsJSON: String = ""

    /// Comma-separated "species:stageRaw" pairs already celebrated (e.g. "catfish:2,tropical:3").
    var celebratedEvolutionsRaw: String = ""
    
    /// Decoded fish catches (computed, not stored).
    var fishCatches: [FishCatch] {
        get {
            guard !fishCatchesJSON.isEmpty,
                  let data = fishCatchesJSON.data(using: .utf8),
                  let catches = try? JSONDecoder().decode([FishCatch].self, from: data) else {
                return []
            }
            return catches
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                fishCatchesJSON = json
            }
        }
    }
    
    /// Per-species total catch counts (decoded from JSON).
    var catchCounts: [String: Int] {
        get {
            guard !catchCountsJSON.isEmpty,
                  let data = catchCountsJSON.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                catchCountsJSON = json
            }
        }
    }

    /// Set of "species:stageRaw" strings that have already been celebrated.
    var celebratedEvolutions: Set<String> {
        get {
            Set(celebratedEvolutionsRaw.split(separator: ",").map(String.init))
                .filter { !$0.isEmpty }
        }
        set {
            celebratedEvolutionsRaw = newValue.sorted().joined(separator: ",")
        }
    }

    /// Increment catch count for a species and return the new total.
    @discardableResult
    func incrementCatchCount(for species: FishSpecies) -> Int {
        var counts = catchCounts
        let newCount = (counts[species.rawValue] ?? 0) + 1
        counts[species.rawValue] = newCount
        catchCounts = counts
        return newCount
    }

    /// Record a new fish catch.
    func addFishCatch(_ catch_: FishCatch) {
        var current = fishCatches
        current.append(catch_)
        // Keep only last 200 to avoid bloating
        if current.count > 200 {
            current = Array(current.suffix(200))
        }
        fishCatches = current
    }
    
    // MARK: Init
    
    init() {
        self.id = UUID()
        self.fish = 0
        self.lifetimeFish = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastCompletionDateRaw = nil
        self.unlockedAccessoriesRaw = ""
        self.equippedAccessoriesRaw = ""
        self.unlockedPropsRaw = ""
        self.unlockedDecorationsRaw = ""
        self.placedDecorationsRaw = ""
        self.totalTasksCompleted = 0
        self.tasksCompletedToday = 0
        self.lastDailyResetRaw = nil
        self.streakFreezes = 0
        self.freezeUsedToday = false
        self.lastFreezeEarnedDate = nil
        self.fishFedToday = 0
        self.lastFedDateRaw = nil
        self.feedingStreak = 0
        self.longestFeedingStreak = 0
        self.celebratedMilestonesRaw = ""
        self.fishCatchesJSON = ""
        self.catchCountsJSON = ""
        self.celebratedEvolutionsRaw = ""
    }
    
    // MARK: - Computed Properties
    
    /// Set of unlocked accessory IDs.
    var unlockedAccessories: Set<String> {
        get {
            Set(unlockedAccessoriesRaw.split(separator: ",").map(String.init))
                .filter { !$0.isEmpty }
        }
        set {
            unlockedAccessoriesRaw = newValue.sorted().joined(separator: ",")
        }
    }
    
    /// Set of currently equipped accessory IDs.
    var equippedAccessories: Set<String> {
        get {
            Set(equippedAccessoriesRaw.split(separator: ",").map(String.init))
                .filter { !$0.isEmpty }
        }
        set {
            equippedAccessoriesRaw = newValue.sorted().joined(separator: ",")
        }
    }
    
    /// Set of unlocked environment props.
    var unlockedProps: Set<String> {
        get {
            Set(unlockedPropsRaw.split(separator: ",").map(String.init))
                .filter { !$0.isEmpty }
        }
        set {
            unlockedPropsRaw = newValue.sorted().joined(separator: ",")
        }
    }
    
    /// Set of unlocked tank decoration IDs.
    var unlockedDecorations: Set<String> {
        get {
            Set(unlockedDecorationsRaw.split(separator: ",").map(String.init))
                .filter { !$0.isEmpty }
        }
        set {
            unlockedDecorationsRaw = newValue.sorted().joined(separator: ",")
        }
    }
    
    /// Set of currently placed (visible) tank decoration IDs.
    var placedDecorations: Set<String> {
        get {
            Set(placedDecorationsRaw.split(separator: ",").map(String.init))
                .filter { !$0.isEmpty }
        }
        set {
            placedDecorationsRaw = newValue.sorted().joined(separator: ",")
        }
    }
    
    /// Set of celebrated milestone counts (10, 25, 50, 100, etc.)
    var celebratedMilestones: Set<Int> {
        get {
            Set(celebratedMilestonesRaw.split(separator: ",").compactMap { Int($0) })
        }
        set {
            celebratedMilestonesRaw = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }
    
    /// Whether a streak freeze can be used today
    var canUseStreakFreeze: Bool {
        streakFreezes > 0 && !freezeUsedToday
    }
    
    /// Current level based on lifetime fish earned.
    var level: Int {
        // Level thresholds: 0, 10, 30, 60, 100, 150, 210, 280, 360, 450...
        // Formula: level n requires n*(n+1)/2 * 10 fish
        var lvl = 0
        var threshold = 0
        while threshold <= lifetimeFish {
            lvl += 1
            threshold += lvl * 10
        }
        return max(1, lvl)
    }
    
    /// Fish needed for the next level.
    var fishForNextLevel: Int {
        var threshold = 0
        for n in 1...(level + 1) {
            threshold += n * 10
        }
        return threshold
    }
    
    /// Progress toward next level (0.0–1.0).
    var levelProgress: Double {
        let currentLevelThreshold: Int = {
            var t = 0
            for n in 1...level {
                t += n * 10
            }
            return t
        }()
        let nextLevelThreshold = fishForNextLevel
        let range = nextLevelThreshold - currentLevelThreshold
        guard range > 0 else { return 0 }
        let progress = lifetimeFish - currentLevelThreshold
        return min(1.0, max(0, Double(progress) / Double(range)))
    }
    
    /// Environment mood based on tasks completed today.
    var environmentMood: EnvironmentMood {
        // Check daily reset first
        resetDailyIfNeeded()
        
        if tasksCompletedToday == 0 {
            return .cold
        } else if tasksCompletedToday <= 2 {
            return .warming
        } else {
            return .productive
        }
        // Note: .golden and .stormy are set contextually by RewardService
    }
    
    // MARK: - Daily Reset
    
    private func resetDailyIfNeeded() {
        let calendar = Calendar.current
        if let last = lastDailyResetRaw, calendar.isDateInToday(last) {
            return // Already reset today
        }
        tasksCompletedToday = 0
        lastDailyResetRaw = .now
    }
}
