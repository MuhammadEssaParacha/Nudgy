//
//  CategoryPreferencesView.swift
//  Nudge
//
//  Phase 15: Category preferences — priority categories + per-category notification toggles.
//  Accessed from YouSettingsView → "Categories" section.
//

import SwiftUI

struct CategoryPreferencesView: View {
    
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let categories = TaskCategory.allCases
    
    var body: some View {
        @Bindable var settings = settings
        
        ScrollView {
            VStack(spacing: DesignTokens.spacingXL) {
                
                // MARK: Priority Categories
                
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Label {
                        Text(String(localized: "Priority Categories"))
                            .font(AppTheme.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.textSecondary)
                            .textCase(.uppercase)
                    } icon: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                    
                    Text(String(localized: "Tasks in these categories get boosted in SmartPick. Pick 3-5."))
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            priorityCategoryCell(cat)
                        }
                    }
                    .padding(DesignTokens.spacingMD)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
                }
                
                // MARK: Notification Preferences
                
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    Label {
                        Text(String(localized: "Category Notifications"))
                            .font(AppTheme.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.textSecondary)
                            .textCase(.uppercase)
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    
                    Text(String(localized: "Turn off notifications for categories you don't want nudges about."))
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                    
                    VStack(spacing: 0) {
                        ForEach(categories, id: \.self) { cat in
                            notificationToggleRow(cat)
                            
                            if cat != categories.last {
                                Divider()
                                    .overlay(Color.white.opacity(0.06))
                            }
                        }
                    }
                    .padding(DesignTokens.spacingMD)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
                }
                
                Spacer(minLength: DesignTokens.spacingXXXL)
            }
            .padding(.horizontal, DesignTokens.spacingLG)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(String(localized: "Categories"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
    
    // MARK: - Priority Category Cell
    
    private func priorityCategoryCell(_ cat: TaskCategory) -> some View {
        let isPriority = settings.priorityCategories.contains(cat.rawValue)
        let tint = cat.primaryColor
        
        return Button {
            HapticService.shared.cardAppear()
            withAnimation(AnimationConstants.springSmooth) {
                if isPriority {
                    settings.priorityCategories.removeAll { $0 == cat.rawValue }
                } else {
                    settings.priorityCategories.append(cat.rawValue)
                }
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Image(systemName: cat.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isPriority ? .white : cat.primaryColor)
                    
                    if isPriority {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                            .offset(x: 12, y: -10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Text(cat.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isPriority ? .white : DesignTokens.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPriority ? tint.opacity(0.2) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isPriority ? tint.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: "\(cat.label), \(isPriority ? String(localized: "priority") : String(localized: "not priority"))",
            hint: String(localized: "Double tap to toggle priority"),
            traits: .isButton
        )
    }
    
    // MARK: - Notification Toggle Row
    
    private func notificationToggleRow(_ cat: TaskCategory) -> some View {
        let isEnabled = settings.isCategoryNotificationEnabled(cat)
        
        return HStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: cat.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(cat.primaryColor)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(cat.label)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    settings.categoryNotificationsEnabled[cat.rawValue] = newValue
                }
            ))
            .tint(cat.primaryColor)
            .labelsHidden()
        }
        .padding(.vertical, 6)
        .nudgeAccessibility(
            label: "\(cat.label) notifications \(isEnabled ? String(localized: "on") : String(localized: "off"))",
            hint: String(localized: "Double tap to toggle"),
            traits: .isButton
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CategoryPreferencesView()
            .environment(AppSettings())
    }
}
