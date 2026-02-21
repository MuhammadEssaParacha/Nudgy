//
//  NudgeCompactRow.swift
//  Nudge
//
//  ADHD-optimized compact task row for the Nudges list.
//
//  Design principles (ADHD research — Barkley 2015, Rapport et al. 2008):
//    • Rich visual differentiation via CategoryIllustration (reduces scanning load)
//    • Minimal text — content + ONE status hint max (working memory limit)
//    • Large tap target — entire row expands inline (no navigation)
//    • Accent-driven status: color = state (blue/green/amber/red)
//    • Quick-done button stays accessible without needing to expand
//    • No right-chevron — expanding down is the interaction, not navigating away
//    • Time cues prominent (combats time blindness)
//

import SwiftUI

struct NudgeCompactRow: View {

    let item: NudgeItem
    var isExpanded: Bool = false
    var isCarried: Bool = false
    var onTap: () -> Void = {}
    var onDone: (() -> Void)?

    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.spacingMD) {
                // Category illustration (personalized per task content)
                CategoryIllustrationView(item: item, size: 42)

                // Content + single-line meta
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.content)
                        .font(AppTheme.body.weight(.medium))
                        .foregroundStyle(
                            item.status == .done
                                ? DesignTokens.textTertiary
                                : DesignTokens.textPrimary
                        )
                        .strikethrough(item.status == .done, color: DesignTokens.textTertiary.opacity(0.5))
                        .lineLimit(2)

                    // Single-line meta — max 2 chips (ADHD: reduce scanning load)
                    HStack(spacing: 6) {
                        // Carry-forward indicator — shows when item was intentionally chosen for today
                        if isCarried {
                            metaChip(icon: "arrow.up.circle.fill", text: String(localized: "Carried"), color: DesignTokens.accentActive)
                        }

                        // Time cue (most important for ADHD — combats time blindness)
                        if let dur = item.durationLabel {
                            metaChip(icon: "clock", text: dur, color: DesignTokens.textSecondary)
                        }
                        
                        // Status cue (one only — priority order)
                        if item.status == .done, let completedAt = item.completedAt {
                            metaChip(icon: "checkmark", text: completedAt.relativeDescription, color: DesignTokens.accentComplete)
                        } else if item.isStale {
                            metaChip(icon: "exclamationmark.triangle.fill", text: String(localized: "\(item.ageInDays)d old"), color: DesignTokens.accentStale)
                        } else if item.status == .snoozed, let until = item.snoozedUntil {
                            metaChip(icon: "moon.zzz.fill", text: until.friendlySnoozeDescription, color: DesignTokens.textSecondary)
                        } else if item.hasDraft {
                            metaChip(icon: "doc.text.fill", text: String(localized: "Ready"), color: DesignTokens.accentActive)
                        } else if let contact = item.contactName, !contact.isEmpty {
                            metaChip(icon: "person.fill", text: contact, color: DesignTokens.textSecondary)
                        } else if let actionType = item.actionType {
                            metaChip(icon: actionType.icon, text: actionType.label, color: DesignTokens.accentActive)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Quick done button (always accessible without expanding)
                if let onDone, item.status != .done {
                    Button {
                        onDone()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DesignTokens.accentComplete)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(DesignTokens.accentComplete.opacity(0.10))
                                    .overlay(
                                        Circle()
                                            .strokeBorder(DesignTokens.accentComplete.opacity(0.15), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(
                        label: String(localized: "Mark done"),
                        hint: String(localized: "Complete this task"),
                        traits: .isButton
                    )
                }
                
                // Expand indicator (subtle arrow that rotates)
                if item.status != .done {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignTokens.textTertiary.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? -180 : 0))
                        .animation(AnimationConstants.springSmooth, value: isExpanded)
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM + 2)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(item.isStale ? 0.10 : 0.05), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: item.content,
            hint: isExpanded
                ? String(localized: "Tap to collapse task details")
                : String(localized: "Tap to expand task details"),
            traits: .isButton
        )
    }
    
    // MARK: - Meta Chip
    
    private func metaChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.08)))
    }
}
