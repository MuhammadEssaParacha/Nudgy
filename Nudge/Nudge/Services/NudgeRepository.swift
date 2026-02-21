//
//  NudgeRepository.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftData
import SwiftUI
import os

/// Central data access layer for NudgeItem CRUD and ordering.
/// All SwiftData queries go through here — views never touch ModelContext directly.
@MainActor @Observable
final class NudgeRepository {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Fetch Active Queue
    
    /// Fetch the ordered queue for One-Thing View.
    /// Priority: items with due times first → overdue → most recent → snoozed resurfacing
    func fetchActiveQueue() -> [NudgeItem] {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "active"
        }
        
        var descriptor = FetchDescriptor<NudgeItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        descriptor.fetchLimit = 50
        
        do {
            let items = try modelContext.fetch(descriptor)
            return prioritize(items)
        } catch {
            Log.data.error("Failed to fetch active queue: \(error, privacy: .public)")
            return []
        }
    }
    
    /// Fetch the next single item for One-Thing View
    func fetchNextItem() -> NudgeItem? {
        fetchActiveQueue().first
    }
    
    // MARK: - Fetch By Status
    
    /// Fetch all snoozed items
    func fetchSnoozed() -> [NudgeItem] {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "snoozed"
        }
        
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.snoozedUntil, order: .forward)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Log.data.error("Failed to fetch snoozed items: \(error, privacy: .public)")
            return []
        }
    }
    
    /// Fetch items completed today
    func fetchCompletedToday() -> [NudgeItem] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return fetchCompletedInRange(from: startOfDay, to: Date.distantFuture)
    }
    
    /// Fetch items completed within a date range (for mood insight category breakdown)
    func fetchCompletedInRange(from start: Date, to end: Date) -> [NudgeItem] {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "done"
        }
        
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        
        do {
            let items = try modelContext.fetch(descriptor)
            // Filter in-memory — can't unwrap Date? in #Predicate
            return items.filter { item in
                guard let completedAt = item.completedAt else { return false }
                return completedAt >= start && completedAt < end
            }
        } catch {
            Log.data.error("Failed to fetch completed items: \(error, privacy: .public)")
            return []
        }
    }
    
    /// Fetch all items for the All Items screen
    func fetchAllGrouped() -> (active: [NudgeItem], snoozed: [NudgeItem], doneToday: [NudgeItem]) {
        return (
            active: fetchActiveQueue(),
            snoozed: fetchSnoozed(),
            doneToday: fetchCompletedToday()
        )
    }
    
    // MARK: - Category Streaks
    
    /// Compute per-category consecutive-day streaks looking back up to 14 days.
    /// Returns an array of (category, days) sorted by longest streak first.
    func categoryStreaks() -> [(category: TaskCategory, days: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Fetch all done items from the last 14 days
        guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) else { return [] }
        let completed = fetchCompletedInRange(from: twoWeeksAgo, to: .distantFuture)
        
        // Group completed items by category, then by day
        var categoryDays: [TaskCategory: Set<Int>] = [:]  // category → set of day-offsets (0=today, 1=yesterday, ...)
        for item in completed {
            guard let date = item.completedAt else { continue }
            let cat = item.resolvedCategory
            guard cat != .general else { continue }
            let dayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? 0
            categoryDays[cat, default: []].insert(dayOffset)
        }
        
        // For each category, count consecutive days starting from today (day 0)
        var streaks: [(category: TaskCategory, days: Int)] = []
        for (cat, days) in categoryDays {
            guard days.contains(0) else { continue } // Must include today
            var streak = 1
            var offset = 1
            while days.contains(offset) {
                streak += 1
                offset += 1
            }
            if streak >= 2 {
                streaks.append((category: cat, days: streak))
            }
        }
        
        return streaks.sorted { $0.days > $1.days }
    }
    
    // MARK: - Resurface Snoozed Items
    
    /// Check for snoozed items that should resurface and activate them.
    /// Call this on app launch and periodically.
    func resurfaceExpiredSnoozes() {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "snoozed"
        }
        
        let descriptor = FetchDescriptor<NudgeItem>(predicate: predicate)
        
        do {
            let snoozed = try modelContext.fetch(descriptor)
            let now = Date()
            // Filter in-memory to avoid force-unwrapping optionals in #Predicate
            let expired = snoozed.filter { item in
                guard let snoozedUntil = item.snoozedUntil else { return false }
                return snoozedUntil <= now
            }
            for item in expired {
                item.resurface()
            }
            if !expired.isEmpty {
                save()
            }
        } catch {
            Log.data.error("Failed to resurface snoozed items: \(error, privacy: .public)")
        }
    }
    
    /// Backfill categories for existing tasks that don't have one assigned yet.
    /// Safe to call repeatedly — only processes items where `categoryRaw` is nil.
    func backfillCategories() {
        // Fetch all items with no category
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: #Predicate<NudgeItem> { $0.categoryRaw == nil }
        )
        
        do {
            let uncategorized = try modelContext.fetch(descriptor)
            guard !uncategorized.isEmpty else { return }
            
            for item in uncategorized {
                let detected = CategoryClassifier.classify(
                    content: item.content,
                    actionType: item.actionType
                )
                item.category = detected
            }
            save()
            Log.data.info("Backfilled categories for \(uncategorized.count) tasks")
        } catch {
            Log.data.error("Failed to backfill categories: \(error, privacy: .public)")
        }
    }
    
    // MARK: - Create
    
    /// Insert a new item from a brain dump
    func createFromBrainDump(
        content: String,
        emoji: String?,
        actionType: ActionType?,
        actionTarget: String? = nil,
        contactName: String?,
        priority: TaskPriority? = nil,
        dueDate: Date? = nil,
        category: TaskCategory? = nil,
        brainDump: BrainDump
    ) -> NudgeItem {
        let maxOrder = fetchMaxSortOrder()
        let resolved = category ?? CategoryClassifier.classify(content: content, actionType: actionType)
        let item = NudgeItem(
            content: content,
            sourceType: .voiceDump,
            emoji: emoji,
            actionType: actionType,
            actionTarget: actionTarget,
            contactName: contactName,
            sortOrder: maxOrder + 1,
            priority: priority,
            dueDate: dueDate,
            category: resolved
        )
        item.brainDump = brainDump
        modelContext.insert(item)
        return item
    }
    
    /// Insert a new item from Share Extension
    func createFromShare(
        content: String,
        url: String?,
        preview: String?,
        snoozedUntil: Date,
        category: TaskCategory? = nil
    ) -> NudgeItem {
        let maxOrder = fetchMaxSortOrder()
        let resolved = category ?? CategoryClassifier.classify(content: content, actionType: url != nil ? .openLink : nil)
        let item = NudgeItem(
            content: content,
            sourceType: .share,
            sourceUrl: url,
            sourcePreview: preview,
            actionType: url != nil ? .openLink : nil,
            actionTarget: url,
            sortOrder: maxOrder + 1,
            category: resolved
        )
        item.snooze(until: snoozedUntil)
        modelContext.insert(item)
        save()
        return item
    }
    
    /// Insert a manually created item
    func createManual(content: String) -> NudgeItem {
        let maxOrder = fetchMaxSortOrder()
        let category = CategoryClassifier.classify(content: content, actionType: nil)
        let item = NudgeItem(
            content: content,
            sourceType: .manual,
            sortOrder: maxOrder + 1,
            category: category
        )
        modelContext.insert(item)
        save()
        return item
    }
    
    /// Insert a manually created item with AI-extracted details (emoji, action type, contact)
    func createManualWithDetails(
        content: String,
        emoji: String?,
        actionType: ActionType?,
        actionTarget: String? = nil,
        contactName: String?,
        priority: TaskPriority? = nil,
        dueDate: Date? = nil,
        category: TaskCategory? = nil
    ) -> NudgeItem {
        let maxOrder = fetchMaxSortOrder()
        let resolved = category ?? CategoryClassifier.classify(content: content, actionType: actionType)
        let item = NudgeItem(
            content: content,
            sourceType: .manual,
            emoji: emoji,
            actionType: actionType,
            actionTarget: actionTarget,
            contactName: contactName,
            sortOrder: maxOrder + 1,
            priority: priority,
            dueDate: dueDate,
            category: resolved
        )
        modelContext.insert(item)
        save()
        return item
    }
    
    // MARK: - Actions
    
    /// Mark item as done
    func markDone(_ item: NudgeItem) {
        let created = item.createdAt
        item.markDone()
        NudgyMemory.shared.trackCategoryCompletion(item.resolvedCategory, createdAt: created)
        save()
    }
    
    /// Snooze item
    func snooze(_ item: NudgeItem, until date: Date) {
        item.snooze(until: date)
        save()
    }
    
    /// Skip item (move to end of queue)
    func skip(_ item: NudgeItem) {
        let maxOrder = fetchMaxSortOrder()
        item.skip(newOrder: maxOrder + 1)
        save()
    }
    
    /// Drop (soft delete) item
    func drop(_ item: NudgeItem) {
        item.drop()
        save()
    }
    
    /// Permanently delete item
    func delete(_ item: NudgeItem) {
        // Cancel any pending notifications for this item
        NotificationService.shared.cancelNotification(for: item.id)
        modelContext.delete(item)
        save()
    }
    
    /// Undo a done action — restore item to active
    func undoDone(_ item: NudgeItem, restoreSortOrder: Int) {
        item.status = .active
        item.completedAt = nil
        item.sortOrder = restoreSortOrder
        item.updatedAt = Date()
        save()
    }
    
    /// Undo a drop action — restore item to active
    func undoDrop(_ item: NudgeItem, restoreSortOrder: Int) {
        item.status = .active
        item.sortOrder = restoreSortOrder
        item.updatedAt = Date()
        save()
    }
    
    /// Resurface a snoozed item — bring it back to active
    func resurfaceItem(_ item: NudgeItem) {
        item.resurface()
        // Cancel the pending snooze notification
        NotificationService.shared.cancelNotification(for: item.id)
        save()
    }
    
    /// Update AI draft on item
    func updateDraft(_ item: NudgeItem, draft: String, subject: String? = nil) {
        item.aiDraft = draft
        item.aiDraftSubject = subject
        item.draftGeneratedAt = Date()
        item.updatedAt = Date()
        save()
    }
    
    // MARK: - Counts
    
    /// Total active items count (for "3 of 7" indicator)
    func activeCount() -> Int {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "active"
        }
        let descriptor = FetchDescriptor<NudgeItem>(predicate: predicate)
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    /// Total completed today
    func completedTodayCount() -> Int {
        fetchCompletedToday().count
    }
    
    /// Total lifetime completed count
    func completedCount() -> Int {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "done"
        }
        let descriptor = FetchDescriptor<NudgeItem>(predicate: predicate)
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    // MARK: - Share Extension Ingest
    
    /// Ingest items from Share Extension via App Group UserDefaults.
    /// Called on app launch and when app becomes active.
    func ingestFromShareExtension() {
        guard let defaults = UserDefaults(suiteName: AppGroupID.suiteName) else { return }
        guard let data = defaults.data(forKey: AppGroupID.pendingItemsKey) else { return }
        
        do {
            let pendingItems = try JSONDecoder().decode([ShareExtensionPayload].self, from: data)
            
            for payload in pendingItems {
                let cat = payload.category.flatMap { TaskCategory(rawValue: $0) }
                _ = createFromShare(
                    content: payload.content,
                    url: payload.url,
                    preview: payload.preview,
                    snoozedUntil: payload.snoozedUntil,
                    category: cat
                )
            }
            
            // Clear after ingestion
            defaults.removeObject(forKey: AppGroupID.pendingItemsKey)
        } catch {
            Log.data.error("Failed to ingest share extension items: \(error, privacy: .public)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchMaxSortOrder() -> Int {
        let descriptor = FetchDescriptor<NudgeItem>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        var limitedDescriptor = descriptor
        limitedDescriptor.fetchLimit = 1
        
        let items = (try? modelContext.fetch(limitedDescriptor)) ?? []
        return items.first?.sortOrder ?? 0
    }
    
    /// Prioritize items using time-aware scoring:
    /// 1. Overdue items (past due date)
    /// 2. Due today with specific time (nearest first)
    /// 3. Scheduled for now (scheduledTime proximity)
    /// 4. Due today (no specific time)
    /// 5. Stale items (3+ days untouched)
    /// 6. Due tomorrow
    /// 7. Energy-matched items for current time-of-day
    /// 8. Everything else by sortOrder
    private func prioritize(_ items: [NudgeItem]) -> [NudgeItem] {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let currentEnergy = EnergyScheduler.energyBucket(for: hour)

        return items.sorted { a, b in
            let scoreA = urgencyScore(a, now: now, calendar: calendar, currentEnergy: currentEnergy)
            let scoreB = urgencyScore(b, now: now, calendar: calendar, currentEnergy: currentEnergy)

            if scoreA != scoreB { return scoreA > scoreB }

            // Tiebreak: closer scheduledTime wins
            if let aTime = a.scheduledTime, let bTime = b.scheduledTime {
                return abs(aTime.timeIntervalSince(now)) < abs(bTime.timeIntervalSince(now))
            }

            return a.sortOrder < b.sortOrder
        }
    }

    /// Compute a numeric urgency score for sorting. Higher = more urgent.
    private func urgencyScore(
        _ item: NudgeItem,
        now: Date,
        calendar: Calendar,
        currentEnergy: EnergyLevel
    ) -> Int {
        var score = 0

        // Tier 1: Overdue due date (past deadline)
        if let dueDate = item.dueDate, dueDate < now {
            score += 100
            // More overdue = higher urgency
            let hoursOverdue = Int(now.timeIntervalSince(dueDate) / 3600)
            score += min(hoursOverdue, 20)
        }

        // Tier 1b: Snoozed and overdue (resurfaced)
        if item.isOverdue {
            score += 90
        }

        // Tier 2: Scheduled time within next 2 hours
        if let scheduled = item.scheduledTime {
            let delta = scheduled.timeIntervalSince(now)
            if delta >= -1800 && delta <= 7200 { // -30min to +2h window
                score += 70
                // Closer = higher
                let minutesAway = Int(abs(delta) / 60)
                score += max(0, 30 - minutesAway)
            } else if delta > 0 && delta <= 14400 { // 2-4h away
                score += 40
            }
        }

        // Tier 3: Due today
        if let dueDate = item.dueDate, calendar.isDateInToday(dueDate) {
            score += 60
        }

        // Tier 4: Stale items (untouched 3+ days)
        if item.isCategoryStale {
            score += 35
            // Staler = more urgent
            score += min(item.ageInDays, 10)
        } else if item.isStale {
            score += 30
        }

        // Tier 5: Due tomorrow
        if let dueDate = item.dueDate, calendar.isDateInTomorrow(dueDate) {
            score += 25
        }

        // Tier 6: Due this week (but not today/tomorrow)
        if let dueDate = item.dueDate,
           !calendar.isDateInToday(dueDate),
           !calendar.isDateInTomorrow(dueDate),
           dueDate > now {
            let daysUntilDue = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 99
            if daysUntilDue <= 7 {
                score += max(0, 20 - daysUntilDue * 2)
            }
        }

        // Tier 7: Energy match bonus
        if let energy = item.energyLevel, energy == currentEnergy {
            score += 10
        }

        // Tier 8: Quick win in afternoon (< 15 min)
        if let mins = item.estimatedMinutes, mins <= 15, (12...17).contains(calendar.component(.hour, from: now)) {
            score += 5
        }

        return score
    }
    
    private func save() {
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        } catch {
            Log.data.error("SwiftData save failed: \(error, privacy: .public)")
        }
    }
}

// MARK: - Share Extension Payload

/// Lightweight JSON payload written by the Share Extension.
/// Must match the definition in NudgeShareExtension/ShareViewController.swift.
struct ShareExtensionPayload: Codable {
    let content: String
    let url: String?
    let preview: String?
    let snoozedUntil: Date
    let savedAt: Date
    let category: String?
}

// MARK: - App Group Constants

enum AppGroupID {
    static let suiteName = "group.com.tarsitgroup.nudge"
    static let pendingItemsKey = "pendingShareItems"
}
