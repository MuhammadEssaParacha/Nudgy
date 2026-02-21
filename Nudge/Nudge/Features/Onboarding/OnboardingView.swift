//
//  OnboardingView.swift
//  Nudge
//
//  Post-auth glassmorphic onboarding — Nudgy teaches you the ropes.
//  Page 1: Brain dump with Nudgy
//  Page 2: One card at a time
//  Page 3: Name + get started
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0
    @State private var firstName: String = ""
    @State private var selectedCategories: Set<TaskCategory> = []
    @State private var selectedAgeGroup: AgeGroup = .adult
    @State private var selectedChallenge: ADHDChallenge = .allOfAbove
    @State private var selectedMode: NudgyPersonalityMode = .gentle
    @FocusState private var nameFieldFocused: Bool

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            mascot: .listening,
            title: String(localized: "Talk, don't type"),
            body: String(localized: "Tap the mic and unload everything. Nudgy turns your ramble into neat task cards."),
            gradient: [Color(hex: "BF5AF2"), Color(hex: "FF375F")]
        ),
        OnboardingPage(
            mascot: .happy,
            title: String(localized: "One card at a time"),
            body: String(localized: "No overwhelming lists. Handle one task, swipe it done, see the next. Simple as that."),
            gradient: [Color(hex: "30D158"), Color(hex: "0A84FF")]
        ),
        OnboardingPage(
            mascot: .thinking,
            title: String(localized: "Auto-sorted by life area"),
            body: String(localized: "Household, finance, health, social — Nudgy auto-tags every task so you see what areas need attention."),
            gradient: [Color(hex: "FF9500"), Color(hex: "FF375F")]
        ),
        OnboardingPage(
            mascot: .waving,
            title: String(localized: "A little about you"),
            body: String(localized: "Two quick questions so Nudgy can talk to you the right way."),
            gradient: [Color(hex: "4FC3F7"), Color(hex: "5E5CE6")]
        ),
        OnboardingPage(
            mascot: .celebrating,
            title: String(localized: "Ready to roll!"),
            body: String(localized: "Nudgy's here whenever you need a nudge. Let's get your first brain unload going."),
            gradient: [Color(hex: "0A84FF"), Color(hex: "5E5CE6")]
        ),
    ]

    private var springAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.5, dampingFraction: 0.8)
    }

    var body: some View {
        ZStack {
            ambientBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text(String(localized: "Skip"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.trailing, DesignTokens.spacingLG)
                    }
                }
                .frame(height: 44)
                .padding(.top, DesignTokens.spacingSM)

                // Pages
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i], index: i)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom controls
                bottomControls
                    .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
        .animation(springAnimation, value: currentPage)
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        ZStack {
            Color.black

            Circle()
                .fill(
                    RadialGradient(
                        colors: [pages[currentPage].gradient[0].opacity(0.25), .clear],
                        center: .center, startRadius: 0, endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: -60, y: -220)
                .blur(radius: 80)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [pages[currentPage].gradient[1].opacity(0.15), .clear],
                        center: .center, startRadius: 0, endRadius: 220
                    )
                )
                .frame(width: 450, height: 450)
                .offset(x: 100, y: 320)
                .blur(radius: 60)
        }
        .animation(.easeInOut(duration: 0.8), value: currentPage)
    }

    // MARK: - Page View

    private func pageView(_ page: OnboardingPage, index: Int) -> some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()

            // Nudgy penguin
            PenguinSceneView(
                size: .large,
                expressionOverride: page.mascot
            )
            .scaleEffect(currentPage == index ? 1 : 0.75)
            .opacity(currentPage == index ? 1 : 0)
            .animation(springAnimation, value: currentPage)

            // Glass card with text
            VStack(spacing: DesignTokens.spacingMD) {
                Text(page.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(page.body)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // ADHD profile quick-pick on page index 3
                if index == 3 {
                    VStack(spacing: DesignTokens.spacingMD) {
                        // Age group
                        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                            Text(String(localized: "How old are you?"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                            HStack(spacing: 6) {
                                ForEach(AgeGroup.allCases, id: \.self) { age in
                                    Button {
                                        HapticService.shared.actionButtonTap()
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedAgeGroup = age
                                        }
                                    } label: {
                                        VStack(spacing: 2) {
                                            Image(systemName: age.icon)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(selectedAgeGroup == age ? Color(hex: "4FC3F7") : .white.opacity(0.4))
                                            Text(age.label.components(separatedBy: " ").first ?? "")
                                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                                .foregroundStyle(selectedAgeGroup == age ? .white.opacity(0.9) : .white.opacity(0.35))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedAgeGroup == age ? Color(hex: "4FC3F7").opacity(0.2) : Color.white.opacity(0.05))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .nudgeAccessibility(label: age.label, traits: .isButton)
                                }
                            }
                        }
                        // What's hardest for you?
                        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                            Text(String(localized: "What's hardest for you?"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                            HStack(spacing: 6) {
                                ForEach([ADHDChallenge.starting, .staying, .emotions, .timeBlindness, .allOfAbove], id: \.self) { c in
                                    Button {
                                        HapticService.shared.actionButtonTap()
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedChallenge = c
                                        }
                                    } label: {
                                        Text(c.emoji)
                                            .font(.system(size: 22))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                Circle()
                                                    .fill(selectedChallenge == c ? Color(hex: "4FC3F7").opacity(0.3) : Color.white.opacity(0.07))
                                            )
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(selectedChallenge == c ? Color(hex: "4FC3F7").opacity(0.7) : Color.white.opacity(0.1), lineWidth: 0.5)
                                            )
                                            .scaleEffect(selectedChallenge == c ? 1.1 : 1.0)
                                    }
                                    .buttonStyle(.plain)
                                    .nudgeAccessibility(label: c.label, traits: .isButton)
                                }
                            }
                            if selectedChallenge != .allOfAbove {
                                Text(selectedChallenge.label)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(hex: "4FC3F7").opacity(0.8))
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        // Nudgy's voice style
                        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                            Text(String(localized: "How should Nudgy talk?"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                            HStack(spacing: 6) {
                                ForEach(NudgyPersonalityMode.allCases, id: \.self) { mode in
                                    Button {
                                        HapticService.shared.actionButtonTap()
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedMode = mode
                                        }
                                    } label: {
                                        VStack(spacing: 2) {
                                            Image(systemName: mode.icon)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(selectedMode == mode ? Color(hex: mode.accentColorHex) : .white.opacity(0.4))
                                            Text(mode.label.components(separatedBy: " ").first ?? "")
                                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                                .foregroundStyle(selectedMode == mode ? .white.opacity(0.9) : .white.opacity(0.35))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedMode == mode ? Color(hex: mode.accentColorHex).opacity(0.2) : Color.white.opacity(0.05))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .nudgeAccessibility(label: mode.label, traits: .isButton)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // Phase 14: Tappable category selection grid — "Pick 3-5 areas"
                if index == 2 {
                    VStack(spacing: 8) {
                        Text(String(localized: "Pick 3-5 areas that matter most"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        categorySelectionGrid
                    }
                    .padding(.top, 4)
                }

                // Name field on last page
                if index == pages.count - 1 {
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.white.opacity(0.35))
                                .frame(width: 20)
                            TextField(String(localized: "Your first name (optional)"), text: $firstName)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundStyle(.white)
                                .focused($nameFieldFocused)
                                .submitLabel(.done)
                                .textContentType(.givenName)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                        )

                        Text(String(localized: "Used to sign off AI-drafted messages"))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(DesignTokens.spacingXL)
            .frame(maxWidth: .infinity)
            .background(glassCard)
            .padding(.horizontal, DesignTokens.spacingLG)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Glass

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.4))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            // Pill dots
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? .white : .white.opacity(0.25))
                        .frame(width: i == currentPage ? 24 : 8, height: 8)
                        .animation(springAnimation, value: currentPage)
                }
            }

            if currentPage == pages.count - 1 {
                // Get Started
                Button {
                    completeOnboarding()
                } label: {
                    Text(String(localized: "Let's go!"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: pages[currentPage].gradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: pages[currentPage].gradient[0].opacity(0.35), radius: 20, y: 8)
                }
                .padding(.horizontal, DesignTokens.spacingXL)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(springAnimation) { currentPage += 1 }
                } label: {
                    Text(String(localized: "Next"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.15), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, DesignTokens.spacingXL)
            }
        }
    }

    // MARK: - Category Selection Grid (Phase 14)
    
    /// All categories except general — displayed as tappable pills.
    private nonisolated static let selectableCategories: [TaskCategory] = TaskCategory.allCases.filter { $0 != .general }
    
    private var categorySelectionGrid: some View {
        // Wrap flow layout using flexible HStacks
        let cats = Self.selectableCategories
        let rows: [[TaskCategory]] = {
            // 4 rows of 5 cats each
            var result: [[TaskCategory]] = []
            var row: [TaskCategory] = []
            for cat in cats {
                row.append(cat)
                if row.count == 5 {
                    result.append(row)
                    row = []
                }
            }
            if !row.isEmpty { result.append(row) }
            return result
        }()
        
        return VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { cat in
                        categoryPill(cat)
                    }
                }
            }
        }
    }
    
    private func categoryPill(_ cat: TaskCategory) -> some View {
        let isSelected = selectedCategories.contains(cat)
        let color = cat.primaryColor
        
        return Button {
            HapticService.shared.prepare()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedCategories.remove(cat)
                } else {
                    selectedCategories.insert(cat)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: cat.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : cat.primaryColor)
                Text(cat.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.35) : .white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.6) : .white.opacity(0.08), lineWidth: 0.5)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: "\(cat.label)\(isSelected ? ", selected" : "")",
            traits: .isButton
        )
    }
    
    // MARK: - Actions

    private func completeOnboarding() {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            settings.userName = trimmed
        }
        // Save priority categories from onboarding selection
        if !selectedCategories.isEmpty {
            settings.priorityCategories = selectedCategories.map(\.rawValue)
        }
        // Save ADHD profile from onboarding selections
        settings.ageGroup = selectedAgeGroup
        settings.adhdBiggestChallenge = selectedChallenge
        settings.nudgyPersonalityMode = selectedMode
        settings.hasCompletedADHDProfile = true
        // Sync profile into NudgyEngine so the first session uses the right voice/context
        NudgyEngine.shared.syncADHDProfile(settings: settings)
        withAnimation(springAnimation) {
            settings.hasCompletedOnboarding = true
        }
    }
}

// MARK: - Model

private struct OnboardingPage {
    let mascot: PenguinExpression
    let title: String
    let body: String
    let gradient: [Color]
}

#Preview {
    OnboardingView()
        .environment(AppSettings())
        .environment(PenguinState())
}
