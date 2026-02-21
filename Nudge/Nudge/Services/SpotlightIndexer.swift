//
//  SpotlightIndexer.swift
//  Nudge
//
//  Indexes active tasks in Core Spotlight so they appear
//  in system-wide search. Tapping a Spotlight result deep-links
//  to the task via nudge://viewTask?id=UUID.
//
//  Called from NudgeApp.onForeground() and after data changes.
//

@preconcurrency import CoreSpotlight
import MobileCoreServices
import Foundation
import os

/// Indexes NudgeItem tasks in Core Spotlight for system search.
enum SpotlightIndexer {
    
    private static let domainIdentifier = "com.essaparacha.nudge.tasks"
    
    /// Index all active tasks. Replaces any previous index.
    @MainActor
    static func indexAllTasks(from repository: NudgeRepository) {
        let activeItems = repository.fetchActiveQueue()
        let snoozedItems = repository.fetchSnoozed()
        let allItems = activeItems + snoozedItems
        
        let searchableItems = allItems.map { item -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = item.content
            attributeSet.contentDescription = buildDescription(for: item)
            attributeSet.keywords = buildKeywords(for: item)
            
            // Deep link via URL
            attributeSet.relatedUniqueIdentifier = item.id.uuidString
            
            // Thumbnail based on action type
            if let actionType = item.actionType {
                attributeSet.thumbnailData = nil // SF Symbols can't be set as data
                attributeSet.contentDescription = "\(actionType.label) • \(attributeSet.contentDescription ?? "")"
            }
            
            return CSSearchableItem(
                uniqueIdentifier: item.id.uuidString,
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
        }
        
        // Delete old index, then add new
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error {
                Log.services.warning("Spotlight delete error: \(error, privacy: .public)")
            }
            
            CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
                if let error {
                    Log.services.warning("Spotlight index error: \(error, privacy: .public)")
                } else {
                    Log.services.debug("Spotlight: indexed \(searchableItems.count) tasks")
                }
            }
        }
    }
    
    /// Remove a specific task from the index (when completed or deleted).
    static func removeTask(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [id.uuidString]
        ) { _ in }
    }
    
    /// Remove all tasks from the index.
    static func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [domainIdentifier]
        ) { _ in }
    }
    
    // MARK: - Helpers
    
    private static func buildDescription(for item: NudgeItem) -> String {
        var parts: [String] = []
        
        // Category label
        let cat = item.resolvedCategory
        if cat != .general {
            parts.append("\(cat.emoji) \(cat.label)")
        }
        
        if let contact = item.contactName, !contact.isEmpty {
            parts.append(contact)
        }
        if let dur = item.durationLabel {
            parts.append(dur)
        }
        if item.isStale {
            parts.append("\(item.ageInDays) days old")
        }
        if let due = item.dueDate {
            parts.append("due \(due.formatted(.dateTime.month(.abbreviated).day()))")
        }
        if item.status == .snoozed, let until = item.snoozedUntil {
            parts.append("snoozed until \(until.formatted(.dateTime.hour().minute()))")
        }
        
        return parts.joined(separator: " • ")
    }
    
    private static func buildKeywords(for item: NudgeItem) -> [String] {
        var keywords = item.content.split(separator: " ").map(String.init)
        
        if let contact = item.contactName {
            keywords.append(contact)
        }
        if let actionType = item.actionType {
            keywords.append(actionType.label)
        }
        
        // Category keyword for searching
        let cat = item.resolvedCategory
        if cat != .general {
            keywords.append(cat.label)
        }
        
        keywords.append("nudge")
        keywords.append("task")
        
        return keywords
    }
}
