//
//  AppIconGeneratorTests.swift
//  NudgeTests
//
//  Re-generates the 3 app icon variants (light / dark / tinted) by rendering
//  the live PenguinMascot SwiftUI view via ImageRenderer.
//
//  ✅ Source of truth: PenguinMascot.swift — no separate Python/Cairo script needed.
//     Editing the penguin and running these tests is all you have to do.
//
//  HOW TO RUN:
//    Xcode → Product > Test  (⌘U),  or focus just this suite in the Test navigator.
//    PNGs are written directly to Assets.xcassets/AppIcon.appiconset/.
//    Rebuild the app (⌘B) after running to pick up the updated icons.
//

import Testing
import SwiftUI
@testable import Nudge

// ─────────────────────────────────────────────────────────────
// MARK: - Test Suite
// ─────────────────────────────────────────────────────────────

@Suite("App Icon Generator")
struct AppIconGeneratorTests {

    // Hard-coded dev-time path — intentional (this is a local asset generator, not CI).
    private static let assetDir =
        "/Users/abdullahimran/Desktop/untitled folder/Nudge/Nudge/Assets.xcassets/AppIcon.appiconset"

    @Test @MainActor func generateLightIcon()  throws { try render(.light,  "icon-light.png")  }
    @Test @MainActor func generateDarkIcon()   throws { try render(.dark,   "icon-dark.png")   }
    @Test @MainActor func generateTintedIcon() throws { try render(.tinted, "icon-tinted.png") }

    // MARK: - Private helpers

    @MainActor
    private func render(_ variant: AppIconCanvas.Variant, _ filename: String) throws {
        let renderer = ImageRenderer(content: AppIconCanvas(variant: variant))
        renderer.scale     = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1024, height: 1024)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            Issue.record("ImageRenderer returned nil for \(filename)")
            return
        }

        let url = URL(fileURLWithPath: "\(Self.assetDir)/\(filename)")
        try data.write(to: url)
        print("✅  Wrote \(filename)")
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Icon Canvas
//
// This is the single place that defines what the app icon looks like.
// Edit the view, run the tests, rebuild — done.
// ─────────────────────────────────────────────────────────────

private struct AppIconCanvas: View {

    enum Variant { case light, dark, tinted }
    let variant: Variant

    var body: some View {
        ZStack {
            background

            PenguinMascot(
                expression: .happy,
                size: 1000,
                accentColor: accentColor,
                showBeanie: false
            )
            // Shift down so the contact shadow / feet are cropped out —
            // gives a clean bust-style portrait composition.
            .offset(y: 100)
        }
        .frame(width: 1024, height: 1024)
        .clipped()
    }

    // MARK: Backgrounds

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .light:
            // Soft lavender — works great on light home screens.
            LinearGradient(
                colors: [Color(hex: "F5F3FF"), Color(hex: "EDE9FE")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .dark:
            // Deep space — matches the app's OLED canvas aesthetic.
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "0A0A18")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .tinted:
            // Near-black base — iOS tinted icon system desaturates
            // and overlays the user's chosen tint color on top.
            LinearGradient(
                colors: [Color(hex: "141420"), Color(hex: "0A0A14")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: Accent color fed into the penguin

    private var accentColor: Color {
        switch variant {
        case .light, .dark: Color(hex: "7C6FF0") // Nudge purple
        case .tinted:       Color.white           // High contrast for tinted template
        }
    }
}
