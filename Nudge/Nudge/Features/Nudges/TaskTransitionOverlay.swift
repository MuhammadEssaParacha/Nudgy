//
//  TaskTransitionOverlay.swift
//  Nudge
//
//  "Done → Next Up" transition card shown after completing a task.
//  Briefly celebrates the completed task, then reveals what's next.
//

import SwiftUI

struct TaskTransitionOverlay: View {
    let completedTask: String
    let completedEmoji: String
    let nextTask: String?
    let nextEmoji: String?
    var completedCategory: TaskCategory = .general
    var nextCategory: TaskCategory = .general
    @Binding var isPresented: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var phase: TransitionPhase = .celebrating
    
    private enum TransitionPhase {
        case celebrating
        case revealing
        case done
    }
    
    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            VStack(spacing: DesignTokens.spacingLG) {
                // Completed task
                VStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(completedCategory != .general ? completedCategory.primaryColor : DesignTokens.accentComplete)
                        .symbolEffect(.bounce, value: phase == .celebrating)
                    
                    Text(String(localized: "Done!"))
                        .font(AppTheme.title2)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: completedEmoji)
                            .font(.system(size: 14))
                            .foregroundStyle(DesignTokens.textSecondary)
                        Text(completedTask)
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(2)
                    }
                }
                .opacity(phase == .celebrating ? 1 : 0.5)
                .scaleEffect(phase == .celebrating ? 1 : 0.9)
                
                // Divider
                if nextTask != nil && phase == .revealing {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.15))
                        .frame(width: 40, height: 2)
                        .transition(.opacity)
                }
                
                // Next task
                if let nextTask, phase == .revealing {
                    VStack(spacing: DesignTokens.spacingSM) {
                        // Phase 16: Show category context for next task
                        HStack(spacing: 4) {
                            Text(String(localized: "Next up"))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                                .textCase(.uppercase)
                                .tracking(1.5)
                            if nextCategory != .general {
                                Image(systemName: nextCategory.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(nextCategory.primaryColor)
                            }
                        }
                        
                        HStack(spacing: DesignTokens.spacingXS) {
                            Image(systemName: nextEmoji ?? "doc.text.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(nextCategory != .general ? nextCategory.primaryColor : DesignTokens.accentActive)
                            Text(nextTask)
                                .font(AppTheme.body.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(DesignTokens.spacingXL)
            .frame(maxWidth: 320)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
        .onAppear { startSequence() }
        .nudgeAccessibility(
            label: {
                let catLabel = completedCategory != .general ? "\(completedCategory.label) " : ""
                var text = String(localized: "\(catLabel)task completed: \(completedTask)")
                if let next = nextTask {
                    let nextCatLabel = nextCategory != .general ? "\(nextCategory.label) " : ""
                    text += ". " + String(localized: "Next up: \(nextCatLabel)task, \(next)")
                }
                return text
            }(),
            hint: String(localized: "Tap to dismiss"),
            traits: .isModal
        )
    }
    
    private func startSequence() {
        let animation = reduceMotion ? .easeInOut(duration: 0.2) : AnimationConstants.springSmooth
        
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if let nextTask, !nextTask.isEmpty {
                withAnimation(animation) { phase = .revealing }
                try? await Task.sleep(for: .seconds(2.0))
            } else {
                try? await Task.sleep(for: .seconds(0.8))
            }
            dismiss()
        }
    }
    
    private func dismiss() {
        withAnimation(AnimationConstants.springSmooth) {
            isPresented = false
        }
    }
}
