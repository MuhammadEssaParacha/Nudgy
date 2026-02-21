//
//  ContentView.swift
//  Nudge
//
//  Root view — iOS 26 native TabView with liquid glass dock.
//  Three tabs: Today (OneThingView), Inbox (NudgyInboxView), Settings.
//  Brain dump is accessed via Nudgy penguin tap — not a tab.
//

import SwiftUI
import CoreSpotlight
import SwiftData
import os

// MARK: - Tab Definition

enum NudgeTab: Int, Hashable {
    case nudgy      = 0
    case nudges     = 1
    case you        = 2
}

// MARK: - Selected Tab Environment

private struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: NudgeTab = .nudgy
}

extension EnvironmentValues {
    var selectedTab: NudgeTab {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

// MARK: - Root View

struct ContentView: View {
    @State private var selectedTab: NudgeTab = .nudgy
    @State private var showBrainDump = false
    @State private var activeItemCount: Int = 0
    @State private var hasOverdueTasks: Bool = false
    @State private var allClear: Bool = false
    @State private var repository: NudgeRepository?
    
    // Option A: Tab bar Nudgy chomp
    @State private var showTabChomp = false
    @State private var tabChompSpecies: FishSpecies? = nil
    
    // Option C: Pending fish for penguin tab
    @State private var pendingFishCount: Int = 0

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    
    /// Smart badge: show exact count for 1-3, cap at 3 for 4+ (avoids overwhelm).
    /// ADHD users respond to manageable numbers, not large counts.
    private var smartBadge: Int {
        if activeItemCount == 0 { return 0 }
        return min(activeItemCount, 3)
    }
    
    /// Dynamic icon for the Nudges tab based on task state.
    private var nudgesTabIcon: String {
        if allClear { return "checkmark.circle" }
        if hasOverdueTasks { return "bell.badge" }
        return "sparkles"
    }
    
    /// Dynamic icon for Nudgy tab based on penguin expression.
    private var nudgyTabExpression: PenguinExpression {
        penguinState.expression
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab(value: NudgeTab.nudgy) {
                    NudgyHomeView()
                } label: {
                    Label {
                        Text(String(localized: "Nudgy"))
                    } icon: {
                        Image("PenguinTab")
                            .renderingMode(.template)
                    }
                }

                Tab(String(localized: "Nudges"), systemImage: nudgesTabIcon, value: NudgeTab.nudges) {
                    NudgesPageView()
                }
                .badge(smartBadge)

                Tab(String(localized: "You"), systemImage: "person.fill", value: NudgeTab.you) {
                    YouView()
                }
            }
            
            // Capture bar — available on Nudgy + Nudges tabs.
            // ADHD principle: capture the thought before it evaporates.
            if selectedTab != .you {
                NudgyCaptureBar {
                    refreshActiveCount()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
            
            // Option A: Tab bar Nudgy chomp overlay
            if showTabChomp {
                GeometryReader { geo in
                    TabBarNudgyChomp(isActive: $showTabChomp, species: tabChompSpecies)
                        .position(
                            x: geo.size.width / 6, // ~first tab position
                            y: geo.size.height - 60
                        )
                }
                .allowsHitTesting(false)
                .zIndex(999)
            }
        } // end ZStack
        .environment(\.selectedTab, selectedTab)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showBrainDump) {
            BrainDumpView(isPresented: $showBrainDump)
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeOpenBrainDump)) { _ in
            showBrainDump = true
        }
        // .nudgeOpenQuickAdd and .nudgeOpenChat are now handled
        // by NudgyCaptureBar directly — no need to route here.
        .onReceive(NotificationCenter.default.publisher(for: .nudgeDataChanged)) { _ in
            refreshActiveCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeSwitchToNudges)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedTab = .nudges
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeNotificationAction)) { notification in
            handleNotificationAction(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            WidgetDataService.processPendingActions(using: modelContext)
            refreshActiveCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeAddToCalendar)) { notification in
            handleAddToCalendar(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeTabChomp)) { notification in
            // Option A: Tab bar Nudgy chomp when task completed on Nudges tab
            if let speciesName = notification.userInfo?["species"] as? String {
                tabChompSpecies = FishSpecies.allCases.first { $0.label == speciesName }
            } else {
                tabChompSpecies = .catfish
            }
            showTabChomp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgePendingFish)) { notification in
            // Option C: Accumulate pending fish for penguin tab
            let count = notification.userInfo?["count"] as? Int ?? 1
            pendingFishCount += count
            penguinState.pendingFishToMunch += count
        }
        .onAppear {
            setupRepository()
            refreshActiveCount()
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            // Tactile feedback on tab switch — ice tap sound + soft haptic
            if oldTab != newTab {
                SoundService.shared.playTabSwitch()
                HapticService.shared.swipeSkip()
            }
            refreshActiveCount()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            // Handle Spotlight search result tap
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let _ = UUID(uuidString: identifier) else { return }
            // Navigate to the task
            selectedTab = .nudges
            NotificationCenter.default.post(
                name: .nudgeNotificationAction,
                object: nil,
                userInfo: ["action": "view", "itemID": identifier]
            )
        }
        // Handoff: continue viewing a task from another device
        .onContinueUserActivity(HandoffService.viewTaskActivity) { activity in
            if let url = HandoffService.handleContinuation(activity) {
                handleDeepLink(url)
            }
        }
        .onContinueUserActivity(HandoffService.browseQueueActivity) { activity in
            if let url = HandoffService.handleContinuation(activity) {
                handleDeepLink(url)
            }
        }
        .onContinueUserActivity(HandoffService.brainDumpActivity) { activity in
            if let url = HandoffService.handleContinuation(activity) {
                handleDeepLink(url)
            }
        }
    }

    // MARK: - Helpers

    private func setupRepository() {
        if repository == nil {
            repository = NudgeRepository(modelContext: modelContext)
        }
    }

    private func refreshActiveCount() {
        setupRepository()
        let activeQueue = repository?.fetchActiveQueue() ?? []
        activeItemCount = activeQueue.count
        hasOverdueTasks = activeQueue.contains { $0.accentStatus == .overdue }
        allClear = activeQueue.isEmpty
        updateLiveActivity(queue: activeQueue)
    }
    
    // MARK: - Live Activity
    
    private func updateLiveActivity(queue: [NudgeItem]) {
        guard settings.liveActivityEnabled else {
            // If user disabled, end any running activity
            if LiveActivityManager.shared.isRunning {
                Task { await LiveActivityManager.shared.endAll() }
            }
            return
        }
        
        guard let topItem = queue.first else {
            // No active tasks — end activity
            Task { await LiveActivityManager.shared.endIfEmpty() }
            return
        }
        
        let emoji = topItem.emoji ?? "pin.fill"
        let accentHex: String
        switch topItem.accentStatus {
        case .stale:    accentHex = "FFB800"
        case .overdue:  accentHex = "FF453A"
        case .complete: accentHex = "30D158"
        case .active:   accentHex = "0A84FF"
        }
        
        let cat = topItem.resolvedCategory
        let catLabel = cat != .general ? cat.label : nil
        let catHex = cat != .general ? cat.primaryColorHex : nil
        
        if LiveActivityManager.shared.isRunning {
            // Update existing
            Task {
                await LiveActivityManager.shared.update(
                    taskContent: topItem.content,
                    taskEmoji: emoji,
                    queuePosition: 1,
                    queueTotal: queue.count,
                    accentHex: accentHex,
                    taskID: topItem.id.uuidString,
                    categoryLabel: catLabel,
                    categoryColorHex: catHex
                )
            }
        } else {
            // Start new
            Task {
                await LiveActivityManager.shared.start(
                    taskContent: topItem.content,
                    taskEmoji: emoji,
                    queuePosition: 1,
                    queueTotal: queue.count,
                    accentHex: accentHex,
                    taskID: topItem.id.uuidString,
                    categoryLabel: catLabel,
                    categoryColorHex: catHex
                )
            }
        }
    }

    /// Handle actions from notification taps
    private func handleNotificationAction(_ notification: Foundation.Notification) {
        guard let action = notification.userInfo?["action"] as? String,
              let itemIDString = notification.userInfo?["itemID"] as? String,
              let itemID = UUID(uuidString: itemIDString) else { return }

        setupRepository()

        let allItems = repository?.fetchActiveQueue() ?? []
        let snoozed = repository?.fetchSnoozed() ?? []
        guard let item = (allItems + snoozed).first(where: { $0.id == itemID }) else { return }

        switch action {
        case "markDone":
            repository?.markDone(item)
            HapticService.shared.completionHaptic(for: item.resolvedCategory)
        case "snoozeTomorrow":
            repository?.snooze(item, until: .tomorrowMorning)
        case "call":
            ActionService.perform(action: .call, item: item)
        case "text":
            ActionService.perform(action: .text, item: item)
        case "view":
            selectedTab = .nudges
        default:
            break
        }

        refreshActiveCount()
    }

    private func handleAddToCalendar(_ notification: Foundation.Notification) {
        guard let itemIDString = notification.userInfo?["itemID"] as? String,
              let itemID = UUID(uuidString: itemIDString) else { return }

        setupRepository()
        let allItems = repository?.fetchActiveQueue() ?? []
        guard let item = allItems.first(where: { $0.id == itemID }) else { return }

        Task {
            if let eventID = await CalendarService.shared.createEvent(from: item) {
                HapticService.shared.swipeDone()
                Log.ui.info("Created calendar event: \(eventID)")
            } else {
                HapticService.shared.error()
                Log.ui.error("Failed to create calendar event for item: \(item.content)")
            }
        }
    }

    /// Handle deep links
    private func handleDeepLink(_ url: URL) {
        guard let scheme = url.scheme, scheme == "nudge" else { return }
        
        // Parse query parameters for action deep links
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let itemID = components?.queryItems?.first(where: { $0.name == "id" })?.value

        switch url.host {
        case "brainDump":
            showBrainDump = true
        case "quickAdd":
            // Route through capture bar via notification
            NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
        case "viewTask", "nudges":
            selectedTab = .nudges
        case "allItems", "inbox":
            selectedTab = .nudges
        case "settings", "you":
            selectedTab = .you
        case "chat", "nudgy":
            selectedTab = .nudgy
        case "markDone":
            if let itemID, let uuid = UUID(uuidString: itemID) {
                handleDeepLinkAction(action: "markDone", itemID: uuid)
            }
        case "snooze":
            if let itemID, let uuid = UUID(uuidString: itemID) {
                handleDeepLinkAction(action: "snoozeTomorrow", itemID: uuid)
            }
        default:
            break
        }
    }
    
    /// Handle action deep links from Dynamic Island / Live Activity buttons
    private func handleDeepLinkAction(action: String, itemID: UUID) {
        setupRepository()
        
        let allItems = repository?.fetchActiveQueue() ?? []
        let snoozed = repository?.fetchSnoozed() ?? []
        guard let item = (allItems + snoozed).first(where: { $0.id == itemID }) else { return }
        
        switch action {
        case "markDone":
            repository?.markDone(item)
            HapticService.shared.completionHaptic(for: item.resolvedCategory)
            SoundService.shared.playTaskDone()
        case "snoozeTomorrow":
            repository?.snooze(item, until: .tomorrowMorning)
            HapticService.shared.swipeSnooze()
        default:
            break
        }
        
        refreshActiveCount()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        selectedTab = .nudges
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [NudgeItem.self, BrainDump.self], inMemory: true)
        .environment(AppSettings())
        .environment(PenguinState())
}
