//
//  FishCounterHUD.swift
//  Nudge
//
//  A compact fish counter pill for the Nudges tab.
//  Shows today's fish earned with a bounce animation on increment.
//  Serves as the target anchor for FishRewardOverlay flying fish.
//
//  Phase 2 + 6 + 7: HUD component, bounce animation, floating +N text.
//

import SwiftUI

// MARK: - Fish Counter HUD

struct FishCounterHUD: View {
    
    let fishToday: Int
    let fish: Int
    let species: FishSpecies?
    
    /// Binding to report the HUD's screen position for flying fish targeting.
    var onPositionChange: ((CGPoint) -> Void)?
    
    @State private var bounceScale: CGFloat = 1.0
    @State private var floatingText: String? = nil
    @State private var floatingOffset: CGFloat = 0
    @State private var floatingOpacity: Double = 0
    @State private var previousFishToday: Int = 0
    @State private var showSparkle = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        GeometryReader { geo in
            let pos = CGPoint(
                x: geo.frame(in: .global).midX,
                y: geo.frame(in: .global).midY
            )
            
            ZStack {
                // Main pill
                HStack(spacing: 5) {
                    // Fish icon
                    FishView(size: 16, color: Color(hex: "FFD54F"), accentColor: Color(hex: "F57F17"))
                        .scaleEffect(x: -1) // Face right
                    
                    Text("\(fishToday)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "FFD54F"))
                        .contentTransition(.numericText(value: Double(fishToday)))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color(hex: "FFD54F").opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(hex: "FFD54F").opacity(0.2), lineWidth: 0.5)
                        )
                )
                .scaleEffect(bounceScale)
                
                // Sparkle burst on increment
                if showSparkle {
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .fill(Color(hex: "FFD54F"))
                            .frame(width: 3, height: 3)
                            .offset(
                                x: cos(Double(i) * .pi / 3) * 20,
                                y: sin(Double(i) * .pi / 3) * 20
                            )
                            .opacity(showSparkle ? 0 : 0.8)
                            .scaleEffect(showSparkle ? 1.5 : 0.5)
                    }
                }
                
                // Floating "+N" text
                if let text = floatingText {
                    Text(text)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "FFD54F"))
                        .offset(y: floatingOffset)
                        .opacity(floatingOpacity)
                }
            }
            .onChange(of: pos) { _, newPos in
                onPositionChange?(newPos)
            }
            .onAppear {
                previousFishToday = fishToday
                onPositionChange?(pos)
            }
        }
        .frame(width: 65, height: 28)
        .onChange(of: fishToday) { oldValue, newValue in
            guard newValue > oldValue else {
                previousFishToday = newValue
                return
            }
            
            let earned = newValue - oldValue
            triggerBounce()
            showFloatingText("+\(earned)")
            previousFishToday = newValue
        }
        .nudgeAccessibility(
            label: String(localized: "\(fishToday) fish earned today, \(fish) fish total"),
            traits: .isStaticText
        )
    }
    
    // MARK: - Animations
    
    private func triggerBounce() {
        guard !reduceMotion else { return }
        
        // Sparkle
        withAnimation(.easeOut(duration: 0.4)) {
            showSparkle = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.4))
            showSparkle = false
        }
        
        // Bounce
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
            bounceScale = 1.3
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bounceScale = 1.0
            }
        }
    }
    
    private func showFloatingText(_ text: String) {
        floatingText = text
        floatingOffset = 0
        floatingOpacity = 1.0
        
        withAnimation(.easeOut(duration: 1.0)) {
            floatingOffset = -30
            floatingOpacity = 0
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            floatingText = nil
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            FishCounterHUD(fishToday: 3, fish: 42, species: .tropical)
            FishCounterHUD(fishToday: 0, fish: 0, species: nil)
        }
    }
    .preferredColorScheme(.dark)
}
