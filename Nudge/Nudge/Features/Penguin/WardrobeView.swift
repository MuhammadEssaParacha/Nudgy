//
//  WardrobeView.swift
//  Nudge
//
//  Accessory shop & equip screen.
//  Browse unlocked and locked accessories, spend fish to unlock,
//  and equip items on Nudgy with instant preview.
//
//  Presented as a sheet from the penguin's home screen.
//

import SwiftUI
import SwiftData

struct WardrobeView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var rewardService = RewardService.shared
    @State private var selectedAccessory: String?
    @State private var showUnlockConfirm = false
    @State private var unlockResult: UnlockResult?
    @State private var showCelebration = false
    @State private var appeared = false
    @State private var nudgyAppeared = false
    @State private var statsAppeared = false
    @State private var tiersAppeared: Set<Int> = []
    @State private var celebrationScale: CGFloat = 1.0
    @State private var sparkleRotation: Double = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.spacingXL) {
                    // Header — Nudgy preview with equipped accessories
                    nudgyPreview
                        .opacity(nudgyAppeared ? 1 : 0)
                        .scaleEffect(nudgyAppeared ? 1 : 0.85)
                    
                    // Stats bar
                    statsBar
                        .opacity(statsAppeared ? 1 : 0)
                        .offset(y: statsAppeared ? 0 : 12)
                    
                    // Accessory grid by tier
                    ForEach(1...4, id: \.self) { tier in
                        tierSection(tier)
                            .opacity(tiersAppeared.contains(tier) ? 1 : 0)
                            .offset(y: tiersAppeared.contains(tier) ? 0 : 20)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.bottom, DesignTokens.spacingXXXL)
            }
            .background(DesignTokens.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "Nudgy's Wardrobe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.accentActive)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear { animateEntrance() }
        }
        .confirmationDialog(
            unlockDialogTitle,
            isPresented: $showUnlockConfirm,
            titleVisibility: .visible
        ) {
            if let id = selectedAccessory {
                let cost = AccessoryCatalog.cost(for: id)
                Button(String(localized: "Unlock for \(cost) 🐟")) {
                    performUnlock(id)
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            }
        }
    }
    
    // MARK: - Entrance Animation
    
    private func animateEntrance() {
        guard !reduceMotion else {
            nudgyAppeared = true
            statsAppeared = true
            tiersAppeared = [1, 2, 3, 4]
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.1)) {
            nudgyAppeared = true
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2)) {
            statsAppeared = true
        }
        for tier in 1...4 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.25 + Double(tier) * 0.08)) {
                _ = tiersAppeared.insert(tier)
            }
        }
    }
    
    // MARK: - Nudgy Preview
    
    private var nudgyPreview: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            nudgyPreviewZStack
                .frame(height: 200)

            Text(String(localized: "Nudgy"))
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(DesignTokens.textTertiary.opacity(0.5))
                .textCase(.uppercase)
                .tracking(2.0)
        }
        .padding(.top, DesignTokens.spacingMD)
    }
    
    private var nudgyPreviewZStack: some View {
        ZStack {
            // Ambient glow behind Nudgy
            nudgyAmbientGlow

            // Celebration sparkles
            if showCelebration && !reduceMotion {
                celebrationSparkles
            }

            nudgyCharacterView
        }
    }
    
    private var nudgyAmbientGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        DesignTokens.accentActive.opacity(showCelebration ? 0.15 : 0.06),
                        DesignTokens.accentActive.opacity(0.02),
                        .clear
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 100
                )
            )
            .frame(width: 200, height: 200)
            .scaleEffect(showCelebration ? 1.3 : 1.0)
            .animation(.easeOut(duration: 0.4), value: showCelebration)
    }
    
    private var nudgyCharacterView: some View {
        let expression: PenguinExpression = showCelebration ? .celebrating : .idle
        return NudgySprite(
            expression: expression,
            size: 160,
            accentColor: DesignTokens.accentActive
        )
        .scaleEffect(celebrationScale)
        .shadow(color: DesignTokens.accentActive.opacity(0.15), radius: 20)
    }

    // MARK: - Celebration Sparkles

    @ViewBuilder
    private var celebrationSparkles: some View {
        let sizes: [CGFloat] = [12, 8, 10, 14, 9, 11]
        let colors: [Color] = [
            Color(hex: "FFD700"), Color(hex: "FF8C00"), DesignTokens.accentComplete,
            Color(hex: "7BB8FF"), Color(hex: "FFB800"), Color.white.opacity(0.7)
        ]
        ForEach(0..<6, id: \.self) { i in
            let angle = Double(i) * .pi / 3.0 + sparkleRotation * .pi / 180.0
            Image(systemName: "sparkle")
                .font(.system(size: sizes[i]))
                .foregroundStyle(colors[i])
                .offset(
                    x: CGFloat(cos(angle)) * 75,
                    y: CGFloat(sin(angle)) * 50
                )
                .opacity(0.8)
        }
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack(spacing: 0) {
            statBadge(
                icon: "fish.fill",
                gradient: [Color(hex: "FFB800"), Color(hex: "FF8C00")],
                value: "\(rewardService.fish)",
                label: String(localized: "Fish")
            )

            thinDivider

            statBadge(
                icon: "star.fill",
                gradient: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                value: String(localized: "Lv.\(rewardService.level)"),
                label: String(localized: "Level")
            )

            thinDivider

            statBadge(
                icon: "flame.fill",
                gradient: [Color(hex: "FF6B35"), Color(hex: "FF453A")],
                value: "\(rewardService.currentStreak)",
                label: String(localized: "Day Streak")
            )
        }
        .padding(.vertical, DesignTokens.spacingMD + 2)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.02), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }
    
    private func statBadge(icon: String, gradient: [Color], value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                )
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(DesignTokens.textPrimary)
            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(DesignTokens.textTertiary)
                .tracking(1.0)
        }
        .frame(maxWidth: .infinity)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 0.5, height: 36)
    }
    
    // MARK: - Tier Section
    
    private func tierSection(_ tier: Int) -> some View {
        let items = AccessoryCatalog.all.filter { AccessoryCatalog.tier(for: $0.id) == tier }
        guard !items.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                // Tier header with icon and color
                HStack(spacing: 8) {
                    Image(systemName: tierIcon(tier))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tierColor(tier))

                    Text(tierTitle(tier))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 8, weight: .medium))
                        Text(tierCost(tier))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(tierColor(tier).opacity(0.7))
                }
                
                // Item grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: DesignTokens.spacingSM),
                        GridItem(.flexible(), spacing: DesignTokens.spacingSM),
                        GridItem(.flexible(), spacing: DesignTokens.spacingSM)
                    ],
                    spacing: DesignTokens.spacingSM
                ) {
                    ForEach(items) { item in
                        accessoryCell(item, tier: tier)
                    }
                }
            }
            .padding(DesignTokens.spacingLG)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [tierColor(tier).opacity(0.03), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        )
    }
    
    private func tierTitle(_ tier: Int) -> String {
        switch tier {
        case 1: return String(localized: "Starter")
        case 2: return String(localized: "Explorer")
        case 3: return String(localized: "Achiever")
        case 4: return String(localized: "Legendary")
        default: return ""
        }
    }
    
    private func tierCost(_ tier: Int) -> String {
        switch tier {
        case 1: return String(localized: "5 each")
        case 2: return String(localized: "15 each")
        case 3: return String(localized: "30 each")
        case 4: return String(localized: "50 each")
        default: return ""
        }
    }

    private func tierIcon(_ tier: Int) -> String {
        switch tier {
        case 1: return "leaf.fill"
        case 2: return "map.fill"
        case 3: return "trophy.fill"
        case 4: return "crown.fill"
        default: return "star.fill"
        }
    }

    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return Color(hex: "88CCFF")
        case 2: return Color(hex: "81C784")
        case 3: return Color(hex: "FFB800")
        case 4: return Color(hex: "FFD700")
        default: return DesignTokens.accentActive
        }
    }
    
    // MARK: - Accessory Cell
    
    private func accessoryCell(_ item: NudgyAccessoryItem, tier: Int) -> some View {
        let isUnlocked = rewardService.unlockedAccessories.contains(item.id)
        let isEquipped = rewardService.equippedAccessories.contains(item.id)
        let canAfford = rewardService.fish >= AccessoryCatalog.cost(for: item.id)
        let tColor = tierColor(tier)
        
        return Button {
            if isUnlocked {
                // Toggle equip with haptic
                HapticService.shared.cardAppear()
                rewardService.toggleEquip(accessoryID: item.id, context: modelContext)
            } else {
                // Attempt unlock
                HapticService.shared.cardAppear()
                selectedAccessory = item.id
                showUnlockConfirm = true
            }
        } label: {
            VStack(spacing: 6) {
                // Icon container
                ZStack {
                    if isUnlocked {
                        Image(systemName: AccessoryCatalog.icon(for: item.id))
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(tColor)
                    } else {
                        VStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(
                                    canAfford
                                        ? tColor
                                        : DesignTokens.textTertiary.opacity(0.5)
                                )
                            HStack(spacing: 1) {
                                Image(systemName: "fish.fill")
                                    .font(.system(size: 7))
                                Text("\(AccessoryCatalog.cost(for: item.id))")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(
                                canAfford
                                    ? tColor.opacity(0.8)
                                    : DesignTokens.textTertiary.opacity(0.4)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            isEquipped
                                ? tColor.opacity(0.08)
                                : Color.white.opacity(0.015)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isEquipped
                                ? tColor.opacity(0.5)
                                : Color.white.opacity(0.06),
                            lineWidth: isEquipped ? 1.5 : 0.5
                        )
                }
                
                // Name
                Text(AccessoryCatalog.displayName(for: item.id))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        isUnlocked
                            ? DesignTokens.textSecondary
                            : DesignTokens.textTertiary.opacity(0.6)
                    )
                    .lineLimit(1)
                
                // Equipped badge
                if isEquipped {
                    HStack(spacing: 2) {
                        Circle()
                            .fill(tColor)
                            .frame(width: 4, height: 4)
                        Text(String(localized: "Wearing"))
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(tColor)
                    }
                }
            }
        }
        .buttonStyle(AccessoryCellButtonStyle())
        .nudgeAccessibility(
            label: AccessoryCatalog.displayName(for: item.id),
            hint: isUnlocked
                ? (isEquipped
                    ? String(localized: "Tap to unequip")
                    : String(localized: "Tap to equip"))
                : String(localized: "Locked. Costs \(AccessoryCatalog.cost(for: item.id)) fish to unlock"),
            traits: .isButton
        )
    }
    
    // MARK: - Unlock
    
    private var unlockDialogTitle: String {
        guard let id = selectedAccessory else { return "" }
        return String(localized: "Unlock \(AccessoryCatalog.displayName(for: id))?")
    }
    
    private func performUnlock(_ accessoryID: String) {
        let result = rewardService.unlock(accessoryID: accessoryID, context: modelContext)
        unlockResult = result
        
        if case .success = result {
            HapticService.shared.swipeDone()
            
            // Auto-equip newly unlocked item
            rewardService.toggleEquip(accessoryID: accessoryID, context: modelContext)
            
            // Celebration sequence
            showCelebration = true
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                celebrationScale = 1.15
            }
            if !reduceMotion {
                withAnimation(.linear(duration: 2.0)) {
                    sparkleRotation += 360
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        celebrationScale = 1.0
                    }
                }
                try? await Task.sleep(for: .seconds(1.2))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showCelebration = false
                    }
                }
            }
        }
    }
}

// MARK: - Accessory Cell Press Style

/// Subtle press-down effect for accessory grid cells.
private struct AccessoryCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Wardrobe") {
    let penguinState = PenguinState()
    
    WardrobeView()
        .environment(penguinState)
}
