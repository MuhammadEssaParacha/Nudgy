//
//  RoutineService.swift
//  Nudge
//
//  Auto-generates NudgeItems from active Routines.
//  Called on app launch and when entering foreground.
//  Each routine only generates once per day.
//

import SwiftData
import SwiftUI
import os.log

private let routineLog = Logger(subsystem: "com.tarsitgroup.nudge", category: "RoutineService")

@MainActor
enum RoutineService {
    
    /// Generate NudgeItems for all active routines that haven't been generated today.
    /// Call this on app launch and foreground re-entry.
    static func generateTodaysRoutines(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Routine>()
        
        guard let routines = try? modelContext.fetch(descriptor) else {
            routineLog.warning("Failed to fetch routines")
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var generatedCount = 0
        
        for routine in routines where routine.isActive && routine.shouldRunToday {
            // Check if already generated today
            if let lastGen = routine.lastGeneratedDate,
               calendar.isDate(lastGen, inSameDayAs: today) {
                continue
            }
            
            let steps = routine.steps
            guard !steps.isEmpty else { continue }
            
            // Get next sort order
            let activePredicate = #Predicate<NudgeItem> { $0.statusRaw == "active" }
            let activeDesc = FetchDescriptor<NudgeItem>(
                predicate: activePredicate,
                sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
            )
            let maxOrder = (try? modelContext.fetch(activeDesc).first?.sortOrder) ?? 0
            
            // Generate tasks for each step
            for (index, step) in steps.enumerated() {
                // Build scheduled time from routine start + cumulative step durations
                var scheduledTime: Date?
                if routine.startHour >= 0 {
                    var components = calendar.dateComponents([.year, .month, .day], from: today)
                    let cumulativeMinutes = steps.prefix(index)
                        .compactMap(\.estimatedMinutes)
                        .reduce(0, +)
                    components.hour = routine.startHour
                    components.minute = routine.startMinute + cumulativeMinutes
                    scheduledTime = calendar.date(from: components)
                }
                
                let item = NudgeItem(
                    content: step.content,
                    sourceType: .manual,
                    emoji: step.emoji,
                    sortOrder: maxOrder + index + 1,
                    estimatedMinutes: step.estimatedMinutes,
                    scheduledTime: scheduledTime,
                    routineID: routine.id,
                    categoryColorHex: routine.colorHex
                )
                // Propagate routine category to generated task
                if let catRaw = routine.categoryRaw,
                   let cat = TaskCategory(rawValue: catRaw) {
                    item.categoryRaw = catRaw
                    item.categoryColorHex = cat.primaryColorHex
                    item.categoryIcon = cat.icon
                }
                // Phase 16: Per-step category override → routine category fallback
                if let stepCatRaw = step.categoryRaw,
                   let stepCat = TaskCategory(rawValue: stepCatRaw) {
                    item.categoryRaw = stepCatRaw
                    item.categoryColorHex = stepCat.primaryColorHex
                    item.categoryIcon = stepCat.icon
                }
                modelContext.insert(item)
                generatedCount += 1
            }
            
            // Mark routine as generated today
            routine.lastGeneratedDate = Date()
        }
        
        if generatedCount > 0 {
            do { try modelContext.save() } catch { Log.services.error("[RoutineService] Save failed: \(error, privacy: .public)") }
            routineLog.info("Generated \(generatedCount) tasks from routines")
            
            // Notify data changed
            NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        }
    }
}
