//
//  DarkCard.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

// MARK: - Dark Card (Glassmorphism)

/// Reusable glass card component — the primary visual building block of Nudge.
///
/// iOS 26 native glassmorphism using `.glassEffect()`:
/// - Native liquid glass rendering with interactive feedback
/// - Accent-tinted top glow for status differentiation
/// - Pulsing border for stale/attention items
/// - Subtle shadow for depth in OLED context
struct DarkCard<Content: View>: View {
    
    let accentColor: Color
    let showPulse: Bool
    let content: Content
    
    @State private var pulseAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(
        accentColor: Color = DesignTokens.accentActive,
        showPulse: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.accentColor = accentColor
        self.showPulse = showPulse
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignTokens.spacingLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // Accent glow (top edge — visible through glass)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(showPulse && pulseAnimation ? 0.15 : 0.08),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            .shadow(color: accentColor.opacity(0.06), radius: 16, y: 6)
            .onAppear {
                if showPulse && !reduceMotion {
                    withAnimation(AnimationConstants.stalePulse) {
                        pulseAnimation = true
                    }
                }
            }
    }
}

// MARK: - Glass Section Card

/// A lighter glass card for settings sections and secondary containers.
/// Uses native iOS 26 `.glassEffect()` for consistent platform look.
struct GlassSection<Content: View>: View {
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignTokens.spacingMD)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
    }
}

// MARK: - Card Variants

extension DarkCard where Content == EmptyView {
    /// Empty card for layout purposes
    init(accentColor: Color = DesignTokens.accentActive) {
        self.accentColor = accentColor
        self.showPulse = false
        self.content = EmptyView()
    }
}

// MARK: - Preview

#Preview("Glass Card — Active") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 16) {
            DarkCard(accentColor: DesignTokens.accentActive) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                    Text("Call the dentist")
                        .cardTitleStyle()
                    Text("Added 2 hours ago")
                        .secondaryTextStyle()
                }
            }
            
            DarkCard(accentColor: DesignTokens.accentStale, showPulse: true) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentStale)
                    Text("Buy dog food")
                        .cardTitleStyle()
                    Text("3 days old")
                        .secondaryTextStyle()
                }
            }
            
            DarkCard(accentColor: DesignTokens.accentComplete) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentComplete)
                    Text("Reply to Sarah")
                        .cardTitleStyle()
                        .strikethrough()
                    Text("Done today")
                        .secondaryTextStyle()
                }
            }
            
            GlassSection {
                Text("Glass section example")
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
            }
        }
        .padding()
    }
}
