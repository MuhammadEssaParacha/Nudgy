//
//  ActiveTaskBubble.swift
//  Nudge
//
//  A compact, glassmorphic "task card" that appears near Nudgy showing
//  the current top-of-queue task. One card at a time — the core Nudge UX.
//
//  When there's an active task, this floats above or near the penguin
//  as a speech-bubble-style card. The user can:
//    - Tap ✓ to complete (triggers fish reward animation)
//    - Tap → to skip (moves to next)
//    - Tap the card to expand / go to One Thing View
//
//  When all tasks are cleared, shows a celebratory "All clear!" state.
//

import SwiftUI

// MARK: - Active Task Bubble

struct ActiveTaskBubble: View {
    let item: NudgeItem?
    let queuePosition: Int
    let queueTotal: Int

    var onDone: () -> Void = {}
    var onSkip: () -> Void = {}
    var onTap: () -> Void = {}

    @State private var isPressed = false
    @State private var doneFlash = false

    var body: some View {
        if let item {
            taskCard(item)
        } else if queueTotal == 0 {
            allClearCard
        }
    }

    // MARK: - Task Card

    private func taskCard(_ item: NudgeItem) -> some View {
        HStack(spacing: 10) {
            // Icon
            TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .small)

            // Task content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.content)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Queue position + metadata
                HStack(spacing: 4) {
                    Text("\(queuePosition)/\(queueTotal)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "00D4FF").opacity(0.7))

                    if item.isStale {
                        Text(String(localized: "STALE"))
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(DesignTokens.accentStale)
                    }

                    if item.isPastDue {
                        Text(String(localized: "OVERDUE"))
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(DesignTokens.accentOverdue)
                    }
                }
            }

            Spacer(minLength: 4)

            // Action buttons
            HStack(spacing: 6) {
                // Skip
                Button {
                    HapticService.shared.prepare()
                    onSkip()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "Skip task"),
                    traits: .isButton
                )

                // Done
                Button {
                    HapticService.shared.prepare()
                    withAnimation(.spring(response: 0.3)) {
                        doneFlash = true
                    }
                    onDone()
                    // Reset flash after animation
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
                        doneFlash = false
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(doneFlash ? .black : DesignTokens.accentComplete)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(doneFlash
                                      ? DesignTokens.accentComplete
                                      : DesignTokens.accentComplete.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "Complete task"),
                    traits: .isButton
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            accentBorderColor(for: item).opacity(0.25),
                            lineWidth: 0.5
                        )
                )
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            onTap()
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPressed)
        .nudgeAccessibility(
            label: "\(item.content), task \(queuePosition) of \(queueTotal)",
            hint: String(localized: "Tap to view full task, or use the done and skip buttons"),
            traits: .isButton
        )
    }

    // MARK: - All Clear Card

    private var allClearCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.accentComplete)

            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "Nothing right now"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignTokens.accentComplete)

                Text(String(localized: "Tap Nudgy to unload your brain"))
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func accentBorderColor(for item: NudgeItem) -> Color {
        switch item.accentStatus {
        case .active:   return DesignTokens.accentActive
        case .stale:    return DesignTokens.accentStale
        case .overdue:  return DesignTokens.accentOverdue
        case .complete: return DesignTokens.accentComplete
        }
    }
}

// MARK: - Preview

#Preview("With Task") {
    ZStack {
        Color.black
        ActiveTaskBubble(
            item: nil,
            queuePosition: 1,
            queueTotal: 5
        )
        .padding(.horizontal, 24)
    }
}
