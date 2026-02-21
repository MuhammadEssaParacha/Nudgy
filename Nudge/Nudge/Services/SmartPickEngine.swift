//
//  SmartPickEngine.swift
//  Nudge
//
//  Intelligent task selection that considers time of day, energy level,
//  task duration, deadlines, and staleness. Replaces random "Pick For Me".
//
//  Scoring formula:
//    score = overdue_bonus + due_today_bonus + stale_penalty
//          + time_match_bonus + energy_match_bonus + quick_win_bonus
//

import SwiftData
import SwiftUI

@MainActor
enum SmartPickEngine {
    
    /// Pick the best task to work on right now, considering context.
    /// Falls back to random if scoring yields ties.
    /// Phase 14: Added settings parameter for priority category boosting.
    static func pickBest(
        from items: [NudgeItem],
        currentEnergy: EnergyLevel? = nil,
        settings: AppSettings? = nil
    ) -> NudgeItem? {
        guard !items.isEmpty else { return nil }
        guard items.count > 1 else { return items.first }
        
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        var scored: [(item: NudgeItem, score: Double)] = items.map { item in
            var score: Double = 0
            
            // 1. Overdue bonus (highest priority)
            if let due = item.dueDate, due < now {
                let hoursOverdue = now.timeIntervalSince(due) / 3600
                score += min(30 + hoursOverdue, 50) // cap at 50
            }
            
            // 2. Due today bonus
            if let due = item.dueDate, calendar.isDateInToday(due) {
                score += 20
            }
            
            // 3. Staleness penalty — category-aware thresholds
            let staleDays = item.categoryAwareStaleDays
            if item.ageInDays >= staleDays + 2 {
                score += Double(item.ageInDays) * 2  // Well past stale
            } else if item.isCategoryStale {
                score += Double(item.ageInDays) * 1.5  // Just became stale for this category
            }
            
            // 4. Time-of-day matching (if item has scheduled time)
            if let scheduled = item.scheduledTime {
                let scheduledHour = calendar.component(.hour, from: scheduled)
                let hourDiff = abs(hour - scheduledHour)
                if hourDiff <= 1 {
                    score += 15 // Within the hour window
                } else if hourDiff <= 2 {
                    score += 8
                }
            }
            
            // 5. Energy matching
            if let energy = currentEnergy, let itemEnergy = item.energyLevel {
                if energy == itemEnergy {
                    score += 10 // Perfect match
                } else if energy == .low && itemEnergy == .low {
                    score += 12 // Extra boost for easy tasks when tired
                }
            } else if currentEnergy == .low {
                // When tired, prefer short tasks
                if let mins = item.estimatedMinutes, mins <= 10 {
                    score += 8
                }
            }
            
            // 6. Quick win bonus — short tasks get a bump in afternoon
            if let mins = item.estimatedMinutes, mins <= 10 && hour >= 14 {
                score += 5
            }
            
            // 7. Has action/draft ready = lower friction
            if item.hasAction {
                score += 3
            }
            if item.hasDraft {
                score += 4
            }
            
            // 8. Small random jitter to break ties (0–2 points)
            score += Double.random(in: 0...2)
            
            return (item, score)
        }
        
        // 9. Category variety bonus — avoid showing the same category repeatedly
        //    If multiple items tie on score, prefer one from a less-common category
        let categoryFrequency: [TaskCategory: Int] = items.reduce(into: [:]) { counts, item in
            counts[item.resolvedCategory, default: 0] += 1
        }
        let maxFreq = categoryFrequency.values.max() ?? 1
        scored = scored.map { entry in
            let cat = entry.item.resolvedCategory
            let freq = categoryFrequency[cat] ?? 1
            // Rare categories get a small bump (up to 3 points)
            let varietyBonus = Double(maxFreq - freq) / Double(max(maxFreq, 1)) * 3.0
            return (entry.item, entry.score + varietyBonus)
        }
        
        // 10. Time-of-day × category affinity — surface tasks that fit the rhythm
        scored = scored.map { entry in
            let cat = entry.item.resolvedCategory
            var bonus: Double = 0
            
            switch hour {
            case 5...10: // Morning — health, exercise, self-care
                if cat == .health || cat == .exercise || cat == .selfCare {
                    bonus = 5
                }
            case 11...14: // Midday — work, homework, appointments
                if cat == .work || cat == .homework || cat == .appointment || cat == .finance {
                    bonus = 4
                }
            case 15...17: // Afternoon — errands, shopping
                if cat == .errand || cat == .shopping || cat == .maintenance {
                    bonus = 4
                }
            case 18...21: // Evening — cooking, cleaning, creative
                if cat == .cooking || cat == .cleaning || cat == .creative || cat == .social {
                    bonus = 5
                }
            case 22...23, 0...4: // Night — self-care wind-down
                if cat == .selfCare || cat == .creative {
                    bonus = 3
                }
            default:
                break
            }
            
            return (entry.item, entry.score + bonus)
        }
        
        // 11. Phase 14: Priority category boost — user-selected categories get a bump
        if let settings, !settings.priorityCategories.isEmpty {
            let prioritySet = Set(settings.priorityCategories)
            scored = scored.map { entry in
                let cat = entry.item.resolvedCategory
                let boost: Double = prioritySet.contains(cat.rawValue) ? 6.0 : 0
                return (entry.item, entry.score + boost)
            }
        }
        
        // Sort by score descending
        scored.sort { $0.score > $1.score }
        
        return scored.first?.item
    }
    
    /// Return all items sorted by SmartPick score (highest first).
    /// Used for up-next ordering so the 2nd/3rd/4th best picks appear in order.
    static func ranked(
        from items: [NudgeItem],
        currentEnergy: EnergyLevel? = nil,
        settings: AppSettings? = nil
    ) -> [NudgeItem] {
        guard items.count > 1 else { return items }
        
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        var scored: [(item: NudgeItem, score: Double)] = items.map { item in
            var score: Double = 0
            
            if let due = item.dueDate, due < now {
                let hoursOverdue = now.timeIntervalSince(due) / 3600
                score += min(30 + hoursOverdue, 50)
            }
            if let due = item.dueDate, calendar.isDateInToday(due) { score += 20 }
            
            let staleDays = item.categoryAwareStaleDays
            if item.ageInDays >= staleDays + 2 {
                score += Double(item.ageInDays) * 2
            } else if item.isCategoryStale {
                score += Double(item.ageInDays) * 1.5
            }
            
            if let scheduled = item.scheduledTime {
                let scheduledHour = calendar.component(.hour, from: scheduled)
                let hourDiff = abs(hour - scheduledHour)
                if hourDiff <= 1 { score += 15 } else if hourDiff <= 2 { score += 8 }
            }
            
            if let energy = currentEnergy, let itemEnergy = item.energyLevel {
                if energy == itemEnergy { score += 10 }
            } else if currentEnergy == .low, let mins = item.estimatedMinutes, mins <= 10 {
                score += 8
            }
            
            if let mins = item.estimatedMinutes, mins <= 10 && hour >= 14 { score += 5 }
            if item.hasAction { score += 3 }
            if item.hasDraft { score += 4 }
            
            // Time-of-day × category affinity
            let cat = item.resolvedCategory
            switch hour {
            case 5...10: if cat == .health || cat == .exercise || cat == .selfCare { score += 5 }
            case 11...14: if cat == .work || cat == .homework || cat == .appointment || cat == .finance { score += 4 }
            case 15...17: if cat == .errand || cat == .shopping || cat == .maintenance { score += 4 }
            case 18...21: if cat == .cooking || cat == .cleaning || cat == .creative || cat == .social { score += 5 }
            default: if cat == .selfCare || cat == .creative { score += 3 }
            }
            
            if let due = item.dueDate, calendar.isDateInTomorrow(due) { score += 12 }
            
            return (item, score)
        }
        
        if let settings, !settings.priorityCategories.isEmpty {
            let prioritySet = Set(settings.priorityCategories)
            scored = scored.map { entry in
                let boost: Double = prioritySet.contains(entry.item.resolvedCategory.rawValue) ? 6.0 : 0
                return (entry.item, entry.score + boost)
            }
        }
        
        scored.sort { $0.score > $1.score }
        return scored.map { $0.item }
    }
    
    /// Generate a short explanation of why this task was picked — Nudgy's gentle voice.
    static func reason(for item: NudgeItem) -> String {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        // Scheduled right now — highest priority reason
        if let scheduled = item.scheduledTime {
            let delta = scheduled.timeIntervalSince(now)
            if abs(delta) < 1800 {
                return String(localized: "this one's scheduled for right now")
            } else if delta > 0 && delta <= 7200 {
                let minsAway = Int(delta / 60)
                if minsAway > 60 {
                    let hrs = minsAway / 60
                    return String(localized: "coming up in about \(hrs) hour\(hrs == 1 ? "" : "s"). …get ready")
                }
                return String(localized: "coming up in \(minsAway) min. …get ready")
            }
        }
        
        if let due = item.dueDate, due < now {
            return String(localized: "this one's been waiting. …whenever you're ready 💙")
        }
        
        if let due = item.dueDate, calendar.isDateInToday(due) {
            let hoursLeft = Int(due.timeIntervalSince(now) / 3600)
            if hoursLeft <= 2 && hoursLeft > 0 {
                return String(localized: "due in \(hoursLeft) hour\(hoursLeft == 1 ? "" : "s"). …you've got this 💪")
            }
            return String(localized: "due today. …just this one for now 🐧")
        }
        
        if let due = item.dueDate, calendar.isDateInTomorrow(due) {
            return String(localized: "due tomorrow. …getting ahead feels good ✨")
        }
        
        if item.ageInDays >= 5 {
            return String(localized: "been sitting \(item.ageInDays) days. …maybe today’s the day? 🧊")
        }
        
        if let mins = item.estimatedMinutes, mins <= 10 {
            return String(localized: "a quick one — \(mins) minutes or less ✨")
        }
        
        if item.hasDraft {
            return String(localized: "draft’s already done. …just needs a send 📬")
        }
        
        if let scheduled = item.scheduledTime {
            let scheduledHour = calendar.component(.hour, from: scheduled)
            if abs(hour - scheduledHour) <= 1 {
                return String(localized: "this was meant for right about now ☕")
            }
        }
        
        // Category-specific whisper from template bank
        let cat = item.resolvedCategory
        if cat != .general {
            let whispers = item.categoryTemplate.nudgyWhispers
            if !whispers.isEmpty {
                // Deterministic but varied — pick based on item ID hash
                let index = abs(item.id.hashValue) % whispers.count
                return whispers[index]
            }
        }
        
        return String(localized: "this one feels right. …one thing at a time")
    }
}
