//
//  MountainLandscape.swift
//  Nudge
//
//  Parallax-layered mountain landscape backdrop for Nudgy's intro journey.
//  Pure SwiftUI — layered shapes with aurora sky, stars, snow-capped peaks,
//  and animated ambient elements (twinkling, cloud drift, aurora shimmer).
//

import SwiftUI

// MARK: - Mountain Landscape

struct MountainLandscape: View {
    
    /// Controls which layer elements are visible (animate in sequentially).
    var revealProgress: CGFloat = 1.0
    
    /// Time-of-day tint — shifts palette for emotional beats.
    var mood: LandscapeMood = .night
    
    /// Whether Nudgy's glow illuminates the foreground.
    var showGlow: Bool = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var starTwinkle: Bool = false
    @State private var auroraPhase: CGFloat = 0
    @State private var cloudOffset: CGFloat = 0
    @State private var snowDriftX: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Layer 0: Sky gradient
                skyGradient
                    .opacity(min(revealProgress * 2, 1.0))
                
                // Layer 1: Stars
                starsField(width: w, height: h)
                    .opacity(revealProgress > 0.1 ? 1.0 : 0.0)
                
                // Layer 2: Aurora borealis
                auroraEffect(width: w, height: h)
                    .opacity(Double(min(max(revealProgress - 0.15, 0) * 3, 1.0)))
                
                // Layer 3: Far mountains (darkest, smallest)
                MountainLayer(
                    peaks: [0.18, 0.22, 0.15, 0.25, 0.19, 0.23, 0.16],
                    baseY: 0.52,
                    color: mood.farMountainColor,
                    jaggedness: 0.06
                )
                .opacity(Double(min(max(revealProgress - 0.2, 0) * 4, 1.0)))
                
                // Layer 4: Mid mountains
                MountainLayer(
                    peaks: [0.22, 0.30, 0.18, 0.35, 0.25, 0.28],
                    baseY: 0.58,
                    color: mood.midMountainColor,
                    jaggedness: 0.08
                )
                .opacity(Double(min(max(revealProgress - 0.3, 0) * 3.5, 1.0)))
                
                // Layer 5: Close mountains with snow caps
                MountainLayer(
                    peaks: [0.28, 0.40, 0.20, 0.38, 0.30],
                    baseY: 0.65,
                    color: mood.closeMountainColor,
                    jaggedness: 0.10,
                    snowCapHeight: 0.06
                )
                .opacity(Double(min(max(revealProgress - 0.4, 0) * 3, 1.0)))
                
                // Layer 6: Snow-covered foreground hills
                foregroundHills(width: w, height: h)
                    .opacity(Double(min(max(revealProgress - 0.5, 0) * 2.5, 1.0)))
                
                // Layer 7: Drifting cloud wisps
                cloudWisps(width: w, height: h)
                    .opacity(Double(min(max(revealProgress - 0.3, 0) * 2, 0.6)))
                
                // Layer 8: Subtle ground glow (Nudgy's presence)
                if showGlow {
                    nudgyGlow(width: w, height: h)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { startAmbientAnimations() }
    }
    
    // MARK: - Sky
    
    private var skyGradient: some View {
        LinearGradient(
            colors: mood.skyColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Stars
    
    private func starsField(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            // Deterministic star placement using simple hash
            let starCount = 60
            for i in 0..<starCount {
                let seed = Double(i * 7919 + 1301)
                let x = (seed.truncatingRemainder(dividingBy: size.width * 1.3)).truncatingRemainder(dividingBy: size.width)
                let y = (seed * 0.618).truncatingRemainder(dividingBy: size.height * 0.55) // Stars only in top half
                let radius: CGFloat = CGFloat(1.0 + (seed * 0.37).truncatingRemainder(dividingBy: 2.0))
                let twinkleGroup = i % 3
                let baseOpacity = 0.3 + (seed * 0.23).truncatingRemainder(dividingBy: 0.6)
                let opacity = starTwinkle && twinkleGroup == 0
                    ? baseOpacity * 0.3
                    : baseOpacity
                
                context.opacity = opacity
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                    with: .color(.white)
                )
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Aurora
    
    private func auroraEffect(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Primary aurora band
            AuroraWave(phase: auroraPhase)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "00E5A0").opacity(0.08),
                            Color(hex: "00C9FF").opacity(0.12),
                            Color(hex: "7B2FBE").opacity(0.06),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: height * 0.35)
                .offset(y: -height * 0.15)
                .blur(radius: 30)
            
            // Secondary shimmer
            AuroraWave(phase: auroraPhase + .pi * 0.5)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "7B2FBE").opacity(0.05),
                            Color(hex: "00E5A0").opacity(0.08),
                            Color(hex: "00C9FF").opacity(0.04),
                        ],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                )
                .frame(height: height * 0.25)
                .offset(y: -height * 0.08)
                .blur(radius: 40)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Foreground Hills
    
    private func foregroundHills(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Main snowy ground
            SnowHillShape()
                .fill(
                    LinearGradient(
                        colors: mood.snowColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: height * 0.32)
                .offset(y: height * 0.35)
            
            // Snow sparkle overlay
            SnowHillShape()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.12), Color.clear],
                        center: .init(x: 0.3, y: 0.2),
                        startRadius: 0,
                        endRadius: width * 0.4
                    )
                )
                .frame(height: height * 0.32)
                .offset(y: height * 0.35)
        }
    }
    
    // MARK: - Cloud Wisps
    
    private func cloudWisps(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.04))
                .frame(width: width * 0.5, height: 8)
                .blur(radius: 12)
                .offset(x: cloudOffset - width * 0.15, y: -height * 0.12)
            
            Capsule()
                .fill(Color.white.opacity(0.03))
                .frame(width: width * 0.35, height: 6)
                .blur(radius: 10)
                .offset(x: -cloudOffset + width * 0.2, y: -height * 0.22)
            
            Capsule()
                .fill(Color.white.opacity(0.025))
                .frame(width: width * 0.45, height: 5)
                .blur(radius: 14)
                .offset(x: cloudOffset * 0.6, y: -height * 0.06)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Nudgy Glow
    
    private func nudgyGlow(width: CGFloat, height: CGFloat) -> some View {
        RadialGradient(
            colors: [
                DesignTokens.accentActive.opacity(0.12),
                DesignTokens.accentActive.opacity(0.04),
                Color.clear,
            ],
            center: .init(x: 0.5, y: 0.68),
            startRadius: 0,
            endRadius: width * 0.35
        )
        .allowsHitTesting(false)
    }
    
    // MARK: - Animations
    
    private func startAmbientAnimations() {
        guard !reduceMotion else { return }
        
        // Star twinkle — alternates groups every 2s
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            starTwinkle = true
        }
        
        // Aurora drift
        withAnimation(
            .easeInOut(duration: 8.0)
            .repeatForever(autoreverses: true)
        ) {
            auroraPhase = .pi * 2
        }
        
        // Cloud drift
        withAnimation(
            .easeInOut(duration: 12.0)
            .repeatForever(autoreverses: true)
        ) {
            cloudOffset = 30
        }
    }
}

// MARK: - Landscape Mood

enum LandscapeMood {
    case night       // Deep blue/purple — default intro
    case dawn        // Warm peach horizon — hope/excitement
    case golden      // Amber glow — fish/reward scenes
    case summit      // Bright blues — final CTA
    
    var skyColors: [Color] {
        switch self {
        case .night:
            return [Color(hex: "050510"), Color(hex: "0A1628"), Color(hex: "0F2040")]
        case .dawn:
            return [Color(hex: "0A1628"), Color(hex: "1A1040"), Color(hex: "2D1B4E")]
        case .golden:
            return [Color(hex: "0A1628"), Color(hex: "1A1535"), Color(hex: "2A1A30")]
        case .summit:
            return [Color(hex: "05101A"), Color(hex: "0A2040"), Color(hex: "0F3060")]
        }
    }
    
    var farMountainColor: Color {
        switch self {
        case .night:   return Color(hex: "0A1830")
        case .dawn:    return Color(hex: "1A1040")
        case .golden:  return Color(hex: "1A1530")
        case .summit:  return Color(hex: "0A2040")
        }
    }
    
    var midMountainColor: Color {
        switch self {
        case .night:   return Color(hex: "0D2040")
        case .dawn:    return Color(hex: "201248")
        case .golden:  return Color(hex: "201838")
        case .summit:  return Color(hex: "0D2848")
        }
    }
    
    var closeMountainColor: Color {
        switch self {
        case .night:   return Color(hex: "102850")
        case .dawn:    return Color(hex: "281555")
        case .golden:  return Color(hex: "281C40")
        case .summit:  return Color(hex: "103058")
        }
    }
    
    var snowColors: [Color] {
        switch self {
        case .night:   return [Color(hex: "C8D8F0"), Color(hex: "8898B0"), Color(hex: "405068")]
        case .dawn:    return [Color(hex: "D8C8E0"), Color(hex: "A898B0"), Color(hex: "584868")]
        case .golden:  return [Color(hex: "E0D0C0"), Color(hex: "B0A090"), Color(hex: "685848")]
        case .summit:  return [Color(hex: "D0E0F8"), Color(hex: "90A8C8"), Color(hex: "485870")]
        }
    }
}

// MARK: - Mountain Layer

/// A single row of procedural peaks drawn as a connected bezier path.
struct MountainLayer: View {
    /// Heights of each peak as fraction of container height (0.0–1.0)
    let peaks: [CGFloat]
    /// Y position where the mountain base sits (fraction, 0 = top)
    let baseY: CGFloat
    /// Fill color
    let color: Color
    /// How jagged the peaks are (higher = sharper)
    var jaggedness: CGFloat = 0.08
    /// Snow cap height as fraction (0 = no snow)
    var snowCapHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            
            ZStack {
                // Mountain fill
                MountainRangeShape(
                    peaks: peaks,
                    baseY: baseY,
                    jaggedness: jaggedness
                )
                .fill(color)
                
                // Snow caps (optional)
                if snowCapHeight > 0 {
                    MountainRangeShape(
                        peaks: peaks,
                        baseY: baseY,
                        jaggedness: jaggedness
                    )
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.8), Color.clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: UnitPoint.top.y + Double(snowCapHeight * 3))
                        )
                    )
                    .mask(
                        // Only show snow on the upper portion
                        VStack(spacing: 0) {
                            Rectangle()
                                .frame(height: h * (baseY - snowCapHeight))
                            Color.clear
                        }
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Custom Shapes

/// Generates a mountain range silhouette from peak height values.
struct MountainRangeShape: Shape {
    let peaks: [CGFloat]
    let baseY: CGFloat
    let jaggedness: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let peakCount = peaks.count
        guard peakCount > 0 else { return Path() }
        
        let segmentWidth = w / CGFloat(peakCount - 1)
        
        return Path { p in
            // Start at bottom-left
            p.move(to: CGPoint(x: 0, y: h))
            
            // Line up to the first peak
            let firstPeakY = h * (baseY - peaks[0])
            p.addLine(to: CGPoint(x: 0, y: firstPeakY))
            
            // Draw peaks with smooth curves
            for i in 0..<(peakCount - 1) {
                let x0 = CGFloat(i) * segmentWidth
                let x1 = CGFloat(i + 1) * segmentWidth
                let y0 = h * (baseY - peaks[i])
                let y1 = h * (baseY - peaks[i + 1])
                
                // Valley between peaks
                let valleyX = (x0 + x1) / 2
                let valleyY = h * (baseY - min(peaks[i], peaks[i + 1]) * 0.3)
                
                // Control points for smooth peak-to-valley-to-peak
                let cp1x = x0 + segmentWidth * 0.25
                let cp1y = y0 + h * jaggedness * 0.3
                let cp2x = valleyX - segmentWidth * 0.1
                let cp2y = valleyY
                
                p.addCurve(
                    to: CGPoint(x: valleyX, y: valleyY),
                    control1: CGPoint(x: cp1x, y: cp1y),
                    control2: CGPoint(x: cp2x, y: cp2y)
                )
                
                let cp3x = valleyX + segmentWidth * 0.1
                let cp3y = valleyY
                let cp4x = x1 - segmentWidth * 0.25
                let cp4y = y1 + h * jaggedness * 0.3
                
                p.addCurve(
                    to: CGPoint(x: x1, y: y1),
                    control1: CGPoint(x: cp3x, y: cp3y),
                    control2: CGPoint(x: cp4x, y: cp4y)
                )
            }
            
            // Close along the bottom
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
        }
    }
}

/// Aurora wave — sinusoidal band that shifts with phase.
struct AuroraWave: Shape {
    var phase: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            p.move(to: CGPoint(x: 0, y: h * 0.5))
            
            let segments = 60
            for i in 0...segments {
                let x = w * CGFloat(i) / CGFloat(segments)
                let normalizedX = CGFloat(i) / CGFloat(segments)
                let y = h * 0.5
                    + sin(normalizedX * .pi * 3 + phase) * h * 0.25
                    + sin(normalizedX * .pi * 1.5 + phase * 0.7) * h * 0.15
                p.addLine(to: CGPoint(x: x, y: y))
            }
            
            p.addLine(to: CGPoint(x: w, y: h))
            p.addLine(to: CGPoint(x: 0, y: h))
            p.closeSubpath()
        }
    }
}

/// Gentle rolling snow hill for the foreground.
struct SnowHillShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            p.move(to: CGPoint(x: 0, y: h * 0.35))
            
            // Gentle rolling curve across the width
            p.addCurve(
                to: CGPoint(x: w * 0.3, y: h * 0.15),
                control1: CGPoint(x: w * 0.08, y: h * 0.30),
                control2: CGPoint(x: w * 0.18, y: h * 0.10)
            )
            p.addCurve(
                to: CGPoint(x: w * 0.55, y: h * 0.25),
                control1: CGPoint(x: w * 0.40, y: h * 0.18),
                control2: CGPoint(x: w * 0.48, y: h * 0.25)
            )
            p.addCurve(
                to: CGPoint(x: w * 0.80, y: h * 0.08),
                control1: CGPoint(x: w * 0.62, y: h * 0.22),
                control2: CGPoint(x: w * 0.72, y: h * 0.06)
            )
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.20),
                control1: CGPoint(x: w * 0.88, y: h * 0.10),
                control2: CGPoint(x: w * 0.95, y: h * 0.18)
            )
            
            // Close along bottom
            p.addLine(to: CGPoint(x: w, y: h))
            p.addLine(to: CGPoint(x: 0, y: h))
            p.closeSubpath()
        }
    }
}

// MARK: - Previews

#Preview("Night Mood") {
    MountainLandscape(mood: .night, showGlow: true)
}

#Preview("Dawn Mood") {
    MountainLandscape(mood: .dawn, showGlow: false)
}

#Preview("Golden Mood") {
    MountainLandscape(mood: .golden, showGlow: true)
}

#Preview("Summit Mood") {
    MountainLandscape(mood: .summit, showGlow: true)
}

#Preview("Reveal Animation") {
    struct RevealDemo: View {
        @State private var progress: CGFloat = 0
        var body: some View {
            ZStack {
                MountainLandscape(revealProgress: progress, mood: .night, showGlow: progress > 0.7)
                VStack {
                    Spacer()
                    Slider(value: $progress, in: 0...1)
                        .padding(32)
                        .tint(.white)
                }
            }
        }
    }
    return RevealDemo()
}
