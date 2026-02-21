//
//  TaskBreakdownView.swift
//  Nudge
//
//  AI-powered task coaching — breaks overwhelming tasks into
//  tiny, concrete steps an ADHD brain can actually start.
//
//  Uses AIService.breakDownTask() → TaskBreakdown (@Generable).
//  Presented as a sheet from CardView's "Break it down" action.
//

import SwiftUI
import SwiftData

struct TaskBreakdownView: View {
    
    let taskContent: String
    let taskEmoji: String?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var breakdown: TaskBreakdown?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addedSteps: Set<Int> = []
    @State private var allAdded = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Glass background
                ZStack {
                    Color.black.ignoresSafeArea()
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [DesignTokens.accentActive.opacity(0.04), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .offset(x: -60, y: -120)
                        .blur(radius: 50)
                }
                .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let breakdown = breakdown {
                    breakdownContent(breakdown)
                } else if let error = errorMessage {
                    errorView(error)
                }
            }
            .navigationTitle(String(localized: "Break It Down"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadBreakdown()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Spacer()
            
            NudgySprite(
                expression: .thinking,
                size: DesignTokens.penguinSizeLarge,
                accentColor: DesignTokens.accentActive
            )
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text(String(localized: "Nudgy is thinking..."))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(String(localized: "Breaking down your task into tiny steps"))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            
            ProgressView()
                .tint(DesignTokens.accentActive)
                .controlSize(.regular)
            
            Spacer()
        }
    }
    
    // MARK: - Breakdown Content
    
    private func breakdownContent(_ breakdown: TaskBreakdown) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXL) {
                // Original task header
                HStack(spacing: DesignTokens.spacingSM) {
                    TaskIconView(emoji: taskEmoji, size: .large)
                    
                    Text(taskContent)
                        .font(AppTheme.body.weight(.medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(2)
                }
                .padding(DesignTokens.spacingMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(Color.white.opacity(0.03))
                )
                
                // Reasoning from Nudgy
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Label {
                        Text(String(localized: "Nudgy's take"))
                            .font(AppTheme.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.accentActive)
                    } icon: {
                        Image(systemName: "apple.intelligence")
                            .font(.system(size: 10))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    
                    Text(breakdown.reasoning)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                
                // Sub-steps
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Text(String(localized: "Tiny steps"))
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.textTertiary)
                    
                    ForEach(Array(breakdown.steps.enumerated()), id: \.offset) { index, step in
                        stepCard(step, index: index)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                
                // Encouragement
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentComplete)
                    
                    Text(breakdown.encouragement)
                        .font(AppTheme.body.italic())
                        .foregroundStyle(DesignTokens.accentComplete)
                }
                .padding(DesignTokens.spacingMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(DesignTokens.accentComplete.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                .strokeBorder(DesignTokens.accentComplete.opacity(0.15), lineWidth: 0.5)
                        )
                )
                
                // Add all button
                if !allAdded {
                    addAllButton(steps: breakdown.steps)
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
        }
    }
    
    // MARK: - Step Card
    
    private func stepCard(_ step: SplitTask, index: Int) -> some View {
        let isAdded = addedSteps.contains(index)
        
        return HStack(spacing: DesignTokens.spacingSM) {
            StepIconView(emoji: step.emoji, size: 16)
            
            Text(step.task)
                .font(AppTheme.body)
                .foregroundStyle(isAdded ? DesignTokens.textTertiary : DesignTokens.textPrimary)
                .strikethrough(isAdded)
            
            Spacer()
            
            Button {
                addStep(step, index: index)
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isAdded ? DesignTokens.accentComplete : DesignTokens.accentActive)
            }
            .disabled(isAdded)
            .nudgeAccessibility(
                label: isAdded
                    ? String(localized: "Added")
                    : String(localized: "Add step: \(step.task)"),
                hint: isAdded ? nil : String(localized: "Creates this as a new task"),
                traits: .isButton
            )
        }
        .padding(DesignTokens.spacingMD)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(Color.white.opacity(0.03))
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .strokeBorder(
                        isAdded ? DesignTokens.accentComplete.opacity(0.3) : Color.white.opacity(0.06),
                        lineWidth: 0.5
                    )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAdded)
    }
    
    // MARK: - Add All Button
    
    private func addAllButton(steps: [SplitTask]) -> some View {
        Button {
            addAllSteps(steps)
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "plus.rectangle.on.rectangle")
                Text(String(localized: "Add all as tasks"))
            }
            .font(AppTheme.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.spacingXL)
            .padding(.vertical, DesignTokens.spacingMD)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(DesignTokens.accentActive)
            )
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: String(localized: "Add all steps as tasks"),
            hint: String(localized: "Creates each step as a separate task in your queue"),
            traits: .isButton
        )
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Spacer()
            
            NudgySprite(
                expression: .confused,
                size: DesignTokens.penguinSizeLarge,
                accentColor: DesignTokens.accentOverdue
            )
            
            Text(String(localized: "Couldn't break it down"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            Text(message)
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await loadBreakdown() }
            } label: {
                Text(String(localized: "Try Again"))
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.accentActive)
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingXL)
    }
    
    // MARK: - Logic
    
    private func loadBreakdown() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await AIService.shared.breakDownTask(taskContent)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                breakdown = result
                isLoading = false
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    private func addStep(_ step: SplitTask, index: Int) {
        let repository = NudgeRepository(modelContext: modelContext)
        let actionType: ActionType? = {
            switch step.action.uppercased() {
            case "CALL": return .call
            case "TEXT": return .text
            case "EMAIL": return .email
            default: return nil
            }
        }()
        _ = repository.createManualWithDetails(
            content: step.task,
            emoji: step.emoji,
            actionType: actionType,
            contactName: step.contact.isEmpty ? nil : step.contact
        )
        
        HapticService.shared.shareSaved()
        _ = withAnimation { addedSteps.insert(index) }
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
    }
    
    private func addAllSteps(_ steps: [SplitTask]) {
        let repository = NudgeRepository(modelContext: modelContext)
        
        for (index, step) in steps.enumerated() where !addedSteps.contains(index) {
            let actionType: ActionType? = {
                switch step.action.uppercased() {
                case "CALL": return .call
                case "TEXT": return .text
                case "EMAIL": return .email
                default: return nil
                }
            }()
            _ = repository.createManualWithDetails(
                content: step.task,
                emoji: step.emoji,
                actionType: actionType,
                contactName: step.contact.isEmpty ? nil : step.contact
            )
        }
        
        HapticService.shared.shareSaved()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            addedSteps = Set(0..<steps.count)
            allAdded = true
        }
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
    }
}

// MARK: - Preview

#Preview {
    TaskBreakdownView(
        taskContent: "Clean the entire house before the party",
        taskEmoji: "🏠"
    )
    .modelContainer(for: [NudgeItem.self, BrainDump.self], inMemory: true)
    .environment(PenguinState())
}
