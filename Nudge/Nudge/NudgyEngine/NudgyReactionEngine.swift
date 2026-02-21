//
//  NudgyReactionEngine.swift
//  Nudge
//
//  Phase 13: Smart reactions to user actions.
//  Handles completion celebrations, snooze reassurance, tap Easter eggs,
//  and greeting flows. Uses the two-tier pattern: curated instant + AI upgrade.
//

import Foundation

// MARK: - NudgyReactionEngine

/// Coordinates Nudgy's reactions to user actions.
/// Uses the two-tier pattern: show curated instantly, upgrade with AI async.
@MainActor
final class NudgyReactionEngine {
    
    static let shared = NudgyReactionEngine()
    private let dialogue = NudgyDialogueEngine.shared
    
    private init() {}
    
    // MARK: - Completion Reaction
    
    /// React to a task being completed. Returns (instant, asyncUpgrade).
    func completionReaction(
        taskContent: String?,
        remainingCount: Int,
        categoryLabel: String? = nil,
        onUpgrade: @escaping @MainActor (String) -> Void
    ) -> String {
        // Use category-specific instant reaction when available
        let instant: String
        if let cat = categoryLabel {
            instant = categoryCompletionReaction(category: cat, remainingCount: remainingCount)
        } else {
            instant = dialogue.curatedCompletionReaction(remainingCount: remainingCount)
        }
        
        // Fire AI upgrade in background
        if let content = taskContent, NudgyConfig.isAvailable {
            Task {
                let smart = await dialogue.smartCompletionReaction(
                    taskContent: content,
                    remainingCount: remainingCount
                )
                if smart != instant {
                    onUpgrade(smart)
                }
            }
        }
        
        return instant
    }
    
    // MARK: - Category Completion Reactions
    
    /// Category-aware instant reactions — Pooh-voiced, mode-aware.
    private func categoryCompletionReaction(category: String, remainingCount: Int) -> String {
        let mode = dialogue.activePersonalityMode
        
        // Quiet mode — always minimal, regardless of category
        if mode == .quiet {
            return remainingCount == 0 ? "all done. 💙" : "done. 🐧"
        }
        
        let lower = category.lowercased()
        let reactions: [String]
        
        switch (lower, mode) {
        // Coach mode — brief, action-forward, still warm
        case ("health", .coach):    reactions = ["Health task done. What's next? 💊", "Good. Taking care of yourself first 🩺"]
        case ("exercise", .coach):  reactions = ["Moved today. That counts. What's next? 💪", "Exercise done. Momentum 🐧"]
        case ("cooking", .coach):   reactions = ["Fed. Good. What else? 🍳", "Kitchen handled. Next? 🐧"]
        case ("cleaning", .coach):  reactions = ["Clean. Good. What's the next move? 🧹", "Sorted. What's next? 🐧"]
        case ("finance", .coach):   reactions = ["Money thing handled. One less worry 💰", "Finance done. What's next? 📊"]
        case ("work", .coach):      reactions = ["Work task done. Good. Next one? 💼", "That's off the plate. Keep going 🐧"]
        case ("study", .coach):     reactions = ["Study done. Good session. What's next? 📚", "Knowledge banked. Next? 🐧"]
        case ("errand", .coach):    reactions = ["Errand done. One less trip. What's next? 🐧", "Sorted. What else is on the list? 💙"]
        case ("social", .coach):    reactions = ["Connection made. Good. What's next? 💬", "People stuff done. Next? 🐧"]
        case (_, .coach):           reactions = ["Done. What's the next thing? 🐧", "Good. Keep going 💙"]
        
        // Silly mode — penguin chaos, still warm underneath
        case ("health", .silly):    reactions = ["*prescribes fish for everything* health thing done! 🐟", "body says thank you. I said you're welcome. we had a moment 💊"]
        case ("exercise", .silly):  reactions = ["you exercised! I waddled in solidarity. we're both athletes 🐧", "*wheezes supportively from the iceberg* you moved! 💪"]
        case ("cooking", .silly):   reactions = ["*sniffs air* oh, you cooked. I'm still on a raw fish diet myself 🐟", "kitchen survived! probably! 🍳"]
        case ("cleaning", .silly):  reactions = ["spotless! well, I assume. penguins can't tell 🐧", "so clean I can see my reflection. handsome bird 🫧"]
        case ("finance", .silly):   reactions = ["money thing done! I would help but I have no pockets 💰", "*counts imaginary fish-coins* financial penguin approves 🐧"]
        case ("work", .silly):      reactions = ["work thing done. in penguin circles that's called 'a big fish' 🐟", "*stamps flipper of approval* professional penguin energy 💼"]
        case ("study", .silly):     reactions = ["*adjusts imaginary glasses* ah yes. knowledge. I have some too. mostly about fish 📚", "brain got bigger! mine stayed the same. typical 🐧"]
        case (_, .silly):           reactions = ["*victory waddle* done!! 🐧", "I tried to do a dance but I fell over. you did great though 💙"]
        
        // Gentle mode (default) — Pooh-voiced
        case ("health", _):    reactions = ["Oh. That's you taking care of yourself. …Good 💊", "Hmm. Health thing sorted. …That matters 🐧"]
        case ("exercise", _):  reactions = ["You moved today. …That's a good thing, I think 💙", "Exercise done. …The body remembers, even if you forget 🐧"]
        case ("cooking", _):   reactions = ["Something got cooked. …That's a small act of love, really 🍳", "Fed. …Penguins understand the importance of eating 🐧"]
        case ("cleaning", _):  reactions = ["*looks around* …That feels better, doesn't it ✨", "Clean. …There's something quiet and nice about that 🫧"]
        case ("fix & build", _): reactions = ["Fixed. …Things that work are a kind of peace 🔧", "Hmm. Sorted. …I admire anyone who can hold a screwdriver. Flippers, you see 🐧"]
        case ("finance", _):   reactions = ["Money thing handled. …One less to carry 💙", "Hmm. That's a weight off. …Finances are heavy things 🐧"]
        case ("work", _):      reactions = ["Work thing done. …One less to carry 💼", "Hmm. That took something. …But it's done now 🐧"]
        case ("study", _):     reactions = ["Study thing finished. …You're learning. That's rather nice 📚", "Hmm. …Your brain is doing well, I think 🐧"]
        case ("errand", _):    reactions = ["Errand done. …One less trip to think about 🐧", "That's sorted. …Errands are small adventures, in a way 💙"]
        case ("social", _):    reactions = ["You reached out. …That takes something. Well done 💬", "People thing done. …Connection matters 💙"]
        case ("self-care", _): reactions = ["You chose yourself. …That's not small. That's big 💙", "Self-care. …Penguins call that 'sitting on warm ice'. Very important 🐧"]
        case ("shopping", _):  reactions = ["Shopping done. …One less list in your head 🐧", "Hmm. Got what you needed. …That's a relief 💙"]
        case ("appointment", _): reactions = ["You showed up. …That's the hardest part, and you did it 📋", "Appointment done. …One less thing on the calendar 💙"]
        case ("creative", _):  reactions = ["You made something. …I find that rather wonderful 🎨", "Creative thing done. …The world has a bit more in it now ✨"]
        default:               reactions = ["Hmm. Done. …One less thing to carry 🐧", "*quiet nod* …That's good 💙", "Well, now. That's done ✨"]
        }
        
        let base = reactions.randomElement() ?? "Done 🐧"
        
        if remainingCount == 0 {
            return "Everything's done. …\(base)"
        }
        return base
    }
    
    // MARK: - Snooze Reaction
    
    /// React to a task being snoozed. Returns (instant, asyncUpgrade).
    func snoozeReaction(
        taskContent: String?,
        onUpgrade: @escaping @MainActor (String) -> Void
    ) -> String {
        let instant = dialogue.curatedSnoozeReaction()
        
        if let content = taskContent, NudgyConfig.isAvailable {
            Task {
                let smart = await dialogue.smartSnoozeReaction(taskContent: content)
                if smart != instant {
                    onUpgrade(smart)
                }
            }
        }
        
        return instant
    }
    
    // MARK: - Tap Reaction
    
    /// React to being tapped. Returns (instant, asyncUpgrade).
    func tapReaction(
        tapCount: Int,
        onUpgrade: @escaping @MainActor (String) -> Void
    ) -> String {
        let instant = dialogue.curatedTapReaction(tapCount: tapCount)
        
        if NudgyConfig.isAvailable {
            let count = tapCount
            Task {
                let smart = await dialogue.smartTapReaction(tapCount: count)
                if smart != instant {
                    onUpgrade(smart)
                }
            }
        }
        
        return instant
    }
    
    // MARK: - Greeting Flow
    
    /// Show a smart greeting. Returns (instant, asyncUpgrade).
    func greeting(
        userName: String?,
        activeTaskCount: Int,
        topCategory: (label: String, emoji: String, count: Int)? = nil,
        onUpgrade: @escaping @MainActor (String) -> Void
    ) -> String {
        // Check memory for user name
        let name = userName ?? NudgyMemory.shared.userName
        let instant = dialogue.curatedGreeting(userName: name, activeTaskCount: activeTaskCount, topCategory: topCategory)
        
        if NudgyConfig.isAvailable {
            Task {
                let smart = await dialogue.smartGreeting(
                    userName: name,
                    activeTaskCount: activeTaskCount
                )
                if smart != instant {
                    onUpgrade(smart)
                }
            }
        }
        
        return instant
    }
    
    // MARK: - Task Presentation
    
    /// Present a task with two-tier dialogue.
    func taskPresentation(
        content: String,
        position: Int,
        total: Int,
        isStale: Bool,
        isOverdue: Bool,
        onUpgrade: @escaping @MainActor (String) -> Void
    ) -> String {
        let instant = dialogue.curatedTaskPresentation(
            content: content, position: position, total: total,
            isStale: isStale, isOverdue: isOverdue
        )
        
        if NudgyConfig.isAvailable {
            Task {
                let smart = await dialogue.smartTaskPresentation(
                    content: content, position: position, total: total,
                    isStale: isStale, isOverdue: isOverdue
                )
                if smart != instant {
                    onUpgrade(smart)
                }
            }
        }
        
        return instant
    }
    
    // MARK: - Idle Chatter
    
    /// Generate idle chatter (async only, no instant version).
    func idleChatter(currentTask: String?, activeCount: Int) async -> String {
        await dialogue.smartIdleChatter(currentTask: currentTask, activeCount: activeCount)
    }
    
    // MARK: - Brain Dump
    
    func brainDumpStart() -> String { dialogue.brainDumpStart() }
    func brainDumpProcessing() -> String { dialogue.brainDumpProcessing() }
    func brainDumpComplete(taskCount: Int) -> String { dialogue.brainDumpComplete(taskCount: taskCount) }
}
