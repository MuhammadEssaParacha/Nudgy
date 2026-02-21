//
//  NudgeDetailPopup.swift
//  Nudge
//
//  Fullscreen glassmorphism popup for task detail.
//  Appears on tap with spring scale, supports swipe-left/right
//  to navigate between tasks in the same section.
//
//  ADHD-optimized: one card at a time, contextual actions,
//  swipe gestures for fluid navigation, dismiss via drag-down.
//

import SwiftUI
import SafariServices
import os

// MARK: - Popup Container (manages card stack + navigation)

struct NudgeDetailPopup: View {

    let items: [NudgeItem]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    // Actions passed from NudgesView
    var onDone: (NudgeItem) -> Void
    var onSnooze: (NudgeItem, Date) -> Void
    var onDelete: (NudgeItem) -> Void
    var onFocus: (NudgeItem) -> Void
    var onAction: (NudgeItem) -> Void
    var onContentChanged: () -> Void

    // Gesture state
    @State private var dragOffset: CGSize = .zero
    @State private var dismissProgress: CGFloat = 0
    @State private var navigateDirection: NavigateDirection = .none
    @State private var isAnimatingTransition = false

    // Appear animation
    @State private var appeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum NavigateDirection {
        case none, left, right
    }

    private var currentItem: NudgeItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    private var hasPrev: Bool { selectedIndex > 0 }
    private var hasNext: Bool { selectedIndex < items.count - 1 }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(appeared ? 0.75 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Card stack
            if let item = currentItem {
                cardStack(for: item)
            }

            // Navigation dots
            if items.count > 1 {
                VStack {
                    Spacer()
                    navigationDots
                        .padding(.bottom, 16)
                        .opacity(appeared ? 1 : 0)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }

    // MARK: - Card Stack

    @ViewBuilder
    private func cardStack(for item: NudgeItem) -> some View {
        ZStack {
            // Peek cards (behind current)
            if hasNext {
                peekCard(offset: 1)
                    .offset(x: 18 + dragOffset.width * -0.05)
                    .scaleEffect(0.92)
                    .opacity(0.3)
                    .blur(radius: 2)
            }

            if hasPrev {
                peekCard(offset: -1)
                    .offset(x: -18 + dragOffset.width * -0.05)
                    .scaleEffect(0.92)
                    .opacity(0.3)
                    .blur(radius: 2)
            }

            // Main card
            NudgeDetailCard(
                item: item,
                onDone: { onDone(item); dismiss() },
                onSnooze: { date in onSnooze(item, date); dismiss() },
                onDelete: { onDelete(item); dismissAfterDelete() },
                onFocus: { onFocus(item); dismiss() },
                onAction: { onAction(item) },
                onContentChanged: onContentChanged,
                onClose: { dismiss() },
                itemIndex: selectedIndex + 1,
                totalItems: items.count
            )
            .offset(x: dragOffset.width, y: max(0, dragOffset.height))
            .scaleEffect(
                1.0 - (abs(dismissProgress) * 0.05),
                anchor: .center
            )
            .rotationEffect(.degrees(Double(dragOffset.width) / 30), anchor: .bottom)
            .opacity(1.0 - abs(dismissProgress) * 0.3)
            .gesture(cardGesture)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.top, 60)
        .padding(.bottom, 50)
    }

    private func peekCard(offset: Int) -> some View {
        let idx = selectedIndex + offset
        let item = items.indices.contains(idx) ? items[idx] : items[selectedIndex]
        let accentColor = AccentColorSystem.shared.color(for: item.accentStatus)

        return RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard + 4)
            .fill(
                LinearGradient(
                    colors: [accentColor.opacity(0.06), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.cornerRadiusCard + 4))
            .frame(maxHeight: .infinity)
    }

    // MARK: - Navigation Dots

    private var navigationDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<min(items.count, 10), id: \.self) { i in
                Circle()
                    .fill(i == selectedIndex ? Color.white : Color.white.opacity(0.25))
                    .frame(width: i == selectedIndex ? 8 : 5, height: i == selectedIndex ? 8 : 5)
                    .animation(.spring(response: 0.3), value: selectedIndex)
            }
            if items.count > 10 {
                Text("+\(items.count - 10)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
    }

    // MARK: - Gesture

    private var cardGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard !isAnimatingTransition else { return }
                dragOffset = value.translation

                // Track dismiss progress (vertical)
                let verticalProgress = value.translation.height / 300
                dismissProgress = max(0, verticalProgress)
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                let hVelocity = value.predictedEndTranslation.width

                // Dismiss downward
                if vertical > 150 || value.predictedEndTranslation.height > 400 {
                    dismiss()
                    return
                }

                // Navigate left (next)
                if (horizontal < -80 || hVelocity < -500) && hasNext {
                    navigateToNext()
                    return
                }

                // Navigate right (prev)
                if (horizontal > 80 || hVelocity > 500) && hasPrev {
                    navigateToPrev()
                    return
                }

                // Snap back
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    dragOffset = .zero
                    dismissProgress = 0
                }
            }
    }

    // MARK: - Navigation

    private func navigateToNext() {
        guard hasNext else { return }
        isAnimatingTransition = true

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            dragOffset = CGSize(width: -UIScreen.current.bounds.width, height: 0)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            selectedIndex += 1
            dragOffset = CGSize(width: UIScreen.current.bounds.width * 0.3, height: 0)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                dragOffset = .zero
                dismissProgress = 0
            }
            HapticService.shared.actionButtonTap()
            isAnimatingTransition = false
        }
    }

    private func navigateToPrev() {
        guard hasPrev else { return }
        isAnimatingTransition = true

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            dragOffset = CGSize(width: UIScreen.current.bounds.width, height: 0)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            selectedIndex -= 1
            dragOffset = CGSize(width: -UIScreen.current.bounds.width * 0.3, height: 0)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                dragOffset = .zero
                dismissProgress = 0
            }
            HapticService.shared.actionButtonTap()
            isAnimatingTransition = false
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        HapticService.shared.actionButtonTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            appeared = false
            dragOffset = CGSize(width: 0, height: 300)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25))
            isPresented = false
        }
    }

    private func dismissAfterDelete() {
        // If we deleted the last item, close popup
        if items.count <= 1 {
            dismiss()
            return
        }
        // If we deleted the last item in the list, go to previous
        if selectedIndex >= items.count - 1 {
            selectedIndex = max(0, items.count - 2)
        }
        // Let the parent refresh, card will update
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            dragOffset = .zero
        }
    }
}

// MARK: - Detail Card (the actual content card)

struct NudgeDetailCard: View {

    let item: NudgeItem

    var onDone: (() -> Void)?
    var onSnooze: ((Date) -> Void)?
    var onDelete: (() -> Void)?
    var onFocus: (() -> Void)?
    var onAction: (() -> Void)?
    var onContentChanged: (() -> Void)?
    var onClose: (() -> Void)?

    var itemIndex: Int = 1
    var totalItems: Int = 1

    // State
    @State private var isEditing = false
    @State private var editedContent: String = ""
    @State private var showSnoozeOptions = false
    @State private var showAlarmPicker = false
    @State private var alarmDate: Date = Date().addingTimeInterval(3600)
    @State private var alarmSet = false
    @State private var showMicroSteps = false
    @State private var microSteps: [MicroStep] = []
    @State private var isLoadingSteps = false
    @State private var showInAppBrowser = false
    @State private var browserURL: URL?
    @State private var showDraftFull = false
    @State private var showCategoryPicker = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {

                // ─── Handle + Position ───
                handleBar

                // ─── Header: Icon + Content + Close ───
                headerSection

                // ─── Compact metadata ───
                compactMeta

                thinDivider

                // ─── Primary Action Area ───
                primaryActionArea

                // ─── Micro-steps (opt-in) ───
                if showMicroSteps {
                    thinDivider
                    microStepsArea
                }

                // ─── Snooze grid (opt-in) ───
                if showSnoozeOptions {
                    thinDivider
                    snoozeGrid
                }

                // ─── Alarm picker (opt-in) ───
                if showAlarmPicker {
                    thinDivider
                    alarmPickerSection
                }

                thinDivider

                // ─── Toolbar ───
                toolbar
            }
            .padding(DesignTokens.spacingLG)
        }
        .frame(maxHeight: UIScreen.current.bounds.height * 0.72)
        .background { cardBackground }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard + 4))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard + 4))
        .shadow(color: accentColor.opacity(0.15), radius: 30, y: 10)
        .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
        .onAppear { editedContent = item.content }
        .sheet(isPresented: $showInAppBrowser) {
            if let url = browserURL {
                InAppBrowserView(url: url) {
                    showInAppBrowser = false
                    browserURL = nil
                }
                .ignoresSafeArea()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .nudgeAccessibilityElement(
            label: String(localized: "Task detail: \(item.content)"),
            hint: String(localized: "Swipe left or right to navigate between tasks. Swipe down to close."),
            value: String(localized: "Item \(itemIndex) of \(totalItems)")
        )
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard + 4)
            .fill(
                LinearGradient(
                    colors: [accentColor.opacity(0.10), accentColor.opacity(0.02), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - Handle Bar

    private var handleBar: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
            Spacer()
        }
        .padding(.top, DesignTokens.spacingXS)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
            // Icon
            TaskIconView(
                emoji: item.emoji,
                actionType: item.actionType,
                size: .large,
                accentColor: accentColor
            )

            // Content (editable)
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                if isEditing {
                    TextField(
                        String(localized: "Task description"),
                        text: $editedContent,
                        axis: .vertical
                    )
                    .font(AppTheme.body.weight(.medium))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .padding(DesignTokens.spacingSM)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.06))
                    )
                    .onSubmit { saveEdit() }
                } else {
                    Text(item.content)
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Contact
                if let contact = item.contactName, !contact.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text(contact)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(DesignTokens.textSecondary)
                }
            }

            Spacer(minLength: 0)

            // Close button
            Button {
                HapticService.shared.actionButtonTap()
                onClose?()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Close"),
                hint: String(localized: "Dismiss task detail"),
                traits: .isButton
            )
        }
    }

    // MARK: - Compact Metadata

    private var compactMeta: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Tappable category chip — opens picker for manual override
            if item.actionType == nil {
                Button {
                    HapticService.shared.actionButtonTap()
                    showCategoryPicker = true
                } label: {
                    HStack(spacing: 4) {
                        CategoryChip(category: item.resolvedCategory, small: false)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showCategoryPicker) {
                    NavigationStack {
                        TaskCategoryPicker(selectedCategory: Binding(
                            get: { item.category },
                            set: { newCat in
                                if let cat = newCat {
                                    item.category = cat
                                } else {
                                    item.categoryRaw = nil
                                }
                                item.updatedAt = Date()
                                onContentChanged?()
                            }
                        ))
                        .navigationTitle(String(localized: "Category"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "Done")) {
                                    showCategoryPicker = false
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium])
                    .preferredColorScheme(.dark)
                }
            }
            
            if let priority = item.priority {
                metadataChip(
                    icon: priority == .high ? "flame.fill" : priority == .medium ? "equal" : "arrow.down",
                    text: priority.rawValue.capitalized,
                    color: priority == .high ? DesignTokens.accentOverdue : priority == .medium ? DesignTokens.accentStale : DesignTokens.textTertiary
                )
            }
            if let dur = item.durationLabel {
                metadataChip(icon: "clock", text: dur, color: DesignTokens.textSecondary)
            }
            if let due = item.dueDate {
                metadataChip(
                    icon: "calendar",
                    text: due.formatted(.dateTime.month(.abbreviated).day()),
                    color: due.isPast ? DesignTokens.accentOverdue : DesignTokens.textSecondary
                )
            }
            if item.isStale {
                metadataChip(
                    icon: "exclamationmark.triangle.fill",
                    text: String(localized: "\(item.ageInDays)d old"),
                    color: DesignTokens.accentStale
                )
            }
            Spacer()
        }
    }

    private func metadataChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.10)))
    }

    // MARK: - Primary Action Area

    @ViewBuilder
    private var primaryActionArea: some View {
        if item.hasDraft {
            draftCard
        } else if item.hasAction {
            actionCard
        } else {
            // Category-aware: show category tools for recognized categories
            let cat = item.resolvedCategory
            if cat != .general {
                CategoryCardView(
                    item: item,
                    category: cat,
                    onFocus: onFocus,
                    onAction: onAction,
                    onTimerStart: { minutes in
                        item.estimatedMinutes = minutes
                        onFocus?()
                    },
                    onOpenMaps: {
                        let query = item.actionTarget ?? item.content
                        if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let url = URL(string: "maps://?q=\(encoded)") {
                            UIApplication.shared.open(url)
                        }
                    },
                    onAddCalendar: {
                        HapticService.shared.actionButtonTap()
                        Task {
                            if let _ = await CalendarService.shared.createEvent(from: item) {
                                HapticService.shared.swipeDone()
                            } else {
                                HapticService.shared.error()
                                Log.ui.error("Failed to create calendar event")
                            }
                        }
                    }
                )
            } else {
                let urls = URLActionGenerator.generateActions(
                    for: item.content,
                    actionType: item.actionType,
                    actionTarget: item.actionTarget
                )
                if !urls.isEmpty {
                    urlActionsCard(urls)
                }
            }
        }
    }

    // MARK: Draft Card

    private var draftCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            if let subject = item.aiDraftSubject, !subject.isEmpty {
                Text(subject)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(1)
            }
            Text(item.aiDraft ?? "")
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.textSecondary.opacity(0.85))
                .lineLimit(showDraftFull ? nil : 5)
                .fixedSize(horizontal: false, vertical: showDraftFull)

            if (item.aiDraft?.count ?? 0) > 120 {
                Button {
                    withAnimation(AnimationConstants.springSmooth) {
                        showDraftFull.toggle()
                    }
                } label: {
                    Text(showDraftFull ? String(localized: "Show less") : String(localized: "Show more"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignTokens.accentActive)
                }
                .buttonStyle(.plain)
            }

            // Send button
            Button {
                HapticService.shared.actionButtonTap()
                onAction?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: item.actionType?.icon ?? "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(sendLabel)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Capsule().fill(accentColor))
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: sendLabel,
                hint: String(localized: "Send the drafted message"),
                traits: .isButton
            )
        }
        .padding(DesignTokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accentColor.opacity(0.05))
        )
    }

    private var sendLabel: String {
        switch item.actionType {
        case .text:  return String(localized: "Send Text")
        case .email: return String(localized: "Send Email")
        case .call:  return String(localized: "Call")
        default:     return String(localized: "Review & Send")
        }
    }

    // MARK: Action Card

    private var actionCard: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            if let actionType = item.actionType {
                Button {
                    HapticService.shared.actionButtonTap()
                    onAction?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: actionType.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(actionType.label)
                            .font(.system(size: 16, weight: .semibold))
                        if let contact = item.contactName {
                            Text(contact)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(accentColor))
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "\(actionType.label) \(item.contactName ?? "")"),
                    hint: String(localized: "Perform the action for this task"),
                    traits: .isButton
                )
            }

            // URL hints
            let urls = URLActionGenerator.generateActions(
                for: item.content,
                actionType: item.actionType,
                actionTarget: item.actionTarget
            )
            if !urls.isEmpty {
                ForEach(Array(urls.prefix(2).enumerated()), id: \.offset) { _, action in
                    urlRow(action)
                }
            }
        }
    }

    // MARK: URL Actions

    private func urlActionsCard(_ urls: [URLAction]) -> some View {
        VStack(spacing: DesignTokens.spacingXS) {
            ForEach(Array(urls.prefix(3).enumerated()), id: \.offset) { _, action in
                urlRow(action)
            }
        }
    }

    private func urlRow(_ action: URLAction) -> some View {
        Button {
            HapticService.shared.actionButtonTap()
            if action.openInApp {
                browserURL = action.url
                showInAppBrowser = true
            } else {
                UIApplication.shared.open(action.url)
            }
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: action.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.accentActive)
                    .frame(width: 22)

                Text(action.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignTokens.textPrimary)

                Spacer()

                Text(action.displayDomain)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Micro-Steps

    private var microStepsArea: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            if !microSteps.isEmpty {
                let done = microSteps.filter(\.isComplete).count
                HStack(spacing: 4) {
                    Text(String(localized: "Steps"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .textCase(.uppercase)

                    Text("\(done)/\(microSteps.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.accentActive)

                    Spacer()

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule()
                                .fill(DesignTokens.accentComplete)
                                .frame(width: geo.size.width * CGFloat(done) / max(1, CGFloat(microSteps.count)))
                        }
                    }
                    .frame(width: 60, height: 4)

                    Button {
                        withAnimation(AnimationConstants.springSmooth) {
                            showMicroSteps = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isLoadingSteps {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(DesignTokens.accentActive)
                        .scaleEffect(0.7)
                    Text(String(localized: "Breaking it down…"))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .padding(.vertical, DesignTokens.spacingSM)
            } else {
                ForEach($microSteps) { $step in
                    Button {
                        withAnimation(AnimationConstants.springSmooth) {
                            step.isComplete.toggle()
                        }
                        HapticService.shared.swipeDone()
                        checkAllComplete()
                    } label: {
                        HStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(step.isComplete ? DesignTokens.accentComplete : DesignTokens.textTertiary.opacity(0.4))

                            StepIconView(emoji: step.emoji, size: 14)

                            Text(step.content)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(step.isComplete ? DesignTokens.textTertiary : DesignTokens.textPrimary)
                                .strikethrough(step.isComplete, color: DesignTokens.textTertiary)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(
                        label: "\(step.isComplete ? String(localized: "Completed") : String(localized: "Not completed")): \(step.content)",
                        hint: String(localized: "Toggle step completion"),
                        traits: .isButton
                    )
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Snooze Grid

    private var snoozeGrid: some View {
        let cal = Calendar.current
        let now = Date()
        let options: [(String, String, Date)] = [
            ("2h", "clock.fill", cal.date(byAdding: .hour, value: 2, to: now)!),
            ("Tonight", "moon.fill", cal.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now),
            ("Tomorrow", "sunrise.fill", cal.date(byAdding: .day, value: 1, to: cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now)!),
            ("Next Week", "calendar", cal.date(byAdding: .day, value: 7, to: cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now)!)
        ]

        return VStack(spacing: DesignTokens.spacingSM) {
            HStack {
                Text(String(localized: "Snooze until…"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    withAnimation(AnimationConstants.springSmooth) {
                        showSnoozeOptions = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(options, id: \.0) { label, icon, date in
                    Button {
                        HapticService.shared.actionButtonTap()
                        onSnooze?(date)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                            Text(String(localized: String.LocalizationValue(label)))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(DesignTokens.accentStale)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(DesignTokens.accentStale.opacity(0.07))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Alarm Picker
    
    private var alarmPickerSection: some View {
        let tint = Color(hex: "FF9F0A")
        let cal = Calendar.current
        let now = Date()
        let presets: [(String, String, Date)] = [
            ("5 min", "clock.fill", cal.date(byAdding: .minute, value: 5, to: now)!),
            ("15 min", "clock.fill", cal.date(byAdding: .minute, value: 15, to: now)!),
            ("30 min", "clock.fill", cal.date(byAdding: .minute, value: 30, to: now)!),
            ("1 hour", "clock.fill", cal.date(byAdding: .hour, value: 1, to: now)!),
            ("Tomorrow 9am", "sunrise.fill", cal.date(byAdding: .day, value: 1, to: cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now)!),
        ]
        
        return VStack(spacing: DesignTokens.spacingSM) {
            HStack {
                Text(String(localized: "Set Alarm"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                if alarmSet {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text(String(localized: "Alarm set"))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(DesignTokens.accentComplete)
                }
                Button {
                    withAnimation(AnimationConstants.springSmooth) {
                        showAlarmPicker = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            // Quick presets
            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(presets.prefix(4), id: \.0) { label, icon, date in
                    Button {
                        HapticService.shared.actionButtonTap()
                        alarmDate = date
                        scheduleAlarm(at: date)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                            Text(String(localized: String.LocalizationValue(label)))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(tint.opacity(0.07))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Custom picker
            HStack(spacing: DesignTokens.spacingSM) {
                DatePicker(
                    String(localized: "Alarm time"),
                    selection: $alarmDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(tint)
                .colorScheme(.dark)
                
                Button {
                    HapticService.shared.actionButtonTap()
                    scheduleAlarm(at: alarmDate)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: alarmSet ? "checkmark.circle.fill" : "alarm.fill")
                            .font(.system(size: 12))
                        Text(alarmSet ? String(localized: "Set!") : String(localized: "Set"))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(alarmSet ? DesignTokens.accentComplete : tint)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private func scheduleAlarm(at date: Date) {
        Task {
            let permitted = await NotificationService.shared.requestPermission()
            if permitted {
                NotificationService.shared.scheduleAlarm(for: item, at: date)
                withAnimation(AnimationConstants.springSmooth) {
                    alarmSet = true
                }
                HapticService.shared.swipeDone()
            } else {
                HapticService.shared.error()
                Log.ui.warning("Alarm not scheduled — notification permission denied")
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 0) {
            toolbarBtn(icon: isEditing ? "checkmark" : "pencil", label: String(localized: "Edit"), color: isEditing ? DesignTokens.accentActive : DesignTokens.textSecondary) {
                withAnimation(AnimationConstants.springSmooth) {
                    if isEditing { saveEdit() } else { isEditing = true; editedContent = item.content }
                }
            }
            Spacer()
            toolbarBtn(icon: "sparkles", label: String(localized: "Steps"), color: showMicroSteps ? DesignTokens.accentActive : DesignTokens.textSecondary) {
                withAnimation(AnimationConstants.springSmooth) {
                    showMicroSteps.toggle()
                    if showMicroSteps && microSteps.isEmpty {
                        generateExecutionSteps()
                    }
                }
            }
            Spacer()
            toolbarBtn(icon: "moon.zzz.fill", label: String(localized: "Snooze"), color: showSnoozeOptions ? DesignTokens.accentStale : DesignTokens.textSecondary) {
                withAnimation(AnimationConstants.springSmooth) {
                    showSnoozeOptions.toggle()
                }
            }
            Spacer()
            toolbarBtn(icon: "alarm.fill", label: String(localized: "Alarm"), color: showAlarmPicker ? Color(hex: "FF9F0A") : DesignTokens.textSecondary) {
                withAnimation(AnimationConstants.springSmooth) {
                    showAlarmPicker.toggle()
                }
            }
            Spacer()
            toolbarBtn(icon: "timer", label: String(localized: "Focus"), color: DesignTokens.textSecondary) {
                onFocus?()
            }
            Spacer()
            toolbarBtn(icon: "trash", label: String(localized: "Delete"), color: DesignTokens.accentOverdue.opacity(0.7)) {
                onDelete?()
            }
            Spacer()
            toolbarBtn(icon: "checkmark.circle.fill", label: String(localized: "Done"), color: DesignTokens.accentComplete) {
                onDone?()
            }
        }
    }

    private func toolbarBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.shared.actionButtonTap()
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: label,
            hint: nil,
            traits: .isButton
        )
    }

    // MARK: - Divider

    private var thinDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
    }

    // MARK: - Helpers

    private func saveEdit() {
        if !editedContent.isEmpty && editedContent != item.content {
            item.content = editedContent
            item.updatedAt = Date()
            onContentChanged?()
        }
        isEditing = false
    }

    private func generateExecutionSteps() {
        guard microSteps.isEmpty else { return }
        isLoadingSteps = true
        Task {
            let steps = await MicroStepGenerator.generate(for: item.content, emoji: item.emoji, category: item.category)
            withAnimation(AnimationConstants.springSmooth) {
                microSteps = steps
                isLoadingSteps = false
            }
        }
    }

    private func checkAllComplete() {
        if !microSteps.isEmpty && microSteps.allSatisfy(\.isComplete) {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                onDone?()
            }
        }
    }
}
