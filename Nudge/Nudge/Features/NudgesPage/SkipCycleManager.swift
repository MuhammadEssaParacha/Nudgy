//
//  SkipCycleManager.swift
//  Nudge
//
//  Tracks skip/cycle behavior on the hero card.
//  After 3 consecutive skips, detects decision paralysis and
//  offers intervention: "Quick Catch" (easiest task) or Brain Dump.
//
//  ADHD research: "rolling dice for to-do list" (255 upvotes r/ADHD)
//  Breaking paralysis requires lowering the bar, not adding more options.
//

import SwiftUI

@MainActor @Observable
final class SkipCycleManager {
    
    private(set) var skipCount: Int = 0
    private(set) var skippedIDs: Set<UUID> = []
    private(set) var showParalysisPrompt = false
    
    /// The previous bounty (for contrast display on skip)
    private(set) var previousBountyValue: Int?
    private(set) var previousSpecies: FishSpecies?
    
    // MARK: - Skip Threshold
    
    private let paralysisThreshold = 3
    
    // MARK: - Record Skip
    
    /// Call when user taps "Not this one" or swipes to skip
    func recordSkip(item: NudgeItem, streak: Int) {
        skippedIDs.insert(item.id)
        skipCount += 1
        
        // Store previous bounty for contrast
        let species = FishEconomy.speciesForTask(item)
        previousSpecies = species
        previousBountyValue = FishEconomy.fishForCatch(
            species: species,
            streak: streak,
            isAllClear: false
        )
        
        // Check paralysis threshold
        if skipCount >= paralysisThreshold {
            showParalysisPrompt = true
        }
    }
    
    /// Reset when user completes a task (breaking the skip cycle)
    func recordCompletion() {
        skipCount = 0
        skippedIDs.removeAll()
        showParalysisPrompt = false
        previousBountyValue = nil
        previousSpecies = nil
    }
    
    /// Dismiss the paralysis prompt without acting
    func dismissParalysisPrompt() {
        showParalysisPrompt = false
        // Reset count so it can trigger again after 3 more skips
        skipCount = 0
    }
    
    /// Pick the easiest task (shortest estimated time or lowest energy)
    func findQuickCatch(from items: [NudgeItem]) -> NudgeItem? {
        // Exclude already-skipped items for variety
        let candidates = items.filter { !skippedIDs.contains($0.id) }
        
        // Prefer items with short estimated time
        let sorted = (candidates.isEmpty ? items : candidates).sorted { a, b in
            let aMinutes = a.estimatedMinutes ?? 30 // Default to 30 if unknown
            let bMinutes = b.estimatedMinutes ?? 30
            
            // Shortest first
            if aMinutes != bMinutes { return aMinutes < bMinutes }
            
            // Then lowest energy
            let aEnergy = a.energyLevel?.sortWeight ?? 1
            let bEnergy = b.energyLevel?.sortWeight ?? 1
            return aEnergy > bEnergy // .low has weight 2 > .high weight 0
        }
        
        return sorted.first
    }
}

/// Extension to get sortWeight for energy-based sorting
private extension EnergyLevel {
    var sortWeight: Int {
        switch self {
        case .low:    return 2
        case .medium: return 1
        case .high:   return 0
        }
    }
}
