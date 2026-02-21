//
//  NotificationService.swift
//  Nudge
//
//  UNUserNotificationCenter wrapper — schedules, cancels, and handles notification actions.
//  Supports: snoozed item resurfacing, stale item check-ins, end-of-day prompts.
//  Registers custom "nudge-knock" notification sound + action categories.
//

import UserNotifications
import UIKit
import Intents
import os

final class NotificationService: NSObject {
    
    static let shared = NotificationService()
    
    // MARK: - Categories
    
    enum Category: String {
        case snoozedItem     = "SNOOZED_ITEM"
        case staleItem       = "STALE_ITEM"
        case endOfDay        = "END_OF_DAY"
    }
    
    // MARK: - Actions
    
    enum Action: String {
        case callNow         = "CALL_NOW"
        case sendText        = "SEND_TEXT"
        case openLink        = "OPEN_LINK"
        case snoozeTomorrow  = "SNOOZE_TOMORROW"
        case markDone        = "MARK_DONE"
        case viewItem        = "VIEW_ITEM"
    }
    
    // MARK: - Notification Templates
    
    private let staleTemplates: [String] = [
        String(localized: "You've had \"%@\" for %d days. Want to do it now or let it go?"),
        String(localized: "\"%@\" has been waiting %d days. Quick 5-minute sprint?"),
        String(localized: "Hey — \"%@\" is still here (%d days). Tackle it or drop it?"),
        String(localized: "\"%@\" — %d days old. Maybe today's the day?"),
        String(localized: "Still thinking about \"%@\"? It's been %d days."),
    ]
    
    private let endOfDayTemplates: [String] = [
        String(localized: "You've got one big thing left. 15-minute sprint?"),
        String(localized: "Almost done for today — one more item to go."),
        String(localized: "Quick win available before you wrap up for the night."),
        String(localized: "One thing left on your plate. You've got this."),
    ]
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    /// Request notification permission and register categories.
    /// Call on first snooze or brain dump.
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            
            if granted {
                registerCategories()
            }
            
            return granted
        } catch {
            Log.notify.error("Notification permission error: \(error, privacy: .public)")
            return false
        }
    }
    
    /// Register notification action categories
    private func registerCategories() {
        let center = UNUserNotificationCenter.current()
        
        // Snoozed item: actionable buttons based on item type
        let snoozedActions = [
            UNNotificationAction(
                identifier: Action.viewItem.rawValue,
                title: String(localized: "View"),
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: Action.snoozeTomorrow.rawValue,
                title: String(localized: "Tomorrow"),
                options: [.destructive]
            ),
        ]
        
        // Snoozed item with call action
        let snoozedCallActions = [
            UNNotificationAction(
                identifier: Action.callNow.rawValue,
                title: String(localized: "Call Now"),
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: Action.sendText.rawValue,
                title: String(localized: "Send Text"),
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: Action.snoozeTomorrow.rawValue,
                title: String(localized: "Tomorrow"),
                options: [.destructive]
            ),
        ]
        
        // Stale item
        let staleActions = [
            UNNotificationAction(
                identifier: Action.markDone.rawValue,
                title: String(localized: "Done"),
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: Action.snoozeTomorrow.rawValue,
                title: String(localized: "Tomorrow"),
                options: [.destructive]
            ),
        ]
        
        // Alarm
        let alarmActions = [
            UNNotificationAction(
                identifier: Action.viewItem.rawValue,
                title: String(localized: "View Task"),
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "SNOOZE_5MIN",
                title: String(localized: "Snooze 5 min"),
                options: []
            ),
            UNNotificationAction(
                identifier: Action.markDone.rawValue,
                title: String(localized: "Done"),
                options: [.foreground]
            ),
        ]
        
        // End of day
        let eodActions = [
            UNNotificationAction(
                identifier: Action.viewItem.rawValue,
                title: String(localized: "Let's do it"),
                options: [.foreground]
            ),
        ]
        
        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(
                identifier: Category.snoozedItem.rawValue,
                actions: snoozedActions,
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: "SNOOZED_ITEM_CALL",
                actions: snoozedCallActions,
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.staleItem.rawValue,
                actions: staleActions,
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.endOfDay.rawValue,
                actions: eodActions,
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: "ALARM",
                actions: alarmActions,
                intentIdentifiers: []
            ),
        ]
        
        center.setNotificationCategories(categories)
        center.delegate = self
    }
    
    // MARK: - Communication Notification Helper
    
    /// Wrap a notification as a communication notification from Nudgy.
    /// This makes the notification appear with Nudgy's avatar, styled like a message.
    private func wrapAsCommunication(_ content: UNMutableNotificationContent) -> UNMutableNotificationContent {
        let handle = INPersonHandle(value: "nudgy", type: .unknown)
        let nudgy = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: "Nudgy 🐧",
            image: nil,
            contactIdentifier: nil,
            customIdentifier: "nudgy-penguin"
        )
        
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: content.body,
            speakableGroupName: nil,
            conversationIdentifier: "nudgy-conversation",
            serviceName: nil,
            sender: nudgy,
            attachments: nil
        )
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        // Donate the interaction (fire-and-forget)
        interaction.donate()
        
        // Update the content with the communication intent
        if let updated = try? content.updating(from: intent) as? UNMutableNotificationContent {
            return updated
        }
        return content
    }
    
    // MARK: - Schedule Snoozed Item Notification
    
    func scheduleSnoozedNotification(for item: NudgeItem, settings: AppSettings? = nil) {
        guard let snoozedUntil = item.snoozedUntil else { return }
        
        // Per-category notification gating
        if let settings {
            guard settings.isCategoryNotificationEnabled(item.resolvedCategory) else { return }
        }
        
        let content = UNMutableNotificationContent()
        
        // Category-aware notification title
        let cat = item.resolvedCategory
        switch cat {
        case .call:        content.title = String(localized: "Time to make that call")
        case .text:        content.title = String(localized: "Quick text waiting")
        case .email:       content.title = String(localized: "Email reminder")
        case .cooking:     content.title = String(localized: "Cooking time!")
        case .cleaning:    content.title = String(localized: "Quick tidy reminder")
        case .exercise:    content.title = String(localized: "Time to move")
        case .health:      content.title = String(localized: "Health reminder")
        case .finance:     content.title = String(localized: "Finance check-in")
        case .work:        content.title = String(localized: "Work nudge")
        case .homework:    content.title = String(localized: "Study time")
        case .shopping:    content.title = String(localized: "Shopping reminder")
        case .errand:      content.title = String(localized: "Errand time")
        case .selfCare:    content.title = String(localized: "Self-care moment")
        case .social:      content.title = String(localized: "Social reminder")
        case .creative:    content.title = String(localized: "Creative time")
        case .appointment: content.title = String(localized: "Appointment reminder")
        case .maintenance: content.title = String(localized: "Fix & build time")
        case .alarm:       content.title = String(localized: "Alarm reminder")
        case .link:        content.title = String(localized: "Link to check")
        case .general:     content.title = String(localized: "Time to nudge")
        }
        content.body = item.content
        content.userInfo = ["itemID": item.id.uuidString]
        
        // Custom notification sound (falls back to default if .caf missing)
        if let _ = Bundle.main.url(forResource: "nudge-knock", withExtension: "caf") {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("nudge-knock.caf"))
        } else {
            content.sound = .default
        }
        
        // Use call-specific category if item has call action
        if item.actionType == .call || item.actionType == .text {
            content.categoryIdentifier = "SNOOZED_ITEM_CALL"
        } else {
            content.categoryIdentifier = Category.snoozedItem.rawValue
        }
        
        content.interruptionLevel = .timeSensitive
        
        // Wrap as communication-style notification from Nudgy
        let finalContent = wrapAsCommunication(content)
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: snoozedUntil
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "snooze-\(item.id.uuidString)",
            content: finalContent,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Schedule Stale Item Notification
    
    func scheduleStaleNotification(for item: NudgeItem, settings: AppSettings) {
        // Per-category notification gating
        guard settings.isCategoryNotificationEnabled(item.resolvedCategory) else { return }
        
        // Check if delivery time (30 min from now) would be during quiet hours
        let deliveryTime = Date().addingTimeInterval(1800)
        guard !settings.isDateInQuietHours(deliveryTime) else { return }
        
        // Check daily nudge cap
        let todayKey = "nudgesSentToday"
        let resetKey = "nudgesResetDate"
        let calendar = Calendar.current
        let lastReset = (UserDefaults.standard.object(forKey: resetKey) as? Date) ?? .distantPast
        if !calendar.isDateInToday(lastReset) {
            UserDefaults.standard.set(0, forKey: todayKey)
            UserDefaults.standard.set(Date(), forKey: resetKey)
        }
        let sentToday = UserDefaults.standard.integer(forKey: todayKey)
        guard sentToday < settings.maxDailyNudges else { return }
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Gentle nudge")
        
        let template = staleTemplates.randomElement() ?? staleTemplates[0]
        let baseBody = String(format: template, item.content, item.ageInDays)
        
        // Prefix with category emoji for context
        let cat = item.resolvedCategory
        if cat != .general {
            content.body = "\(cat.label): \(baseBody)"
        } else {
            content.body = baseBody
        }
        content.categoryIdentifier = Category.staleItem.rawValue
        content.userInfo = ["itemID": item.id.uuidString]
        
        // Custom notification sound
        if let _ = Bundle.main.url(forResource: "nudge-knock", withExtension: "caf") {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("nudge-knock.caf"))
        } else {
            content.sound = .default
        }
        
        content.interruptionLevel = .timeSensitive
        
        // Wrap as communication-style notification from Nudgy
        let finalContent = wrapAsCommunication(content)
        
        // Schedule for 30 minutes from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1800, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "stale-\(item.id.uuidString)",
            content: finalContent,
            trigger: trigger
        )
        
        // Increment sent counter
        UserDefaults.standard.set(sentToday + 1, forKey: todayKey)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Schedule End-of-Day Prompt
    
    func scheduleEndOfDayPrompt(remainingCount: Int, settings: AppSettings, remainingItems: [NudgeItem] = []) {
        guard remainingCount > 0 else { return }
        
        // Build 4pm today
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 16
        components.minute = 0
        
        guard let targetDate = calendar.date(from: components) else { return }
        
        // If 4pm already passed today, skip (don't schedule in the past)
        guard targetDate > Date() else { return }
        
        // If 4pm falls in quiet hours, skip
        guard !settings.isDateInQuietHours(targetDate) else { return }
        
        let content = UNMutableNotificationContent()
        
        // Category-aware title and body
        if !remainingItems.isEmpty {
            let catCounts = Dictionary(grouping: remainingItems, by: { $0.resolvedCategory })
                .mapValues(\.count)
                .sorted { $0.value > $1.value }
            content.title = String(localized: "\(remainingCount) nudges left")
            let catSummary = catCounts.prefix(3)
                .map { "\($0.value) \($0.key.label.lowercased())" }
                .joined(separator: ", ")
            content.body = String(localized: "\(catSummary) — any quick wins before bed?")
        } else {
            content.title = String(localized: "Almost there")
            content.body = endOfDayTemplates.randomElement() ?? endOfDayTemplates[0]
        }
        content.categoryIdentifier = Category.endOfDay.rawValue
        content.sound = .default
        
        // Wrap as communication-style notification from Nudgy
        let finalContent = wrapAsCommunication(content)
        
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "eod-\(Date().formatted(.iso8601.year().month().day()))",
            content: finalContent,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Schedule Alarm Notification
    
    /// Schedule a loud alarm-style notification for a NudgeItem at the given date.
    /// Uses the longest-duration system sound to mimic an alarm.
    func scheduleAlarm(for item: NudgeItem, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "⏰ Alarm — Nudge")
        content.body = item.content
        content.userInfo = ["itemID": item.id.uuidString, "isAlarm": true]
        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .timeSensitive
        
        // Use custom alarm sound if available, otherwise use the loudest default
        if let _ = Bundle.main.url(forResource: "nudge-alarm", withExtension: "caf") {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("nudge-alarm.caf"))
        } else {
            content.sound = UNNotificationSound.defaultCritical
        }
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "alarm-\(item.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
        Log.notify.debug("Alarm scheduled for \(item.content) at \(date)")
    }
    
    /// Cancel a scheduled alarm for an item.
    func cancelAlarm(for itemID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["alarm-\(itemID.uuidString)"]
        )
    }
    
    // MARK: - Cancel
    
    func cancelNotification(for itemID: UUID) {
        let identifiers = [
            "snooze-\(itemID.uuidString)",
            "stale-\(itemID.uuidString)",
            "alarm-\(itemID.uuidString)",
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
    
    /// Handle notification action tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let itemIDString = userInfo["itemID"] as? String
        
        let action: String
        
        switch response.actionIdentifier {
        case Action.callNow.rawValue:
            action = "call"
        case Action.sendText.rawValue:
            action = "text"
        case Action.snoozeTomorrow.rawValue:
            action = "snoozeTomorrow"
        case Action.markDone.rawValue:
            action = "markDone"
        case "SNOOZE_5MIN":
            // Re-schedule the alarm 5 minutes from now
            if let itemID = itemIDString,
               let content = response.notification.request.content.mutableCopy() as? UNMutableNotificationContent {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "alarm-\(itemID)",
                    content: content,
                    trigger: trigger
                )
                do {
                    try await UNUserNotificationCenter.current().add(request)
                } catch {
                    Log.notify.error("Failed to re-schedule snoozed alarm: \(error, privacy: .public)")
                }
            }
            return
        case Action.viewItem.rawValue, UNNotificationDefaultActionIdentifier:
            action = "view"
        default:
            return
        }
        
        // Post on the main thread — NotificationCenter observers expect it
        await MainActor.run {
            NotificationCenter.default.post(
                name: .nudgeNotificationAction,
                object: nil,
                userInfo: ["action": action, "itemID": itemIDString ?? ""]
            )
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let nudgeNotificationAction = Notification.Name("nudgeNotificationAction")
}
