//
//  WidgetDataService.swift
//  Nudge
//
//  Centralizes all widget data syncing and pending action processing.
//  Called from views and NudgeApp on foreground.
//

import Foundation
import WidgetKit
import SwiftData
import os

@MainActor
enum WidgetDataService {
    
    private static let log = Logger(subsystem: "com.tarsitgroup.nudge", category: "WidgetData")
    
    // MARK: - Sync Widget Data
    
    /// Write current task state to shared App Group UserDefaults
    /// so Home Screen, Lock Screen, and Control Center widgets can read it.
    static func sync(
        activeTasks: [NudgeItem],
        completedTodayCount: Int,
        totalTodayCount: Int,
        wardrobe: NudgyWardrobe? = nil
    ) {
        guard let defaults = UserDefaults(suiteName: AppGroupID.suiteName) else { return }
        
        let nextItem = activeTasks.first
        
        // Core task data
        defaults.set(nextItem?.content, forKey: "widget_nextTask")
        defaults.set(nextItem?.emoji ?? "pawprint.fill", forKey: "widget_nextTaskEmoji")
        defaults.set(nextItem?.id.uuidString, forKey: "widget_nextTaskID")
        defaults.set(activeTasks.count, forKey: "widget_activeCount")
        defaults.set(completedTodayCount, forKey: "widget_completedToday")
        defaults.set(totalTodayCount, forKey: "widget_totalToday")
        
        // Category data for tinting
        if let nextItem {
            let cat = nextItem.resolvedCategory
            if cat != .general {
                defaults.set(cat.primaryColorHex, forKey: "widget_nextTaskCategoryColor")
                defaults.set(cat.label, forKey: "widget_nextTaskCategoryLabel")
            } else {
                defaults.removeObject(forKey: "widget_nextTaskCategoryColor")
                defaults.removeObject(forKey: "widget_nextTaskCategoryLabel")
            }
        } else {
            defaults.removeObject(forKey: "widget_nextTaskCategoryColor")
            defaults.removeObject(forKey: "widget_nextTaskCategoryLabel")
        }
        
        // Category breakdown for medium widget
        let catCounts = Dictionary(grouping: activeTasks, by: { $0.resolvedCategory })
            .mapValues(\.count)
            .filter { $0.key != .general }
            .sorted { $0.value > $1.value }
        let breakdownStr = catCounts.prefix(4)
            .map { "\($0.key.icon):\($0.value):\($0.key.primaryColorHex)" }
            .joined(separator: ",")
        defaults.set(breakdownStr, forKey: "widget_categoryBreakdown")
        
        // Gamification data for large widget
        if let wardrobe {
            defaults.set(wardrobe.currentStreak, forKey: "widget_streakDays")
            defaults.set(wardrobe.lifetimeFish, forKey: "widget_totalFish")
            defaults.set(wardrobe.level, forKey: "widget_level")
        }
        
        // Queue tasks for large widget (top 4)
        let queueData = activeTasks.prefix(4).map { item -> [String: String] in
            let cat = item.resolvedCategory
            var dict: [String: String] = [
                "id": item.id.uuidString,
                "content": item.content,
                "emoji": item.emoji ?? "checklist"
            ]
            if cat != .general {
                dict["catColor"] = cat.primaryColorHex
                dict["catLabel"] = cat.label
            }
            return dict
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: queueData),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            defaults.set(jsonStr, forKey: "widget_queueTasks")
        }
        
        // Reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()
        
        log.debug("Widget data synced — \(activeTasks.count) active, \(completedTodayCount) done")
    }
    
    // MARK: - Process Pending Widget Actions
    
    /// Check for and process any pending actions from interactive widget buttons.
    /// Call this on app foreground and after data refresh.
    static func processPendingActions(using context: ModelContext) {
        let repository = NudgeRepository(modelContext: context)
        guard let defaults = UserDefaults(suiteName: AppGroupID.suiteName) else { return }
        
        // Process pending "Mark Done"
        if let taskID = defaults.string(forKey: "widget_pendingDoneTaskID"),
           let timestamp = defaults.object(forKey: "widget_pendingDoneTimestamp") as? Double {
            // Only process if recent (within last 60 seconds — prevents stale actions)
            let age = Date().timeIntervalSince1970 - timestamp
            if age < 60, let uuid = UUID(uuidString: taskID) {
                let descriptor = FetchDescriptor<NudgeItem>(
                    predicate: #Predicate { $0.statusRaw == "active" }
                )
                if let items = try? context.fetch(descriptor),
                   let item = items.first(where: { $0.id == uuid }) {
                    repository.markDone(item)
                    log.info("Widget action: marked done — \(item.content)")
                    NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
                }
            }
            defaults.removeObject(forKey: "widget_pendingDoneTaskID")
            defaults.removeObject(forKey: "widget_pendingDoneTimestamp")
        }
        
        // Process pending "Skip" — move task to end of queue
        if let taskID = defaults.string(forKey: "widget_pendingSkipTaskID"),
           let timestamp = defaults.object(forKey: "widget_pendingSkipTimestamp") as? Double {
            let age = Date().timeIntervalSince1970 - timestamp
            if age < 60, let uuid = UUID(uuidString: taskID) {
                let descriptor = FetchDescriptor<NudgeItem>(
                    predicate: #Predicate { $0.statusRaw == "active" },
                    sortBy: [SortDescriptor(\.sortOrder)]
                )
                if let items = try? context.fetch(descriptor),
                   let item = items.first(where: { $0.id == uuid }) {
                    // Move to end of queue by setting sortOrder higher than all others
                    let maxOrder = items.last?.sortOrder ?? 0
                    item.sortOrder = maxOrder + 1
                    try? context.save()
                    log.info("Widget action: skipped — \(item.content)")
                    NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
                }
            }
            defaults.removeObject(forKey: "widget_pendingSkipTaskID")
            defaults.removeObject(forKey: "widget_pendingSkipTimestamp")
        }
    }
}
