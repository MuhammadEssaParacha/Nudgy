//
//  NudgyMemory.swift
//  Nudge
//
//  Phase 2: Persistent per-user conversation memory.
//  Stores conversation summaries, user preferences learned over time,
//  and emotional context. File-backed with JSON encoding.
//
//  Memory gives Nudgy continuity — she remembers past conversations,
//  user patterns, and emotional state across app sessions.
//

import Foundation
import os

extension Notification.Name {
    static let nudgyMemoryChanged = Notification.Name("nudgyMemoryChanged")
}

// MARK: - Memory Models

/// A single memorable fact Nudgy has learned about the user.
struct NudgyMemoryFact: Codable, Identifiable, Equatable {
    let id: UUID
    let fact: String
    let category: FactCategory
    let learnedAt: Date
    var lastReferencedAt: Date
    var referenceCount: Int
    
    enum FactCategory: String, Codable {
        case preference    // "User prefers morning tasks"
        case personal      // "User's name is Abdullah"
        case emotional     // "User gets stressed about work deadlines"
        case behavioral    // "User often snoozes tasks to tomorrow"
        case contextual    // "User works from home on Fridays"
    }
    
    init(fact: String, category: FactCategory) {
        self.id = UUID()
        self.fact = fact
        self.category = category
        self.learnedAt = .now
        self.lastReferencedAt = .now
        self.referenceCount = 1
    }
}

/// Summary of a past conversation for long-term recall.
struct ConversationSummary: Codable, Identifiable {
    let id: UUID
    let summary: String
    let date: Date
    let turnCount: Int
    let tasksCreated: Int
    let tasksCompleted: Int
    let mood: String? // e.g., "stressed", "productive", "playful"
    
    init(summary: String, turnCount: Int, tasksCreated: Int = 0, tasksCompleted: Int = 0, mood: String? = nil) {
        self.id = UUID()
        self.summary = summary
        self.date = .now
        self.turnCount = turnCount
        self.tasksCreated = tasksCreated
        self.tasksCompleted = tasksCompleted
        self.mood = mood
    }
}

/// The full persistent memory store.
struct NudgyMemoryStore: Codable {
    var facts: [NudgyMemoryFact] = []
    var conversationSummaries: [ConversationSummary] = []
    var userName: String?
    var totalConversations: Int = 0
    var totalTasksCreated: Int = 0
    var totalTasksCompleted: Int = 0
    var firstInteractionDate: Date?
    var lastInteractionDate: Date?
    var preferredGreetingStyle: String? // learned over time
    
    // MARK: - Category Pattern Memory
    
    /// Cumulative completion counts per category rawValue (e.g. "exercise": 14)
    var categoryCompletionCounts: [String: Int] = [:]
    
    /// Preferred time-of-day per category rawValue (e.g. "exercise": "morning")
    var categoryPreferredTimes: [String: String] = [:]
    
    /// Top 3 category rawValues from the last 7 days (most→least)
    var lastWeekTopCategories: [String] = []
    
    /// Phase 16: Average hours from creation to completion per category (rolling average)
    var categoryAvgCompletionHours: [String: Double] = [:]
    
    /// Get facts relevant to a topic (simple keyword match).
    func relevantFacts(for topic: String) -> [NudgyMemoryFact] {
        let lower = topic.lowercased()
        return facts.filter { $0.fact.lowercased().contains(lower) }
            .sorted { $0.referenceCount > $1.referenceCount }
    }
    
    /// Get recent conversation summaries.
    func recentSummaries(limit: Int = 5) -> [ConversationSummary] {
        Array(conversationSummaries.suffix(limit))
    }
    
    /// Build a memory context string for the LLM system prompt.
    func contextForPrompt() -> String {
        var lines: [String] = []
        
        if let name = userName {
            lines.append("User's name: \(name)")
        }
        
        if let first = firstInteractionDate {
            let days = Calendar.current.dateComponents([.day], from: first, to: .now).day ?? 0
            lines.append("You've known this user for \(days) day\(days == 1 ? "" : "s").")
        }
        
        // Include top facts (most referenced)
        let topFacts = facts
            .sorted { $0.referenceCount > $1.referenceCount }
            .prefix(8)
        if !topFacts.isEmpty {
            lines.append("Things you remember about them:")
            for fact in topFacts {
                lines.append("- \(fact.fact)")
            }
        }
        
        // Include recent conversation context
        let recent = recentSummaries(limit: 3)
        if !recent.isEmpty {
            lines.append("Recent conversations:")
            for summary in recent {
                let dateStr = summary.date.formatted(.dateTime.month().day())
                lines.append("- \(dateStr): \(summary.summary)")
            }
        }
        
        // Stats
        if totalTasksCompleted > 0 {
            lines.append("They've completed \(totalTasksCompleted) tasks with your help.")
        }
        
        // Category patterns
        let topCategories = categoryCompletionCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
        if !topCategories.isEmpty {
            let categoryList = topCategories.map { rawValue, count in
                let label = TaskCategory(rawValue: rawValue)?.label ?? rawValue
                return "\(label): \(count)"
            }.joined(separator: ", ")
            lines.append("Their most-completed categories: \(categoryList).")
        }
        
        if !lastWeekTopCategories.isEmpty {
            let weekLabels = lastWeekTopCategories.compactMap { TaskCategory(rawValue: $0)?.label }
            if !weekLabels.isEmpty {
                lines.append("This week they're focusing on: \(weekLabels.joined(separator: ", ")).")
            }
        }
        
        let timePrefs = categoryPreferredTimes.prefix(3)
        if !timePrefs.isEmpty {
            let prefs = timePrefs.map { rawValue, time in
                let label = TaskCategory(rawValue: rawValue)?.label ?? rawValue
                return "\(label) → \(time)"
            }.joined(separator: ", ")
            lines.append("Preferred times: \(prefs).")
        }
        
        // Phase 16: Completion velocity insights
        let velocities = categoryAvgCompletionHours
            .sorted { $0.value < $1.value }
        if velocities.count >= 2 {
            let fastest = velocities.first!
            let slowest = velocities.last!
            let fastLabel = TaskCategory(rawValue: fastest.key)?.label ?? fastest.key
            let slowLabel = TaskCategory(rawValue: slowest.key)?.label ?? slowest.key
            let fastHrs = String(format: "%.0f", fastest.value)
            let slowHrs = String(format: "%.0f", slowest.value)
            lines.append("Completion speed: \(fastLabel) tasks avg \(fastHrs)h, \(slowLabel) tasks avg \(slowHrs)h.")
        }
        
        return lines.isEmpty ? "" : lines.joined(separator: "\n")
    }
}

// MARK: - NudgyMemory (Manager)

/// Manages persistent conversation memory for Nudgy.
/// File-backed JSON storage in the App Group container.
@MainActor @Observable
final class NudgyMemory {
    
    static let shared = NudgyMemory()
    
    private(set) var store: NudgyMemoryStore
    
    private var fileURL: URL
    private var activeUserID: String?
    
    private init() {
        // Store in App Group for share extension access
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: NudgyConfig.Memory.appGroup
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        let url = container.appendingPathComponent(NudgyConfig.Memory.archiveFileName)
        self.fileURL = url
        
        // Load existing memory
        if let data = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode(NudgyMemoryStore.self, from: data) {
            self.store = loaded
        } else {
            self.store = NudgyMemoryStore()
        }
    }

    /// Switch memory to a specific signed-in user.
    /// Call on sign-in and sign-out so each account gets isolated memory.
    func setActiveUser(id: String?) {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: NudgyConfig.Memory.appGroup
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        activeUserID = id

        if let id, !id.isEmpty {
            fileURL = container.appendingPathComponent("nudgy_memory_\(id).json")
        } else {
            fileURL = container.appendingPathComponent(NudgyConfig.Memory.archiveFileName)
        }

        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(NudgyMemoryStore.self, from: data) {
            store = loaded
        } else {
            store = NudgyMemoryStore()
        }
    }
    
    // MARK: - Facts
    
    /// Learn a new fact about the user.
    func learn(_ fact: String, category: NudgyMemoryFact.FactCategory) {
        // Avoid duplicates
        guard !store.facts.contains(where: { $0.fact.lowercased() == fact.lowercased() }) else {
            // Bump reference count instead
            if let index = store.facts.firstIndex(where: { $0.fact.lowercased() == fact.lowercased() }) {
                store.facts[index].referenceCount += 1
                store.facts[index].lastReferencedAt = .now
            }
            save()
            return
        }
        
        let memoryFact = NudgyMemoryFact(fact: fact, category: category)
        store.facts.append(memoryFact)
        
        // Trim oldest facts if over limit (keep most referenced)
        if store.facts.count > 50 {
            store.facts.sort { $0.referenceCount > $1.referenceCount }
            store.facts = Array(store.facts.prefix(40))
        }
        
        save()
    }
    
    /// Update the user's name if mentioned.
    func updateUserName(_ name: String) {
        guard !name.isEmpty else { return }
        store.userName = name
        learn("User's name is \(name)", category: .personal)
        save()
    }
    
    // MARK: - Conversation Summaries
    
    /// Save a conversation summary.
    func saveConversationSummary(_ summary: ConversationSummary) {
        store.conversationSummaries.append(summary)
        store.totalConversations += 1
        store.totalTasksCreated += summary.tasksCreated
        store.totalTasksCompleted += summary.tasksCompleted
        store.lastInteractionDate = .now
        
        if store.firstInteractionDate == nil {
            store.firstInteractionDate = .now
        }
        
        // Trim old summaries
        let maxStored = NudgyConfig.Memory.maxStoredConversations
        if store.conversationSummaries.count > maxStored {
            store.conversationSummaries = Array(store.conversationSummaries.suffix(maxStored))
        }
        
        // Prune summaries older than retention period
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -NudgyConfig.Memory.retentionDays,
            to: .now
        ) ?? .now
        store.conversationSummaries.removeAll { $0.date < cutoff }
        
        save()
    }
    
    /// Record an interaction timestamp.
    func recordInteraction() {
        store.lastInteractionDate = .now
        if store.firstInteractionDate == nil {
            store.firstInteractionDate = .now
        }
        save()
    }
    
    // MARK: - Category Pattern Tracking
    
    /// Track a task completion for category pattern memory.
    func trackCategoryCompletion(_ category: TaskCategory, createdAt: Date? = nil) {
        let raw = category.rawValue
        let count = store.categoryCompletionCounts[raw, default: 0]
        store.categoryCompletionCounts[raw] = count + 1
        
        // Record preferred time-of-day for this category
        let hour = Calendar.current.component(.hour, from: .now)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default: timeOfDay = "night"
        }
        store.categoryPreferredTimes[raw] = timeOfDay
        
        // Phase 16: Track completion velocity (rolling average hours)
        if let created = createdAt {
            let hours = Date().timeIntervalSince(created) / 3600.0
            let existingAvg = store.categoryAvgCompletionHours[raw] ?? hours
            // Exponential moving average — recent completions weigh more
            let newAvg = count > 0 ? (existingAvg * Double(count) + hours) / Double(count + 1) : hours
            store.categoryAvgCompletionHours[raw] = newAvg
        }
        
        save()
    }
    
    /// Refresh last-week top categories from a set of recently completed items.
    func refreshWeeklyTopCategories(recentCompletions: [(category: String, date: Date)]) {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let weekItems = recentCompletions.filter { $0.date > oneWeekAgo }
        
        var counts: [String: Int] = [:]
        for item in weekItems {
            counts[item.category, default: 0] += 1
        }
        
        store.lastWeekTopCategories = counts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
        
        save()
    }
    
    // MARK: - Context Generation
    
    /// Get memory context for the LLM system prompt.
    func memoryContext() -> String {
        store.contextForPrompt()
    }
    
    /// Get the user's name from memory.
    var userName: String? {
        store.userName
    }
    
    // MARK: - Persistence
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(store)
            try data.write(to: fileURL, options: .atomic)
            NotificationCenter.default.post(name: .nudgyMemoryChanged, object: nil)
        } catch {
            Log.ai.error("NudgyMemory: Failed to save: \(error, privacy: .public)")
        }
    }
    
    /// Clear all memory (for privacy/reset).
    func clearAll() {
        store = NudgyMemoryStore()
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Forget (remove) a specific fact by ID.
    func forget(_ factID: UUID) {
        store.facts.removeAll { $0.id == factID }
        save()
    }
    
    /// Export memory as JSON data (for debugging/backup).
    func exportJSON() -> Data? {
        try? JSONEncoder().encode(store)
    }

    /// Replace the current memory store (used when hydrating from CloudKit).
    func replaceStore(_ newStore: NudgyMemoryStore) {
        store = newStore
        // Persist immediately so local cache matches what we just loaded.
        do {
            let data = try JSONEncoder().encode(store)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.ai.error("NudgyMemory: Failed to replace store: \(error, privacy: .public)")
        }
        NotificationCenter.default.post(name: .nudgyMemoryChanged, object: nil)
    }
}
