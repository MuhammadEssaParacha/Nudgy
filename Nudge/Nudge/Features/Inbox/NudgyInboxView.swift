//
//  NudgyInboxView.swift
//  Nudge
//
//  The Nudgy Inbox — where AI-organized tasks and suggestions land.
//  This is the "approval layer" — Nudgy proposes, you approve.
//
//  Replaces the old AllItemsView. Groups items by:
//  • Nudgy Suggestions (AI-prioritized tasks needing approval)
//  • Up Next (active queue)
//  • Snoozed (waiting)
//  • Done Today (completed)
//

import SwiftUI
import SwiftData
import TipKit

struct NudgyInboxView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(PenguinState.self) private var penguinState
    
    @State private var repository: NudgeRepository?
    @State private var activeItems: [NudgeItem] = []
    @State private var snoozedItems: [NudgeItem] = []
    @State private var doneItems: [NudgeItem] = []
    @State private var editingItem: NudgeItem?
    @State private var showSnoozeFor: NudgeItem?
    @State private var showBreakdownFor: NudgeItem?
    
    // Undo state
    @State private var undoItem: NudgeItem?
    @State private var undoPreviousSortOrder: Int = 0
    @State private var showUndoToast = false
    @State private var undoTimerTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if activeItems.isEmpty && snoozedItems.isEmpty && doneItems.isEmpty {
                    emptyView
                } else {
                    listContent
                }
                
                // Undo toast
                if showUndoToast {
                    undoToastView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(String(localized: "Inbox"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
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
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            repository?.resurfaceExpiredSnoozes()
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeDataChanged)) { _ in
            refreshData()
        }
        .sheet(item: $editingItem) { item in
            ItemEditSheet(item: item) {
                refreshData()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $showSnoozeFor) { item in
            SnoozePickerView(item: item) { date in
                repository?.snooze(item, until: date)
                showSnoozeFor = nil
                refreshData()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $showBreakdownFor) { item in
            TaskBreakdownView(
                taskContent: item.content,
                taskEmoji: item.emoji
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.black)
        }
    }
    
    // MARK: - List Content
    
    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingLG) {
                
                // Up Next section
                if !activeItems.isEmpty {
                    inboxSection(
                        title: String(localized: "Up Next"),
                        icon: "sparkle",
                        count: activeItems.count,
                        color: DesignTokens.accentActive
                    ) {
                        ForEach(activeItems, id: \.id) { item in
                            InboxItemRow(
                                item: item,
                                onTap: { editingItem = item },
                                onDone: { markDoneWithUndo(item) },
                                onSnooze: { showSnoozeFor = item },
                                onBreakDown: { showBreakdownFor = item }
                            )
                        }
                    }
                }
                
                // Snoozed section
                if !snoozedItems.isEmpty {
                    inboxSection(
                        title: String(localized: "Snoozed"),
                        icon: "clock.fill",
                        count: snoozedItems.count,
                        color: DesignTokens.textSecondary
                    ) {
                        ForEach(snoozedItems, id: \.id) { item in
                            InboxItemRow(
                                item: item,
                                onTap: { editingItem = item },
                                onDone: { markDoneWithUndo(item) },
                                onSnooze: nil,
                                onBreakDown: nil
                            )
                        }
                    }
                }
                
                // Done Today section
                if !doneItems.isEmpty {
                    inboxSection(
                        title: String(localized: "Done Today"),
                        icon: "checkmark.circle.fill",
                        count: doneItems.count,
                        color: DesignTokens.accentComplete
                    ) {
                        ForEach(doneItems, id: \.id) { item in
                            InboxItemRow(
                                item: item,
                                onTap: { editingItem = item },
                                onDone: nil,
                                onSnooze: nil,
                                onBreakDown: nil
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
        .refreshable { refreshData() }
    }
    
    // MARK: - Section Builder
    
    private func inboxSection<Content: View>(
        title: String,
        icon: String,
        count: Int,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            // Section header
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .textCase(.uppercase)
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.12))
                    )
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingXS)
            
            content()
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()
            
            PenguinSceneView(
                size: .large,
                expressionOverride: .sleeping,
                accentColorOverride: DesignTokens.textTertiary
            )
            .onAppear {
                penguinState.expression = .sleeping
                penguinState.say(
                    String(localized: "Your inbox is empty!\nTap Nudgy to get started."),
                    style: .whisper,
                    autoDismiss: 6.0
                )
            }
            
            VStack(spacing: DesignTokens.spacingMD) {
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
                            .strokeBorder(DesignTokens.accentActive, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Undo
    
    private func markDoneWithUndo(_ item: NudgeItem) {
        undoPreviousSortOrder = item.sortOrder
        repository?.markDone(item)
        HapticService.shared.completionHaptic(for: item.resolvedCategory)
        
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
    }
    
    private func undoLastDone() {
        guard let item = undoItem else { return }
        repository?.undoDone(item, restoreSortOrder: undoPreviousSortOrder)
        undoTimerTask?.cancel()
        dismissUndoToast()
        HapticService.shared.prepare()
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
    }
    
    private func dismissUndoToast() {
        withAnimation(.easeOut(duration: 0.25)) {
            showUndoToast = false
        }
        undoItem = nil
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
    
    // MARK: - Helpers
    
    private func setupRepository() {
        if repository == nil {
            repository = NudgeRepository(modelContext: modelContext)
        }
    }
    
    private func refreshData() {
        guard let repository else { return }
        let grouped = repository.fetchAllGrouped()
        activeItems = grouped.active
        snoozedItems = grouped.snoozed
        doneItems = grouped.doneToday
    }
}

// MARK: - Inbox Item Row (Glass Card)

struct InboxItemRow: View {
    
    let item: NudgeItem
    var onTap: () -> Void = {}
    var onDone: (() -> Void)?
    var onSnooze: (() -> Void)?
    var onBreakDown: (() -> Void)?
    var onFocus: (() -> Void)?
    
    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }
    
    private var category: TaskCategory { item.resolvedCategory }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.spacingMD) {
                // Icon
                TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .medium, accentColor: accentColor)
                
                // Content
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(item.content)
                        .font(AppTheme.body)
                        .foregroundStyle(
                            item.status == .done
                                ? DesignTokens.textTertiary
                                : DesignTokens.textPrimary
                        )
                        .strikethrough(item.status == .done)
                        .lineLimit(2)
                    
                    HStack(spacing: DesignTokens.spacingSM) {
                        if item.status == .snoozed, let until = item.snoozedUntil {
                            Label(until.friendlySnoozeDescription, systemImage: "clock")
                        } else if item.status == .done, let completedAt = item.completedAt {
                            Label(completedAt.relativeDescription, systemImage: "checkmark")
                                .foregroundStyle(DesignTokens.accentComplete)
                        } else {
                            Text(item.createdAt.relativeDescription)
                        }
                        
                        if let actionType = item.actionType {
                            Image(systemName: actionType.icon)
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                        
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
                        
                        // Category chip
                        if category != .general {
                            HStack(spacing: 3) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(category.primaryColor)
                                Text(category.label)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(category.primaryColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(category.primaryColor.opacity(0.10))
                            )
                        }
                    }
                    .font(AppTheme.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
                }
                
                Spacer()
                
                // Quick action buttons
                HStack(spacing: DesignTokens.spacingSM) {
                    if let onFocus, item.status != .done {
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
                    }
                    
                    if let onBreakDown, AIService.shared.isAvailable {
                        Button {
                            HapticService.shared.prepare()
                            onBreakDown()
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundStyle(DesignTokens.accentActive)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(DesignTokens.accentActive.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
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
            }
            .padding(DesignTokens.spacingMD)
            .background {
                // Accent glow visible through glass — category-tinted for non-general
                let tintColor = category != .general ? category.primaryColor : accentColor
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(
                        LinearGradient(
                            colors: [tintColor.opacity(item.isStale ? 0.10 : 0.05), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDone {
                Button { onDone() } label: {
                    Label(String(localized: "Mark Done"), systemImage: "checkmark.circle")
                }
            }
            if let onSnooze {
                Button { onSnooze() } label: {
                    Label(String(localized: "Snooze"), systemImage: "clock")
                }
            }
            if let onBreakDown, AIService.shared.isAvailable {
                Button { onBreakDown() } label: {
                    Label(String(localized: "Break it down"), systemImage: "sparkles")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NudgeItem.self, BrainDump.self, configurations: config)
    
    let ctx = container.mainContext
    ctx.insert(NudgeItem(content: "Call the dentist", emoji: "📞", actionType: .call, sortOrder: 1))
    ctx.insert(NudgeItem(content: "Buy dog food", emoji: "🐶", sortOrder: 2))
    ctx.insert(NudgeItem(content: "Read Jake's article", emoji: "📖", sortOrder: 3))
    
    let doneItem = NudgeItem(content: "Reply to Sarah", emoji: "💬", sortOrder: 0)
    doneItem.markDone()
    ctx.insert(doneItem)
    
    return NudgyInboxView()
        .modelContainer(container)
        .environment(AppSettings())
        .environment(PenguinState())
}
