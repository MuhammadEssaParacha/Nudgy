//
//  FollowUpService.swift
//  Nudge
//
//  Phase 15: Smart Follow-Ups.
//  After executing actions (calling, emailing, searching), Nudgy
//  auto-creates confirmation nudges:
//    "Did you order the towels?"
//    "Did Dr. Chen answer? Need to reschedule?"
//    "Did you find what you needed on Amazon?"
//
//  These follow-ups appear the next day as gentle check-ins.
//

import SwiftData
import os
import Foundation

// MARK: - Follow-Up Templates

enum FollowUpService {
    
    /// Generate a follow-up nudge for a completed action.
    /// Returns a new NudgeItem to be inserted, or nil if no follow-up needed.
    static func generateFollowUp(
        originalItem: NudgeItem,
        actionPerformed: ActionType,
        modelContext: ModelContext
    ) -> NudgeItem? {
        
        let content = originalItem.content
        let contactName = originalItem.contactName ?? ""
        
        let followUpContent: String
        let followUpEmoji: String
        let scheduledDelay: TimeInterval
        
        switch actionPerformed {
        case .call:
            if !contactName.isEmpty {
                followUpContent = String(localized: "Did \(contactName) answer? Any next steps?")
            } else {
                followUpContent = String(localized: "Did that call go well? Anything to follow up on?")
            }
            followUpEmoji = "📞"
            scheduledDelay = 3600 * 2  // 2 hours later
            
        case .text:
            if !contactName.isEmpty {
                followUpContent = String(localized: "Did \(contactName) reply? Need to follow up?")
            } else {
                followUpContent = String(localized: "Any reply to your message? Need to follow up?")
            }
            followUpEmoji = "💬"
            scheduledDelay = 3600 * 4  // 4 hours later
            
        case .email:
            if !contactName.isEmpty {
                followUpContent = String(localized: "Check for \(contactName)'s email reply")
            } else {
                followUpContent = String(localized: "Check for email replies")
            }
            followUpEmoji = "📧"
            scheduledDelay = 3600 * 24  // Next day
            
        case .search:
            // Extract what they were searching for
            let searchTerm = extractSearchSubject(from: content)
            followUpContent = String(localized: "Did you find \(searchTerm)? Need to order/buy it?")
            followUpEmoji = "🔍"
            scheduledDelay = 3600 * 6  // 6 hours later
            
        case .navigate:
            followUpContent = String(localized: "Did you make it there okay? Anything else needed?")
            followUpEmoji = "📍"
            scheduledDelay = 3600 * 3  // 3 hours later
            
        case .openLink:
            followUpContent = String(localized: "Did you finish what you needed online?")
            followUpEmoji = "🔗"
            scheduledDelay = 3600 * 4  // 4 hours later
            
        case .addToCalendar:
            followUpContent = String(localized: "Calendar event added — set a reminder to prepare?")
            followUpEmoji = "📅"
            scheduledDelay = 3600 * 24  // Next day
            
        default:
            // No follow-up for basic tasks
            return nil
        }
        
        // Create the follow-up item
        let followUp = NudgeItem(
            content: followUpContent,
            emoji: followUpEmoji
        )
        followUp.scheduledTime = Date().addingTimeInterval(scheduledDelay)
        followUp.priority = .low
        followUp.parentTaskContent = content
        
        return followUp
    }
    
    /// Check if a follow-up should be created for a task that was just completed.
    /// Returns true if the task had an external action type (call, email, search, etc.)
    static func shouldCreateFollowUp(for item: NudgeItem) -> Bool {
        guard let actionType = item.actionType else { return false }
        return actionType.isExternalAction || actionType.isCompositionAction
    }
    
    /// Create and save follow-up nudges for a completed task.
    /// Called from task completion flow.
    static func createFollowUpIfNeeded(
        for item: NudgeItem,
        modelContext: ModelContext
    ) {
        guard shouldCreateFollowUp(for: item),
              let actionType = item.actionType else { return }
        
        // Don't create follow-up if one already exists for this task
        let originalContent = item.content
        let activeStatus = "active"
        let allActive = FetchDescriptor<NudgeItem>(
            predicate: #Predicate<NudgeItem> { $0.statusRaw == activeStatus }
        )
        
        if let existing = try? modelContext.fetch(allActive),
           existing.contains(where: { $0.parentTaskContent == originalContent }) {
            return // Follow-up already exists
        }
        
        if let followUp = generateFollowUp(
            originalItem: item,
            actionPerformed: actionType,
            modelContext: modelContext
        ) {
            modelContext.insert(followUp)
            do { try modelContext.save() } catch { Log.services.error("[FollowUp] Save failed: \(error, privacy: .public)") }
        }
    }
    
    // MARK: - Helpers
    
    private static func extractSearchSubject(from content: String) -> String {
        let lower = content.lowercased()
        let prefixes = ["buy ", "order ", "find ", "search ", "look for ", "get ", "shop for "]
        for prefix in prefixes {
            if let range = lower.range(of: prefix) {
                return String(content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Fall back to the whole content
        return content
    }
}
