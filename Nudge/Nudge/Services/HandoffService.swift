//
//  HandoffService.swift
//  Nudge
//
//  NSUserActivity-based Handoff support.
//  When viewing a task on iPhone, the user can continue on iPad (and vice versa).
//  Also powers Spotlight "Siri Suggestions" for recently viewed tasks.
//
//  Activity types must be declared in Info.plist under NSUserActivityTypes.
//

import Foundation
import UIKit
import CoreSpotlight

/// Manages Handoff user activities for task continuity across devices.
enum HandoffService {
    
    // MARK: - Activity Types
    
    /// Viewing a specific task
    static let viewTaskActivity = "com.essaparacha.nudge.viewTask"
    /// Browsing the task queue
    static let browseQueueActivity = "com.essaparacha.nudge.browseQueue"
    /// Brain dump session
    static let brainDumpActivity = "com.essaparacha.nudge.brainDump"
    
    // MARK: - Create Activities
    
    /// Create a Handoff activity for viewing a specific task.
    @MainActor
    static func viewTaskUserActivity(for item: NudgeItem) -> NSUserActivity {
        let activity = NSUserActivity(activityType: viewTaskActivity)
        activity.title = item.content
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        
        // Store task ID for continuation
        activity.userInfo = [
            "taskID": item.id.uuidString,
            "taskContent": item.content
        ]
        
        // Deep link
        activity.webpageURL = nil
        activity.targetContentIdentifier = "nudge://viewTask?id=\(item.id.uuidString)"
        
        // Spotlight attributes
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = item.content
        attributes.contentDescription = buildDescription(for: item)
        attributes.relatedUniqueIdentifier = item.id.uuidString
        activity.contentAttributeSet = attributes
        
        // Expiration
        activity.expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        
        return activity
    }
    
    /// Create a Handoff activity for browsing the queue.
    @MainActor
    static func browseQueueUserActivity(activeCount: Int) -> NSUserActivity {
        let activity = NSUserActivity(activityType: browseQueueActivity)
        activity.title = String(localized: "Nudge Queue (\(activeCount) tasks)")
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPrediction = true
        
        activity.userInfo = ["activeCount": activeCount]
        activity.targetContentIdentifier = "nudge://nudges"
        
        return activity
    }
    
    /// Create a Handoff activity for brain dump.
    @MainActor
    static func brainDumpUserActivity() -> NSUserActivity {
        let activity = NSUserActivity(activityType: brainDumpActivity)
        activity.title = String(localized: "Unload")
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPrediction = true
        
        activity.targetContentIdentifier = "nudge://brainDump"
        
        return activity
    }
    
    // MARK: - Handle Continuation
    
    /// Parse a received NSUserActivity and return the deep link URL to handle.
    @MainActor
    static func handleContinuation(_ activity: NSUserActivity) -> URL? {
        switch activity.activityType {
        case viewTaskActivity:
            if let taskID = activity.userInfo?["taskID"] as? String {
                return URL(string: "nudge://viewTask?id=\(taskID)")
            }
        case browseQueueActivity:
            return URL(string: "nudge://nudges")
        case brainDumpActivity:
            return URL(string: "nudge://brainDump")
        default:
            break
        }
        return nil
    }
    
    // MARK: - Helpers
    
    private static func buildDescription(for item: NudgeItem) -> String {
        var parts: [String] = []
        
        if let contact = item.contactName, !contact.isEmpty {
            parts.append(contact)
        }
        if let actionType = item.actionType {
            parts.append(actionType.label)
        }
        if let dur = item.durationLabel {
            parts.append(dur)
        }
        if item.isStale {
            parts.append(String(localized: "\(item.ageInDays) days old"))
        }
        
        return parts.isEmpty ? String(localized: "Nudge task") : parts.joined(separator: " • ")
    }
}
