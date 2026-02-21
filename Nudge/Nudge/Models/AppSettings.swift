//
//  AppSettings.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

/// Lightweight settings stored in UserDefaults (not SwiftData).
/// No migrations, no model container complexity.
@Observable
final class AppSettings {

    /// Set by the app after authentication so user-specific settings are isolated per account.
    /// Not persisted directly; it’s derived from the active signed-in user.
    var activeUserID: String?

    private func scopedKey(_ base: String) -> String {
        guard let activeUserID, !activeUserID.isEmpty else { return base }
        return "\(activeUserID):\(base)"
    }
    
    // MARK: - Quiet Hours
    
    var quietHoursStart: Int {
        get { UserDefaults.standard.object(forKey: "quietHoursStart") as? Int ?? 21 }
        set { UserDefaults.standard.set(newValue, forKey: "quietHoursStart") }
    }
    
    var quietHoursEnd: Int {
        get { UserDefaults.standard.object(forKey: "quietHoursEnd") as? Int ?? 8 }
        set { UserDefaults.standard.set(newValue, forKey: "quietHoursEnd") }
    }
    
    // MARK: - Notifications
    
    var maxDailyNudges: Int {
        get { UserDefaults.standard.object(forKey: "maxDailyNudges") as? Int ?? 3 }
        set { UserDefaults.standard.set(newValue, forKey: "maxDailyNudges") }
    }
    
    // MARK: - Live Activity
    
    var liveActivityEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "liveActivityEnabled") }
    }
    
    var liveActivityPromptShown: Bool {
        get { UserDefaults.standard.bool(forKey: "liveActivityPromptShown") }
        set { UserDefaults.standard.set(newValue, forKey: "liveActivityPromptShown") }
    }
    
    // MARK: - Subscription
    
    var isPro: Bool {
        get { UserDefaults.standard.bool(forKey: "isPro") }
        set { UserDefaults.standard.set(newValue, forKey: "isPro") }
    }
    
    // MARK: - Usage Tracking (Free Tier Limits)
    
    var dailyDumpsUsed: Int {
        get { UserDefaults.standard.integer(forKey: scopedKey("dailyDumpsUsed")) }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("dailyDumpsUsed")) }
    }
    
    var dailyDumpsResetDate: Date {
        get {
            (UserDefaults.standard.object(forKey: scopedKey("dailyDumpsResetDate")) as? Date) ?? .distantPast
        }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("dailyDumpsResetDate")) }
    }
    
    var savedItemsCount: Int {
        get { UserDefaults.standard.integer(forKey: scopedKey("savedItemsCount")) }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("savedItemsCount")) }
    }
    
    // MARK: - Smart Resurfacing
    
    /// ID of the last task the user was focused on.
    var lastFocusedItemID: String? {
        get { UserDefaults.standard.string(forKey: scopedKey("lastFocusedItemID")) }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("lastFocusedItemID")) }
    }
    
    /// When the user last focused on a task.
    var lastFocusedAt: Date? {
        get { UserDefaults.standard.object(forKey: scopedKey("lastFocusedAt")) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("lastFocusedAt")) }
    }
    
    /// Content of the last focused task (cached for quick greeting).
    var lastFocusedContent: String? {
        get { UserDefaults.standard.string(forKey: scopedKey("lastFocusedContent")) }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("lastFocusedContent")) }
    }
    
    /// Track when the user was last active (for welcome-back context).
    var lastActiveDate: Date? {
        get { UserDefaults.standard.object(forKey: scopedKey("lastActiveDate")) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("lastActiveDate")) }
    }
    
    /// Tasks completed today.
    var todayCompletedCount: Int {
        get { UserDefaults.standard.integer(forKey: scopedKey("todayCompletedCount")) }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("todayCompletedCount")) }
    }
    
    /// Date of the todayCompletedCount reset.
    var todayCompletedResetDate: Date {
        get {
            (UserDefaults.standard.object(forKey: scopedKey("todayCompletedResetDate")) as? Date) ?? .distantPast
        }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("todayCompletedResetDate")) }
    }
    
    /// Record that the user focused on a specific task.
    func recordFocus(itemID: UUID, content: String) {
        lastFocusedItemID = itemID.uuidString
        lastFocusedContent = content
        lastFocusedAt = .now
    }
    
    /// Record a task completion for daily stats.
    func recordCompletion() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(todayCompletedResetDate) {
            todayCompletedCount = 0
            todayCompletedResetDate = .now
        }
        todayCompletedCount += 1
    }
    
    /// Update last active timestamp.
    func recordActivity() {
        lastActiveDate = .now
    }
    
    // MARK: - User Info
    
    var userName: String {
        get {
            access(keyPath: \.userName)
            return UserDefaults.standard.string(forKey: scopedKey("userName")) ?? ""
        }
        set {
            withMutation(keyPath: \.userName) {
                UserDefaults.standard.set(newValue, forKey: scopedKey("userName"))
            }
        }
    }
    
    // MARK: - Onboarding
    
    /// Global flag — shown before auth. Not user-scoped.
    var hasSeenIntro: Bool {
        get {
            access(keyPath: \.hasSeenIntro)
            return UserDefaults.standard.bool(forKey: "hasSeenIntro")
        }
        set {
            withMutation(keyPath: \.hasSeenIntro) {
                UserDefaults.standard.set(newValue, forKey: "hasSeenIntro")
            }
        }
    }

    var hasCompletedOnboarding: Bool {
        get {
            access(keyPath: \.hasCompletedOnboarding)
            return UserDefaults.standard.bool(forKey: scopedKey("hasCompletedOnboarding"))
        }
        set {
            withMutation(keyPath: \.hasCompletedOnboarding) {
                UserDefaults.standard.set(newValue, forKey: scopedKey("hasCompletedOnboarding"))
            }
        }
    }
    
    // MARK: - ADHD Profile

    var ageGroup: AgeGroup {
        get {
            access(keyPath: \.ageGroup)
            let raw = UserDefaults.standard.string(forKey: scopedKey("ageGroup")) ?? AgeGroup.adult.rawValue
            return AgeGroup(rawValue: raw) ?? .adult
        }
        set {
            withMutation(keyPath: \.ageGroup) {
                UserDefaults.standard.set(newValue.rawValue, forKey: scopedKey("ageGroup"))
            }
        }
    }

    var adhdSubtype: ADHDSubtype {
        get {
            access(keyPath: \.adhdSubtype)
            let raw = UserDefaults.standard.string(forKey: scopedKey("adhdSubtype")) ?? ADHDSubtype.unsure.rawValue
            return ADHDSubtype(rawValue: raw) ?? .unsure
        }
        set {
            withMutation(keyPath: \.adhdSubtype) {
                UserDefaults.standard.set(newValue.rawValue, forKey: scopedKey("adhdSubtype"))
            }
        }
    }

    var adhdBiggestChallenge: ADHDChallenge {
        get {
            access(keyPath: \.adhdBiggestChallenge)
            let raw = UserDefaults.standard.string(forKey: scopedKey("adhdBiggestChallenge")) ?? ADHDChallenge.allOfAbove.rawValue
            return ADHDChallenge(rawValue: raw) ?? .allOfAbove
        }
        set {
            withMutation(keyPath: \.adhdBiggestChallenge) {
                UserDefaults.standard.set(newValue.rawValue, forKey: scopedKey("adhdBiggestChallenge"))
            }
        }
    }

    var nudgyPersonalityMode: NudgyPersonalityMode {
        get {
            access(keyPath: \.nudgyPersonalityMode)
            let raw = UserDefaults.standard.string(forKey: scopedKey("nudgyPersonalityMode")) ?? NudgyPersonalityMode.gentle.rawValue
            return NudgyPersonalityMode(rawValue: raw) ?? .gentle
        }
        set {
            withMutation(keyPath: \.nudgyPersonalityMode) {
                UserDefaults.standard.set(newValue.rawValue, forKey: scopedKey("nudgyPersonalityMode"))
            }
        }
    }

    var selectedPersona: UserPersona {
        get {
            access(keyPath: \.selectedPersona)
            let raw = UserDefaults.standard.string(forKey: scopedKey("selectedPersona")) ?? UserPersona.adhd.rawValue
            return UserPersona(rawValue: raw) ?? .adhd
        }
        set {
            withMutation(keyPath: \.selectedPersona) {
                UserDefaults.standard.set(newValue.rawValue, forKey: scopedKey("selectedPersona"))
            }
        }
    }

    var hasCompletedADHDProfile: Bool {
        get { access(keyPath: \.hasCompletedADHDProfile); return UserDefaults.standard.bool(forKey: scopedKey("hasCompletedADHDProfile")) }
        set { withMutation(keyPath: \.hasCompletedADHDProfile) { UserDefaults.standard.set(newValue, forKey: scopedKey("hasCompletedADHDProfile")) } }
    }

    // MARK: - Medication Awareness

    var medicationEnabled: Bool {
        get {
            access(keyPath: \.medicationEnabled)
            return UserDefaults.standard.bool(forKey: scopedKey("medicationEnabled"))
        }
        set {
            withMutation(keyPath: \.medicationEnabled) {
                UserDefaults.standard.set(newValue, forKey: scopedKey("medicationEnabled"))
            }
        }
    }

    var medicationTime: Date {
        get {
            access(keyPath: \.medicationTime)
            return (UserDefaults.standard.object(forKey: scopedKey("medicationTime")) as? Date)
                ?? Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!
        }
        set {
            withMutation(keyPath: \.medicationTime) {
                UserDefaults.standard.set(newValue, forKey: scopedKey("medicationTime"))
            }
        }
    }

    // MARK: - Category Preferences (Phase 14)
    
    /// User's priority categories selected during onboarding or settings.
    /// Stored as raw string array of TaskCategory raw values.
    var priorityCategories: [String] {
        get {
            access(keyPath: \.priorityCategories)
            return UserDefaults.standard.stringArray(forKey: scopedKey("priorityCategories")) ?? []
        }
        set {
            withMutation(keyPath: \.priorityCategories) {
                UserDefaults.standard.set(newValue, forKey: scopedKey("priorityCategories"))
            }
        }
    }
    
    /// Per-category notification toggles. Key = TaskCategory.rawValue, Value = enabled.
    var categoryNotificationsEnabled: [String: Bool] {
        get {
            access(keyPath: \.categoryNotificationsEnabled)
            return (UserDefaults.standard.dictionary(forKey: scopedKey("categoryNotificationsEnabled")) as? [String: Bool]) ?? [:]
        }
        set {
            withMutation(keyPath: \.categoryNotificationsEnabled) {
                UserDefaults.standard.set(newValue, forKey: scopedKey("categoryNotificationsEnabled"))
            }
        }
    }
    
    /// Whether notifications are enabled for a specific category.
    func isCategoryNotificationEnabled(_ category: TaskCategory) -> Bool {
        categoryNotificationsEnabled[category.rawValue] ?? true // Default: enabled
    }
    
    // MARK: - Computed Helpers
    
    /// Whether the user can do another brain dump (free tier check)
    var canDoBrainDump: Bool {
        isPro || dailyDumpsUsed < FreeTierLimits.brainDumpsPerDay
    }
    
    /// Whether the user can save another shared item (free tier check)
    var canSaveSharedItem: Bool {
        isPro || savedItemsCount < FreeTierLimits.savedItems
    }
    
    /// Whether we're currently in quiet hours
    var isInQuietHours: Bool {
        isDateInQuietHours(Date())
    }
    
    /// Whether a specific date falls within quiet hours
    func isDateInQuietHours(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if quietHoursStart > quietHoursEnd {
            // Wraps midnight: e.g., 21-8 means 9pm → 8am
            return hour >= quietHoursStart || hour < quietHoursEnd
        } else {
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
    }
    
    /// Returns the next date when quiet hours end
    func nextQuietHoursEnd(after date: Date = Date()) -> Date {
        let calendar = Calendar.current
        var target = calendar.date(bySettingHour: quietHoursEnd, minute: 0, second: 0, of: date) ?? date
        // If that time has already passed today, use tomorrow
        if target <= date {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return target
    }
    
    /// Reset daily dump counter if needed (call on app launch)
    func resetDailyCountersIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(dailyDumpsResetDate) {
            dailyDumpsUsed = 0
            dailyDumpsResetDate = Date()
        }
    }
    
    /// Record a brain dump usage
    func recordBrainDump() {
        dailyDumpsUsed += 1
    }
}
