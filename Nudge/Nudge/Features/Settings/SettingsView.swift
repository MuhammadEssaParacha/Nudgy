//
//  SettingsView.swift
//  Nudge
//
//  Minimal settings screen — quiet hours, nudge frequency, Live Activity toggle, Pro upgrade.
//

import SwiftUI
import StoreKit
import TipKit

struct SettingsView: View {
    
    @Environment(AppSettings.self) private var settings
    
    @State private var showPaywall = false
    
    private let liveActivityTip = LiveActivityTip()
    
    var body: some View {
        @Bindable var settings = settings
        
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
                                endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 320)
                        .offset(x: 80, y: -100)
                        .blur(radius: 60)
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.spacingLG) {
                        
                        // Penguin header
                        PenguinSceneView(
                            size: .medium,
                            expressionOverride: .idle,
                            accentColorOverride: DesignTokens.accentActive
                        )
                        .padding(.top, DesignTokens.spacingLG)
                        
                        // Notifications section
                        settingsSection(title: String(localized: "Notifications")) {
                            VStack(spacing: DesignTokens.spacingMD) {
                                settingsRow(
                                    icon: "moon.fill",
                                    title: String(localized: "Quiet Hours Start"),
                                    value: "\(formatHour(settings.quietHoursStart))"
                                )
                                
                                Picker(String(localized: "Start"), selection: $settings.quietHoursStart) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(formatHour(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 100)
                                
                                settingsRow(
                                    icon: "sunrise.fill",
                                    title: String(localized: "Quiet Hours End"),
                                    value: "\(formatHour(settings.quietHoursEnd))"
                                )
                                
                                Picker(String(localized: "End"), selection: $settings.quietHoursEnd) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(formatHour(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 100)
                                
                                Stepper(
                                    value: $settings.maxDailyNudges,
                                    in: 1...10
                                ) {
                                    settingsRow(
                                        icon: "bell.fill",
                                        title: String(localized: "Max Daily Nudges"),
                                        value: "\(settings.maxDailyNudges)"
                                    )
                                }
                            }
                        }
                        
                        // Live Activity section
                        settingsSection(title: String(localized: "Lock Screen")) {
                            VStack(spacing: DesignTokens.spacingSM) {
                                TipView(liveActivityTip)
                                    .tipBackground(DesignTokens.cardSurface)
                                
                                Toggle(isOn: $settings.liveActivityEnabled) {
                                    settingsRow(
                                        icon: "lock.circle.fill",
                                        title: String(localized: "Show on Lock Screen"),
                                        subtitle: String(localized: "Current task on Dynamic Island & Lock Screen")
                                    )
                                }
                                .tint(DesignTokens.accentActive)
                                .onChange(of: settings.liveActivityEnabled) { _, newValue in
                                    if newValue {
                                        Task { await LiveActivityTip.liveActivityEnabled.donate() }
                                    }
                                }
                            }
                        }
                        
                        // Your Name section
                        settingsSection(title: String(localized: "Personalization")) {
                            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                                settingsRow(
                                    icon: "person.fill",
                                    title: String(localized: "Your Name"),
                                    subtitle: String(localized: "Used to sign off AI-drafted messages")
                                )
                                
                                TextField(
                                    String(localized: "First name"),
                                    text: $settings.userName
                                )
                                .font(AppTheme.body)
                                .foregroundStyle(DesignTokens.textPrimary)
                                .submitLabel(.done)
                                .padding(DesignTokens.spacingMD)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                        }
                        
                        // Pro section
                        if !settings.isPro {
                            settingsSection(title: String(localized: "Upgrade")) {
                                Button {
                                    showPaywall = true
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                                            Text(String(localized: "Nudge Pro"))
                                                .font(AppTheme.body.weight(.semibold))
                                                .foregroundStyle(DesignTokens.textPrimary)
                                            Text(String(localized: "Unlimited brain unloads, AI drafts, and more"))
                                                .font(AppTheme.caption)
                                                .foregroundStyle(DesignTokens.textSecondary)
                                        }
                                        Spacer()
                                        Text(PurchaseService.shared.monthlyProduct?.displayPrice ?? String(localized: "Upgrade"))
                                            .font(AppTheme.body.weight(.bold))
                                            .foregroundStyle(DesignTokens.accentActive)
                                    }
                                    .padding(DesignTokens.spacingMD)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                            .fill(DesignTokens.accentActive.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                                    .strokeBorder(DesignTokens.accentActive.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // About section
                        settingsSection(title: String(localized: "About")) {
                            VStack(spacing: DesignTokens.spacingSM) {
                                settingsRow(
                                    icon: "info.circle.fill",
                                    title: String(localized: "Version"),
                                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                                )
                                
                                Button {
                                    if let url = URL(string: "mailto:support@nudgeapp.com") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    settingsRow(
                                        icon: "envelope.fill",
                                        title: String(localized: "Contact Support")
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Spacer for bottom padding
                        Spacer(minLength: DesignTokens.spacingXXXL)
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                }
            }
            .navigationTitle(String(localized: "Settings"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Reusable Components
    
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(title)
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
                .textCase(.uppercase)
            
            content()
                .padding(DesignTokens.spacingMD)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }
    
    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        value: String? = nil
    ) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DesignTokens.accentActive)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            
            Spacer()
            
            if let value {
                Text(value)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    private func formatHour(_ hour: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppSettings())
        .environment(PenguinState())
}
