//
//  PaywallView.swift
//  Nudge
//
//  Modal paywall — shown when hitting free tier limits or from Settings.
//  Feature comparison (Free vs Pro), monthly + yearly buttons, restore.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    
    @State private var purchaseService = PurchaseService.shared
    @State private var showError = false
    @State private var errorText = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DesignTokens.spacingXL) {
                    // Close button
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .nudgeAccessibility(
                            label: String(localized: "Close"),
                            hint: String(localized: "Dismiss paywall"),
                            traits: .isButton
                        )
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.top, DesignTokens.spacingSM)
                    
                    // Nudgy on the paywall — excited about Pro
                    PenguinSceneView(
                        size: .large,
                        expressionOverride: .celebrating
                    )
                    .onAppear {
                        penguinState.expression = .celebrating
                        penguinState.say(
                            String(localized: "Unlock my full potential! 🚀"),
                            style: .announcement,
                            autoDismiss: 5.0
                        )
                    }
                    
                    // Title
                    VStack(spacing: DesignTokens.spacingSM) {
                        Text(String(localized: "Unlock Nudge Pro"))
                            .font(AppTheme.displayFont)
                            .foregroundStyle(DesignTokens.textPrimary)
                        
                        Text(String(localized: "Your brain deserves the full experience"))
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Feature comparison
                    featureComparison
                    
                    // Price buttons
                    priceButtons
                    
                    // Restore
                    Button {
                        Task {
                            await purchaseService.restorePurchases()
                            purchaseService.syncToSettings(settings)
                            if purchaseService.isPro { dismiss() }
                        }
                    } label: {
                        if purchaseService.isLoading {
                            ProgressView()
                                .tint(DesignTokens.textTertiary)
                        } else {
                            Text(String(localized: "Restore Purchases"))
                                .font(.system(size: 14))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                    }
                    .disabled(purchaseService.isLoading)
                    
                    // Legal
                    VStack(spacing: 4) {
                        Text(String(localized: "Subscriptions auto-renew unless cancelled 24 hours before the end of the current period."))
                            .font(.system(size: 11))
                            .foregroundStyle(DesignTokens.textTertiary)
                        
                        HStack(spacing: 4) {
                            if let termsURL = URL(string: "https://nudge-app.com/terms") {
                                Link(String(localized: "Terms of Service"), destination: termsURL)
                            }
                            Text("·")
                                .foregroundStyle(DesignTokens.textTertiary)
                            if let privacyURL = URL(string: "https://nudge-app.com/privacy") {
                                Link(String(localized: "Privacy Policy"), destination: privacyURL)
                            }
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.accentActive)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .padding(.bottom, DesignTokens.spacingXXL)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await purchaseService.loadProducts()
        }
        .alert(String(localized: "Error"), isPresented: $showError) {
            Button(String(localized: "OK")) {}
        } message: {
            Text(errorText)
        }
    }
    
    // MARK: - Feature Comparison
    
    private var featureComparison: some View {
        VStack(spacing: 0) {
            featureRow(String(localized: "Brain Unloads"), free: String(localized: "3/day"), pro: String(localized: "Unlimited"))
            Divider().background(DesignTokens.cardBorder)
            featureRow(String(localized: "Saved Items"), free: String(localized: "5 total"), pro: String(localized: "Unlimited"))
            Divider().background(DesignTokens.cardBorder)
            featureRow(String(localized: "AI Message Drafts"), free: "—", pro: "✓")
            Divider().background(DesignTokens.cardBorder)
            featureRow(String(localized: "Smart Notifications"), free: String(localized: "Basic"), pro: String(localized: "Full"))
            Divider().background(DesignTokens.cardBorder)
            featureRow(String(localized: "Action Buttons in Notifications"), free: "—", pro: "✓")
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        .padding(.horizontal, DesignTokens.spacingLG)
    }
    
    private func featureRow(_ feature: String, free: String, pro: String) -> some View {
        HStack {
            Text(feature)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignTokens.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(free)
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.textTertiary)
                .frame(width: 70)
            
            Text(pro)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.accentActive)
                .frame(width: 70)
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.vertical, DesignTokens.spacingMD)
    }
    
    // MARK: - Price Buttons
    
    private var priceButtons: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // Yearly (best value)
            if let yearly = purchaseService.yearlyProduct {
                Button {
                    purchase(yearly)
                } label: {
                    VStack(spacing: 4) {
                        HStack {
                            Text(String(localized: "Yearly"))
                                .font(.system(size: 17, weight: .semibold))
                            
                            Spacer()
                            
                            Text(yearly.displayPrice)
                                .font(.system(size: 17, weight: .bold))
                            Text("/yr")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        HStack {
                            Text(purchaseService.yearlySavingsText)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(DesignTokens.accentComplete.opacity(0.2)))
                                .foregroundStyle(DesignTokens.accentComplete)
                            
                            Spacer()
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(DesignTokens.spacingLG)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                            .fill(DesignTokens.accentActive)
                    )
                }
                .disabled(purchaseService.isLoading)
            }
            
            // Monthly
            if let monthly = purchaseService.monthlyProduct {
                Button {
                    purchase(monthly)
                } label: {
                    HStack {
                        Text(String(localized: "Monthly"))
                            .font(.system(size: 17, weight: .medium))
                        
                        Spacer()
                        
                        Text(monthly.displayPrice)
                            .font(.system(size: 17, weight: .semibold))
                        Text("/mo")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)
                    .padding(DesignTokens.spacingLG)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                            .strokeBorder(DesignTokens.accentActive, lineWidth: 1.5)
                    )
                }
                .disabled(purchaseService.isLoading)
            }
            
            if purchaseService.isLoading {
                ProgressView()
                    .tint(DesignTokens.accentActive)
            }
        }
        .padding(.horizontal, DesignTokens.spacingLG)
    }
    
    // MARK: - Purchase
    
    private func purchase(_ product: Product) {
        Task {
            do {
                let success = try await purchaseService.purchase(product)
                if success {
                    purchaseService.syncToSettings(settings)
                    dismiss()
                }
            } catch {
                errorText = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environment(AppSettings())
        .environment(PenguinState())
}
