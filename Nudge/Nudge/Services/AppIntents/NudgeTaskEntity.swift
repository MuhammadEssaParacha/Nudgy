//
//  NudgeTaskEntity.swift
//  Nudge
//
//  AppEntity wrapping NudgeItem for the App Intents system.
//  Surfaces tasks in Shortcuts, Spotlight, Action Button,
//  and Control Center — 6 system surfaces without Siri voice.
//

import AppIntents
import SwiftData
import Foundation

/// An App Entity representing a Nudge task.
/// Enables Shortcuts actions, Spotlight indexing, and system-wide task operations.
struct NudgeTaskEntity: AppEntity {
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Task"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) tasks")
        )
    }
    
    static var defaultQuery = NudgeTaskQuery()
    
    var id: String // UUID string
    
    @Property(title: "Title")
    var title: String
    
    @Property(title: "Status")
    var status: String
    
    @Property(title: "Action Type")
    var actionType: String?
    
    @Property(title: "Contact")
    var contactName: String?
    
    @Property(title: "Due Date")
    var dueDate: Date?
    
    @Property(title: "Duration (minutes)")
    var estimatedMinutes: Int?
    
    @Property(title: "Priority")
    var priority: String?
    
    @Property(title: "Category")
    var categoryName: String?
    
    @Property(title: "Category Emoji")
    var categoryEmoji: String?
    
    @Property(title: "Created")
    var createdAt: Date
    
    var displayRepresentation: DisplayRepresentation {
        let catEmoji = categoryEmoji ?? ""
        let subtitle: String
        if let contact = contactName {
            subtitle = contact
        } else if let cat = categoryName, cat != "General" {
            subtitle = "\(catEmoji) \(cat)"
        } else if let dur = estimatedMinutes {
            subtitle = "\(dur) min"
        } else {
            subtitle = status.capitalized
        }
        
        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: LocalizedStringResource(stringLiteral: subtitle),
            image: .init(systemName: categoryEmoji != nil ? "tag.fill" : "circle")
        )
    }
    
    /// Create an entity from a NudgeItem.
    @MainActor
    init(from item: NudgeItem) {
        self.id = item.id.uuidString
        self.title = item.content
        self.status = item.statusRaw
        self.actionType = item.actionTypeRaw
        self.contactName = item.contactName
        self.dueDate = item.dueDate
        self.estimatedMinutes = item.estimatedMinutes
        self.priority = item.priorityRaw
        self.categoryName = item.resolvedCategory.label
        self.categoryEmoji = item.resolvedCategory.emoji
        self.createdAt = item.createdAt
    }
    
    init(id: String, title: String) {
        self.id = id
        self.title = title
        self.status = "active"
        self.createdAt = Date()
    }
}

// MARK: - Entity Query

/// Query for finding Nudge tasks — powers Shortcuts parameter resolution,
/// Spotlight search results, and entity pickers in the Shortcuts app.
struct NudgeTaskQuery: EntityQuery {
    
    @MainActor
    func entities(for identifiers: [String]) async throws -> [NudgeTaskEntity] {
        guard let container = IntentModelAccess.makeContainer() else {
            return []
        }
        
        let context = container.mainContext
        let uuids = identifiers.compactMap { UUID(uuidString: $0) }
        
        // Fetch all active items and filter by IDs
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: #Predicate { $0.statusRaw != "dropped" }
        )
        
        let items = (try? context.fetch(descriptor)) ?? []
        return items
            .filter { uuids.contains($0.id) }
            .map { NudgeTaskEntity(from: $0) }
    }
    
    @MainActor
    func suggestedEntities() async throws -> [NudgeTaskEntity] {
        guard let container = IntentModelAccess.makeContainer() else {
            return []
        }
        
        let context = container.mainContext
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: #Predicate { $0.statusRaw == "active" },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        
        let items = (try? context.fetch(descriptor)) ?? []
        return Array(items.prefix(10).map { NudgeTaskEntity(from: $0) })
    }
}

// MARK: - String Search Extension

extension NudgeTaskQuery: EntityStringQuery {
    
    @MainActor
    func entities(matching string: String) async throws -> [NudgeTaskEntity] {
        guard let container = IntentModelAccess.makeContainer() else {
            return []
        }
        
        let context = container.mainContext
        let searchText = string.lowercased()
        
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: #Predicate { $0.statusRaw == "active" },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        
        let items = (try? context.fetch(descriptor)) ?? []
        return items
            .filter {
                $0.content.lowercased().contains(searchText) ||
                $0.resolvedCategory.label.lowercased().contains(searchText) ||
                $0.resolvedCategory.emoji.contains(searchText)
            }
            .prefix(10)
            .map { NudgeTaskEntity(from: $0) }
    }
}
