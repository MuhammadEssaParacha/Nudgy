//
//  BrainDump.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftData
import Foundation

@Model
final class BrainDump {
    
    var id: UUID = UUID()
    var rawTranscript: String = ""
    var processedAt: Date = Date()
    
    /// Relationship to the NudgeItems created from this dump
    @Relationship(deleteRule: .nullify, inverse: \NudgeItem.brainDump)
    var items: [NudgeItem] = []
    
    init(rawTranscript: String, items: [NudgeItem] = []) {
        self.id = UUID()
        self.rawTranscript = rawTranscript
        self.processedAt = Date()
        self.items = items
    }
    
    /// Number of tasks extracted from this dump
    var taskCount: Int { items.count }
    
    /// Whether this dump was a single item (no AI splitting needed)
    var wasSingleItem: Bool { items.count <= 1 }
}
