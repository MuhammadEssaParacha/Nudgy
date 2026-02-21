//
//  NudgySprite.swift
//  Nudge
//
//  The main Nudgy character view — replaces LottieNudgyView as the character
//  renderer when sprite art is available.
//
//  Layers:
//    1. SpriteAnimator (base penguin body animation)
//    2. AccessoryOverlay (equipped items — scarf, hat, etc.)
//    3. Expression-driven transforms (float, sway, bounce — same as LottieNudgyView)
//
//  Falls back to the existing PenguinMascot bezier rendering via SpriteAnimator's
//  placeholder mode when artist PNGs aren't in the asset catalog yet.
//

import SwiftUI

// MARK: - Accessory Item Definition

/// An accessory that can be layered on top of Nudgy's sprite.
struct NudgyAccessoryItem: Identifiable, Equatable {
    let id: String                 // e.g. "scarf-blue", "beanie-red"
    let imageName: String          // Asset catalog name
    let slot: AccessorySlot        // Where it goes on the body
    let offsetX: CGFloat           // Relative offset from center (fraction of size)
    let offsetY: CGFloat           // Relative offset from center (fraction of size)
    let scale: CGFloat             // Relative scale (1.0 = same as penguin)
    
    /// Slots determine layering order and prevent conflicts.
    enum AccessorySlot: String, CaseIterable {
        case head       // Hats, beanies, crowns
        case face       // Sunglasses, masks
        case neck       // Scarves, bow ties
        case body       // Backpacks, capes
        case held       // Books, fishing rods (needs alt idle frames)
        case furniture  // Chairs, beds (rendered behind penguin)
    }
}

// MARK: - Accessory Catalog

/// All available accessories and their positioning data.
/// Offsets are fractions of the penguin size — e.g. 0.1 = 10% of penguin height.
enum AccessoryCatalog {
    
    static let all: [NudgyAccessoryItem] = [
        // Tier 1 — Quick unlocks (5 🐟 each)
        NudgyAccessoryItem(id: "scarf-blue", imageName: "acc-scarf-blue", slot: .neck,
                          offsetX: 0, offsetY: 0.15, scale: 0.5),
        NudgyAccessoryItem(id: "scarf-red", imageName: "acc-scarf-red", slot: .neck,
                          offsetX: 0, offsetY: 0.15, scale: 0.5),
        NudgyAccessoryItem(id: "bow-tie", imageName: "acc-bow-tie", slot: .neck,
                          offsetX: 0, offsetY: 0.12, scale: 0.25),
        NudgyAccessoryItem(id: "sunglasses", imageName: "acc-sunglasses", slot: .face,
                          offsetX: 0, offsetY: -0.12, scale: 0.35),
        NudgyAccessoryItem(id: "flower", imageName: "acc-flower", slot: .head,
                          offsetX: 0.15, offsetY: -0.32, scale: 0.2),
        
        // Tier 2 — Medium effort (15 🐟 each)
        NudgyAccessoryItem(id: "beanie-red", imageName: "acc-beanie-red", slot: .head,
                          offsetX: 0, offsetY: -0.33, scale: 0.45),
        NudgyAccessoryItem(id: "headphones", imageName: "acc-headphones", slot: .head,
                          offsetX: 0, offsetY: -0.22, scale: 0.5),
        NudgyAccessoryItem(id: "backpack", imageName: "acc-backpack", slot: .body,
                          offsetX: 0, offsetY: 0.05, scale: 0.4),
        NudgyAccessoryItem(id: "bandana", imageName: "acc-bandana", slot: .neck,
                          offsetX: 0, offsetY: 0.1, scale: 0.45),
        
        // Tier 3 — Real commitment (30 🐟 each)
        NudgyAccessoryItem(id: "book", imageName: "acc-book", slot: .held,
                          offsetX: 0.2, offsetY: 0.1, scale: 0.3),
        NudgyAccessoryItem(id: "guitar", imageName: "acc-guitar", slot: .held,
                          offsetX: -0.15, offsetY: 0.05, scale: 0.45),
        NudgyAccessoryItem(id: "armchair", imageName: "acc-armchair", slot: .furniture,
                          offsetX: 0, offsetY: 0.15, scale: 0.8),
        
        // Tier 4 — Legendary (50 🐟 each)
        NudgyAccessoryItem(id: "crown", imageName: "acc-crown", slot: .head,
                          offsetX: 0, offsetY: -0.35, scale: 0.35),
        NudgyAccessoryItem(id: "cape", imageName: "acc-cape", slot: .body,
                          offsetX: 0, offsetY: -0.05, scale: 0.7),
    ]
    
    static func item(for id: String) -> NudgyAccessoryItem? {
        all.first { $0.id == id }
    }
    
    /// Cost in fish to unlock each accessory.
    static func cost(for id: String) -> Int {
        switch id {
        // Tier 1
        case "scarf-blue", "scarf-red", "bow-tie", "sunglasses", "flower":
            return 5
        // Tier 2
        case "beanie-red", "headphones", "backpack", "bandana":
            return 15
        // Tier 3
        case "book", "guitar", "armchair":
            return 30
        // Tier 4
        case "crown", "cape":
            return 50
        default:
            return 10
        }
    }
    
    /// Tier label for display.
    static func tier(for id: String) -> Int {
        let cost = cost(for: id)
        switch cost {
        case ...5:  return 1
        case ...15: return 2
        case ...30: return 3
        default:    return 4
        }
    }
    
    /// SF Symbol icon for placeholder UI.
    static func icon(for id: String) -> String {
        switch id {
        case "scarf-blue":  return "wind"
        case "scarf-red":   return "wind"
        case "bow-tie":     return "gift.fill"
        case "sunglasses":  return "eyeglasses"
        case "flower":      return "camera.macro"
        case "beanie-red":  return "hood.fill"
        case "headphones":  return "headphones"
        case "backpack":    return "backpack.fill"
        case "bandana":     return "flag.fill"
        case "book":        return "book.fill"
        case "guitar":      return "guitars.fill"
        case "armchair":    return "chair.lounge.fill"
        case "crown":       return "crown.fill"
        case "cape":        return "bolt.shield.fill"
        default:            return "gift.fill"
        }
    }
    
    /// Deprecated — use `icon(for:)` for rendering.
    static func emoji(for id: String) -> String {
        switch id {
        case "scarf-blue":  return "🧣"
        case "scarf-red":   return "🧣"
        case "bow-tie":     return "🎀"
        case "sunglasses":  return "🕶️"
        case "flower":      return "🌸"
        case "beanie-red":  return "🧢"
        case "headphones":  return "🎧"
        case "backpack":    return "🎒"
        case "bandana":     return "🏴‍☠️"
        case "book":        return "📖"
        case "guitar":      return "🎸"
        case "armchair":    return "🪑"
        case "crown":       return "👑"
        case "cape":        return "🦸"
        default:            return "🎁"
        }
    }
    
    /// Display name for each accessory.
    static func displayName(for id: String) -> String {
        switch id {
        case "scarf-blue":  return String(localized: "Blue Scarf")
        case "scarf-red":   return String(localized: "Red Scarf")
        case "bow-tie":     return String(localized: "Bow Tie")
        case "sunglasses":  return String(localized: "Sunglasses")
        case "flower":      return String(localized: "Flower")
        case "beanie-red":  return String(localized: "Red Beanie")
        case "headphones":  return String(localized: "Headphones")
        case "backpack":    return String(localized: "Backpack")
        case "bandana":     return String(localized: "Bandana")
        case "book":        return String(localized: "Tiny Book")
        case "guitar":      return String(localized: "Guitar")
        case "armchair":    return String(localized: "Armchair")
        case "crown":       return String(localized: "Crown")
        case "cape":        return String(localized: "Cape")
        default:            return id.capitalized
        }
    }
}

// MARK: - Accessory Overlay View

/// Renders equipped accessories layered on top of the penguin sprite.
struct AccessoryOverlay: View {
    let equippedIDs: Set<String>
    let penguinSize: CGFloat
    
    /// Whether to use placeholder emojis or real PNG assets.
    var usePlaceholder: Bool = true
    
    var body: some View {
        ZStack {
            ForEach(sortedAccessories, id: \.id) { item in
                accessoryView(for: item)
                    .offset(
                        x: item.offsetX * penguinSize,
                        y: item.offsetY * penguinSize
                    )
            }
        }
        .frame(width: penguinSize, height: penguinSize)
        .allowsHitTesting(false) // Accessories don't intercept taps
    }
    
    /// Sorted by slot for correct layering: furniture → body → neck → face → head → held.
    private var sortedAccessories: [NudgyAccessoryItem] {
        let slotOrder: [NudgyAccessoryItem.AccessorySlot] = [
            .furniture, .body, .neck, .face, .head, .held
        ]
        return equippedIDs
            .compactMap { AccessoryCatalog.item(for: $0) }
            .sorted { (slotOrder.firstIndex(of: $0.slot) ?? 999) < (slotOrder.firstIndex(of: $1.slot) ?? 999) }
    }
    
    @ViewBuilder
    private func accessoryView(for item: NudgyAccessoryItem) -> some View {
        if usePlaceholder || UIImage(named: item.imageName) == nil {
            // Placeholder: SF Symbol fallback
            Image(systemName: AccessoryCatalog.icon(for: item.id))
                .font(.system(size: item.scale * penguinSize * 0.35, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        } else {
            Image(item.imageName)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: item.scale * penguinSize, height: item.scale * penguinSize)
        }
    }
}

// MARK: - NudgySprite (Composed Character)

/// The full Nudgy character: sprite animation + accessory overlays + expression transforms.
/// Drop-in replacement for LottieNudgyView with the same init signature.
struct NudgySprite: View {
    let expression: PenguinExpression
    let size: CGFloat
    var accentColor: Color = DesignTokens.accentActive
    var equippedAccessories: Set<String> = []
    
    /// Whether artist PNGs are available. When false, falls back to PenguinMascot bezier.
    var useSpriteArt: Bool = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            // Furniture accessories render BEHIND the penguin
            AccessoryOverlay(
                equippedIDs: furnitureAccessories,
                penguinSize: size,
                usePlaceholder: !useSpriteArt
            )
            
            // The penguin character — PenguinMascot (custom bezier) via SpriteAnimator
            SpriteAnimator(
                animation: SpriteAnimation.from(expression: expression),
                size: size,
                usePlaceholder: !useSpriteArt
            )
            
            // Wearable accessories render ON TOP of the penguin
            AccessoryOverlay(
                equippedIDs: wearableAccessories,
                penguinSize: size,
                usePlaceholder: !useSpriteArt
            )
        }
        // Subtle accent glow only — all motion is handled by PenguinMascot internally
        .shadow(
            color: accentColor.opacity(0.15),
            radius: size * 0.08
        )
    }
    
    // MARK: - Accessory Filtering
    
    private var furnitureAccessories: Set<String> {
        equippedAccessories.filter { id in
            AccessoryCatalog.item(for: id)?.slot == .furniture
        }
    }
    
    private var wearableAccessories: Set<String> {
        equippedAccessories.filter { id in
            AccessoryCatalog.item(for: id)?.slot != .furniture
        }
    }
    
    // MARK: - Transform Animations
    // All motion is handled by PenguinMascot internally.
    // NudgySprite only adds a static accent glow shadow.
}

// MARK: - Preview

#Preview("NudgySprite with Accessories") {
    let equipped: Set<String> = ["scarf-blue", "beanie-red"]
    
    return ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            NudgySprite(
                expression: .idle,
                size: 240,
                equippedAccessories: equipped,
                useSpriteArt: false
            )
            
            NudgySprite(
                expression: .happy,
                size: 120,
                equippedAccessories: ["crown"],
                useSpriteArt: false
            )
        }
    }
}
