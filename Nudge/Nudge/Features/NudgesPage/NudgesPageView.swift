//
//  NudgesPageView.swift
//  Nudge
//
//  The redesigned Nudges tab — "One Surface, Zero Navigation."
//
//  Layout (progressive scroll density — ADHD-optimized):
//    0. Time subtitle + drafting indicator
//    1. Category filter chips (if ≥2 categories)
//    2. Hero card (THE task, picked by SmartPick — first thing you see)
//    3. "Not this one" skip button
//    4. Paralysis prompt (after 3 skips)
//    5. Up next (2 peek cards — reduced for less choice paralysis)
//    6. Done today (trophy case)
//    7. Stats strip (fish, streak, progress — below the action zone)
//    8. Streak risk banner
//    9. Daily challenge badge
//   10. Pile count (expandable remaining, sorted by urgency)
//
//  Key innovations:
//  - Cards EXECUTE tasks, not just display them (CALL/TEXT/EMAIL buttons)
//  - SmartPick auto-chooses with energy awareness (no user decision needed)
//  - Fish bounty visible BEFORE completion (forward-looking motivation)
//  - Completion chain: card flies off → fish arc → next card rises (900ms)
//  - Paralysis detection at 3 skips → Nudgy intervention
//
//  ADHD research backing:
//  - "I know what to do, I just can't do it" (716 upvotes r/ADHD)
//  - Body doubling / "what do you need to do?" (12K upvotes)
//  - "1-thing theory" from 131 tips thread (9.6K upvotes)
//

import SwiftUI
import SwiftData
import WidgetKit

struct NudgesPageView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(\.selectedTab) private var selectedTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - State
    
    @State private var repository: NudgeRepository?
    
    // Data
    @State private var allActive: [NudgeItem] = []
    @State private var snoozedItems: [NudgeItem] = []
    @State private var doneToday: [NudgeItem] = []
    
    // Hero card
    @State private var heroItem: NudgeItem?
    @State private var heroReason: String = ""
    @State private var upNextItems: [NudgeItem] = []
    @State private var pileItems: [NudgeItem] = []
    
    // Skip cycle
    @State private var skipManager = SkipCycleManager()
    
    // Fish rewards
    @State private var fishHUDPosition: CGPoint = CGPoint(x: 60, y: 60)
    @State private var lastEarnedSpecies: FishSpecies?
    @State private var lastFishEarned: Int = 0
    @State private var showCompletionParticles = false
    @State private var completionCategoryColor: Color? = nil
    @State private var lastCompletionCategoryInfo: (icon: String, label: String, count: Int)? = nil
    
    // Drafting
    @State private var draftGenerationTask: Task<Void, Never>?
    
    // Message compose
    @State private var showMessageCompose = false
    @State private var messageRecipient = ""
    @State private var messageBody = ""
    
    // Focus timer
    @State private var focusTimerItem: NudgeItem?
    
    // Undo
    @State private var undoItem: NudgeItem?
    @State private var undoPreviousSortOrder: Int = 0
    @State private var showUndoToast = false
    @State private var undoTimerTask: Task<Void, Never>?
    
    // Hero card transition
    @State private var heroTransitionID = UUID()
    
    // Category filter
    @State private var selectedCategoryFilter: TaskCategory? = nil
    
    // Background glow
    @State private var breatheAnimation = false
    
    // SpeciesToast timing
    @State private var showSpeciesToast = false
    
    // Drafting indicator
    @State private var isDraftingCount: Int = 0
    
    // Time-based auto-refresh (every 15 min to keep urgency scores fresh)
    @State private var refreshTask: Task<Void, Never>? = nil
    
    // Detail popup (tap any stacked card to inspect)
    @State private var showDetailPopup = false
    @State private var detailItems: [NudgeItem] = []
    @State private var detailSelectedIndex: Int = 0
    
    // MARK: - Computed
    
    private var currentEnergy: EnergyLevel {
        let hour = Calendar.current.component(.hour, from: Date())
        return EnergyScheduler.energyBucket(for: hour)
    }
    
    private var totalToday: Int {
        allActive.count + doneToday.count
    }
    
    private var emptyVariant: NudgesEmptyState.EmptyVariant {
        if allActive.isEmpty && !doneToday.isEmpty {
            return .allClear
        }
        if allActive.isEmpty && !snoozedItems.isEmpty {
            return .allSnoozed
        }
        return .noTasks
    }
    
    /// Categories present in the active queue (for filter chips).
    private var activeCategories: [TaskCategory] {
        var seen = Set<TaskCategory>()
        var result: [TaskCategory] = []
        for item in allActive {
            let cat = item.resolvedCategory
            if cat != .general && seen.insert(cat).inserted {
                result.append(cat)
            }
        }
        return result.sorted { $0.label < $1.label }
    }
    
    /// Filtered items based on category selection.
    private var filteredActive: [NudgeItem] {
        guard let filter = selectedCategoryFilter else { return allActive }
        return allActive.filter { $0.resolvedCategory == filter }
    }
    
    // MARK: - Time-Aware Greeting
    
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return String(localized: "Good morning")
        case 12..<17: return String(localized: "Good afternoon")
        case 17..<21: return String(localized: "Good evening")
        default:      return String(localized: "Late night")
        }
    }
    
    private var timeSubtitle: String {
        // When category filter is active, show filtered context
        if let filter = selectedCategoryFilter {
            let count = filteredActive.count
            let label = filter.label.lowercased()
            if count == 0 {
                return String(localized: "No \(label) tasks right now")
            } else if count == 1 {
                return String(localized: "1 \(label) task")
            }
            return String(localized: "\(count) \(label) tasks")
        }
        
        let active = allActive.count
        let done = doneToday.count
        if done > 0 && active > 0 {
            return String(localized: "\(done) done · \(active) to go")
        } else if active == 1 {
            return String(localized: "Just one thing today")
        } else if active > 0 {
            return String(localized: "\(active) nudges waiting")
        }
        return String(localized: "Let's get started")
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Antarctic background
                ambientBackground
                    .ignoresSafeArea()
                
                if allActive.isEmpty {
                    NudgesEmptyState(
                        variant: emptyVariant,
                        snoozedCount: snoozedItems.count,
                        lastFishEarned: lastFishEarned,
                        categoryRecap: buildCategoryRecap(),
                        onWakeSnooze: wakeOldestSnooze
                    )
                    .transition(.opacity)
                } else {
                    mainScrollContent
                        .transition(.opacity)
                }
                
                // Undo toast
                if showUndoToast {
                    undoToastOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Completion particles
                if showCompletionParticles {
                    CompletionParticles(isActive: $showCompletionParticles, categoryColor: completionCategoryColor)
                        .allowsHitTesting(false)
                }
                
                // Fish reward flying animation
                FishRewardOverlay()
                    .allowsHitTesting(false)
                
                // Fish burst
                CompletionFishBurst()
                    .allowsHitTesting(false)
                
                // Species toast (delayed for celebration sequence)
                if showSpeciesToast, let species = lastEarnedSpecies {
                    SpeciesToast(
                        species: species,
                        fishEarned: lastFishEarned,
                        isRare: species == .swordfish || species == .whale,
                        categoryInfo: lastCompletionCategoryInfo,
                        isPresented: $showSpeciesToast
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(50)
                }
                
                // Detail popup — tap any stacked card to inspect
                if showDetailPopup {
                    NudgeDetailPopup(
                        items: detailItems,
                        selectedIndex: $detailSelectedIndex,
                        isPresented: $showDetailPopup,
                        onDone: { item in markDoneWithCelebration(item) },
                        onSnooze: { item, date in
                            repository?.snooze(item, until: date)
                            refreshData()
                            NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
                            syncLiveActivity()
                        },
                        onDelete: { item in
                            repository?.drop(item)
                            refreshData()
                            NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
                            syncLiveActivity()
                        },
                        onFocus: { item in
                            showDetailPopup = false
                            focusTimerItem = item
                        },
                        onAction: { item in performAction(item) },
                        onContentChanged: { refreshData() }
                    )
                    .transition(.opacity)
                    .zIndex(200)
                }
            }
            .navigationTitle(timeGreeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: DesignTokens.spacingSM) {
                        HStack(spacing: 2) {
                            Image(systemName: "fish.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignTokens.goldCurrency)
                            Text("\(RewardService.shared.fish)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        
                    }
                    .opacity(0.7)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupRepository()
            refreshData()
            triggerDraftGeneration()
            syncLiveActivity()
            breatheAnimation = true
            // Start 15-min auto-refresh to keep time-based scoring fresh
            refreshTask?.cancel()
            refreshTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(900))
                    guard !Task.isCancelled else { break }
                    refreshData()
                }
            }
        }
        .onDisappear {
            undoTimerTask?.cancel()
            draftGenerationTask?.cancel()
            refreshTask?.cancel()
            refreshTask = nil
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .nudges {
                setupRepository()
                refreshData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            repository?.resurfaceExpiredSnoozes()
            refreshData()
            triggerDraftGeneration()
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
    
    // MARK: - Main Scroll Content
    
    private var mainScrollContent: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingLG) {
                // Time-aware subtitle + inline quick capture
                HStack(spacing: DesignTokens.spacingSM) {
                    Text(timeSubtitle)
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                    
                    if isDraftingCount > 0 {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(DesignTokens.accentActive)
                            Text(String(localized: "Drafting \(isDraftingCount)..."))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.spacingXS)
                
                // 1. Category filter chips
                if activeCategories.count >= 2 {
                    categoryFilterStrip
                }
                
                // 2. Hero card — first thing you see
                if let hero = heroItem {
                    HeroCardView(
                        item: hero,
                        reason: heroReason,
                        streak: RewardService.shared.currentStreak,
                        onDone: { markDoneWithCelebration(hero) },
                        onSnooze: { snoozeQuick(hero) },
                        onSkip: { skipToNext(hero) },
                        onAction: { performAction(hero) },
                        onFocus: { focusTimerItem = hero },
                        onRegenerate: hero.hasDraft
                            ? { regenerateDraft(hero) }
                            : nil,
                        onDetail: { openDetail(for: hero, in: allActive) }
                    )
                    .id(heroTransitionID)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity
                        )
                    )
                    .scrollTransition(.animated(.spring(response: 0.5, dampingFraction: 0.82))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.3)
                            .scaleEffect(phase.isIdentity ? 1 : 0.92)
                    }
                }
                
                // 3. "Not this one" skip button
                if heroItem != nil && allActive.count > 1 {
                    skipButton
                        .transition(.opacity)
                }
                
                // 4. Paralysis prompt
                if skipManager.showParalysisPrompt {
                    ParalysisPromptView(
                        skipCount: skipManager.skipCount,
                        onQuickCatch: {
                            if let quick = skipManager.findQuickCatch(from: allActive) {
                                promoteToHero(quick)
                            }
                            skipManager.dismissParalysisPrompt()
                        },
                        onBrainDump: {
                            skipManager.dismissParalysisPrompt()
                            NotificationCenter.default.post(name: .nudgeOpenBrainDump, object: nil)
                        },
                        onDismiss: {
                            skipManager.dismissParalysisPrompt()
                        }
                    )
                }
                
                // 5. Up next — only 2 to reduce choice paralysis
                UpNextSection(
                    items: upNextItems,
                    streak: RewardService.shared.currentStreak,
                    onPromote: { item in promoteToHero(item) },
                    onDetail: { item in openDetail(for: item, in: upNextItems) },
                    onDone: { item in markDoneWithCelebration(item) },
                    onSnooze: { item in snoozeQuick(item) }
                )
                .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.4)
                        .offset(y: phase.isIdentity ? 0 : 20)
                }
                
                // 6. Done today (tappable cards)
                DoneTodayStrip(items: doneToday, onTapItem: { item in
                    openDetail(for: item, in: doneToday)
                })
                    .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.4)
                            .offset(y: phase.isIdentity ? 0 : 16)
                    }
                
                // 7. Pile
                PileCountRow(
                    items: pileItems,
                    streak: RewardService.shared.currentStreak,
                    onDone: { item in markDoneWithCelebration(item) },
                    onSnooze: { item in snoozeQuick(item) },
                    onDetail: { item in openDetail(for: item, in: pileItems) }
                )
                .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.4)
                        .offset(y: phase.isIdentity ? 0 : 16)
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
        .refreshable { refreshData() }
    }
    
    // MARK: - Skip Button
    
    private var skipButton: some View {
        Button {
            if let hero = heroItem {
                skipToNext(hero)
            }
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "arrow.forward.circle")
                    .font(AppTheme.footnote)
                Text(String(localized: "Not this one"))
                    .font(AppTheme.footnote.weight(.medium))
            }
            .foregroundStyle(DesignTokens.textTertiary)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingSM)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.03))
            }
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: String(localized: "Skip this task"),
            hint: String(localized: "Shows the next task Nudgy recommends"),
            traits: .isButton
        )
    }
    
    // MARK: - Ambient Background
    
    private var ambientBackground: some View {
        GeometryReader { geo in
            ZStack {
                AntarcticEnvironment(
                    mood: RewardService.shared.environmentMood,
                    unlockedProps: RewardService.shared.unlockedProps,
                    fishCount: RewardService.shared.fish,
                    level: RewardService.shared.level,
                    stage: StageTier.from(level: RewardService.shared.level),
                    sceneWidth: geo.size.width,
                    sceneHeight: geo.size.height,
                    isActive: selectedTab == .nudges
                )
                
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
    
    // MARK: - Undo Toast
    
    private var undoToastOverlay: some View {
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
                    HapticService.shared.swipeSkip()
                    undoLastDone()
                } label: {
                    Text(String(localized: "Undo"))
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                }
                .nudgeAccessibility(
                    label: String(localized: "Undo"),
                    hint: String(localized: "Bring back the last completed task"),
                    traits: .isButton
                )
            }
            .padding(DesignTokens.spacingLG)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
            .shadow(color: .black.opacity(0.4), radius: 16, y: 4)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, 80)
            .nudgeAccessibilityElement(
                label: String(localized: "Task marked done"),
                hint: String(localized: "Undo button available")
            )
        }
        .nudgeAnnouncement(String(localized: "Task completed. Undo available."))
    }
    
    // MARK: - Data
    
    private func setupRepository() {
        if repository == nil {
            repository = NudgeRepository(modelContext: modelContext)
        }
    }
    
    private func refreshData() {
        setupRepository()
        guard let repository else { return }
        
        let grouped = repository.fetchAllGrouped()
        
        // Apply focus filter
        let filteredActive = applyFocusFilter(grouped.active)
        
        withAnimation(AnimationConstants.springSmooth) {
            allActive = filteredActive
            snoozedItems = grouped.snoozed
            doneToday = grouped.doneToday
        }
        
        // Auto-clear category filter if no active items match
        if let filter = selectedCategoryFilter,
           !allActive.contains(where: { $0.resolvedCategory == filter }) {
            withAnimation(AnimationConstants.springSmooth) {
                selectedCategoryFilter = nil
            }
        }
        
        // Pick hero card
        pickHero()
    }
    
    private func applyFocusFilter(_ items: [NudgeItem]) -> [NudgeItem] {
        let defaults = UserDefaults(suiteName: AppGroupID.suiteName)
        guard let filterRaw = defaults?.string(forKey: "focusFilter_energyLevel"),
              filterRaw != "all",
              let filter = EnergyLevel(rawValue: filterRaw) else {
            return items
        }
        return items.filter { item in
            guard let energy = item.energyLevel else { return true }
            return energy == filter
        }
    }
    
    // MARK: - Hero Selection
    
    private func pickHero() {
        // Use filtered list when a category filter is active
        let source = filteredActive
        
        guard !source.isEmpty else {
            heroItem = nil
            heroReason = ""
            upNextItems = []
            pileItems = []
            return
        }
        
        // Exclude currently skipped items (unless all are skipped)
        let candidates = source.filter { !skipManager.skippedIDs.contains($0.id) }
        let pool = candidates.isEmpty ? source : candidates
        
        // SmartPick with energy awareness (the fix!)
        let picked = SmartPickEngine.pickBest(from: pool, currentEnergy: currentEnergy)
            ?? pool.first
        
        guard let hero = picked else { return }
        
        // Only change hero if it's different (avoid re-picks on refresh)
        if heroItem?.id != hero.id {
            withAnimation(reduceMotion ? .none : AnimationConstants.springSmooth) {
                heroItem = hero
                heroReason = SmartPickEngine.reason(for: hero)
                if heroReason.isEmpty { heroReason = String(localized: "let's get this one done") }
                heroTransitionID = UUID() // Force new transition
            }
            
            // Announce to VoiceOver
            UIAccessibility.post(notification: .announcement, argument: hero.content)
            
            // Trigger draft generation for new hero
            triggerHeroDraft(hero)
        }
        
        // Build up-next and pile lists (SmartPick-ranked ordering)
        let remaining = source.filter { $0.id != hero.id }
        let ranked = SmartPickEngine.ranked(from: remaining, currentEnergy: currentEnergy)
        withAnimation(AnimationConstants.springSmooth) {
            upNextItems = Array(ranked.prefix(2))
            pileItems = ranked.count > 2 ? Array(ranked.dropFirst(2)) : []
        }
    }
    
    // MARK: - Category Filter Strip
    
    private var categoryFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingXS) {
                // "All" chip
                filterChip(
                    icon: "sparkles",
                    label: String(localized: "All · \(allActive.count)"),
                    isSelected: selectedCategoryFilter == nil,
                    color: DesignTokens.accentActive
                ) {
                    withAnimation(AnimationConstants.springSmooth) {
                        selectedCategoryFilter = nil
                    }
                    pickHero()
                }
                
                ForEach(activeCategories, id: \.self) { category in
                    let count = allActive.filter { $0.resolvedCategory == category }.count
                    filterChip(
                        icon: category.icon,
                        label: "\(category.label) · \(count)",
                        isSelected: selectedCategoryFilter == category,
                        color: category.primaryColor
                    ) {
                        withAnimation(AnimationConstants.springSmooth) {
                            selectedCategoryFilter = (selectedCategoryFilter == category) ? nil : category
                        }
                        pickHero()
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingXS)
        }
    }
    
    private func filterChip(icon: String, label: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.shared.snoozeTimeSelected()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : DesignTokens.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.30) : Color.white.opacity(0.05))
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? color.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.95)
            .animation(AnimationConstants.springSnappy, value: isSelected)
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: isSelected ? String(localized: "\(label), selected") : label,
            hint: String(localized: "Filter tasks by category"),
            traits: isSelected ? [.isButton, .isSelected] : .isButton
        )
    }
    
    // MARK: - Actions
    
    private func markDoneWithCelebration(_ item: NudgeItem) {
        let previousSortOrder = item.sortOrder
        repository?.markDone(item)
        HapticService.shared.completionHaptic(for: item.resolvedCategory)
        SoundService.shared.playTaskDone()
        
        // Remove from Spotlight
        SpotlightIndexer.removeTask(id: item.id)
        
        // Phase 7: Category-colored celebration particles
        let doneCat = item.resolvedCategory
        completionCategoryColor = doneCat != .general ? doneCat.primaryColor : nil
        showCompletionParticles = true
        
        // Phase 7: Category counter for SpeciesToast
        if doneCat != .general {
            let catDoneToday = doneToday.filter { $0.resolvedCategory == doneCat }.count + 1 // +1 for this one
            lastCompletionCategoryInfo = (icon: doneCat.icon, label: doneCat.label, count: catDoneToday)
        } else {
            lastCompletionCategoryInfo = nil
        }
        
        // Record fish reward
        let isAllClear = allActive.count <= 1
        let earned = RewardService.shared.recordCompletion(
            context: modelContext,
            item: item,
            isAllClear: isAllClear
        )
        let species = FishEconomy.speciesForTask(item)
        lastEarnedSpecies = species
        lastFishEarned = earned
        
        // Post fish burst
        NotificationCenter.default.post(
            name: .nudgeFishBurst,
            object: nil,
            userInfo: [
                "origin": CGPoint(x: 200, y: 400),
                "hudPosition": fishHUDPosition,
                "fishCount": min(species.fishValue, 5),
                "categoryRaw": item.resolvedCategory.rawValue
            ]
        )
        SoundService.shared.playFishCaught()
        
        // Pending fish for penguin tab
        NotificationCenter.default.post(
            name: .nudgePendingFish,
            object: nil,
            userInfo: ["count": 1]
        )
        
        // Tab chomp → NudgyPeek → SpeciesToast (sequenced)
        Task { @MainActor in
            // 0.4s — tab chomp
            try? await Task.sleep(for: .seconds(0.4))
            NotificationCenter.default.post(
                name: .nudgeTabChomp,
                object: nil,
                userInfo: ["species": species.label]
            )
            
            // 0.8s — SpeciesToast slides in
            try? await Task.sleep(for: .seconds(0.4))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showSpeciesToast = true
            }
            
            // 4.2s — auto-dismiss SpeciesToast
            try? await Task.sleep(for: .seconds(3.0))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showSpeciesToast = false
            }
            // Clear species after animation
            try? await Task.sleep(for: .seconds(0.35))
            lastEarnedSpecies = nil
            lastFishEarned = 0
        }
        
        // Reset skip cycle
        skipManager.recordCompletion()
        
        // Undo
        undoItem = item
        undoPreviousSortOrder = previousSortOrder
        undoTimerTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showUndoToast = true
        }
        undoTimerTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            dismissUndoToast()
        }
        
        // Refresh and sync
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }
    
    private func snoozeQuick(_ item: NudgeItem) {
        let snoozeDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        repository?.snooze(item, until: snoozeDate)
        HapticService.shared.swipeSnooze()
        SoundService.shared.playSnooze()
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }
    
    /// Wake the oldest snoozed task — called from the "all snoozed" empty state.
    private func wakeOldestSnooze() {
        guard let oldest = snoozedItems.sorted(by: { $0.snoozedUntil ?? .distantFuture < $1.snoozedUntil ?? .distantFuture }).first else { return }
        repository?.resurfaceItem(oldest)
        HapticService.shared.cardAppear()
        SoundService.shared.playNudgeKnock()
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }
    
    private func skipToNext(_ item: NudgeItem) {
        HapticService.shared.prepare()
        
        withAnimation(reduceMotion ? .none : AnimationConstants.springSmooth) {
            skipManager.recordSkip(item: item, streak: RewardService.shared.currentStreak)
            pickHero()
        }
    }
    
    private func openDetail(for item: NudgeItem, in list: [NudgeItem]) {
        detailItems = list
        detailSelectedIndex = list.firstIndex(where: { $0.id == item.id }) ?? 0
        withAnimation(AnimationConstants.springSmooth) {
            showDetailPopup = true
        }
        HapticService.shared.actionButtonTap()
    }
    
    private func promoteToHero(_ item: NudgeItem) {
        HapticService.shared.actionButtonTap()
        
        // Reset skips when user makes a deliberate choice
        skipManager.recordCompletion()
        
        withAnimation(reduceMotion ? .none : AnimationConstants.springSmooth) {
            heroItem = item
            heroReason = SmartPickEngine.reason(for: item)
            if heroReason.isEmpty { heroReason = String(localized: "let's get this one done") }
            heroTransitionID = UUID()
            
            let remaining = filteredActive.filter { $0.id != item.id }
            let ranked = SmartPickEngine.ranked(from: remaining, currentEnergy: currentEnergy)
            upNextItems = Array(ranked.prefix(2))
            pileItems = ranked.count > 2 ? Array(ranked.dropFirst(2)) : []
        }
        
        // Announce to VoiceOver
        UIAccessibility.post(notification: .announcement, argument: item.content)
        
        triggerHeroDraft(item)
    }
    
    private func performAction(_ item: NudgeItem) {
        guard let actionType = item.actionType else { return }
        HapticService.shared.actionButtonTap()
        ActionService.perform(action: actionType, item: item)
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
        withAnimation(AnimationConstants.springSmooth) {
            showUndoToast = false
        }
        undoItem = nil
    }
    
    // MARK: - Draft Generation
    
    private func triggerDraftGeneration() {
        guard let repository else { return }
        draftGenerationTask?.cancel()
        draftGenerationTask = Task {
            let needsDraft = allActive.filter { item in
                guard let actionType = item.actionType,
                      actionType == .text || actionType == .email else { return false }
                return !item.hasDraft
            }
            
            for item in needsDraft {
                guard !Task.isCancelled else { break }
                await DraftService.shared.generateDraftIfNeeded(
                    for: item,
                    isPro: settings.isPro,
                    repository: repository,
                    senderName: settings.userName.isEmpty ? nil : settings.userName
                )
            }
        }
    }
    
    private func triggerHeroDraft(_ item: NudgeItem) {
        guard let repository,
              let actionType = item.actionType,
              actionType == .text || actionType == .email,
              !item.hasDraft else { return }
        
        Task {
            await DraftService.shared.generateDraftIfNeeded(
                for: item,
                isPro: settings.isPro,
                repository: repository,
                senderName: settings.userName.isEmpty ? nil : settings.userName
            )
            // Refresh to show the newly generated draft
            refreshData()
        }
    }
    
    private func regenerateDraft(_ item: NudgeItem) {
        guard let repository else { return }
        Task {
            await DraftService.shared.regenerateDraft(
                for: item,
                isPro: settings.isPro,
                repository: repository,
                senderName: settings.userName.isEmpty ? nil : settings.userName
            )
            refreshData()
        }
    }
    
    // MARK: - Live Activity
    
    private func syncLiveActivity() {
        syncWidgetData()
        
        if let repository {
            SpotlightIndexer.indexAllTasks(from: repository)
        }
        
        guard settings.liveActivityEnabled else { return }
        
        guard let topItem = heroItem ?? allActive.first else {
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
    
    /// Phase 7: Build category recap for empty state
    private func buildCategoryRecap() -> [(icon: String, label: String, color: Color, count: Int)] {
        var counts: [TaskCategory: Int] = [:]
        for item in doneToday {
            let cat = item.resolvedCategory
            guard cat != .general else { continue }
            counts[cat, default: 0] += 1
        }
        return counts
            .map { (icon: $0.key.icon, label: $0.key.label, color: $0.key.primaryColor, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private func syncWidgetData() {
        // Use heroItem as the "next" task if set, otherwise first active
        let orderedActive: [NudgeItem] = {
            guard let hero = heroItem else { return allActive }
            // Put heroItem first so WidgetDataService picks it as the next task
            return [hero] + allActive.filter { $0.id != hero.id }
        }()
        let completedCount = doneToday.count
        let totalCount = totalToday
        
        // Get wardrobe for gamification data
        let wardrobe: NudgyWardrobe? = {
            let descriptor = FetchDescriptor<NudgyWardrobe>()
            return try? modelContext.fetch(descriptor).first
        }()
        
        WidgetDataService.sync(
            activeTasks: orderedActive,
            completedTodayCount: completedCount,
            totalTodayCount: totalCount,
            wardrobe: wardrobe
        )
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NudgeItem.self, BrainDump.self, NudgyWardrobe.self, configurations: config)
    
    let ctx = container.mainContext
    let item1 = NudgeItem(content: "Call Dr. Patel about prescription", emoji: "📞", actionType: .call, actionTarget: "555-1234", contactName: "Dr. Patel", sortOrder: 1)
    item1.aiDraft = "Ask about prescription renewal\nConfirm next appointment"
    item1.estimatedMinutes = 10
    ctx.insert(item1)
    
    let item2 = NudgeItem(content: "Text Sarah about Saturday plans", emoji: "💬", actionType: .text, actionTarget: "555-5678", contactName: "Sarah", sortOrder: 2)
    item2.aiDraft = "Hey Sarah! Are we still on for brunch at 11?"
    ctx.insert(item2)
    
    ctx.insert(NudgeItem(content: "Buy dog food", emoji: "🐶", sortOrder: 3))
    ctx.insert(NudgeItem(content: "Clean kitchen", emoji: "🧹", sortOrder: 4))
    ctx.insert(NudgeItem(content: "File expense report", emoji: "📊", sortOrder: 5))
    
    return NudgesPageView()
        .modelContainer(container)
        .environment(AppSettings())
        .environment(PenguinState())
}
