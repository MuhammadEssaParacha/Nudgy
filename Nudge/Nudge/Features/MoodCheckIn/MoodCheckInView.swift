//
//  MoodCheckInView.swift
//  Nudge
//
//  A gentle 5-emoji mood check-in presented by Nudgy.
//  Quick tap → optional note → save.
//  Appears once per day (or on demand from Nudgy tab).
//
//  ADHD-optimized: No text required, giant tap targets,
//  optional note only if they want to add one.
//

import SwiftUI
import SwiftData
import os

struct MoodCheckInView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var selectedMood: MoodLevel?
    @State private var selectedEnergy: EnergyLevel?
    @State private var note: String = ""
    @State private var phase: CheckInPhase = .mood
    @State private var isSaving = false
    @State private var autoDismissTask: Task<Void, Never>?
    
    private enum CheckInPhase {
        case mood, energy, note, done
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: DesignTokens.spacingXXL) {
                    Spacer()
                    
                    switch phase {
                    case .mood:
                        moodPickerView
                    case .energy:
                        energyPickerView
                    case .note:
                        noteView
                    case .done:
                        doneView
                    }
                    
                    Spacer()
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.spacingLG)
            }
            .navigationTitle(String(localized: "Check In"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Skip")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.textTertiary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Mood Picker
    
    private var moodPickerView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Text(String(localized: "How are you feeling?"))
                .font(AppTheme.title2)
                .foregroundStyle(DesignTokens.textPrimary)
            
            Text(String(localized: "No wrong answers — just a quick check-in 💙"))
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: DesignTokens.spacingLG) {
                ForEach(MoodLevel.allCases, id: \.self) { mood in
                    Button {
                        selectedMood = mood
                        HapticService.shared.actionButtonTap()
                        
                        withAnimation(AnimationConstants.springSmooth) {
                            phase = .energy
                        }
                    } label: {
                        VStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: mood.icon)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(selectedMood == mood ? mood.color : .white.opacity(0.6))
                                .scaleEffect(selectedMood == mood ? 1.2 : 1.0)
                            
                            Text(mood.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(
                                    selectedMood == mood
                                        ? mood.color
                                        : DesignTokens.textTertiary
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                .fill(
                                    selectedMood == mood
                                        ? mood.color.opacity(0.12)
                                        : DesignTokens.cardSurface.opacity(0.3)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(
                        label: mood.label,
                        hint: String(localized: "Select \(mood.label) mood"),
                        traits: .isButton
                    )
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Energy Picker
    
    private var energyPickerView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Text(String(localized: "Energy level?"))
                .font(AppTheme.title2)
                .foregroundStyle(DesignTokens.textPrimary)
            
            HStack(spacing: DesignTokens.spacingLG) {
                ForEach(EnergyLevel.allCases, id: \.self) { energy in
                    Button {
                        selectedEnergy = energy
                        HapticService.shared.actionButtonTap()
                        
                        withAnimation(AnimationConstants.springSmooth) {
                            phase = .note
                        }
                    } label: {
                        VStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: energy.icon)
                                .font(.system(size: 32))
                                .foregroundStyle(energyColor(energy))
                            
                            Text(energy.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingLG)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Note View
    
    private var noteView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            if let mood = selectedMood {
                Image(systemName: mood.icon)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(mood.color)
            }
            
            Text(String(localized: "Anything on your mind?"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            TextField(String(localized: "Optional note..."), text: $note, axis: .vertical)
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(3...6)
                .submitLabel(.done)
                .padding(DesignTokens.spacingMD)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
            
            HStack(spacing: DesignTokens.spacingMD) {
                Button {
                    saveCheckIn()
                } label: {
                    Text(note.isEmpty ? String(localized: "Skip Note") : String(localized: "Save"))
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
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Done View
    
    private var doneView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DesignTokens.accentComplete)
            
            Text(String(localized: "Logged! 💙"))
                .font(AppTheme.title2)
                .foregroundStyle(DesignTokens.textPrimary)
            
            if let mood = selectedMood {
                Text(String(localized: "You're feeling \(mood.label.lowercased()) today"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .onAppear {
            autoDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }
    
    // MARK: - Save
    
    private func saveCheckIn() {
        guard let mood = selectedMood else { return }
        isSaving = true
        
        // Count today's completions
        let repo = NudgeRepository(modelContext: modelContext)
        let completedToday = repo.completedTodayCount()
        
        let entry = MoodEntry(
            mood: mood,
            note: note.isEmpty ? nil : note,
            tasksCompleted: completedToday,
            energy: selectedEnergy
        )
        
        modelContext.insert(entry)
        do {
            try modelContext.save()
        } catch {
            Log.ui.error("[MoodCheckIn] Save failed: \(error, privacy: .public)")
            isSaving = false
            return
        }
        
        HapticService.shared.swipeDone()
        
        withAnimation(AnimationConstants.springSmooth) {
            phase = .done
        }
    }
    
    // MARK: - Helpers
    
    private func energyColor(_ energy: EnergyLevel) -> Color {
        switch energy {
        case .low: return DesignTokens.accentStale
        case .medium: return DesignTokens.accentActive
        case .high: return DesignTokens.accentComplete
        }
    }
}
