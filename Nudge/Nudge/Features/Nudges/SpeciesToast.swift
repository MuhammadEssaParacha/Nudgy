//
//  SpeciesToast.swift
//  Nudge
//
//  A brief toast that reveals the fish species earned after completing a task.
//  Slides in from the top, shows species emoji + name + fish earned, then auto-dismisses.
//  Rare catches (swordfish, whale) get extra sparkle + haptic.
//
//  Phase 8 + 10: Species toast component + rare catch celebration.
//

import SwiftUI

// MARK: - Species Toast

struct SpeciesToast: View {
    
    let species: FishSpecies
    let fishEarned: Int
    let isRare: Bool
    /// Optional category info: (icon, label, count today) for the completed task's category
    var categoryInfo: (icon: String, label: String, count: Int)? = nil
    @Binding var isPresented: Bool
    
    @State private var sparkleRotation: Double = 0
    @State private var glowPulse: Bool = false
    @State private var dismissTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var isVeryRare: Bool {
        species == .whale
    }
    
    var body: some View {
        VStack {
            toastContent
                .padding(.top, 60)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Haptic for rare catches
            if isRare {
                HapticService.shared.swipeDone()
                if isVeryRare {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.15))
                        HapticService.shared.swipeDone()
                    }
                }
            }
            
            // Sparkle rotation for rare
            if isRare && !reduceMotion {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    sparkleRotation = 360
                }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
            
            // Auto-dismiss (cancellable)
            let duration = species.celebrationDuration
            dismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    isPresented = false
                }
            }
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }
    
    private var toastContent: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // Fish icon with species-specific glow
            ZStack {
                if isRare {
                    // Glow ring for rare catches
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: species.glowColorHex).opacity(glowPulse ? 0.3 : 0.1),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    // Rotating sparkle dots
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(Color(hex: species.glowColorHex).opacity(0.6))
                            .frame(width: 3, height: 3)
                            .offset(y: -22)
                            .rotationEffect(.degrees(sparkleRotation + Double(i) * 90))
                    }
                }
                
                FishView(
                    size: species.displaySize,
                    color: species.fishColor,
                    accentColor: species.fishAccentColor
                )
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(species.description)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isRare ? Color(hex: species.glowColorHex) : DesignTokens.textPrimary)
                
                HStack(spacing: 4) {
                    Image(systemName: species.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: species.glowColorHex))
                    Text(species.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                    
                    Text("•")
                        .foregroundStyle(DesignTokens.textTertiary)
                    
                    HStack(spacing: 2) {
                        Text("+\(fishEarned)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Image(systemName: "fish.fill")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "87CEEB"))
                }
                
                // Category counter (e.g. "🏠 Household × 3 today")
                if let info = categoryInfo, info.count >= 2 {
                    HStack(spacing: 3) {
                        Image(systemName: info.icon)
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(info.label) × \(info.count) today")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM + 2)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(
                    isRare
                        ? Color(hex: species.glowColorHex).opacity(0.08)
                        : Color(hex: "FFD54F").opacity(0.05)
                )
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        .padding(.horizontal, DesignTokens.spacingLG)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            SpeciesToast(species: .catfish, fishEarned: 1, isRare: false, isPresented: .constant(true))
            SpeciesToast(species: .swordfish, fishEarned: 10, isRare: true, isPresented: .constant(true))
            SpeciesToast(species: .whale, fishEarned: 15, isRare: true, isPresented: .constant(true))
        }
    }
    .preferredColorScheme(.dark)
}
