//
//  RewardService.swift
//  Nudge
//
//  Manages the reward loop: earning fish, unlocking accessories,
//  tracking streaks, and updating environment mood.
//
//  Singleton via RewardService.shared. Requires a ModelContext to operate
//  (passed per-call, same pattern as NudgeRepository).
//
//  Call flow:
//    Task completed → RewardService.shared.recordCompletion(context:)
//    Buy accessory  → RewardService.shared.unlock(accessoryID:context:)
//    Equip/unequip  → RewardService.shared.equip(accessoryID:context:)
//

import SwiftData
import SwiftUI
import os

// MARK: - Reward Constants

nonisolated enum RewardConstants {
    /// Fish earned per task completed.
    static let fishPerTask: Int = 2
    
    /// Bonus fish for clearing ALL tasks.
    static let allClearBonus: Int = 5
    
    /// Streak multiplier kicks in at this many consecutive days.
    static let streakMultiplierThreshold: Int = 3
    
    /// Streak multiplier: 2× fish after 3+ day streak.
    static let streakMultiplier: Int = 2
    
    /// Notification posted when fish count changes (for UI refresh).
    static let fishChangedNotification = Notification.Name("nudgeFishChanged")
    
    /// Notification posted when an accessory is unlocked.
    static let accessoryUnlockedNotification = Notification.Name("nudgeAccessoryUnlocked")
    
    /// Notification posted when a daily challenge is completed.
    static let challengeCompletedNotification = Notification.Name("nudgeChallengeCompleted")
}

// MARK: - Unlock Result

enum UnlockResult {
    case success(accessoryID: String, remainingFish: Int)
    case alreadyUnlocked
    case insufficientFish(have: Int, need: Int)
    case notFound
}

// MARK: - RewardService

@Observable
final class RewardService {
    
    static let shared = RewardService()
    
    // MARK: - Published State (for UI binding)
    
    /// Current fish count (mirrors wardrobe, updated on every mutation).
    private(set) var fish: Int = 0
    
    /// Currently equipped accessory IDs (mirrors wardrobe).
    private(set) var equippedAccessories: Set<String> = []
    
    /// All unlocked accessory IDs (mirrors wardrobe).
    private(set) var unlockedAccessories: Set<String> = []
    
    /// Unlocked environment props.
    private(set) var unlockedProps: Set<String> = []
    
    /// Current streak.
    private(set) var currentStreak: Int = 0
    
    /// Current level.
    private(set) var level: Int = 1
    
    /// Progress toward next level (0.0–1.0).
    private(set) var levelProgress: Double = 0
    
    /// Tasks completed today.
    private(set) var tasksCompletedToday: Int = 0
    
    /// Environment mood based on today's productivity.
    private(set) var environmentMood: EnvironmentMood = .cold
    
    /// The stage tier BEFORE the last level-up (for detecting tier changes).
    private(set) var previousStage: StageTier = .bareIce
    
    /// Set to the new tier when a stage-up happens (nil if no recent stage-up).
    private(set) var pendingStageUp: StageTier? = nil
    
    /// Today's daily challenges.
    private(set) var dailyChallenges: [DailyChallenge] = []
    
    /// Fish catches (for aquarium display).
    private(set) var fishCatches: [FishCatch] = []

    /// Total catches per species (drives evolution stage).
    private(set) var catchCountsPerSpecies: [String: Int] = [:]

    /// Set when a fish just evolved — consumed by the celebration overlay.
    private(set) var pendingEvolution: (species: FishSpecies, stage: FishEvolutionStage)? = nil
    
    // MARK: - Private Helpers
    
    /// Save context with error logging — never silently swallow data loss.
    private func safeSave(_ context: ModelContext, label: String = "RewardService") {
        do {
            try context.save()
        } catch {
            Log.services.error("[\(label)] Failed to save: \(error, privacy: .public)")
        }
    }
    
    /// The most recent fish catch (for animation).
    private(set) var lastFishCatch: FishCatch? = nil
    
    /// Clear the last fish catch after it's been consumed by the ceremony overlay.
    func clearLastFishCatch() {
        lastFishCatch = nil
    }
    
    /// Unlocked tank decoration IDs.
    private(set) var unlockedDecorations: Set<String> = []
    
    /// Currently placed (visible) tank decoration IDs.
    private(set) var placedDecorations: Set<String> = []
    
    /// Times fish were fed today.
    private(set) var fishFedToday: Int = 0
    
    /// Consecutive days of feeding fish.
    private(set) var feedingStreak: Int = 0
    
    /// Longest feeding streak ever.
    private(set) var longestFeedingStreak: Int = 0
    
    /// Fish happiness level (0.0–1.0) based on feeding today.
    var fishHappiness: Double {
        min(Double(fishFedToday) / 3.0, 1.0)
    }
    
    /// Date the current set of daily challenges was generated.
    private var challengeDate: Date? = nil
    
    private init() {}
    
    // MARK: - Bootstrap
    
    /// Load or create the wardrobe on app launch. Call from NudgeApp.bootstrap().
    func bootstrap(context: ModelContext) {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        syncState(from: wardrobe)
    }
    
    // MARK: - Task Completion Reward
    
    /// Record a task completion — earn fish, update streak, etc.
    /// Pass the completed item to earn species-appropriate fish.
    /// Returns the number of fish earned (for UI animation).
    @discardableResult
    func recordCompletion(context: ModelContext, item: NudgeItem? = nil, isAllClear: Bool = false) -> Int {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        
        // Update streak
        updateStreak(wardrobe: wardrobe)
        
        // Fish economy: determine species and reward
        let species: FishSpecies
        if let item {
            species = FishEconomy.speciesForTask(item)
        } else {
            species = .catfish
        }
        
        // Calculate fish via fish economy
        var earned = FishEconomy.fishForCatch(
            species: species,
            streak: wardrobe.currentStreak,
            isAllClear: isAllClear
        )
        
        // Record the fish catch
        if let item {
            let fishCatch = FishCatch(
                species: species,
                taskContent: item.content,
                taskEmoji: item.emoji ?? "checklist"
            )
            wardrobe.addFishCatch(fishCatch)
            lastFishCatch = fishCatch

            // Evolution check — increment count, check threshold crossing
            let prevCount = (wardrobe.catchCounts[species.rawValue] ?? 0)
            let newCount = wardrobe.incrementCatchCount(for: species)
            let prevStage = FishEvolutionStage.stage(for: species, catchCount: prevCount)
            let newStage  = FishEvolutionStage.stage(for: species, catchCount: newCount)
            if newStage > prevStage {
                let key = "\(species.rawValue):\(newStage.rawValue)"
                if !wardrobe.celebratedEvolutions.contains(key) {
                    var celebrated = wardrobe.celebratedEvolutions
                    celebrated.insert(key)
                    wardrobe.celebratedEvolutions = celebrated
                    pendingEvolution = (species: species, stage: newStage)
                    NotificationCenter.default.post(name: .nudgeFishEvolved, object: pendingEvolution)
                }
            }
        }
        
        // Credit fish
        wardrobe.fish += earned
        wardrobe.lifetimeFish += earned
        wardrobe.totalTasksCompleted += 1
        wardrobe.tasksCompletedToday += 1
        
        // Detect stage tier change
        let oldStage = StageTier.from(level: level)
        
        // Save and sync
        safeSave(context, label: "recordCompletion")
        syncState(from: wardrobe)
        
        // Check streak milestone bonus (3, 7, 14, 30 day rewards)
        let streakBonus = checkStreakMilestoneBonus(context: context)
        earned += streakBonus
        
        let newStage = StageTier.from(level: wardrobe.level)
        if newStage.rawValue > oldStage.rawValue {
            previousStage = oldStage
            pendingStageUp = newStage
            NotificationCenter.default.post(name: .nudgeStageUp, object: newStage)
        }
        
        // Update daily challenges
        updateChallengeProgress(tasksToday: wardrobe.tasksCompletedToday, isAllClear: isAllClear, completedCategoryRaw: item?.categoryRaw)
        
        NotificationCenter.default.post(name: RewardConstants.fishChangedNotification, object: nil)
        
        return earned
    }
    
    // MARK: - Unlock Accessory
    
    /// Attempt to unlock an accessory. Deducts fish if successful.
    func unlock(accessoryID: String, context: ModelContext) -> UnlockResult {
        guard AccessoryCatalog.item(for: accessoryID) != nil else {
            return .notFound
        }
        
        let wardrobe = fetchOrCreateWardrobe(context: context)
        
        // Already unlocked?
        if wardrobe.unlockedAccessories.contains(accessoryID) {
            return .alreadyUnlocked
        }
        
        let cost = AccessoryCatalog.cost(for: accessoryID)
        
        // Can afford?
        guard wardrobe.fish >= cost else {
            return .insufficientFish(have: wardrobe.fish, need: cost)
        }
        
        // Deduct and unlock
        wardrobe.fish -= cost
        var unlocked = wardrobe.unlockedAccessories
        unlocked.insert(accessoryID)
        wardrobe.unlockedAccessories = unlocked
        
        safeSave(context, label: "unlockAccessory")
        syncState(from: wardrobe)
        
        NotificationCenter.default.post(
            name: RewardConstants.accessoryUnlockedNotification,
            object: accessoryID
        )
        
        return .success(accessoryID: accessoryID, remainingFish: wardrobe.fish)
    }
    
    // MARK: - Equip / Unequip
    
    /// Toggle equipping an accessory. Enforces one-per-slot.
    func toggleEquip(accessoryID: String, context: ModelContext) {
        guard let item = AccessoryCatalog.item(for: accessoryID) else { return }
        
        let wardrobe = fetchOrCreateWardrobe(context: context)
        var equipped = wardrobe.equippedAccessories
        
        if equipped.contains(accessoryID) {
            // Unequip
            equipped.remove(accessoryID)
        } else {
            // Unequip any existing item in the same slot
            let sameSlotItems = equipped.filter { id in
                AccessoryCatalog.item(for: id)?.slot == item.slot
            }
            for existing in sameSlotItems {
                equipped.remove(existing)
            }
            
            // Equip the new item
            equipped.insert(accessoryID)
        }
        
        wardrobe.equippedAccessories = equipped
        safeSave(context, label: "equipAccessory")
        syncState(from: wardrobe)
    }
    
    // MARK: - Environment Mood
    
    /// Get the environment mood considering both today's tasks and overdue state.
    func computeMood(tasksCompletedToday: Int, hasOverdue: Bool, isAllClear: Bool) -> EnvironmentMood {
        if hasOverdue {
            return .stormy
        }
        if isAllClear && tasksCompletedToday > 0 {
            return .golden
        }
        if tasksCompletedToday >= 3 {
            return .productive
        }
        if tasksCompletedToday > 0 {
            return .warming
        }
        return .cold
    }
    
    /// Update the mood and sync to state.
    func updateMood(context: ModelContext, hasOverdue: Bool = false, isAllClear: Bool = false) {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        environmentMood = computeMood(
            tasksCompletedToday: wardrobe.tasksCompletedToday,
            hasOverdue: hasOverdue,
            isAllClear: isAllClear
        )
    }
    
    // MARK: - Streak Management
    
    private func updateStreak(wardrobe: NudgyWardrobe) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        if let lastDate = wardrobe.lastCompletionDateRaw {
            let lastDay = calendar.startOfDay(for: lastDate)
            
            if lastDay == today {
                // Already completed today — streak unchanged
                return
            }
            
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysDiff == 1 {
                // Consecutive day — extend streak
                wardrobe.currentStreak += 1
            } else if daysDiff == 2 && wardrobe.canUseStreakFreeze {
                // Missed one day — use streak freeze to save streak
                wardrobe.currentStreak += 1
                wardrobe.streakFreezes -= 1
                wardrobe.freezeUsedToday = true
            } else {
                // Gap too large — reset streak
                wardrobe.currentStreak = 1
            }
        } else {
            // First ever completion
            wardrobe.currentStreak = 1
        }
        
        wardrobe.lastCompletionDateRaw = .now
        wardrobe.longestStreak = max(wardrobe.longestStreak, wardrobe.currentStreak)
        
        // Award streak freeze every 7-day streak
        if wardrobe.currentStreak > 0 && wardrobe.currentStreak % 7 == 0 {
            let today = calendar.startOfDay(for: Date())
            if wardrobe.lastFreezeEarnedDate == nil || !calendar.isDate(wardrobe.lastFreezeEarnedDate!, inSameDayAs: today) {
                wardrobe.streakFreezes = min(wardrobe.streakFreezes + 1, 3) // Max 3 freezes
                wardrobe.lastFreezeEarnedDate = today
            }
        }
    }
    
    // MARK: - Data Access
    
    /// Fetch the single wardrobe record, creating one if it doesn't exist.
    private func fetchOrCreateWardrobe(context: ModelContext) -> NudgyWardrobe {
        let descriptor = FetchDescriptor<NudgyWardrobe>()
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // First launch — create wardrobe
        let wardrobe = NudgyWardrobe()
        context.insert(wardrobe)
        safeSave(context, label: "createWardrobe")
        return wardrobe
    }
    
    /// Sync observable state from the wardrobe model.
    /// Only writes properties that actually changed to avoid unnecessary view invalidations.
    private func syncState(from wardrobe: NudgyWardrobe) {
        if fish != wardrobe.fish { fish = wardrobe.fish }
        if equippedAccessories != wardrobe.equippedAccessories { equippedAccessories = wardrobe.equippedAccessories }
        if unlockedAccessories != wardrobe.unlockedAccessories { unlockedAccessories = wardrobe.unlockedAccessories }
        if unlockedProps != wardrobe.unlockedProps { unlockedProps = wardrobe.unlockedProps }
        if currentStreak != wardrobe.currentStreak { currentStreak = wardrobe.currentStreak }
        if level != wardrobe.level { level = wardrobe.level }
        if levelProgress != wardrobe.levelProgress { levelProgress = wardrobe.levelProgress }
        if tasksCompletedToday != wardrobe.tasksCompletedToday { tasksCompletedToday = wardrobe.tasksCompletedToday }
        if environmentMood != wardrobe.environmentMood { environmentMood = wardrobe.environmentMood }
        if fishCatches != wardrobe.fishCatches { fishCatches = wardrobe.fishCatches }
        if catchCountsPerSpecies != wardrobe.catchCounts { catchCountsPerSpecies = wardrobe.catchCounts }
        if unlockedDecorations != wardrobe.unlockedDecorations { unlockedDecorations = wardrobe.unlockedDecorations }
        if placedDecorations != wardrobe.placedDecorations { placedDecorations = wardrobe.placedDecorations }
        if fishFedToday != wardrobe.fishFedToday { fishFedToday = wardrobe.fishFedToday }
        if feedingStreak != wardrobe.feedingStreak { feedingStreak = wardrobe.feedingStreak }
        if longestFeedingStreak != wardrobe.longestFeedingStreak { longestFeedingStreak = wardrobe.longestFeedingStreak }
        
        // Regenerate challenges if new day
        regenerateChallengesIfNeeded()
    }
    
    // MARK: - Feeding
    
    /// Record a fish feeding. Awards bonus fish for feeding streaks.
    /// Returns fish earned from feeding bonus (0 if none).
    @discardableResult
    func recordFeeding(context: ModelContext) -> Int {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        // Reset daily counter if new day
        if let lastFed = wardrobe.lastFedDateRaw {
            let lastFedDay = calendar.startOfDay(for: lastFed)
            if lastFedDay != today {
                wardrobe.fishFedToday = 0
                
                // Update feeding streak
                let daysDiff = calendar.dateComponents([.day], from: lastFedDay, to: today).day ?? 0
                if daysDiff == 1 {
                    wardrobe.feedingStreak += 1
                } else if daysDiff > 1 {
                    wardrobe.feedingStreak = 1
                }
            }
        } else {
            // First ever feed
            wardrobe.feedingStreak = 1
        }
        
        wardrobe.fishFedToday += 1
        wardrobe.lastFedDateRaw = .now
        wardrobe.longestFeedingStreak = max(wardrobe.longestFeedingStreak, wardrobe.feedingStreak)
        
        // Streak bonus fish
        var bonus = 0
        
        // First feed of the day: streak milestone bonus
        if wardrobe.fishFedToday == 1 {
            if wardrobe.feedingStreak >= 7 {
                bonus = 5  // 7+ day feeding streak: +5 🐟
            } else if wardrobe.feedingStreak >= 3 {
                bonus = 2  // 3+ day feeding streak: +2 🐟
            }
        }
        
        // Feed 3 times in a day bonus
        if wardrobe.fishFedToday == 3 {
            bonus += 3  // Full belly bonus: +3 🐟
        }
        
        if bonus > 0 {
            wardrobe.fish += bonus
            wardrobe.lifetimeFish += bonus
        }
        
        safeSave(context, label: "feedFish")
        syncState(from: wardrobe)
        
        if bonus > 0 {
            NotificationCenter.default.post(name: RewardConstants.fishChangedNotification, object: nil)
        }
        
        return bonus
    }
    
    /// Fish bonus description for current feeding streak.
    var feedingStreakBonusLabel: String? {
        if feedingStreak >= 7 {
            return String(localized: "+5 per day (7-day feeding streak!)")
        } else if feedingStreak >= 3 {
            return String(localized: "+2 per day (3-day feeding streak)")
        }
        return nil
    }
    
    // MARK: - Streak Fish Milestones
    
    /// Fish bonus for task completion streak milestones.
    /// Called after streak is updated in recordCompletion.
    func checkStreakMilestoneBonus(context: ModelContext) -> Int {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        let streak = wardrobe.currentStreak
        var bonus = 0
        
        // Streak milestones: 3, 7, 14, 30 days
        let milestones: [(Int, Int)] = [(3, 5), (7, 15), (14, 30), (30, 75)]
        for (milestone, reward) in milestones {
            if streak == milestone {
                bonus = reward
                break
            }
        }
        
        if bonus > 0 {
            wardrobe.fish += bonus
            wardrobe.lifetimeFish += bonus
            safeSave(context, label: "streakMilestone")
            syncState(from: wardrobe)
        }
        
        return bonus
    }
    
    // MARK: - Tank Decorations
    
    /// Unlock a tank decoration by spending fish.
    func unlockDecoration(_ decoID: String, cost: Int, context: ModelContext) {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        guard wardrobe.fish >= cost else { return }
        guard !wardrobe.unlockedDecorations.contains(decoID) else { return }
        
        wardrobe.fish -= cost
        var unlocked = wardrobe.unlockedDecorations
        unlocked.insert(decoID)
        wardrobe.unlockedDecorations = unlocked
        
        // Auto-place when bought
        var placed = wardrobe.placedDecorations
        placed.insert(decoID)
        wardrobe.placedDecorations = placed
        
        safeSave(context, label: "unlockDecoration")
        syncState(from: wardrobe)
    }
    
    /// Toggle a decoration's placement in the tank.
    func toggleDecoration(_ decoID: String, context: ModelContext) {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        var placed = wardrobe.placedDecorations
        if placed.contains(decoID) {
            placed.remove(decoID)
        } else {
            placed.insert(decoID)
        }
        wardrobe.placedDecorations = placed
        safeSave(context, label: "toggleDecoration")
        syncState(from: wardrobe)
    }
    
    // MARK: - Stage Up
    
    /// Acknowledge the stage-up celebration was shown.
    func acknowledgeStageUp() {
        pendingStageUp = nil
    }

    /// Acknowledge the fish evolution celebration was shown.
    func acknowledgePendingEvolution() {
        pendingEvolution = nil
    }
    
    // MARK: - Daily Challenges
    
    /// Regenerate daily challenges if the date has changed.
    private func regenerateChallengesIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        
        if challengeDate != today {
            // Phase 10: Determine top active category for category challenges
            var topCat: TaskCategory? = nil
            if let container = IntentModelAccess.makeContainer() {
                let context = container.mainContext
                let repo = NudgeRepository(modelContext: context)
                let active = repo.fetchActiveQueue()
                let catCounts = Dictionary(grouping: active, by: { $0.resolvedCategory }).mapValues(\.count)
                topCat = catCounts.filter({ $0.key != .general }).max(by: { $0.value < $1.value })?.key
            }
            
            dailyChallenges = ChallengeGenerator.generateDaily(
                level: level,
                streak: currentStreak,
                topCategory: topCat
            )
            challengeDate = today
        }
    }
    
    /// Update challenge progress after a task completion.
    private func updateChallengeProgress(tasksToday: Int, isAllClear: Bool, completedCategoryRaw: String? = nil) {
        var anyCompleted = false
        
        for i in dailyChallenges.indices {
            guard !dailyChallenges[i].isCompleted else { continue }
            
            var completed = false
            
            switch dailyChallenges[i].requirement {
            case .completeTasks(let count):
                completed = tasksToday >= count
            case .clearAll:
                completed = isAllClear
            case .maintainStreak:
                completed = currentStreak > 0
            case .completeBeforeNoon:
                let hour = Calendar.current.component(.hour, from: .now)
                completed = hour < 12
            case .brainDump:
                break  // Set externally via completeBrainDumpChallenge()
            case .completeCategory(let rawValue, _):
                // Phase 10: Category-specific challenge
                if let catRaw = completedCategoryRaw, catRaw == rawValue {
                    completed = true
                }
            }
            
            if completed {
                dailyChallenges[i].isCompleted = true
                anyCompleted = true
            }
        }
        
        if anyCompleted {
            NotificationCenter.default.post(
                name: RewardConstants.challengeCompletedNotification,
                object: nil
            )
        }
    }
    
    /// Mark the brain dump challenge as completed (called from brain dump flow).
    func completeBrainDumpChallenge(context: ModelContext) {
        guard let idx = dailyChallenges.firstIndex(where: { $0.id == "brain-dump" && !$0.isCompleted }) else { return }
        
        dailyChallenges[idx].isCompleted = true
        
        // Award bonus fish
        let wardrobe = fetchOrCreateWardrobe(context: context)
        wardrobe.fish += dailyChallenges[idx].bonusFish
        wardrobe.lifetimeFish += dailyChallenges[idx].bonusFish
        safeSave(context, label: "brainDumpChallenge")
        syncState(from: wardrobe)
        
        NotificationCenter.default.post(
            name: RewardConstants.challengeCompletedNotification,
            object: nil
        )
    }
    
    /// Award bonus fish for completed challenges. Call after showing challenge-complete UI.
}
