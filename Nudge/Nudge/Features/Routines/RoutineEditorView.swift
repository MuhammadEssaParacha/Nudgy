//
//  RoutineEditorView.swift
//  Nudge
//
//  Create or edit a routine with steps, schedule, and emoji.
//  Steps support drag-to-reorder and inline editing.
//
//  ADHD-optimized: minimal required fields, visual emoji selection,
//  quick-add steps with default emojis.
//

import SwiftUI
import SwiftData
import os

struct RoutineEditorView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let routine: Routine?
    
    // Form state
    @State private var name: String = ""
    @State private var emoji: String = "checklist"
    @State private var schedule: RepeatSchedule = .daily
    @State private var customDays: Set<Int> = []
    @State private var startHour: Int = 8
    @State private var startMinute: Int = 0
    @State private var colorHex: String = "007AFF"
    @State private var steps: [RoutineStep] = []
    @State private var selectedCategory: TaskCategory?
    
    // UI state
    @State private var newStepContent: String = ""
    @State private var showEmojiGrid = false
    @State private var editingStepID: UUID?
    @State private var showDeleteConfirmation = false
    
    private let isEditing: Bool
    
    private let weekdays: [(label: String, number: Int)] = [
        ("S", 1), ("M", 2), ("T", 3), ("W", 4), ("T", 5), ("F", 6), ("S", 7)
    ]
    
    private let routineEmojis = [
        "sun.max.fill", "moon.fill", "dumbbell.fill", "figure.mind.and.body", "books.vertical.fill", "target", "figure.run", "frying.pan.fill",
        "pills.fill", "sparkles", "doc.text.fill", "paintpalette.fill", "brain.head.profile.fill", "bed.double.fill", "drop.fill", "leaf.fill",
        "pawprint.fill", "iphone", "music.note", "cup.and.saucer.fill", "fork.knife", "scalemass.fill", "checklist", "star.fill"
    ]
    
    private let colorOptions: [(hex: String, name: String)] = [
        ("007AFF", "Blue"), ("30D158", "Green"), ("FF9F0A", "Amber"),
        ("FF453A", "Red"), ("BF5AF2", "Purple"), ("FF2D55", "Pink"),
        ("64D2FF", "Cyan"), ("FFD60A", "Yellow")
    ]
    
    init(routine: Routine?) {
        self.routine = routine
        self.isEditing = routine != nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.spacingXL) {
                    // Header: Emoji + Name
                    headerSection
                    
                    // Schedule
                    scheduleSection
                    
                    // Category (optional)
                    routineCategorySection
                    
                    // Color
                    colorSection
                    
                    // Steps
                    stepsSection
                    
                    // Delete (editing only)
                    if isEditing {
                        deleteSection
                    }
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.top, DesignTokens.spacingMD)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(isEditing ? String(localized: "Edit Routine") : String(localized: "New Routine"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? String(localized: "Save") : String(localized: "Create")) {
                        saveRoutine()
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(
                        name.trimmingCharacters(in: .whitespaces).isEmpty
                            ? DesignTokens.textTertiary
                            : DesignTokens.accentActive
                    )
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { loadExistingRoutine() }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // Emoji picker button
            Button {
                showEmojiGrid.toggle()
            } label: {
                Image(systemName: emoji)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color(hex: colorHex))
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(Color(hex: colorHex).opacity(0.15))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color(hex: colorHex).opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            if showEmojiGrid {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: DesignTokens.spacingSM) {
                    ForEach(routineEmojis, id: \.self) { e in
                        Button {
                            emoji = e
                            showEmojiGrid = false
                            HapticService.shared.actionButtonTap()
                        } label: {
                            Image(systemName: e)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color(hex: colorHex))
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(emoji == e ? Color(hex: colorHex).opacity(0.2) : .clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignTokens.spacingSM)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            // Name field
            TextField(String(localized: "Routine name"), text: $name)
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .padding(DesignTokens.spacingMD)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }
    
    // MARK: - Schedule Section
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text(String(localized: "Schedule"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            // Schedule type pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(RepeatSchedule.allCases, id: \.self) { sched in
                        Button {
                            schedule = sched
                            HapticService.shared.actionButtonTap()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: sched.icon)
                                    .font(.system(size: 11))
                                Text(sched.label)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(
                                schedule == sched ? .white : DesignTokens.textSecondary
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        schedule == sched
                                            ? Color(hex: colorHex)
                                            : DesignTokens.cardSurface.opacity(0.6)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Custom day picker
            if schedule == .custom {
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(weekdays, id: \.number) { day in
                        Button {
                            if customDays.contains(day.number) {
                                customDays.remove(day.number)
                            } else {
                                customDays.insert(day.number)
                            }
                            HapticService.shared.actionButtonTap()
                        } label: {
                            Text(day.label)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(
                                    customDays.contains(day.number)
                                        ? .white
                                        : DesignTokens.textSecondary
                                )
                                .background(
                                    Circle()
                                        .fill(
                                            customDays.contains(day.number)
                                                ? Color(hex: colorHex)
                                                : DesignTokens.cardSurface.opacity(0.4)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingSM)
            }
            
            // Start time
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.textSecondary)
                
                Text(String(localized: "Start time"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                
                Spacer()
                
                DatePicker(
                    "",
                    selection: Binding(
                        get: {
                            Calendar.current.date(
                                from: DateComponents(hour: startHour, minute: startMinute)
                            ) ?? Date()
                        },
                        set: { date in
                            startHour = Calendar.current.component(.hour, from: date)
                            startMinute = Calendar.current.component(.minute, from: date)
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .colorScheme(.dark)
            }
            .padding(DesignTokens.spacingMD)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }
    
    // MARK: - Category Section
    
    private var routineCategorySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text(String(localized: "Category"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingXS) {
                    // "None" option
                    Button {
                        withAnimation(AnimationConstants.springSmooth) { selectedCategory = nil }
                        HapticService.shared.actionButtonTap()
                    } label: {
                        Text(String(localized: "None"))
                            .font(.system(size: 12, weight: selectedCategory == nil ? .bold : .medium))
                            .foregroundStyle(selectedCategory == nil ? .white : DesignTokens.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == nil ? DesignTokens.accentActive.opacity(0.3) : Color.white.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(TaskCategory.allCases.filter { $0 != .general }, id: \.self) { cat in
                        Button {
                            withAnimation(AnimationConstants.springSmooth) {
                                selectedCategory = cat
                                colorHex = cat.primaryColorHex
                            }
                            HapticService.shared.actionButtonTap()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(selectedCategory == cat ? .white : cat.primaryColor)
                                Text(cat.label).font(.system(size: 12, weight: selectedCategory == cat ? .bold : .medium))
                            }
                            .foregroundStyle(selectedCategory == cat ? .white : DesignTokens.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == cat ? cat.primaryColor.opacity(0.3) : Color.white.opacity(0.05))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Color Section
    
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text(String(localized: "Color"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            HStack(spacing: DesignTokens.spacingMD) {
                ForEach(colorOptions, id: \.hex) { option in
                    Button {
                        colorHex = option.hex
                        HapticService.shared.actionButtonTap()
                    } label: {
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 32, height: 32)
                            .overlay {
                                if colorHex == option.hex {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(
                        label: option.name,
                        traits: colorHex == option.hex ? [.isButton, .isSelected] : .isButton
                    )
                }
            }
        }
    }
    
    // MARK: - Steps Section
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            HStack {
                Text(String(localized: "Steps"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Spacer()
                
                if !steps.isEmpty {
                    Text(String(localized: "\(steps.count) steps"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            
            // Existing steps (drag-reorder)
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step: step, index: index)
            }
            .onMove { from, to in
                steps.move(fromOffsets: from, toOffset: to)
                reindexSteps()
            }
            
            // Add step
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignTokens.accentActive.opacity(0.6))
                
                TextField(String(localized: "Add a step..."), text: $newStepContent)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .submitLabel(.done)
                    .onSubmit {
                        addStep()
                    }
                
                if !newStepContent.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        addStep()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(label: String(localized: "Add step"), hint: nil, traits: .isButton)
                }
            }
            .padding(DesignTokens.spacingMD)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }
    
    // MARK: - Step Row
    
    private func stepRow(step: RoutineStep, index: Int) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.textTertiary)
            
            // Step number
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color(hex: colorHex).opacity(0.12))
                )
            
            // Icon
            StepIconView(emoji: step.emoji ?? "circle.fill", size: 14)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(step.content)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if let mins = step.estimatedMinutes, mins > 0 {
                        Text(String(localized: "\(mins) min"))
                            .font(.system(size: 10))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    // Phase 16: Per-step category chip
                    if let stepCat = step.category {
                        HStack(spacing: 2) {
                            Image(systemName: stepCat.icon)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(stepCat.primaryColor)
                            Text(stepCat.label)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(stepCat.primaryColor)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(stepCat.primaryColor.opacity(0.12))
                        )
                    }
                }
            }
            
            Spacer()
            
            // Delete
            Button {
                withAnimation(AnimationConstants.springSmooth) {
                    steps.removeAll { $0.id == step.id }
                    reindexSteps()
                }
                HapticService.shared.actionButtonTap()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(label: String(localized: "Delete step"), hint: nil, traits: .isButton)
        }
        .padding(DesignTokens.spacingSM)
        .padding(.horizontal, DesignTokens.spacingXS)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
    }
    
    // MARK: - Delete Section
    
    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text(String(localized: "Delete Routine"))
            }
            .font(AppTheme.body.weight(.medium))
            .foregroundStyle(DesignTokens.accentOverdue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(DesignTokens.accentOverdue.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, DesignTokens.spacingLG)
        .confirmationDialog(
            String(localized: "Delete this routine?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete Routine"), role: .destructive) {
                if let routine {
                    modelContext.delete(routine)
                    do { try modelContext.save() } catch { Log.ui.error("[RoutineEditor] Delete save failed: \(error, privacy: .public)") }
                    HapticService.shared.actionButtonTap()
                    dismiss()
                }
            }
        } message: {
            Text(String(localized: "This action cannot be undone."))
        }
    }
    
    // MARK: - Actions
    
    private func loadExistingRoutine() {
        guard let routine else { return }
        name = routine.name
        emoji = routine.emoji
        schedule = routine.schedule
        customDays = Set(routine.customDays)
        startHour = routine.startHour
        startMinute = routine.startMinute
        colorHex = routine.colorHex ?? "007AFF"
        steps = routine.steps
        selectedCategory = routine.category
    }
    
    private func addStep() {
        let trimmed = newStepContent.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let step = RoutineStep(
            content: trimmed,
            emoji: guessEmoji(for: trimmed),
            sortOrder: steps.count
        )
        
        withAnimation(AnimationConstants.springSmooth) {
            steps.append(step)
        }
        
        newStepContent = ""
        HapticService.shared.actionButtonTap()
    }
    
    private func reindexSteps() {
        for i in steps.indices {
            steps[i].sortOrder = i
        }
    }
    
    private func saveRoutine() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        if let routine {
            // Update existing
            routine.name = trimmed
            routine.emoji = emoji
            routine.schedule = schedule
            routine.customDays = Array(customDays)
            routine.startHour = startHour
            routine.startMinute = startMinute
            routine.colorHex = colorHex
            routine.steps = steps
            routine.categoryRaw = selectedCategory?.rawValue
        } else {
            // Create new
            let newRoutine = Routine(
                name: trimmed,
                emoji: emoji,
                schedule: schedule,
                startHour: startHour,
                startMinute: startMinute,
                steps: steps,
                colorHex: colorHex,
                categoryRaw: selectedCategory?.rawValue
            )
            newRoutine.customDays = Array(customDays)
            modelContext.insert(newRoutine)
        }
        
        do { try modelContext.save() } catch { Log.ui.error("[RoutineEditor] Save failed: \(error, privacy: .public)") }
        HapticService.shared.swipeDone()
        dismiss()
    }
    
    /// Simple emoji guesser based on step keywords
    private func guessEmoji(for text: String) -> String {
        let lower = text.lowercased()
        let emojiMap: [(keywords: [String], emoji: String)] = [
            (["wake", "alarm", "get up"], "alarm.fill"),
            (["shower", "bath", "wash"], "drop.fill"),
            (["brush", "teeth"], "mouth.fill"),
            (["breakfast", "eat", "meal", "food", "lunch", "dinner"], "frying.pan.fill"),
            (["coffee", "tea"], "cup.and.saucer.fill"),
            (["exercise", "workout", "gym", "run", "jog"], "dumbbell.fill"),
            (["meditat", "mindful", "breath"], "figure.mind.and.body"),
            (["read", "book", "article"], "books.vertical.fill"),
            (["write", "journal"], "doc.text.fill"),
            (["clean", "tidy", "laundry", "dishes"], "sparkles"),
            (["walk", "dog", "pet"], "pawprint.fill"),
            (["meds", "medicine", "vitamin", "pill"], "pills.fill"),
            (["stretch", "yoga"], "figure.mind.and.body"),
            (["water", "drink", "hydrate"], "drop.fill"),
            (["email", "inbox"], "envelope.fill"),
            (["review", "plan", "agenda"], "checklist"),
            (["skin", "face", "moistur"], "star.fill"),
            (["sleep", "bed", "rest"], "bed.double.fill"),
            (["phone", "screen"], "iphone"),
            (["music", "listen"], "music.note")
        ]
        
        for entry in emojiMap {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                return entry.emoji
            }
        }
        
        return "▸"
    }
}
