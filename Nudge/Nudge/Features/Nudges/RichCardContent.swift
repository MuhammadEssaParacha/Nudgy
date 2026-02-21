//
//  RichCardContent.swift
//  Nudge
//
//  Rich inline content for Nudge task cards.
//  Shows draft previews, URL action buttons, contact info,
//  and map previews directly on the card — no sheet needed.
//
//  Phases 10-12: Email/Text preview, Shopping/Link, Location/Call
//

import SwiftUI
import MapKit

// MARK: - Draft Preview Strip

/// Shows a compact email/text draft preview inline on a task card.
/// One tap → opens compose with everything pre-filled.
struct DraftPreviewStrip: View {
    let item: NudgeItem
    var onSend: (() -> Void)?
    
    var body: some View {
        if let draft = item.aiDraft, !draft.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                // Subject line (email only)
                if let subject = item.aiDraftSubject, !subject.isEmpty {
                    Text(subject)
                        .font(AppTheme.captionBold)
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(1)
                }
                
                // Body preview
                Text(draft)
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                    .lineLimit(2)
                
                // Send button
                Button {
                    HapticService.shared.actionButtonTap()
                    onSend?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 9))
                        Text(String(localized: "Review & Send"))
                            .font(AppTheme.captionBold)
                    }
                    .foregroundStyle(DesignTokens.accentActive)
                    .padding(.horizontal, DesignTokens.spacingSM)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignTokens.accentActive.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, DesignTokens.spacingXS)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
        }
    }
}

// MARK: - URL Action Buttons

/// Shows smart URL action buttons for a task (Search Amazon, Get Directions, etc.)
struct URLActionButtons: View {
    let item: NudgeItem
    var onOpenURL: ((URL) -> Void)?
    
    private var urlActions: [URLAction] {
        URLActionGenerator.generateActions(
            for: item.content,
            actionType: item.actionType,
            actionTarget: item.actionTarget
        )
    }
    
    var body: some View {
        if !urlActions.isEmpty {
            VStack(spacing: DesignTokens.spacingXS) {
                ForEach(Array(urlActions.prefix(2).enumerated()), id: \.offset) { _, action in
                    Button {
                        HapticService.shared.actionButtonTap()
                        if action.openInApp {
                            onOpenURL?(action.url)
                        } else {
                            UIApplication.shared.open(action.url)
                        }
                    } label: {
                        HStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: action.icon)
                                .font(.system(size: 11))
                            Text(action.label)
                                .font(AppTheme.captionBold)
                            Spacer()
                            Text(action.displayDomain)
                                .font(.system(size: 9))
                                .foregroundStyle(DesignTokens.textTertiary)
                            Image(systemName: action.openInApp ? "arrow.up.right.square" : "safari")
                                .font(.system(size: 9))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .foregroundStyle(DesignTokens.accentActive)
                        .padding(.horizontal, DesignTokens.spacingSM)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(DesignTokens.accentActive.opacity(0.06))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Contact Info Strip

/// Shows contact photo placeholder and quick-action for call tasks.
struct ContactInfoStrip: View {
    let contactName: String
    let actionType: ActionType
    var onCall: (() -> Void)?
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Contact avatar circle
            Circle()
                .fill(DesignTokens.accentActive.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay {
                    Text(String(contactName.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(contactName)
                    .font(AppTheme.captionBold)
                    .foregroundStyle(DesignTokens.textPrimary)
                Text(actionType.label)
                    .font(.system(size: 9))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            
            Spacer()
            
            // Quick action button
            Button {
                HapticService.shared.actionButtonTap()
                onCall?()
            } label: {
                Image(systemName: actionType.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(DesignTokens.accentActive))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.spacingSM)
        .padding(.vertical, DesignTokens.spacingXS)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
    }
}

// MARK: - Fish Reward Badge

/// Shows what fish you'll earn for completing this task.
struct FishRewardBadge: View {
    let item: NudgeItem
    
    private var species: FishSpecies {
        FishEconomy.speciesForTask(item)
    }
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: species.icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(hex: species.glowColorHex))
            HStack(spacing: 1) {
                Text("+\(species.fishValue)")
                Image(systemName: "fish.fill")
                    .font(.system(size: 7))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(DesignTokens.textTertiary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.white.opacity(0.04)))
    }
}
