//
//  ActionCTAButton.swift
//  Nudge
//
//  The primary call-to-action button on the hero card.
//  Adapts based on what the task IS:
//  - CALL → "📞 Call [Contact]"
//  - TEXT → "💬 Text [Contact]"
//  - EMAIL → "✉️ Email [Contact]"
//  - LINK → "🔗 Open Link"
//  - Has estimated time → "▶ Start Focus"
//  - Generic → "✓ I did it"
//
//  Every card has ONE primary action. Never a passive display.
//

import SwiftUI

struct ActionCTAButton: View {
    
    let item: NudgeItem
    let onAction: () -> Void
    let onDone: () -> Void
    let onFocus: (() -> Void)?

    @State private var shimmerPhase: CGFloat = 0
    @State private var shimmerCount = 0
    private let maxShimmers = 2

    /// Determines the CTA variant
    private var ctaVariant: CTAVariant {
        if let actionType = item.actionType {
            switch actionType {
            case .call:          return .call
            case .text:          return .text
            case .email:         return .email
            case .openLink:      return .openLink
            case .search:        return .search
            case .navigate:      return .navigate
            case .addToCalendar: return .calendar
            case .setAlarm:      return .alarm
            }
        }
        if item.estimatedMinutes != nil, onFocus != nil {
            return .focus
        }
        return .done
    }
    
    var body: some View {
        Button {
            HapticService.shared.actionButtonTap()
            switch ctaVariant {
            case .call, .text, .email, .openLink, .search, .navigate, .calendar, .alarm:
                onAction()
            case .focus:
                onFocus?()
            case .done:
                onDone()
            }
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: ctaVariant.icon)
                    .font(AppTheme.body.weight(.semibold))
                
                Text(ctaLabel)
                    .font(AppTheme.body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingMD)
            .background {
                Capsule()
                    .fill(ctaVariant.color)
                    .shadow(color: ctaVariant.color.opacity(0.3), radius: 8, y: 4)
            }
            .overlay {
                // Sweeping shimmer — subtle light sweep every ~3 seconds
                GeometryReader { geo in
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.22), location: 0.4),
                                    .init(color: .white.opacity(0.32), location: 0.5),
                                    .init(color: .white.opacity(0.22), location: 0.6),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.45)
                        .offset(x: shimmerPhase * (geo.size.width * 1.5) - geo.size.width * 0.3)
                }
                .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: ctaLabel,
            hint: String(localized: "Performs the primary action for this task"),
            traits: .isButton
        )
        .onAppear {
            runShimmer()
        }
        
        // Secondary Focus button — always available when primary CTA isn't focus
        if ctaVariant != .focus, let onFocus {
            Button {
                HapticService.shared.actionButtonTap()
                onFocus()
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "timer")
                        .font(AppTheme.footnote.weight(.semibold))
                    
                    Text(String(localized: "Start Focus Timer"))
                        .font(AppTheme.footnote.weight(.medium))
                }
                .foregroundStyle(DesignTokens.accentFocus)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingSM + 2)
                .background {
                    Capsule()
                        .fill(DesignTokens.accentFocus.opacity(0.10))
                        .overlay(
                            Capsule()
                                .strokeBorder(DesignTokens.accentFocus.opacity(0.25), lineWidth: 0.5)
                        )
                }
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Start Focus Timer"),
                hint: String(localized: "Open the focus timer for this task"),
                traits: .isButton
            )
        }
    }
    
    // MARK: - Label Logic
    
    /// Run shimmer animation a limited number of times, then stop.
    private func runShimmer() {
        guard shimmerCount < maxShimmers else { return }
        shimmerPhase = 0
        withAnimation(.linear(duration: 2.5).delay(shimmerCount == 0 ? 1.2 : 0.5)) {
            shimmerPhase = 1
        }
        // Schedule next shimmer after this one completes
        let delay = shimmerCount == 0 ? 3.7 : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            shimmerCount += 1
            runShimmer()
        }
    }
    
    private var ctaLabel: String {
        switch ctaVariant {
        case .call:
            if let contact = item.contactName, !contact.isEmpty {
                return String(localized: "Call \(contact)")
            }
            return String(localized: "Call")
        case .text:
            if let contact = item.contactName, !contact.isEmpty {
                return String(localized: "Text \(contact)")
            }
            return String(localized: "Send Text")
        case .email:
            if let contact = item.contactName, !contact.isEmpty {
                return String(localized: "Email \(contact)")
            }
            return String(localized: "Send Email")
        case .openLink:
            return String(localized: "Open Link")
        case .search:
            return String(localized: "Search")
        case .navigate:
            return String(localized: "Navigate")
        case .calendar:
            return String(localized: "Add to Calendar")
        case .alarm:
            return String(localized: "Set Alarm")
        case .focus:
            if let mins = item.estimatedMinutes {
                return String(localized: "Start Focus · \(mins) min")
            }
            return String(localized: "Start Focus")
        case .done:
            return categoryDoneLabel
        }
    }
    
    /// Category-specific "done" label — more satisfying than generic "I did it".
    private var categoryDoneLabel: String {
        guard let cat = item.category else {
            return String(localized: "I did it ✓")
        }
        switch cat {
        case .health:      return String(localized: "Taken care of 💊")
        case .exercise:    return String(localized: "Workout done 💪")
        case .cooking:     return String(localized: "Cooked ✓")
        case .cleaning:    return String(localized: "Cleaned ✓")
        case .finance:     return String(localized: "Paid ✓")
        case .work:        return String(localized: "Done ✓")
        case .homework:    return String(localized: "Studied ✓")
        case .errand:      return String(localized: "Ran it ✓")
        case .social:      return String(localized: "Reached out ✓")
        case .selfCare:    return String(localized: "Took care of me ✓")
        case .shopping:    return String(localized: "Bought it ✓")
        case .maintenance: return String(localized: "Fixed ✓")
        case .appointment: return String(localized: "Handled ✓")
        case .creative:    return String(localized: "Made something ✓")
        case .call, .text, .email, .link, .alarm:
            return String(localized: "I did it ✓") // action types handled above
        case .general:     return String(localized: "I did it ✓")
        }
    }
}

// MARK: - CTA Variant

private enum CTAVariant {
    case call, text, email, openLink, search, navigate, calendar, alarm
    case focus
    case done
    
    var icon: String {
        switch self {
        case .call:     return "phone.fill"
        case .text:     return "message.fill"
        case .email:    return "envelope.fill"
        case .openLink: return "link"
        case .search:   return "magnifyingglass"
        case .navigate: return "map.fill"
        case .calendar: return "calendar.badge.plus"
        case .alarm:    return "alarm.fill"
        case .focus:    return "timer"
        case .done:     return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .call:     return DesignTokens.accentComplete
        case .text:     return DesignTokens.accentActive
        case .email:    return DesignTokens.accentActive
        case .openLink: return DesignTokens.accentIndigo
        case .search:   return DesignTokens.accentIndigo
        case .navigate: return DesignTokens.accentStale
        case .calendar: return DesignTokens.accentStale
        case .alarm:    return DesignTokens.accentStale
        case .focus:    return DesignTokens.accentFocus
        case .done:     return DesignTokens.accentComplete
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            ActionCTAButton(
                item: NudgeItem(content: "Call Dr. Patel", emoji: "📞", actionType: .call, contactName: "Dr. Patel", sortOrder: 1),
                onAction: {},
                onDone: {},
                onFocus: nil
            )
            
            ActionCTAButton(
                item: NudgeItem(content: "Text Sarah", emoji: "💬", actionType: .text, contactName: "Sarah", sortOrder: 2),
                onAction: {},
                onDone: {},
                onFocus: nil
            )
            
            ActionCTAButton(
                item: NudgeItem(content: "Buy groceries", emoji: "🛒", sortOrder: 3),
                onAction: {},
                onDone: {},
                onFocus: {}
            )
            
            ActionCTAButton(
                item: NudgeItem(content: "Do laundry", emoji: "👕", sortOrder: 4),
                onAction: {},
                onDone: {},
                onFocus: nil
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
