//
//  NudgesView.swift
//  Nudge
//
//  The "Nudges" tab — time-horizon grouped task view.
//
//  ADHD-optimized layout (Phase 1):
//  • Day-grouped collapsible sections: Today → Tomorrow → This Week → Later → Snoozed → Done
//  • Daily progress header with animated ring
//  • "Today" capped at 5 items (working memory limit, Rapport et al., 2008)
//  • Swipe-to-complete and swipe-to-snooze gestures
//  • Items with drafts/actions surface at the top of their group
//

import SwiftUI
import SwiftData
import WidgetKit
import os.log

private let nudgesLog = Logger(subsystem: "com.tarsitgroup.nudge", category: "NudgesView")

struct NudgesView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(PenguinState.self) private var penguinState
    @Environment(AppSettings.self) private var settings

    @State private var repository: NudgeRepository?

    // Time-horizon grouped items
    @State private var horizonGroups = TimeHorizonGroups()
    
    // Section expand/collapse state (persisted per session)
    @State private var expandedSections: Set<TimeHorizon> = [.today, .tomorrow]
    
    // Draft generation
    @State private var draftGenerationTask: Task<Void, Never>?
    @State private var isDraftingCount: Int = 0
    
    // AI insight
    @State private var aiInsight: String?
    @State private var isGeneratingInsight = false

    // Inline expansion (ADHD: expand in place, no navigation)
    @State private var expandedItemID: UUID?
    @State private var userActivity: NSUserActivity?

    // Message compose
    @State private var showMessageCompose = false
    @State private var messageRecipient = ""
    @State private var messageBody = ""

    // Undo
    @State private var undoItem: NudgeItem?
    @State private var undoPreviousSortOrder: Int = 0
    @State private var showUndoToast = false
    @State private var undoTimerTask: Task<Void, Never>?
    
    // Delete undo
    @State private var undoDeleteItem: NudgeItem?
    @State private var showDeleteUndoToast = false
    @State private var undoDeleteTimerTask: Task<Void, Never>?
    
    // Live Activity prompt
    @State private var showLiveActivityPrompt = false

    // Morning brief
    @State private var dismissedMorningBrief = false
    
    // Pick For Me
    @State private var pickedItem: NudgeItem?
    @State private var showPickedCard = false
    
    // Inline micro-steps (Phase 3)
    @State private var expandedMicroSteps: Set<UUID> = []
    @State private var microStepsCache: [UUID: [MicroStep]] = [:]
    @State private var microStepsLoading: Set<UUID> = []
    
    // Completion celebration (Phase 7)
    @State private var showCompletionParticles = false
    
    // Fish reward system (Phases 1-17)
    @State private var fishHUDPosition: CGPoint = CGPoint(x: 200, y: 80)
    @State private var lastCompletedItemPosition: CGPoint = CGPoint(x: 200, y: 400)
    @State private var showSpeciesToast = false
    @State private var lastEarnedSpecies: FishSpecies? = nil
    @State private var lastFishEarned: Int = 0
    @State private var showNudgyPeek = false
    @State private var showTransitionOverlay = false
    @State private var completedTaskContent: String = ""
    @State private var completedTaskEmoji: String = "checklist"
    @State private var nextTaskContent: String? = nil
    @State private var nextTaskEmoji: String? = nil
    @State private var completedTaskCategory: TaskCategory = .general
    @State private var nextTaskCategory: TaskCategory = .general
    @State private var isAllClearCelebration = false
    
    // Focus Timer (Phase 3)
    @State private var focusTimerItem: NudgeItem?
    
    // View mode
    @State private var showTimeline = false
    @State private var calendarService = CalendarService.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breatheAnimation = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient Antarctic background (matches Nudgy tab)
                nudgesAmbientBackground
                    .ignoresSafeArea()

                if horizonGroups.isEmpty {
                    emptyView
                } else {
                    if showTimeline {
                        TimelineView(
                            calendarEvents: calendarService.todayEvents,
                            onTapTask: { item in toggleExpand(item) }
                        )
                    } else {
                        listContent
                    }
                }

                // Undo toast
                if showUndoToast {
                    undoToastView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Delete undo toast
                if showDeleteUndoToast {
                    deleteUndoToastView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Phase 7: Completion celebration particles
                if showCompletionParticles {
                    CompletionParticles(isActive: $showCompletionParticles)
                        .allowsHitTesting(false)
                }
                
                // Phase 5: Fish reward flying animation overlay
                FishRewardOverlay()
                    .allowsHitTesting(false)
                
                // Phase 4: Celebratory fish burst on completion
                CompletionFishBurst()
                    .allowsHitTesting(false)
                
                // Phase 9: Species toast ("Caught a Tropical Fish!")
                if showSpeciesToast, let species = lastEarnedSpecies {
                    SpeciesToast(
                        species: species,
                        fishEarned: lastFishEarned,
                        isRare: species == .swordfish || species == .whale,
                        isPresented: $showSpeciesToast
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(50)
                }
                
                // Phase 13: Mini Nudgy peek-munch at bottom
                VStack {
                    Spacer()
                    NudgyPeekMunch(isActive: $showNudgyPeek, species: lastEarnedSpecies)
                        .padding(.bottom, 70)
                }
                .allowsHitTesting(false)
                .zIndex(40)
                
                // Phase 16: Task transition overlay (Done → Next Up)
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
                    .zIndex(60)
                }
                
                // Floating "Pick For Me" button
                if !showTimeline && !horizonGroups.isEmpty && horizonGroups.today.count >= 2 && !showPickedCard {
                    VStack {
                        Spacer()
                        PickForMeButton {
                            pickRandomTask()
                        }
                        .padding(.bottom, 90)
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                
                // Picked task focus card
                if showPickedCard, let item = pickedItem {
                    PickedTaskCard(
                        item: item,
                        onDone: {
                            dismissPickedCard()
                            markDoneWithUndo(item)
                        },
                        onSnooze: {
                            dismissPickedCard()
                            snoozeQuick(item)
                        },
                        onStartFocus: {
                            dismissPickedCard()
                            focusTimerItem = item
                        },
                        onDismiss: {
                            dismissPickedCard()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
                
                // (Inline expansion — no popup overlay)
            }
            .navigationTitle(String(localized: "Nudges"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(AnimationConstants.springSmooth) {
                            showTimeline.toggle()
                        }
                        HapticService.shared.actionButtonTap()
                    } label: {
                        Image(systemName: showTimeline ? "list.bullet" : "calendar.day.timeline.leading")
                            .font(.system(size: 18))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .nudgeAccessibility(
                        label: showTimeline ? String(localized: "List view") : String(localized: "Timeline view"),
                        hint: String(localized: "Switches between list and timeline views"),
                        traits: .isButton
                    )
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .nudgeAccessibility(
                        label: String(localized: "Add task"),
                        hint: String(localized: "Opens quick add"),
                        traits: .isButton
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupRepository()
            refreshData()
            triggerDraftGeneration()
            generateAIInsight()
            syncLiveActivity()
            promptLiveActivityIfNeeded()
            calendarService.fetchTodayEvents()
            // Start breathing glow animation
            breatheAnimation = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            repository?.resurfaceExpiredSnoozes()
            refreshData()
            triggerDraftGeneration()
            generateAIInsight()
            syncLiveActivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeDataChanged)) { _ in
            refreshData()
            triggerDraftGeneration()
            syncLiveActivity()
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
        // Detail/draft/snooze handled by inline expanded card
        .sheet(isPresented: $showMessageCompose) {
            if ActionService.canSendText {
                MessageComposeView(
                    recipients: [messageRecipient],
                    body: messageBody,
                    onFinished: { showMessageCompose = false }
                )
            }
        }
        .fullScreenCover(item: $focusTimerItem) { item in
            FocusTimerView(
                item: item,
                isPresented: Binding(
                    get: { focusTimerItem != nil },
                    set: { if !$0 { focusTimerItem = nil } }
                )
            )
            .onDisappear {
                refreshData()
                syncLiveActivity()
            }
        }
    }
    
    // MARK: - Ambient Background

    private var nudgesAmbientBackground: some View {
        GeometryReader { geo in
            ZStack {
                AntarcticEnvironment(
                    mood: RewardService.shared.environmentMood,
                    unlockedProps: RewardService.shared.unlockedProps,
                    fishCount: RewardService.shared.fish,
                    level: RewardService.shared.level,
                    stage: StageTier.from(level: RewardService.shared.level),
                    sceneWidth: geo.size.width,
                    sceneHeight: geo.size.height
                )

                // Subtle breathing glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignTokens.accentActive.opacity(breatheAnimation ? 0.04 : 0.01),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(y: geo.size.height * 0.3)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 5).repeatForever(autoreverses: true),
                        value: breatheAnimation
                    )
            }
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingLG) {
                
                // Daily progress header
                DailyProgressHeader(
                    completedToday: horizonGroups.doneToday.count,
                    totalToday: horizonGroups.today.count + horizonGroups.doneToday.count,
                    streak: RewardService.shared.currentStreak,
                    fishToday: RewardService.shared.tasksCompletedToday,
                    fish: RewardService.shared.fish,
                    lastSpecies: lastEarnedSpecies,
                    onFishHUDPosition: { pos in
                        fishHUDPosition = pos
                    }
                )

                // Morning brief banner — Plan Tomorrow surfaced in the morning
                if !dismissedMorningBrief,
                   TomorrowPlanStore.shared.isFreshForMorning,
                   TomorrowPlanStore.shared.hasPlan {
                    morningBriefBanner
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Live Activity opt-in prompt
                if showLiveActivityPrompt && !settings.liveActivityEnabled {
                    liveActivityPromptBanner
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // AI Insight banner — contextual advice from Nudgy
                if let insight = aiInsight, !insight.isEmpty {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image("NudgyMascot")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Text(insight)
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(3)
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.easeOut(duration: 0.25)) {
                                aiInsight = nil
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DesignTokens.textTertiary)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .nudgeAccessibility(
                            label: String(localized: "Dismiss insight"),
                            traits: .isButton
                        )
                    }
                    .padding(DesignTokens.spacingMD)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .fill(DesignTokens.accentActive.opacity(0.05))
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Drafting indicator
                if isDraftingCount > 0 {
                    HStack(spacing: DesignTokens.spacingSM) {
                        ProgressView()
                            .tint(DesignTokens.accentActive)
                            .scaleEffect(0.8)
                        
                        Text(String(localized: "Nudgy is drafting messages…"))
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeOut(duration: 0.3), value: isDraftingCount)
                }

                // Phase 5: Quick capture inline field
                InlineQuickCapture {
                    refreshData()
                }
                
                // Time-horizon sections
                ForEach(TimeHorizon.allCases) { horizon in
                    let items = horizonGroups.items(for: horizon)
                    if !items.isEmpty {
                        horizonSection(for: horizon, items: items)
                    } else if horizon.showsEmptyState {
                        // Phase 4: Smart empty state for key sections
                        horizonEmptySection(for: horizon)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
        .refreshable { refreshData() }
    }

    // MARK: - Horizon Section Builder
    
    /// Builds a collapsible section for a given time horizon.
    /// Compact rows expand inline to show full detail.
    private func horizonSection(for horizon: TimeHorizon, items: [NudgeItem]) -> some View {
        CollapsibleNudgeSection(
            horizon: horizon,
            count: items.count,
            accentColor: horizon.accentColor,
            isExpanded: Binding(
                get: { expandedSections.contains(horizon) },
                set: { newValue in
                    if newValue {
                        expandedSections.insert(horizon)
                    } else {
                        expandedSections.remove(horizon)
                    }
                }
            )
        ) {
            ForEach(items, id: \.id) { item in
                itemRow(for: item, in: horizon)
            }
        }
    }
    
    /// Phase 4: Empty state for a section with no items.
    /// Shows a contextual, encouraging message instead of hiding the section.
    private func horizonEmptySection(for horizon: TimeHorizon) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header (non-interactive — no collapse for empty)
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: horizon.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(horizon.accentColor.opacity(0.5))
                    .frame(width: 20)
                
                Text(horizon.title)
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingXS)
            .padding(.vertical, DesignTokens.spacingXS)
            
            // Empty message
            SectionEmptyState(
                horizon: horizon,
                hasCompletedToday: !horizonGroups.doneToday.isEmpty
            )
        }
    }
    
    /// Picks the right row component for an item.
    /// Tap toggles inline expansion. Swipe gestures for done/snooze.
    /// Compact row ALWAYS visible — expanded card slides below it.
    @ViewBuilder
    private func itemRow(for item: NudgeItem, in horizon: TimeHorizon) -> some View {
        let isExpanded = expandedItemID == item.id
        let isCarried = horizon != .doneToday
            && TomorrowPlanStore.shared.isFreshForMorning
            && TomorrowPlanStore.shared.carryForwardIDs.contains(item.id.uuidString)

        if horizon == .doneToday {
            // Done items — compact, read-only feel (no expansion)
            NudgeCompactRow(
                item: item,
                isExpanded: false,
                onTap: {},
                onDone: nil
            )
        } else {
            // Swipe wraps the ENTIRE card (compact + expanded).
            // Right swipe → Done (green). Left swipe → Snooze 2h (amber).
            SwipeableRow(
                content: {
                    VStack(spacing: 0) {
                        // Compact row — ALWAYS visible, tap to toggle expand/collapse
                        NudgeCompactRow(
                            item: item,
                            isExpanded: isExpanded,
                            isCarried: isCarried,
                            onTap: { toggleExpand(item) },
                            onDone: { markDoneWithUndo(item) }
                        )
                        
                        // Expanded detail — slides below compact row
                        if isExpanded {
                            NudgeExpandedCard(
                                item: item,
                                onDone: { markDoneWithUndo(item) },
                                onSnooze: { date in
                                    repository?.snooze(item, until: date)
                                    refreshData()
                                },
                                onDelete: { deleteWithUndo(item) },
                                onCollapse: { collapseItem() },
                                onFocus: { focusTimerItem = item },
                                onAction: { performAction(item) },
                                onContentChanged: { refreshData() }
                            )
                            .padding(.top, 1)
                        }
                    }
                    .background {
                        // Track item position for fish burst origin
                        GeometryReader { itemGeo in
                            Color.clear
                                .onAppear {
                                    // Cache the last known row center
                                    lastCompletedItemPosition = CGPoint(
                                        x: itemGeo.frame(in: .global).midX,
                                        y: itemGeo.frame(in: .global).midY
                                    )
                                }
                                .onChange(of: itemGeo.frame(in: .global).midY) { _, _ in
                                    lastCompletedItemPosition = CGPoint(
                                        x: itemGeo.frame(in: .global).midX,
                                        y: itemGeo.frame(in: .global).midY
                                    )
                                }
                        }
                    }
                },
                onSwipeLeading: { markDoneWithUndo(item) },
                leadingLabel: String(localized: "Done"),
                leadingIcon: "checkmark",
                leadingColor: DesignTokens.accentComplete,
                categoryColor: item.resolvedCategory != .general ? item.resolvedCategory.primaryColor : nil,
                onSwipeTrailing: { snoozeQuick(item) },
                trailingLabel: String(localized: "Snooze"),
                trailingIcon: "moon.zzz.fill",
                trailingColor: DesignTokens.accentStale
            )
        }
    }
    
    // MARK: - Inline Expansion Helpers
    
    /// Toggle expansion for an item (ADHD: one card at a time).
    private func toggleExpand(_ item: NudgeItem) {
        HapticService.shared.actionButtonTap()
        withAnimation(AnimationConstants.springSmooth) {
            if expandedItemID == item.id {
                expandedItemID = nil
                // Clear Handoff activity when collapsing
                userActivity?.invalidate()
                userActivity = nil
            } else {
                expandedItemID = item.id
                // Advertise this task for Handoff
                let activity = HandoffService.viewTaskUserActivity(for: item)
                activity.becomeCurrent()
                userActivity = activity
            }
        }
    }
    
    /// Collapse the currently expanded item.
    private func collapseItem() {
        HapticService.shared.actionButtonTap()
        withAnimation(AnimationConstants.springSmooth) {
            expandedItemID = nil
        }
    }
    
    private func snoozeQuick(_ item: NudgeItem) {
        // Category-smart quick snooze — different life areas need different re-surface timing
        let calendar = Calendar.current
        let snoozeDate: Date
        
        switch item.resolvedCategory {
        case .cooking:
            // Meal prep is time-sensitive — come back in 30 min
            snoozeDate = calendar.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        case .exercise, .selfCare:
            // "I'll do it in an hour"
            snoozeDate = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        case .cleaning:
            // "I'll tidy up this afternoon"
            snoozeDate = calendar.date(byAdding: .hour, value: 3, to: Date()) ?? Date()
        case .finance:
            // Bills need quiet focus — tonight at 8pm
            var tonight = calendar.dateComponents([.year, .month, .day], from: Date())
            tonight.hour = 20
            snoozeDate = calendar.date(from: tonight) ?? calendar.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        case .appointment:
            // Appointments are day-scheduled — tomorrow 9am
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            var morning = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            morning.hour = 9
            snoozeDate = calendar.date(from: morning) ?? calendar.date(byAdding: .hour, value: 12, to: Date()) ?? Date()
        default:
            // Standard 2-hour snooze for everything else
            snoozeDate = calendar.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        }
        
        repository?.snooze(item, until: snoozeDate)
        HapticService.shared.swipeDone()

        // Clean up expanded state
        expandedItemID = nil
        expandedMicroSteps.remove(item.id)
        microStepsCache.removeValue(forKey: item.id)

        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }

    private func deleteWithUndo(_ item: NudgeItem) {
        undoPreviousSortOrder = item.sortOrder
        repository?.drop(item)
        HapticService.shared.actionButtonTap()

        // Clean up any cached state for this item
        expandedItemID = nil
        expandedMicroSteps.remove(item.id)
        microStepsCache.removeValue(forKey: item.id)

        undoDeleteItem = item
        undoDeleteTimerTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showDeleteUndoToast = true
        }
        undoDeleteTimerTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            dismissDeleteUndoToast()
        }

        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }

    private func undoLastDelete() {
        guard let item = undoDeleteItem else { return }
        // Restore from dropped status via repository
        repository?.undoDrop(item, restoreSortOrder: undoPreviousSortOrder)
        undoDeleteTimerTask?.cancel()
        dismissDeleteUndoToast()
        HapticService.shared.prepare()
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }

    private func dismissDeleteUndoToast() {
        withAnimation(.easeOut(duration: 0.25)) {
            showDeleteUndoToast = false
        }
        undoDeleteItem = nil
    }

    // MARK: - Empty View (Phase 4: Time-aware, personality-driven)

    private var emptyView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()

            PenguinSceneView(
                size: .large,
                expressionOverride: emptyViewExpression,
                accentColorOverride: DesignTokens.textTertiary
            )

            VStack(spacing: DesignTokens.spacingSM) {
                Text(emptyViewTitle)
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)

                Text(emptyViewSubtitle)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.spacingXL)
            }
            
            HStack(spacing: DesignTokens.spacingMD) {
                // Primary CTA — talk to Nudgy
                Button {
                    NotificationCenter.default.post(name: .nudgeOpenChat, object: nil)
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "bubble.left.fill")
                        Text(String(localized: "Talk to Nudgy"))
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
                
                // Secondary CTA — quick add
                Button {
                    NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
                } label: {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "plus")
                        Text(String(localized: "Add"))
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.accentActive)
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background(
                        Capsule()
                            .strokeBorder(DesignTokens.accentActive.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }
    
    // MARK: - Time-Aware Empty State Helpers
    
    /// The current period of day for contextual messaging.
    private enum DayPeriod {
        case morning   // 5am–12pm
        case afternoon // 12pm–5pm
        case evening   // 5pm–9pm
        case night     // 9pm–5am
        
        static var current: DayPeriod {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<12:  return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            default:      return .night
            }
        }
    }
    
    private var emptyViewExpression: PenguinExpression {
        switch DayPeriod.current {
        case .morning:   return .idle
        case .afternoon: return .thinking
        case .evening:   return .idle
        case .night:     return .sleeping
        }
    }
    
    private var emptyViewTitle: String {
        switch DayPeriod.current {
        case .morning:   return String(localized: "Good morning!")
        case .afternoon: return String(localized: "Quiet afternoon")
        case .evening:   return String(localized: "Winding down")
        case .night:     return String(localized: "Nothing on your plate")
        }
    }
    
    private var emptyViewSubtitle: String {
        switch DayPeriod.current {
        case .morning:
            return String(localized: "No nudges yet — tell Nudgy what's on your mind, or add one yourself")
        case .afternoon:
            return String(localized: "Your list is clear. Unload something, or enjoy the quiet")
        case .evening:
            return String(localized: "Nothing pending. Prep tomorrow, or just relax — you've earned it")
        case .night:
            return String(localized: "Nothing pending. Nudgy's here if you remember something")
        }
    }

    // MARK: - Actions

    private func performAction(_ item: NudgeItem) {
        guard let actionType = item.actionType else { return }
        HapticService.shared.actionButtonTap()
        ActionService.perform(action: actionType, item: item)
    }

    // MARK: - Undo

    private func markDoneWithUndo(_ item: NudgeItem) {
        undoPreviousSortOrder = item.sortOrder
        repository?.markDone(item)
        HapticService.shared.completionHaptic(for: item.resolvedCategory)
        
        // Remove from Spotlight index
        SpotlightIndexer.removeTask(id: item.id)
        
        // Phase 7: Trigger celebration particles
        showCompletionParticles = true
        
        // ── Phase 1: Record fish reward ──
        let allActive = horizonGroups.allActive
        let isAllClear = allActive.count <= 1 // This was the last one
        let earned = RewardService.shared.recordCompletion(
            context: modelContext,
            item: item,
            isAllClear: isAllClear
        )
        let species = FishEconomy.speciesForTask(item)
        lastEarnedSpecies = species
        lastFishEarned = earned
        
        // ── Phase 4: Post fish burst notification (fires immediately at item position) ──
        NotificationCenter.default.post(
            name: .nudgeFishBurst,
            object: nil,
            userInfo: [
                "origin": lastCompletedItemPosition,
                "hudPosition": fishHUDPosition,
                "fishCount": min(species.fishValue, 5),
                "categoryRaw": item.resolvedCategory.rawValue
            ]
        )
        
        // ── Phase 12: Tab bar Nudgy chomp (Option A — fires with burst) ──
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.4))
            NotificationCenter.default.post(
                name: .nudgeTabChomp,
                object: nil,
                userInfo: ["species": species.label]
            )
        }
        
        // ── Phase 14: Pending fish for penguin tab (Option C) ──
        NotificationCenter.default.post(
            name: .nudgePendingFish,
            object: nil,
            userInfo: ["count": 1]
        )
        
        // ── Phase 9: Species toast (after burst settles ~1.5s) ──
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showSpeciesToast = true
            }
        }
        
        // ── Phase 13: Nudgy peek-munch (after toast shows ~3s) ──
        let toastDuration = species.celebrationDuration
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5 + toastDuration + 0.3))
            showNudgyPeek = true
        }
        
        // ── Phase 16: Task transition overlay (optional — only if next task exists) ──
        completedTaskContent = item.content
        completedTaskEmoji = item.emoji ?? "checklist"
        completedTaskCategory = item.resolvedCategory
        let remainingActive = allActive.filter { $0.id != item.id }
        nextTaskContent = remainingActive.first?.content
        nextTaskEmoji = remainingActive.first?.emoji
        nextTaskCategory = remainingActive.first?.resolvedCategory ?? .general
        if nextTaskContent != nil {
            let transitionDelay = 1.5 + toastDuration + 0.3 + 2.3  // after peek-munch finishes
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(transitionDelay))
                withAnimation(AnimationConstants.springSmooth) {
                    showTransitionOverlay = true
                }
            }
        }
        
        // ── Phase 11: All-clear celebration ──
        if isAllClear {
            isAllClearCelebration = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                HapticService.shared.swipeDone()
            }
        }
        
        // Clean up any cached state for this item
        expandedItemID = nil
        expandedMicroSteps.remove(item.id)
        microStepsCache.removeValue(forKey: item.id)

        undoItem = item
        undoTimerTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showUndoToast = true
        }
        undoTimerTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            dismissUndoToast()
        }

        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }

    private func undoLastDone() {
        guard let item = undoItem else { return }
        repository?.undoDone(item, restoreSortOrder: undoPreviousSortOrder)
        undoTimerTask?.cancel()
        dismissUndoToast()
        HapticService.shared.prepare()
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }

    private func dismissUndoToast() {
        withAnimation(.easeOut(duration: 0.25)) {
            showUndoToast = false
        }
        undoItem = nil
    }
    
    // MARK: - Pick For Me
    
    private func pickRandomTask() {
        let candidates = horizonGroups.today
        guard candidates.count >= 2 else { return }
        
        // Smart pick: considers deadlines, staleness, time-of-day, energy
        guard let picked = SmartPickEngine.pickBest(from: candidates) else { return }
        pickedItem = picked
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showPickedCard = true
        }
    }
    
    private func dismissPickedCard() {
        withAnimation(.easeOut(duration: 0.2)) {
            showPickedCard = false
        }
    }
    
    // MARK: - Inline Micro-Steps (Phase 3)
    
    /// Toggle inline micro-step expansion for an item.
    /// First expansion triggers AI generation (or instant heuristic fallback).
    private func toggleMicroSteps(for item: NudgeItem) {
        let id = item.id
        
        if expandedMicroSteps.contains(id) {
            // Collapse
            collapseMicroSteps(for: item)
        } else {
            // Expand
            HapticService.shared.prepare()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                _ = expandedMicroSteps.insert(id)
            }
            
            // Generate if not cached
            if microStepsCache[id] == nil {
                microStepsLoading.insert(id)
                Task {
                    let steps = await MicroStepGenerator.generate(
                        for: item.content,
                        emoji: item.emoji,
                        category: item.category
                    )
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        microStepsCache[id] = steps
                        microStepsLoading.remove(id)
                    }
                }
            }
        }
    }
    
    /// Collapse micro-steps for an item (keeps cache for re-expansion).
    private func collapseMicroSteps(for item: NudgeItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            _ = expandedMicroSteps.remove(item.id)
        }
    }

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
            }
            .padding(DesignTokens.spacingLG)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
            .shadow(color: .black.opacity(0.4), radius: 16, y: 4)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, 80)
        }
    }

    private var deleteUndoToastView: some View {
        VStack {
            Spacer()

            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: "trash.fill")
                    .foregroundStyle(DesignTokens.accentOverdue)

                Text(String(localized: "Deleted"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)

                Spacer()

                Button {
                    undoLastDelete()
                } label: {
                    Text(String(localized: "Undo"))
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                }
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

    private func refreshData() {
        setupRepository()
        guard let repository else { return }
        let grouped = repository.fetchAllGrouped()
        
        // Apply Focus Filter energy level if active
        let filteredActive = applyFocusFilter(grouped.active)

        // Use time-horizon grouper for ADHD-optimized layout
        let newGroups = TimeHorizonGrouper.group(
            active: filteredActive,
            snoozed: grouped.snoozed,
            doneToday: grouped.doneToday
        )
        
        withAnimation(.easeOut(duration: 0.2)) {
            // Clear expandedItemID if the item is no longer in any active section
            if let eid = expandedItemID {
                let allItemIDs = Set(newGroups.allActive.map(\.id) + newGroups.snoozed.map(\.id))
                if !allItemIDs.contains(eid) {
                    expandedItemID = nil
                }
            }
            horizonGroups = newGroups
        }
    }
    
    /// Apply Focus Filter energy level (set by iOS Focus modes via NudgeFocusFilter).
    /// Tasks without an energy level are always shown (they haven't been classified).
    private func applyFocusFilter(_ items: [NudgeItem]) -> [NudgeItem] {
        let defaults = UserDefaults(suiteName: "group.com.tarsitgroup.nudge")
        var filtered = items
        
        // Energy filter
        if let filterRaw = defaults?.string(forKey: "focusFilter_energyLevel"),
           filterRaw != "all",
           let filter = EnergyLevel(rawValue: filterRaw) {
            filtered = filtered.filter { item in
                guard let energy = item.energyLevel else { return true }
                return energy == filter
            }
        }
        
        // Phase 10: Category filter
        if let catFilterStr = defaults?.string(forKey: "focusFilter_categories"),
           !catFilterStr.isEmpty {
            let allowedRaws = Set(catFilterStr.split(separator: ",").map(String.init))
            filtered = filtered.filter { item in
                allowedRaws.contains(item.categoryRaw ?? "general")
            }
        }
        
        return filtered
    }
    
    // MARK: - Draft Generation
    
    private func triggerDraftGeneration() {
        guard let repository else { return }
        draftGenerationTask?.cancel()
        draftGenerationTask = Task {
            // Find actionable items (text/email) without drafts
            let allActive = horizonGroups.allActive
            let needsDraft = allActive.filter { item in
                guard let actionType = item.actionType,
                      actionType == .text || actionType == .email else { return false }
                return !item.hasDraft
            }
            
            guard !needsDraft.isEmpty else { return }
            
            isDraftingCount = needsDraft.count
            
            for item in needsDraft {
                guard !Task.isCancelled else { break }
                await DraftService.shared.generateDraftIfNeeded(
                    for: item,
                    isPro: settings.isPro,
                    repository: repository,
                    senderName: settings.userName.isEmpty ? nil : settings.userName
                )
                isDraftingCount -= 1
                // Refresh to surface newly-drafted items at the top of their group
                refreshData()
            }
            
            isDraftingCount = 0
        }
    }
    
    // MARK: - AI Insight
    
    private func generateAIInsight() {
        let allActive = horizonGroups.allActive
        let totalActive = allActive.count
        guard totalActive > 0, AIService.shared.isAvailable else {
            aiInsight = nil
            return
        }
        guard !isGeneratingInsight else { return }
        isGeneratingInsight = true
        
        Task {
            defer { isGeneratingInsight = false }
            
            let taskSummary = allActive.prefix(5).map { item in
                let emoji = item.emoji ?? "pin.fill"
                let age = Calendar.current.dateComponents([.day], from: item.createdAt, to: Date()).day ?? 0
                return "\(emoji) \(item.content) (age: \(age)d)"
            }.joined(separator: "\n")
            
            let overdueCount = allActive.filter { $0.accentStatus == .overdue }.count
            let staleCount = allActive.filter { $0.accentStatus == .stale }.count
            let draftedCount = allActive.filter { $0.hasDraft }.count
            
            let line = await NudgyDialogueEngine.shared.smartIdleChatter(
                currentTask: "User has \(totalActive) active tasks (\(overdueCount) overdue, \(staleCount) stale, \(draftedCount) with drafts ready):\n\(taskSummary)",
                activeCount: totalActive
            )
            
            withAnimation(.easeOut(duration: 0.3)) {
                aiInsight = line
            }
        }
    }
    
    // MARK: - Live Activity Sync
    
    /// Sync the Live Activity with current Nudges data directly from this view.
    private func syncLiveActivity() {
        // Also sync widget data (shared UserDefaults for Home/Lock Screen widgets)
        syncWidgetData()
        
        // Re-index tasks in Spotlight
        if let repository {
            SpotlightIndexer.indexAllTasks(from: repository)
        }
        
        nudgesLog.info("syncLiveActivity called — liveActivityEnabled: \(self.settings.liveActivityEnabled)")
        guard settings.liveActivityEnabled else { return }
        
        let allActive = horizonGroups.allActive
        nudgesLog.info("syncLiveActivity — allActive count: \(allActive.count)")
        guard let topItem = allActive.first else {
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
            Task {
                await LiveActivityManager.shared.update(
                    taskContent: topItem.content,
                    taskEmoji: emoji,
                    queuePosition: 1,
                    queueTotal: allActive.count,
                    accentHex: accentHex,
                    taskID: topItem.id.uuidString,
                    categoryLabel: catLabel,
                    categoryColorHex: catHex
                )
            }
        } else {
            Task {
                await LiveActivityManager.shared.start(
                    taskContent: topItem.content,
                    taskEmoji: emoji,
                    queuePosition: 1,
                    queueTotal: allActive.count,
                    accentHex: accentHex,
                    taskID: topItem.id.uuidString,
                    categoryLabel: catLabel,
                    categoryColorHex: catHex
                )
            }
        }
    }
    
    // MARK: - Widget Data Sync
    
    /// Write current task data to shared App Group UserDefaults
    /// so Home Screen and Lock Screen widgets can read it.
    private func syncWidgetData() {
        let allActive = horizonGroups.allActive
        let completedCount = horizonGroups.doneToday.count
        let totalCount = horizonGroups.today.count + completedCount
        
        // Get wardrobe for gamification data
        let wardrobe: NudgyWardrobe? = {
            let descriptor = FetchDescriptor<NudgyWardrobe>()
            return try? modelContext.fetch(descriptor).first
        }()
        
        WidgetDataService.sync(
            activeTasks: allActive,
            completedTodayCount: completedCount,
            totalTodayCount: totalCount,
            wardrobe: wardrobe
        )
    }
    
    /// Prompt user to enable Live Activity if they haven't been asked and have active tasks.
    private func promptLiveActivityIfNeeded() {
        let totalActive = horizonGroups.activeCount
        guard totalActive >= 1,
              !settings.liveActivityEnabled,
              !settings.liveActivityPromptShown else {
            showLiveActivityPrompt = false
            return
        }
        withAnimation(.easeOut(duration: 0.3)) {
            showLiveActivityPrompt = true
        }
    }
    
    /// Morning brief — shows today’s intention and carry-forward count from last night’s plan
    private var morningBriefBanner: some View {
        let store = TomorrowPlanStore.shared
        return HStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: store.energyMode.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(store.energyMode.accentColor)
                .frame(width: 32, height: 32)
                .background(Circle().fill(store.energyMode.accentColor.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Today’s intention"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(store.intentionText)
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(2)
                if !store.carryForwardIDs.isEmpty {
                    let n = store.carryForwardIDs.count
                    Text(n == 1
                         ? String(localized: "1 task carried forward")
                         : String(localized: "\(n) tasks carried forward"))
                        .font(AppTheme.footnote)
                        .foregroundStyle(store.energyMode.accentColor)
                }
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    dismissedMorningBrief = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Dismiss morning brief"),
                traits: .isButton
            )
        }
        .padding(DesignTokens.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                .fill(store.energyMode.accentColor.opacity(0.06))
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
    }

    /// Live Activity opt-in banner
    private var liveActivityPromptBanner: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "platter.filled.top.and.arrow.up.iphone")
                    .font(.system(size: 22))
                    .foregroundStyle(DesignTokens.accentActive)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Live Activity"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(String(localized: "See your current task on Lock Screen & Dynamic Island"))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showLiveActivityPrompt = false
                    }
                    settings.liveActivityPromptShown = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "Dismiss"),
                    traits: .isButton
                )
            }
            
            HStack(spacing: DesignTokens.spacingSM) {
                Button {
                    settings.liveActivityEnabled = true
                    settings.liveActivityPromptShown = true
                    withAnimation(.easeOut(duration: 0.25)) {
                        showLiveActivityPrompt = false
                    }
                    syncLiveActivity()
                } label: {
                    Text(String(localized: "Enable"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background(
                            Capsule().fill(DesignTokens.accentActive)
                        )
                }
                .buttonStyle(.plain)
                
                Button {
                    settings.liveActivityPromptShown = true
                    withAnimation(.easeOut(duration: 0.25)) {
                        showLiveActivityPrompt = false
                    }
                } label: {
                    Text(String(localized: "Not now"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(DesignTokens.accentActive.opacity(0.04))
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
    }
}

// MARK: - Actionable Nudge Row (items Nudgy prepared actions for)

struct ActionableNudgeRow: View {

    let item: NudgeItem
    var onTap: () -> Void = {}
    var onAction: (() -> Void)?
    var onDone: (() -> Void)?
    var onViewDraft: (() -> Void)?
    var onFocus: (() -> Void)?

    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }

    private var actionLabel: String {
        switch item.actionType {
        case .call:           return String(localized: "Call")
        case .text:           return String(localized: "Text")
        case .email:          return String(localized: "Email")
        case .openLink:       return String(localized: "Open")
        case .search:         return String(localized: "Search")
        case .navigate:       return String(localized: "Navigate")
        case .addToCalendar:  return String(localized: "Add")
        case .setAlarm:       return String(localized: "Alarm")
        case nil:             return String(localized: "Act")
        }
    }

    private var actionIcon: String {
        item.actionType?.icon ?? "bolt.fill"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // Top row: emoji + content + done button
                HStack(spacing: DesignTokens.spacingMD) {
                    TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .medium, accentColor: accentColor)

                    VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                        Text(item.content)
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textPrimary)
                            .lineLimit(2)

                        if let contact = item.contactName, !contact.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 10))
                                Text(contact)
                            }
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                        }
                        
                        // Phase 8: Stale age badge
                        if item.isStale {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                Text(String(localized: "\(item.ageInDays)d old"))
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DesignTokens.accentStale)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(DesignTokens.accentStale.opacity(0.12))
                            )
                        }
                    }

                    Spacer()
                    
                    // Focus timer button
                    if let onFocus {
                        Button {
                            HapticService.shared.actionButtonTap()
                            onFocus()
                        } label: {
                            Image(systemName: "timer")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DesignTokens.accentActive)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(DesignTokens.accentActive.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                        .nudgeAccessibility(
                            label: String(localized: "Start focus timer"),
                            hint: String(localized: "Opens a countdown timer for this task"),
                            traits: .isButton
                        )
                    }

                    if let onDone {
                        Button {
                            onDone()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DesignTokens.accentComplete)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(DesignTokens.accentComplete.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Duration badge
                if let label = item.durationLabel {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(label)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                    )
                }

                // Draft preview (if Nudgy drafted something)
                if item.hasDraft, let draft = item.aiDraft {
                    Button {
                        onViewDraft?()
                    } label: {
                        HStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DesignTokens.accentActive)

                            Text(draft)
                                .font(AppTheme.footnote)
                                .foregroundStyle(DesignTokens.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .padding(DesignTokens.spacingSM)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                                .fill(DesignTokens.accentActive.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Action button
                if let onAction, item.hasAction {
                    Button {
                        onAction()
                    } label: {
                        HStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: actionIcon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(actionLabel)
                                .font(AppTheme.body.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingSM + 2)
                        .background(
                            Capsule()
                                .fill(DesignTokens.accentActive)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.spacingMD)
            .background {
                // Accent glow visible through glass
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(item.isStale ? 0.12 : 0.07), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Draft Preview Sheet

struct DraftPreviewSheet: View {

    let item: NudgeItem
    let onSend: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Nudgy's Draft"))
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.textPrimary)

                    if let contact = item.contactName {
                        Text(String(localized: "For \(contact)"))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }

            // Subject (for emails)
            if let subject = item.aiDraftSubject, !subject.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Subject"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                        .textCase(.uppercase)

                    Text(subject)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Draft body
            if let draft = item.aiDraft {
                ScrollView {
                    Text(draft)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()

            // Send button
            Button {
                onSend()
                dismiss()
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: item.actionType?.icon ?? "paperplane.fill")
                    Text(String(localized: "Send"))
                }
                .font(AppTheme.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingMD)
                .background(
                    Capsule()
                        .fill(DesignTokens.accentActive)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.spacingLG)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NudgeItem.self, BrainDump.self, configurations: config)

    let ctx = container.mainContext
    let item1 = NudgeItem(content: "Text Sarah about Saturday plans", emoji: "💬", actionType: .text, actionTarget: "555-1234", contactName: "Sarah", sortOrder: 1)
    item1.aiDraft = "Hey Sarah! Just wanted to check in about Saturday — are we still on for brunch at 11?"
    ctx.insert(item1)

    let item2 = NudgeItem(content: "Email landlord about lease renewal", emoji: "📧", actionType: .email, actionTarget: "landlord@email.com", contactName: "Mr. Johnson", sortOrder: 2)
    item2.aiDraft = "Hi Mr. Johnson, I'm writing to inquire about the lease renewal for my apartment."
    item2.aiDraftSubject = "Lease Renewal Inquiry"
    ctx.insert(item2)

    ctx.insert(NudgeItem(content: "Buy dog food", emoji: "🐶", sortOrder: 3))
    ctx.insert(NudgeItem(content: "Read Jake's article", emoji: "📖", sortOrder: 4))

    return NudgesView()
        .modelContainer(container)
        .environment(AppSettings())
        .environment(PenguinState())
}
