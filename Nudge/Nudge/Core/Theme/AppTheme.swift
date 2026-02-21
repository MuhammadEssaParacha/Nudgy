//
//  AppTheme.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

// MARK: - App Theme

enum AppTheme {
    
    // MARK: Typography
    //
    // Design philosophy: "Warm on Cold"
    // - Headings use SF Rounded — friendly warmth against the dark Antarctic glass
    // - Body text stays SF Pro — clean, native, readable
    // - Nudgy's voice uses SF Rounded at a heavier weight — it's HIS personality
    // - Never use more than one custom font — consistency > novelty
    //
    // All fonts use Dynamic Type automatically via .system() initializers.
    
    /// Large display text — empty state messages, onboarding headings
    /// SF Rounded for warmth — this is where brand personality shows most
    static let displayFont: Font = .system(.largeTitle, design: .rounded, weight: .bold)
    
    /// Card task title — the main text users read
    /// Rounded to match display hierarchy — feels cohesive with headings
    static let taskTitle: Font = .system(.title2, design: .rounded, weight: .semibold)
    
    /// Medium title — used in overlays and editors
    static let title2: Font = .system(.title2, design: .rounded, weight: .semibold)
    
    /// Small title — section names, form field headings
    static let title3: Font = .system(.title3, design: .rounded, weight: .semibold)
    
    /// General title — used where title2/title3 are too specific
    static let title: Font = .system(.title2, design: .rounded, weight: .semibold)
    
    /// Section headers, button labels
    static let headline: Font = .system(.headline, design: .rounded, weight: .semibold)
    
    /// Body text — descriptions, draft previews
    /// SF Pro (default) for readability — warm headings + clean body = the balance
    static let body: Font = .system(.body, design: .default, weight: .regular)
    
    /// Subheadline — slightly smaller body, secondary emphasis
    static let subheadline: Font = .system(.subheadline, design: .default, weight: .regular)
    
    /// Secondary text — timestamps, metadata, hints
    static let caption: Font = .system(.caption, design: .default, weight: .regular)
    
    /// Bold caption — counts, badges, emphasis in small text
    static let captionBold: Font = .system(.caption, design: .default, weight: .bold)
    
    /// Small labels — queue position, counts
    static let footnote: Font = .system(.footnote, design: .default, weight: .regular)
    
    /// Rounded variant for mascot-adjacent UI (friendly feel)
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
    
    /// Nudgy's speech bubble text — rounded, friendly, slightly warm
    /// This IS Nudgy's voice — rounder and warmer than the rest of the UI
    static let nudgyBubbleFont: Font = .system(.callout, design: .rounded, weight: .medium)
    
    /// Nudgy's name label — used below the penguin when shown large
    static let nudgyNameFont: Font = .system(.caption2, design: .rounded, weight: .semibold)
    
    /// Status/HUD text — small rounded labels for counters, levels, badges
    static let hudFont: Font = .system(.caption2, design: .rounded, weight: .bold)
    
    /// Hint text — small, muted instructions below interactive elements
    static let hintFont: Font = .system(size: 11, weight: .medium, design: .rounded)
    
    /// Emoji display — large emoji on cards. Use `emoji(size:)` for custom sizes.
    static let emoji: Font = .system(size: 32)
    
    /// Emoji at a custom size
    static func emoji(size: CGFloat) -> Font {
        .system(size: size)
    }
}

// MARK: - View Modifiers for Consistent Styling

struct CardTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.taskTitle)
            .foregroundStyle(DesignTokens.textPrimary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }
}

struct SecondaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.caption)
            .foregroundStyle(DesignTokens.textSecondary)
    }
}

struct TertiaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.footnote)
            .foregroundStyle(DesignTokens.textTertiary)
    }
}

struct AccentButtonStyle: ViewModifier {
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(AppTheme.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton))
    }
}

// MARK: - View Extension Shortcuts

extension View {
    func cardTitleStyle() -> some View {
        modifier(CardTitleStyle())
    }
    
    func secondaryTextStyle() -> some View {
        modifier(SecondaryTextStyle())
    }
    
    func tertiaryTextStyle() -> some View {
        modifier(TertiaryTextStyle())
    }
    
    func accentButtonStyle(color: Color = DesignTokens.accentActive) -> some View {
        modifier(AccentButtonStyle(color: color))
    }
}
