//
//  OneThingView.swift
//  Nudge
//
//  The main screen — penguin character center stage.
//  The penguin presents ONE task at a time via speech bubble + compact card.
//  Swipe the card to act. Anti-list, anti-overwhelm.
//

import SwiftUI
import SwiftData
import TipKit
import os

struct OneThingView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    
    @State private var repository: NudgeRepository?
    @State private var activeQueue: [NudgeItem] = []
    @State private var currentIndex = 0
    @State private var showSnoozePicker = false
    @State private var showMessageCompose = false
    @State private var messageRecipient = ""
    @State private var messageBody = ""
    
    // Undo state
    @State private var undoItem: NudgeItem?
    @State private var undoPreviousSortOrder: Int = 0
    @State private var showUndoToast = false
    @State private var undoTimerTask: Task<Void, Never>?
    @State private var hasPlayedAllClear = false
    @State private var hasGreeted = false
    @State private var showNudgyChat = false
    @State private var showBreakdown = false
    @State private var showPrioritySuggestion = false
    @State private var prioritySuggestion: PrioritySuggestion?
    @State private var isPriorityLoading = false
    @State private var showContactPicker = false
    @State private var pendingContactActionItemID: UUID?
    @State private var pendingContactActionType: ActionType?
    
    // Task transition celebration overlay
    @State private var showTransitionOverlay = false
    @State private var completedTaskContent: String = ""
    @State private var completedTaskEmoji: String = "checkmark"
    @State private var completedTaskCategory: TaskCategory = .general
    @State private var nextTaskContent: String?
    @State private var nextTaskEmoji: String?
    @State private var nextTaskCategory: TaskCategory = .general
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let brainDumpTip = BrainDumpTip()
    private let swipeRightTip = SwipeRightTip()
    
    // MARK: - Current Item
    
    private var currentItem: NudgeItem? {
        guard currentIndex < activeQueue.count else { return nil }
        return activeQueue[currentIndex]
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Glass background with depth orbs
            ZStack {
                Color.black.ignoresSafeArea()
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [(currentItem?.resolvedCategory.primaryColor ?? DesignTokens.accentActive).opacity(0.05), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .offset(x: -60, y: -220)
                    .blur(radius: 60)
                    .animation(.easeOut(duration: 0.8), value: currentItem?.categoryRaw)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [(currentItem?.resolvedCategory.gradientColors.last ?? DesignTokens.accentComplete).opacity(0.03), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .offset(x: 100, y: 280)
                    .blur(radius: 50)
                    .animation(.easeOut(duration: 0.8), value: currentItem?.categoryRaw)
            }
            .ignoresSafeArea()
            
            if let item = currentItem {
                taskView(item)
            } else {
                emptyStateView
            }
            
            // Task completion celebration overlay
            if showTransitionOverlay {
                TaskTransitionOverlay(
                    completedTask: completedTaskContent,
                    completedEmoji: completedTaskEmoji,
                    nextTask: nextTaskContent,
                    nextEmoji: nextTaskEmoji,
                    completedCategory: completedTaskCategory,
                    nextCategory: nextTaskCategory,
                    isPresented: $showTransitionOverlay
                )
                .transition(.opacity)
                .zIndex(10)
            }
            
            // Undo toast overlay
            if showUndoToast {
                undoToastView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            setupRepository()
            refreshQueue()
            greetUserIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            repository?.resurfaceExpiredSnoozes()
            refreshQueue()
            greetUserIfNeeded()
        }
        .onChange(of: currentIndex) {
            updatePenguinForCurrentTask()
            generateDraftIfNeeded()
            updateLiveActivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeComposeMessage)) { notification in
            if let recipient = notification.userInfo?["recipient"] as? String,
               let body = notification.userInfo?["body"] as? String {
                messageRecipient = recipient
                messageBody = body
                if ActionService.canSendText {
                    showMessageCompose = true
                }
            }
        }
        .sheet(isPresented: $showSnoozePicker) {
            if let item = currentItem {
                SnoozePickerView(item: item) { date in
                    snoozeItem(item, until: date)
                    showSnoozePicker = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showMessageCompose) {
            if ActionService.canSendText {
                MessageComposeView(
                    recipients: [messageRecipient],
                    body: messageBody,
                    onFinished: { showMessageCompose = false }
                )
            }
        }
        .sheet(isPresented: $showNudgyChat) {
            NudgyChatView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
        }
        .sheet(isPresented: $showBreakdown) {
            if let item = currentItem {
                TaskBreakdownView(
                    taskContent: item.content,
                    taskEmoji: item.emoji
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
            }
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView(
                onContactSelected: { name, phone, email in
                    handleContactPicked(name: name, phone: phone, email: email)
                    showContactPicker = false
                },
                onCancelled: {
                    showContactPicker = false
                    pendingContactActionItemID = nil
                    pendingContactActionType = nil
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeNeedsContactPicker)) { notification in
            if let itemIDString = notification.userInfo?["itemID"] as? String,
               let actionRaw = notification.userInfo?["actionType"] as? String {
                pendingContactActionItemID = UUID(uuidString: itemIDString)
                pendingContactActionType = ActionType(rawValue: actionRaw)
                showContactPicker = true
            }
        }
    }
    
    // MARK: - Task View (Penguin-Centered)
    
    private func taskView(_ item: NudgeItem) -> some View {
        VStack(spacing: 0) {
            // Swipe tip (shows once, above penguin)
            TipView(swipeRightTip)
                .tipBackground(DesignTokens.cardSurface)
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.top, DesignTokens.spacingMD)
            
            Spacer()
            
            // ★ Penguin — center stage
            PenguinSceneView(size: .hero, onTap: {
                // Tap penguin → start brain dump
                NotificationCenter.default.post(name: .nudgeOpenBrainDump, object: nil)
            }, onChatTap: {
                HapticService.shared.prepare()
                showNudgyChat = true
            })
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        HapticService.shared.prepare()
                        showNudgyChat = true
                    }
            )
            
            Spacer()
            
            // ★ Priority suggestion banner (when queue has 3+ tasks)
            if let suggestion = prioritySuggestion {
                priorityBanner(suggestion)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Swipeable card (compact, below penguin)
            CardView(
                item: item,
                queuePosition: currentIndex + 1,
                queueTotal: activeQueue.count,
                onDone: { markDone(item) },
                onSnooze: { showSnoozePicker = true },
                onSkip: { skipItem(item) },
                onAction: { handleAction(item) },
                onBreakDown: { showBreakdown = true }
            )
            .id(item.id)
            .transition(AnimationConstants.cardTransition)
            .onAppear {
                HapticService.shared.cardAppear()
            }
            .padding(.bottom, DesignTokens.spacingMD)
        }
    }
    
    // MARK: - Empty State (Penguin Resting)
    
    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            // Brain dump tip
            TipView(brainDumpTip)
                .tipBackground(DesignTokens.cardSurface)
                .padding(.horizontal, DesignTokens.spacingLG)
            
            Spacer()
            
            // ★ Penguin — center stage, resting/celebrating
            PenguinSceneView(size: .hero, onTap: {
                // Tap penguin → start brain dump
                NotificationCenter.default.post(name: .nudgeOpenBrainDump, object: nil)
            }, onChatTap: {
                HapticService.shared.prepare()
                showNudgyChat = true
            })
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        HapticService.shared.prepare()
                        showNudgyChat = true
                    }
            )
            
            Spacer()
            
            // CTA buttons
            VStack(spacing: DesignTokens.spacingMD) {
                // Completed today count + category recap
                let doneCount = repository?.completedTodayCount() ?? 0
                if doneCount > 0 {
                    VStack(spacing: 6) {
                        Text(String(localized: "\(doneCount) completed today"))
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.accentComplete)
                        
                        // Phase 7: Category recap chips
                        let doneCats = categoryRecap()
                        if !doneCats.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(doneCats.prefix(5), id: \.category) { stat in
                                    HStack(spacing: 2) {
                                        Image(systemName: stat.category.icon)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(stat.category.primaryColor)
                                        Text("×\(stat.count)")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(stat.category.primaryColor.opacity(0.85))
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                }
                
                Button {
                    NotificationCenter.default.post(name: .nudgeOpenBrainDump, object: nil)
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "mic.fill")
                        Text(String(localized: "Start a Brain Unload"))
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background(
                        Capsule()
                            .fill(DesignTokens.accentActive)
                    )
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "Start a brain unload"),
                    hint: String(localized: "Opens the voice brain unload recorder"),
                    traits: .isButton
                )
                
                Button {
                    NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "plus")
                        Text(String(localized: "Type a Task"))
                    }
                    .font(AppTheme.body.weight(.medium))
                    .foregroundStyle(DesignTokens.accentActive)
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background(
                        Capsule()
                            .strokeBorder(DesignTokens.accentActive, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "Type a task"),
                    hint: String(localized: "Opens a text field to add a task manually"),
                    traits: .isButton
                )
                
                // Chat with Nudgy button
                if AIService.shared.isAvailable {
                    Button {
                        HapticService.shared.prepare()
                        showNudgyChat = true
                    } label: {
                        HStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text(String(localized: "Chat with Nudgy"))
                        }
                        .font(AppTheme.caption.weight(.medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .padding(.horizontal, DesignTokens.spacingLG)
                        .padding(.vertical, DesignTokens.spacingSM)
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(
                        label: String(localized: "Chat with Nudgy"),
                        hint: String(localized: "Opens a conversation with your penguin assistant"),
                        traits: .isButton
                    )
                }
            }
            .padding(.bottom, DesignTokens.spacingXL)
        }
        .nudgeAnnouncement(String(localized: "All tasks complete"))
        .onAppear {
            if !hasPlayedAllClear {
                SoundService.shared.playAllClear()
                hasPlayedAllClear = true
            }
        }
    }
    
    // MARK: - Penguin State Management
    
    /// Greet the user on first appearance with a contextual line.
    private func greetUserIfNeeded() {
        guard !hasGreeted else { return }
        hasGreeted = true
        
        // Compute top category from active queue
        let categoryCounts: [TaskCategory: Int] = activeQueue.reduce(into: [:]) { counts, item in
            let cat = item.resolvedCategory
            if cat != .general { counts[cat, default: 0] += 1 }
        }
        let topCat: (label: String, emoji: String, count: Int)? = categoryCounts
            .max(by: { $0.value < $1.value })
            .map { ($0.key.label, $0.key.emoji, $0.value) }
        
        // Smart greeting: NudgyEngine shows curated instantly, upgrades to AI-generated
        let overdueCount = activeQueue.filter { $0.accentStatus == .overdue }.count
        let staleCount = activeQueue.filter { $0.accentStatus == .stale }.count
        let doneToday = repository?.completedTodayCount() ?? 0
        
        // Phase 14: Build category context for category-aware proactive nudges
        let doneTodayItems = repository?.fetchCompletedToday() ?? []
        let catContext = CategoryNudgeContext.build(from: activeQueue, doneToday: doneTodayItems)
        
        NudgyEngine.shared.greet(
            userName: settings.userName,
            activeTaskCount: activeQueue.count,
            overdueCount: overdueCount,
            staleCount: staleCount,
            doneToday: doneToday,
            topCategory: topCat,
            categoryContext: catContext
        )
    }
    
    /// Update penguin to reflect the current task.
    private func updatePenguinForCurrentTask() {
        if let item = currentItem {
            let accentColor = AccentColorSystem.shared.color(for: item.accentStatus)
            // Present task card via PenguinState (visual state)
            penguinState.presentTask(
                content: item.content,
                emoji: item.emoji,
                position: currentIndex + 1,
                total: activeQueue.count,
                accentColor: accentColor
            )
            
            // Smart task comment: NudgyEngine handles curated + AI upgrade
            NudgyEngine.shared.presentTask(
                content: item.content,
                emoji: item.emoji,
                position: currentIndex + 1,
                total: activeQueue.count,
                accentColor: accentColor,
                isStale: item.isStale,
                isOverdue: item.isOverdue
            )
        } else {
            let doneCount = repository?.completedTodayCount() ?? 0
            NudgyEngine.shared.showAllClear(doneCount: doneCount)
        }
    }
    
    // MARK: - Category Recap
    
    /// Returns per-category done-today counts (excluding .general), sorted by count descending.
    private func categoryRecap() -> [(category: TaskCategory, count: Int)] {
        guard let repo = repository else { return [] }
        let done = repo.fetchCompletedToday()
        var counts: [TaskCategory: Int] = [:]
        for item in done {
            let cat = item.resolvedCategory
            guard cat != .general else { continue }
            counts[cat, default: 0] += 1
        }
        return counts
            .map { (category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    // MARK: - Actions
    
    private func markDone(_ item: NudgeItem) {
        undoPreviousSortOrder = item.sortOrder
        
        repository?.markDone(item)
        
        // Award fish for completion
        let remaining = max(0, activeQueue.count - 1)
        let isAllClear = remaining == 0
        let earned = RewardService.shared.recordCompletion(context: modelContext, item: item, isAllClear: isAllClear)
        RewardService.shared.updateMood(context: modelContext, isAllClear: isAllClear)
        
        // Show fish earned feedback in speech bubble
        if earned > 0 {
            let streakText = RewardService.shared.currentStreak >= 3 ? " (\(RewardService.shared.currentStreak)-day streak 🔥)" : ""
            penguinState.queueDialogue("+\(earned) ❄️\(streakText)", style: .whisper, autoDismiss: 2.0)
        }
        
        // Smart AI-powered completion reaction via NudgyEngine
        NudgyEngine.shared.reactToCompletion(taskContent: item.content, remainingCount: remaining, categoryLabel: item.resolvedCategory.label)
        
        Task { await SwipeRightTip.swipeDoneCompleted.donate() }
        
        // Capture completed task info for transition overlay
        completedTaskContent = item.content
        completedTaskEmoji = item.emoji ?? "checkmark"
        completedTaskCategory = item.resolvedCategory
        
        undoItem = item
        undoTimerTask?.cancel()
        withAnimation(AnimationConstants.undoToast) {
            showUndoToast = true
        }
        undoTimerTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            dismissUndoToast()
        }
        
        advanceToNext()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
    }
    
    private func undoLastDone() {
        guard let item = undoItem else { return }
        repository?.undoDone(item, restoreSortOrder: undoPreviousSortOrder)
        
        undoTimerTask?.cancel()
        dismissUndoToast()
        
        HapticService.shared.prepare()
        refreshQueue()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
    }
    
    private func dismissUndoToast() {
        withAnimation(.easeOut(duration: 0.25)) {
            showUndoToast = false
        }
        undoItem = nil
    }
    
    private func snoozeItem(_ item: NudgeItem, until date: Date) {
        repository?.snooze(item, until: date)
        NudgyEngine.shared.reactToSnooze(taskContent: item.content)

        // ADHD: Snooze pattern insight — gentle observation when a task keeps getting pushed
        let daysSinceCreated = Calendar.current.dateComponents([.day], from: item.createdAt, to: .now).day ?? 0
        let sameTaskSnoozes = max(1, daysSinceCreated / 2) // Approximate: older tasks likely snoozed more
        let totalTasks = activeQueue.count
        let insight = NudgyEngine.shared.analyzeSnoozePattern(
            snoozeCount: sameTaskSnoozes,
            totalTasks: totalTasks,
            sameTaskSnoozes: sameTaskSnoozes
        )
        if let suggestion = NudgyEngine.shared.snoozeSuggestion(for: insight) {
            penguinState.queueDialogue(suggestion, style: .whisper, autoDismiss: 6.0)
        }

        Task {
            let permitted = await NotificationService.shared.requestPermission()
            if permitted {
                NotificationService.shared.scheduleSnoozedNotification(for: item, settings: settings)
            } else {
                Log.ui.warning("Snooze notification not scheduled — permission denied")
            }
        }
        
        advanceToNext()
    }
    
    private func skipItem(_ item: NudgeItem) {
        repository?.skip(item)
        advanceToNext()
    }
    
    private func handleAction(_ item: NudgeItem) {
        guard let actionType = item.actionType else { return }
        ActionService.perform(action: actionType, item: item)
    }
    
    // MARK: - Draft & Live Activity
    
    private func generateDraftIfNeeded() {
        guard let item = currentItem, let repo = repository else { return }
        Task {
            await DraftService.shared.generateDraftIfNeeded(
                for: item,
                isPro: settings.isPro,
                repository: repo,
                senderName: settings.userName.isEmpty ? nil : settings.userName
            )
        }
    }
    
    private func updateLiveActivity() {
        guard settings.liveActivityEnabled else { return }
        guard let item = currentItem else {
            Task { await LiveActivityManager.shared.endAll() }
            return
        }
        
        let accentHex = item.isStale ? "FF9F0A" : (item.isOverdue ? "FF453A" : "007AFF")
        let taskID = item.id.uuidString
        let cat = item.resolvedCategory
        let catLabel = cat != .general ? cat.label : nil
        let catHex = cat != .general ? cat.primaryColorHex : nil
        
        if LiveActivityManager.shared.isRunning {
            Task {
                await LiveActivityManager.shared.update(
                    taskContent: item.content,
                    taskEmoji: item.emoji ?? "checklist",
                    queuePosition: currentIndex + 1,
                    queueTotal: activeQueue.count,
                    accentHex: accentHex,
                    taskID: taskID,
                    categoryLabel: catLabel,
                    categoryColorHex: catHex
                )
            }
        } else {
            Task {
                await LiveActivityManager.shared.start(
                    taskContent: item.content,
                    taskEmoji: item.emoji ?? "checklist",
                    queuePosition: currentIndex + 1,
                    queueTotal: activeQueue.count,
                    accentHex: accentHex,
                    taskID: taskID,
                    categoryLabel: catLabel,
                    categoryColorHex: catHex
                )
            }
        }
    }
    
    private func advanceToNext() {
        let previousContent = currentItem?.content
        
        withAnimation(AnimationConstants.cardAppear) {
            refreshQueue()
        }
        
        // Populate transition overlay with next task info
        if let nextItem = currentItem {
            nextTaskContent = nextItem.content
            nextTaskEmoji = nextItem.emoji
            nextTaskCategory = nextItem.resolvedCategory
        } else {
            nextTaskContent = nil
            nextTaskEmoji = nil
            nextTaskCategory = .general
        }
        
        // Show celebration overlay for completed tasks
        if previousContent != nil {
            withAnimation(AnimationConstants.springSmooth) {
                showTransitionOverlay = true
            }
        }
        
        Task { @MainActor in
            if let nextItem = currentItem {
                HapticService.shared.cardAppear()

                // ADHD: Transition support — help the brain switch gears
                if let prev = previousContent {
                    let msg = await NudgyEngine.shared.transitionTo(
                        nextTask: nextItem.content,
                        from: prev
                    )
                    penguinState.queueDialogue(msg, style: .whisper, autoDismiss: 5.0)
                }
            }
        }
    }
    
    // MARK: - Contact Resolution Fallback
    
    /// Called when user picks a contact from ContactPickerView (fallback for unresolved contacts).
    private func handleContactPicked(name: String, phone: String?, email: String?) {
        guard let itemID = pendingContactActionItemID,
              let actionType = pendingContactActionType else { return }
        
        // Find the item in the queue
        let allItems = (repository?.fetchActiveQueue() ?? []) + (repository?.fetchSnoozed() ?? [])
        guard let item = allItems.first(where: { $0.id == itemID }) else { return }
        
        // Resolve the target based on action type
        let target = ContactHelper.actionTarget(phone: phone, email: email, for: actionType)
        
        if let target, !target.isEmpty {
            // Cache on the item for future use
            item.contactName = name
            item.actionTarget = target
            do { try modelContext.save() } catch { Log.ui.error("[OneThing] Contact save failed: \(error, privacy: .public)") }
            
            // Now execute the action
            HapticService.shared.actionButtonTap()
            ActionService.perform(action: actionType, item: item)
        } else {
            HapticService.shared.error()
        }
        
        pendingContactActionItemID = nil
        pendingContactActionType = nil
    }
    
    // MARK: - Undo Toast
    
    private var undoToastView: some View {
        VStack {
            Spacer()
            
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.accentComplete)
                
                Text(String(localized: "Marked done"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Spacer()
                
                Button {
                    undoLastDone()
                } label: {
                    Text(String(localized: "Undo"))
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                }
                .nudgeAccessibility(
                    label: String(localized: "Undo completion"),
                    hint: String(localized: "Returns the task to your queue"),
                    traits: .isButton
                )
            }
            .padding(DesignTokens.spacingLG)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
            .shadow(color: .black.opacity(0.4), radius: 16, y: 4)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, 80)
        }
    }
    
    // MARK: - Helpers
    
    private func setupRepository() {
        if repository == nil {
            repository = NudgeRepository(modelContext: modelContext)
        }
    }
    
    private func refreshQueue() {
        activeQueue = repository?.fetchActiveQueue() ?? []
        currentIndex = 0
        if !activeQueue.isEmpty {
            hasPlayedAllClear = false
            // Smart resurfacing: record the current top task as focused
            if let topItem = activeQueue.first {
                settings.recordFocus(itemID: topItem.id, content: topItem.content)
            }
        }
        updatePenguinForCurrentTask()
        fetchPrioritySuggestionIfNeeded()
    }
    
    // MARK: - Priority Suggestion
    
    private func fetchPrioritySuggestionIfNeeded() {
        // Only show when queue has 3+ tasks and AI is available
        guard activeQueue.count >= 3,
              AIService.shared.isAvailable,
              !isPriorityLoading else { return }
        
        isPriorityLoading = true
        Task {
            do {
                let snapshots = NudgyToolbox.snapshotTasks(from: modelContext)
                    .filter { $0.statusRaw == "active" }
                
                guard snapshots.count >= 3 else {
                    isPriorityLoading = false
                    return
                }
                
                let suggestion = try await AIService.shared.suggestPriority(tasks: snapshots)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    prioritySuggestion = suggestion
                }
            } catch {
                Log.ui.warning("Priority suggestion failed: \(error, privacy: .public)")
            }
            isPriorityLoading = false
        }
    }
    
    // MARK: - Priority Banner
    
    private func priorityBanner(_ suggestion: PrioritySuggestion) -> some View {
        Button {
            // Dismiss the banner
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                prioritySuggestion = nil
            }
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.accentActive)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.whyThisFirst)
                        .font(AppTheme.caption.weight(.medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingSM + 2)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                    .fill(DesignTokens.accentActive.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .strokeBorder(DesignTokens.accentActive.opacity(0.15), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.bottom, DesignTokens.spacingSM)
        .nudgeAccessibility(
            label: String(localized: "Nudgy suggests: \(suggestion.whyThisFirst)"),
            hint: String(localized: "Tap to dismiss"),
            traits: .isButton
        )
    }
}

// MARK: - Preview

#Preview("With Items") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NudgeItem.self, BrainDump.self, configurations: config)
    
    let ctx = container.mainContext
    ctx.insert(NudgeItem(content: "Call the dentist", emoji: "📞", actionType: .call, contactName: "Dr. Chen", sortOrder: 1))
    ctx.insert(NudgeItem(content: "Reply to Sarah about Saturday", emoji: "💬", actionType: .text, contactName: "Sarah", sortOrder: 2))
    ctx.insert(NudgeItem(content: "Buy dog food", emoji: "🐶", sortOrder: 3))
    
    return OneThingView()
        .modelContainer(container)
        .environment(AppSettings())
        .environment(PenguinState())
}

#Preview("Empty State") {
    OneThingView()
        .modelContainer(for: [NudgeItem.self, BrainDump.self], inMemory: true)
        .environment(AppSettings())
        .environment(PenguinState())
}
