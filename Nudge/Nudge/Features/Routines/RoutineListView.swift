//
//  RoutineListView.swift
//  Nudge
//
//  Browse, create, and manage repeating routines.
//  Each routine auto-generates tasks on its schedule.
//
//  ADHD-optimized: routines reduce decision fatigue by
//  turning recurring work into autopilot sequences.
//

import SwiftUI
import SwiftData
import os

struct RoutineListView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    
    @State private var showCreateSheet = false
    @State private var editingRoutine: Routine?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if routines.isEmpty {
                    emptyState
                } else {
                    routineList
                }
            }
            .navigationTitle(String(localized: "Routines"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.shared.actionButtonTap()
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .nudgeAccessibility(
                        label: String(localized: "New routine"),
                        hint: String(localized: "Creates a new repeating routine"),
                        traits: .isButton
                    )
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                RoutineEditorView(routine: nil)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $editingRoutine) { routine in
                RoutineEditorView(routine: routine)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Image(systemName: "arrow.trianglehead.2.counterclockwise.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DesignTokens.accentActive.opacity(0.6))
            
            Text(String(localized: "No routines yet"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            Text(String(localized: "Routines turn your daily habits into autopilot — no more remembering what comes next."))
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.spacingXXL)
            
            Button {
                HapticService.shared.actionButtonTap()
                showCreateSheet = true
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "plus")
                    Text(String(localized: "Create First Routine"))
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
        }
    }
    
    // MARK: - Routine List
    
    private var routineList: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingMD) {
                // Active routines
                let active = routines.filter(\.isActive)
                let paused = routines.filter { !$0.isActive }
                
                if !active.isEmpty {
                    sectionHeader(String(localized: "Active"), count: active.count)
                    
                    ForEach(active) { routine in
                        routineCard(routine)
                    }
                }
                
                if !paused.isEmpty {
                    sectionHeader(String(localized: "Paused"), count: paused.count)
                        .padding(.top, DesignTokens.spacingSM)
                    
                    ForEach(paused) { routine in
                        routineCard(routine)
                            .opacity(0.6)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingSM)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            Text("\(count)")
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
            
            Spacer()
        }
    }
    
    // MARK: - Routine Card
    
    private func routineCard(_ routine: Routine) -> some View {
        Button {
            editingRoutine = routine
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                // Top row: emoji + name + toggle
                HStack(spacing: DesignTokens.spacingMD) {
                    Image(systemName: TaskIconResolver.resolveSymbol(for: routine.emoji))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(hex: routine.colorHex ?? "007AFF"))
                        .frame(width: 36, height: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.name)
                            .font(AppTheme.headline)
                            .foregroundStyle(DesignTokens.textPrimary)
                        
                        HStack(spacing: DesignTokens.spacingSM) {
                            Label(routine.schedule.label, systemImage: routine.schedule.icon)
                            
                            Text("•")
                            
                            Label(routine.startTimeLabel, systemImage: "clock")
                        }
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { routine.isActive },
                        set: { newValue in
                            routine.isActive = newValue
                            do { try modelContext.save() } catch { Log.ui.error("[Routine] Toggle save failed: \(error, privacy: .public)") }
                            HapticService.shared.actionButtonTap()
                        }
                    ))
                    .labelsHidden()
                    .tint(DesignTokens.accentActive)
                }
                
                // Steps preview
                let steps = routine.steps
                if !steps.isEmpty {
                    HStack(spacing: DesignTokens.spacingSM) {
                        ForEach(steps.prefix(5)) { step in
                            StepIconView(emoji: step.emoji ?? "circle.fill", size: 13)
                        }
                        
                        if steps.count > 5 {
                            Text(String(localized: "+\(steps.count - 5)"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        
                        Spacer()
                        
                        if routine.totalEstimatedMinutes > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(String(localized: "\(routine.totalEstimatedMinutes) min"))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DesignTokens.textTertiary)
                        }
                    }
                } else {
                    Text(String(localized: "No steps yet — tap to add"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .padding(DesignTokens.spacingMD)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(
                        LinearGradient(
                            colors: [routine.color.opacity(0.07), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingRoutine = routine
            } label: {
                Label(String(localized: "Edit"), systemImage: "pencil")
            }
            
            Button {
                routine.isActive.toggle()
                do { try modelContext.save() } catch { Log.ui.error("[Routine] Toggle save failed: \(error, privacy: .public)") }
            } label: {
                Label(
                    routine.isActive ? String(localized: "Pause") : String(localized: "Resume"),
                    systemImage: routine.isActive ? "pause.circle" : "play.circle"
                )
            }
            
            Divider()
            
            Button(role: .destructive) {
                modelContext.delete(routine)
                do { try modelContext.save() } catch { Log.ui.error("[Routine] Delete save failed: \(error, privacy: .public)") }
                HapticService.shared.actionButtonTap()
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
    }
}
