//
//  ADHDProfileSetupView.swift
//  Nudge
//
//  ADHD profile setup — 3 quick questions that calibrate Nudgy's
//  language, suggestions, and support style.
//
//  Used in onboarding (as a late page) and accessible from YouSettingsView
//  so users can update their profile any time.
//

import SwiftUI

struct ADHDProfileSetupView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    /// Whether this is embedded in onboarding (no navigation chrome).
    var isOnboarding: Bool = false
    var onComplete: (() -> Void)?

    @State private var step = 0   // 0: age, 1: challenge, 2: mode
    @State private var selectedAge: AgeGroup = .adult
    @State private var selectedChallenge: ADHDChallenge = .allOfAbove
    @State private var selectedMode: NudgyPersonalityMode = .gentle
    @State private var animateIn = false

    private let totalSteps = 3

    var body: some View {
        Group {
            if isOnboarding {
                content
            } else {
                NavigationStack {
                    content
                        .navigationTitle(String(localized: "Your Profile"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(String(localized: "Cancel")) { dismiss() }
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                        }
                }
                .preferredColorScheme(.dark)
            }
        }
        .onAppear {
            selectedAge = settings.ageGroup
            selectedChallenge = settings.adhdBiggestChallenge
            selectedMode = settings.nudgyPersonalityMode
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { animateIn = true }
        }
    }

    // MARK: - Main Content

    private var content: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ambientGlow.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                if !isOnboarding {
                    stepIndicator
                        .padding(.top, DesignTokens.spacingXL)
                }

                // Question card
                TabView(selection: $step) {
                    ageGroupStep.tag(0)
                    challengeStep.tag(1)
                    personalityModeStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)

                // Navigation buttons
                navigationButtons
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .padding(.bottom, isOnboarding ? DesignTokens.spacingMD : DesignTokens.spacingXXXL)
            }
        }
    }

    // MARK: - Step Views

    private var ageGroupStep: some View {
        questionCard(
            title: String(localized: "How old are you?"),
            subtitle: String(localized: "Nudgy adapts its language and examples to match you"),
            penguin: .idle
        ) {
            VStack(spacing: DesignTokens.spacingSM) {
                ForEach(AgeGroup.allCases, id: \.self) { age in
                    profileOptionRow(
                        icon: age.icon,
                        title: age.label,
                        subtitle: nil,
                        isSelected: selectedAge == age,
                        accentHex: "#4FC3F7"
                    ) { selectedAge = age }
                }
            }
        }
    }

    private var challengeStep: some View {
        questionCard(
            title: String(localized: "What's hardest for you?"),
            subtitle: String(localized: "Nudgy will proactively offer the right kind of help"),
            penguin: .thinking
        ) {
            VStack(spacing: DesignTokens.spacingXS) {
                ForEach(ADHDChallenge.allCases, id: \.self) { challenge in
                    profileOptionRow(
                        icon: nil,
                        emojiIcon: challenge.emoji,
                        title: challenge.label,
                        subtitle: challenge.description,
                        isSelected: selectedChallenge == challenge,
                        accentHex: "#4FC3F7"
                    ) { selectedChallenge = challenge }
                }
            }
        }
    }

    private var personalityModeStep: some View {
        questionCard(
            title: String(localized: "How should Nudgy talk?"),
            subtitle: String(localized: "You can change this any time in settings"),
            penguin: .happy
        ) {
            VStack(spacing: DesignTokens.spacingSM) {
                ForEach(NudgyPersonalityMode.allCases, id: \.self) { mode in
                    profileOptionRow(
                        icon: mode.icon,
                        title: mode.label,
                        subtitle: mode.description,
                        isSelected: selectedMode == mode,
                        accentHex: mode.accentColorHex
                    ) { selectedMode = mode }
                }
            }
        }
    }

    // MARK: - Reusable Components

    private func questionCard(
        title: String,
        subtitle: String,
        penguin: PenguinExpression,
        @ViewBuilder options: () -> some View
    ) -> some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingLG) {
                Spacer(minLength: DesignTokens.spacingLG)

                // Mini Nudgy
                PenguinSceneView(size: .medium, expressionOverride: penguin)
                    .scaleEffect(animateIn ? 1 : 0.7)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animateIn)

                // Heading
                VStack(spacing: DesignTokens.spacingXS) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignTokens.spacingXL)

                // Options
                options()
                    .padding(.horizontal, DesignTokens.spacingLG)

                Spacer(minLength: DesignTokens.spacingXXXL)
            }
        }
    }

    private func profileOptionRow(
        icon: String? = nil,
        emojiIcon: String? = nil,
        title: String,
        subtitle: String?,
        isSelected: Bool,
        accentHex: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { onTap() }
            HapticService.shared.actionButtonTap()
        } label: {
            HStack(spacing: DesignTokens.spacingMD) {
                // Icon
                Group {
                    if let emoji = emojiIcon {
                        Text(emoji)
                            .font(.system(size: 22))
                    } else if let sfIcon = icon {
                        Image(systemName: sfIcon)
                            .font(.system(size: 18))
                            .foregroundStyle(isSelected ? Color(hex: accentHex) : DesignTokens.textTertiary)
                    }
                }
                .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.body.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? DesignTokens.textPrimary : DesignTokens.textSecondary)
                    if let sub = subtitle {
                        Text(sub)
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color(hex: accentHex) : DesignTokens.textTertiary)
            }
            .padding(DesignTokens.spacingMD)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(Color(hex: accentHex).opacity(0.10))
                }
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Color(hex: "#4FC3F7") : Color.white.opacity(0.2))
                    .frame(width: i == step ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
        .padding(.bottom, DesignTokens.spacingMD)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            if step > 0 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            Button {
                if step < totalSteps - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { step += 1 }
                } else {
                    saveProfile()
                }
            } label: {
                Text(step < totalSteps - 1 ? String(localized: "Next") : String(localized: "Done"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#4FC3F7"))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Ambient Background

    private var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#4FC3F7").opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .offset(x: -80, y: -220)
                .blur(radius: 80)
        }
    }

    // MARK: - Save

    private func saveProfile() {
        settings.ageGroup = selectedAge
        settings.adhdBiggestChallenge = selectedChallenge
        settings.nudgyPersonalityMode = selectedMode
        settings.hasCompletedADHDProfile = true
        HapticService.shared.swipeDone()

        if isOnboarding {
            onComplete?()
        } else {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    ADHDProfileSetupView()
        .environment(AppSettings())
        .environment(PenguinState())
}
