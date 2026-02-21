//
//  InlineQuickCapture.swift
//  Nudge
//
//  A minimal, inline text field for instant task capture right in the Nudges tab.
//  No sheet, no AI parsing delay — just type and hit return.
//
//  ADHD research backing:
//  • Every extra tap/transition is a dropout risk (Barkley, 2012)
//  • "Capture before it evaporates" — ADHD working memory holds 2-3 items
//    for ~20 seconds (Rapport et al., 2008)
//  • The field disappears after entry, preventing visual clutter
//

import SwiftUI
import SwiftData

struct InlineQuickCapture: View {
    
    @Environment(\.modelContext) private var modelContext
    var onTaskAdded: () -> Void
    
    @State private var text = ""
    @State private var isExpanded = false
    @State private var justAdded = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Expanded text field
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignTokens.accentActive)
                    
                    TextField(
                        String(localized: "Quick add..."),
                        text: $text
                    )
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit {
                        addTask()
                    }
                    
                    if !text.isEmpty {
                        Button {
                            addTask()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM + 2)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            } else {
                // Collapsed tap target
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.1))
                        isFocused = true
                    }
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignTokens.textTertiary)
                        
                        Text(justAdded
                             ? String(localized: "Added! Tap to add another")
                             : String(localized: "Quick add a task…"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(justAdded ? DesignTokens.accentComplete : DesignTokens.textTertiary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .nudgeAccessibility(
            label: String(localized: "Quick add task"),
            hint: String(localized: "Double tap to add a task quickly"),
            traits: .isButton
        )
    }
    
    // MARK: - Add Task
    
    private func addTask() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let repo = NudgeRepository(modelContext: modelContext)
        _ = repo.createManual(content: trimmed)
        
        HapticService.shared.swipeDone()
        text = ""
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = false
            justAdded = true
        }
        
        // Reset "Added!" text after a few seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 0.2)) {
                justAdded = false
            }
        }
        
        onTaskAdded()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 16) {
            InlineQuickCapture(onTaskAdded: {})
                .padding()
        }
    }
    .preferredColorScheme(.dark)
}
