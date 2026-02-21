//
//  ActionService.swift
//  Nudge
//
//  Opens phone calls, text messages, emails, and links.
//  SMS uses MFMessageComposeViewController for pre-filled body support.
//

import SwiftUI
import MessageUI

/// Central action launcher — routes tasks to Phone, Messages, Mail, Safari.
enum ActionService {
    
    /// Open Phone app with the given number.
    @MainActor
    static func openCall(number: String) {
        guard let url = URL(string: "tel:\(number.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? number)") else { return }
        HapticService.shared.actionButtonTap()
        UIApplication.shared.open(url)
    }
    
    /// Open a link in Safari.
    @MainActor
    static func openLink(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        HapticService.shared.actionButtonTap()
        UIApplication.shared.open(url)
    }
    
    /// Open Mail compose with optional subject and body.
    @MainActor
    static func openEmail(to: String, subject: String? = nil, body: String? = nil) {
        var components = URLComponents(string: "mailto:\(to)")
        var queryItems: [URLQueryItem] = []
        if let subject { queryItems.append(.init(name: "subject", value: subject)) }
        if let body { queryItems.append(.init(name: "body", value: body)) }
        if !queryItems.isEmpty { components?.queryItems = queryItems }
        
        guard let url = components?.url else { return }
        HapticService.shared.actionButtonTap()
        UIApplication.shared.open(url)
    }
    
    /// Whether the device can send text messages.
    static var canSendText: Bool {
        MFMessageComposeViewController.canSendText()
    }
    
    /// Route an action for a NudgeItem.
    /// If actionTarget is missing, attempts on-device contact resolution first,
    /// then posts `.nudgeNeedsContactPicker` if resolution fails.
    @MainActor
    static func perform(action: ActionType, item: NudgeItem) {
        if let target = item.actionTarget, !target.isEmpty {
            executeAction(action, target: target, item: item)
        } else if let contactName = item.contactName, !contactName.isEmpty {
            // Try to resolve contact name → phone/email on-device
            Task {
                let (target, resolvedName) = await ContactResolver.shared.resolveActionTarget(
                    name: contactName,
                    for: action
                )
                if let target, !target.isEmpty {
                    // Cache the resolved target on the item for next time
                    item.actionTarget = target
                    if let resolvedName { item.contactName = resolvedName }
                    executeAction(action, target: target, item: item)
                } else {
                    // Resolution failed — ask user to pick a contact
                    HapticService.shared.error()
                    NotificationCenter.default.post(
                        name: .nudgeNeedsContactPicker,
                        object: nil,
                        userInfo: [
                            "itemID": item.id.uuidString,
                            "actionType": action.rawValue
                        ]
                    )
                }
            }
        } else {
            // No target and no contact name — nothing to resolve
            HapticService.shared.error()
        }
    }
    
    /// Execute an action with a known target.
    @MainActor
    private static func executeAction(_ action: ActionType, target: String, item: NudgeItem) {
        switch action {
        case .call:
            openCall(number: target)
        case .email:
            openEmail(
                to: target,
                subject: item.aiDraftSubject,
                body: item.aiDraft
            )
        case .openLink:
            // Post notification to open in-app browser instead of Safari
            if let url = URL(string: target) {
                NotificationCenter.default.post(
                    name: .nudgeOpenBrowser,
                    object: nil,
                    userInfo: [
                        "url": url,
                        "itemID": item.id.uuidString
                    ]
                )
            } else {
                openLink(urlString: target)
            }
        case .text:
            // Text messages are handled via MessageComposeView (UIViewControllerRepresentable)
            // Post a notification so the view layer can present the compose sheet
            SoundService.shared.playSendMessage()
            NotificationCenter.default.post(
                name: .nudgeComposeMessage,
                object: nil,
                userInfo: [
                    "recipient": target,
                    "body": item.aiDraft ?? "",
                    "itemID": item.id.uuidString
                ]
            )
        case .search:
            // Generate smart URL and open in-app browser
            let actions = URLActionGenerator.generateActions(for: item.content, actionType: .search, actionTarget: target)
            if let first = actions.first {
                NotificationCenter.default.post(
                    name: .nudgeOpenBrowser,
                    object: nil,
                    userInfo: [
                        "url": first.url,
                        "itemID": item.id.uuidString
                    ]
                )
            }
        case .navigate:
            // Open in Apple Maps
            let actions = URLActionGenerator.generateActions(for: item.content, actionType: .navigate, actionTarget: target)
            if let first = actions.first {
                UIApplication.shared.open(first.url)
            }
        case .addToCalendar:
            // Post notification for calendar event creation
            NotificationCenter.default.post(
                name: .nudgeAddToCalendar,
                object: nil,
                userInfo: [
                    "content": item.content,
                    "itemID": item.id.uuidString
                ]
            )
        case .setAlarm:
            // Post notification for alarm picker presentation
            NotificationCenter.default.post(
                name: .nudgeSetAlarm,
                object: nil,
                userInfo: [
                    "content": item.content,
                    "itemID": item.id.uuidString,
                    "dueDate": (item.dueDate ?? item.scheduledTime) as Any
                ]
            )
        }
    }
    
    // MARK: - Smart Action Execution
    
    /// Execute a URLAction — opens in-app browser or system app.
    @MainActor
    static func executeURLAction(_ action: URLAction, for item: NudgeItem? = nil) {
        HapticService.shared.actionButtonTap()
        if action.openInApp {
            NotificationCenter.default.post(
                name: .nudgeOpenBrowser,
                object: nil,
                userInfo: [
                    "url": action.url,
                    "itemID": item?.id.uuidString ?? ""
                ]
            )
        } else {
            UIApplication.shared.open(action.url)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when ActionService needs to present MFMessageComposeViewController
    static let nudgeComposeMessage = Notification.Name("nudgeComposeMessage")
    
    /// Posted when a view wants to open the Brain Dump overlay
    static let nudgeOpenBrainDump = Notification.Name("nudgeOpenBrainDump")
    
    /// Posted when a view wants to open the Quick Add sheet
    static let nudgeOpenQuickAdd = Notification.Name("nudgeOpenQuickAdd")
    
    /// Posted when a view wants to open the Nudgy Chat sheet
    static let nudgeOpenChat = Notification.Name("nudgeOpenChat")
    
    /// Posted when data changes and badge/views should refresh
    static let nudgeDataChanged = Notification.Name("nudgeDataChanged")
    
    /// Posted when ActionService can't resolve a contact — view should show ContactPickerView
    static let nudgeNeedsContactPicker = Notification.Name("nudgeNeedsContactPicker")
    
    /// Posted when TTS was skipped (voice disabled) — voice conversation loop should auto-resume listening
    static let nudgyTTSSkipped = Notification.Name("nudgyTTSSkipped")
    
    /// Posted when a URL should be opened in the in-app browser
    static let nudgeOpenBrowser = Notification.Name("nudgeOpenBrowser")
    
    /// Posted when a task should be added to the calendar
    static let nudgeAddToCalendar = Notification.Name("nudgeAddToCalendar")
    
    /// Posted when an alarm should be set for a task
    static let nudgeSetAlarm = Notification.Name("nudgeSetAlarm")
    
    /// Posted when Nudgy wants to execute an action from chat (draft → send)
    static let nudgeChatExecuteAction = Notification.Name("nudgeChatExecuteAction")
    
    /// Posted when a follow-up nudge should be created after an action
    static let nudgeCreateFollowUp = Notification.Name("nudgeCreateFollowUp")
    
    /// Posted when the tab bar Nudgy should play a chomp animation (Option A)
    static let nudgeTabChomp = Notification.Name("nudgeTabChomp")
    
    /// Posted when fish are pending for the penguin tab to "munch" (Option C)
    static let nudgePendingFish = Notification.Name("nudgePendingFish")
    
    /// Posted to switch to the Nudges tab (e.g. after task creation)
    static let nudgeSwitchToNudges = Notification.Name("nudgeSwitchToNudges")

    /// Posted when a fish species evolves to a new stage.
    /// `object` is a `(species: FishSpecies, stage: FishEvolutionStage)` tuple.
    static let nudgeFishEvolved = Notification.Name("nudgeFishEvolved")
}

// MARK: - Message Compose View (UIViewControllerRepresentable)

/// SwiftUI wrapper for MFMessageComposeViewController.
/// Required because `sms:` URL scheme doesn't support pre-filled body.
struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinished: () -> Void = {}
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }
    
    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinished: () -> Void
        
        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }
        
        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)
            onFinished()
        }
    }
}
