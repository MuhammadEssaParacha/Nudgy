//
//  MilestoneCelebrationView.swift
//  Nudge
//
//  Full-screen celebration overlay when the user hits a task milestone.
//  Big emoji, confetti-like particles, and a warm message from Nudgy.
//

import SwiftUI

struct MilestoneCelebrationView: View {
    
    let milestone: Int
    var topCategory: TaskCategory?
    @Binding var isPresented: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showContent = false
    @State private var particlePhase: CGFloat = 0
    
    private var info: (title: String, subtitle: String, icon: String) {
        MilestoneService.message(for: milestone)
    }
    
    /// Accent color — category-tinted when a top category is provided.
    private var celebrationColor: Color {
        topCategory?.primaryColor ?? DesignTokens.accentComplete
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            // Celebration particles
            if !reduceMotion {
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill(particleColor(i))
                        .frame(width: CGFloat.random(in: 4...8))
                        .offset(
                            x: CGFloat.random(in: -150...150),
                            y: -200 + particlePhase * CGFloat.random(in: 300...500)
                        )
                        .opacity(1 - particlePhase)
                }
            }
            
            // Content
            if showContent {
                VStack(spacing: DesignTokens.spacingXXL) {
                    Spacer()
                    
                    Image(systemName: info.icon)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(celebrationColor)
                    
                    VStack(spacing: DesignTokens.spacingMD) {
                        Text(info.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(celebrationColor)
                        
                        Text(info.subtitle)
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignTokens.spacingXXL)
                        
                        // Category context line
                        if let cat = topCategory, cat != .general {
                            HStack(spacing: DesignTokens.spacingXS) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(cat.primaryColor)
                                Text(String(localized: "Most completed: \(cat.label)"))
                                    .font(AppTheme.caption.weight(.medium))
                                    .foregroundStyle(cat.primaryColor)
                            }
                            .padding(.top, DesignTokens.spacingXS)
                        }
                    }
                    
                    // Bonus fish
                    let bonus = MilestoneService.bonusFish(for: milestone)
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DesignTokens.accentActive)
                        Text(String(localized: "+\(bonus) fish"))
                            .font(AppTheme.body.weight(.semibold))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background(
                        Capsule()
                            .fill(DesignTokens.accentActive.opacity(0.12))
                    )
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Text(String(localized: "Let's keep going! 💪"))
                            .font(AppTheme.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.spacingMD)
                            .background(
                                Capsule()
                                    .fill(celebrationColor)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DesignTokens.spacingXXL)
                    .padding(.bottom, DesignTokens.spacingXXXL)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .onAppear {
            HapticService.shared.swipeDone()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
            
            if !reduceMotion {
                withAnimation(.easeOut(duration: 2.0)) {
                    particlePhase = 1.0
                }
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
    }
    
    private func particleColor(_ index: Int) -> Color {
        // Category-tinted particles when a top category is provided
        if let cat = topCategory, cat != .general {
            let catColors: [Color] = [
                cat.gradientColors[0],
                cat.gradientColors.count > 1 ? cat.gradientColors[1] : cat.gradientColors[0],
                DesignTokens.accentComplete,
                Color(hex: "FFD60A"),
                cat.gradientColors[0].opacity(0.8),
                Color(hex: "FF2D55")
            ]
            return catColors[index % catColors.count]
        }
        
        let colors: [Color] = [
            DesignTokens.accentActive,
            DesignTokens.accentComplete,
            DesignTokens.accentStale,
            Color(hex: "BF5AF2"),
            Color(hex: "FF2D55"),
            Color(hex: "FFD60A")
        ]
        return colors[index % colors.count]
    }
}
