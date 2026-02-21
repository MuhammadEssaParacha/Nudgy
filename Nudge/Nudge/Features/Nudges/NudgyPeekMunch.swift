//
//  NudgyPeekMunch.swift
//  Nudge
//
//  Option B: A mini Nudgy head that peeks up from the bottom of the Nudges tab
//  after completing a task, catches a flying fish, and dips back down.
//  A delightful 2-second micro-animation that rewards without interrupting.
//
//  Phase 13: Mini Nudgy peek-munch animation.
//

import SwiftUI

// MARK: - Nudgy Peek Munch

struct NudgyPeekMunch: View {
    
    @Binding var isActive: Bool
    let species: FishSpecies?
    
    @State private var peekOffset: CGFloat = 80
    @State private var mouthOpen = false
    @State private var fishVisible = true
    @State private var fishOffset: CGFloat = -40
    @State private var happyBounce = false
    @State private var showHeart = false
    @State private var animationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Fish that flies toward Nudgy's mouth
            if fishVisible, let species {
                FishView(
                    size: 18,
                    color: species.fishColor,
                    accentColor: species.fishAccentColor
                )
                .scaleEffect(x: -1)
                .offset(x: 20, y: peekOffset + fishOffset - 20)
                .transition(.opacity)
            }
            
            // Nudgy peeking head
            ZStack {
                // Simple penguin head silhouette
                VStack(spacing: 0) {
                    // Head
                    ZStack {
                        // Head shape
                        Ellipse()
                            .fill(Color(hex: "2C2C2E"))
                            .frame(width: 50, height: 45)
                        
                        // White face patch
                        Ellipse()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 32, height: 28)
                            .offset(y: 3)
                        
                        // Eyes
                        HStack(spacing: 10) {
                            // Left eye
                            Ellipse()
                                .fill(Color(hex: "0A0A0E"))
                                .frame(width: 7, height: mouthOpen ? 8 : 7)
                            // Right eye
                            Ellipse()
                                .fill(Color(hex: "0A0A0E"))
                                .frame(width: 7, height: mouthOpen ? 8 : 7)
                        }
                        .offset(y: -2)
                        
                        // Eye glints
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 2.5, height: 2.5)
                                .offset(x: 1, y: -1)
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 2.5, height: 2.5)
                                .offset(x: 1, y: -1)
                        }
                        .offset(y: -2)
                        
                        // Beak / mouth
                        if mouthOpen {
                            // Open mouth — catching fish!
                            Ellipse()
                                .fill(Color(hex: "FF8A65"))
                                .frame(width: 12, height: 8)
                                .offset(y: 10)
                        } else {
                            // Closed beak — happy
                            Triangle()
                                .fill(Color(hex: "FF8A65"))
                                .frame(width: 10, height: 6)
                                .offset(y: 9)
                        }
                    }
                    .scaleEffect(happyBounce ? 1.1 : 1.0)
                }
                
                // Heart when munching
                if showHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.pink)
                        .offset(x: 25, y: -25)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .offset(y: peekOffset)
        }
        .frame(height: 60)
        .clipped()
        .onAppear { if isActive { performPeekMunch() } }
        .onDisappear { animationTask?.cancel() }
        .onChange(of: isActive) { _, active in
            if active {
                performPeekMunch()
            }
        }
    }
    
    // MARK: - Animation Sequence
    
    private func performPeekMunch() {
        animationTask?.cancel()
        
        guard !reduceMotion else {
            animationTask = Task { @MainActor in
                withAnimation(.easeOut(duration: 0.3)) { peekOffset = 10 }
                try? await Task.sleep(for: .seconds(1.0))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.3)) { peekOffset = 80 }
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled else { return }
                isActive = false
            }
            return
        }
        
        // Reset state
        peekOffset = 80
        mouthOpen = false
        fishVisible = true
        fishOffset = -40
        happyBounce = false
        showHeart = false
        
        animationTask = Task { @MainActor in
            // Step 1: Nudgy peeks up
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                peekOffset = 10
            }
            
            // Step 2: Open mouth
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                mouthOpen = true
            }
            
            // Step 3: Fish flies into mouth
            try? await Task.sleep(for: .seconds(0.1))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.25)) {
                fishOffset = 10
            }
            
            // Step 4: Fish disappears, mouth closes — munch!
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            fishVisible = false
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                mouthOpen = false
            }
            HapticService.shared.prepare()
            
            // Step 5: Happy bounce + heart
            try? await Task.sleep(for: .seconds(0.1))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
                happyBounce = true
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showHeart = true
            }
            
            // Step 6: Settle
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                happyBounce = false
            }
            
            // Step 7: Nudgy dips back down
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showHeart = false
            }
            withAnimation(.easeIn(duration: 0.3)) {
                peekOffset = 80
            }
            
            // Step 8: Cleanup
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            isActive = false
        }
    }
}

// MARK: - Munch Triangle Shape

private struct MunchTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            NudgyPeekMunch(isActive: .constant(true), species: .tropical)
        }
    }
    .preferredColorScheme(.dark)
}
