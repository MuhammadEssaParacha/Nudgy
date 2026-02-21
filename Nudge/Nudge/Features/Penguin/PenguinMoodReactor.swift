//
//  PenguinMoodReactor.swift
//  Nudge
//
//  Drives Nudgy's expression and idle behavior based on the environment state.
//
//  The reactor listens to RewardService and maps environment mood + time of day
//  + streak + recent activity into penguin expressions and periodic reactions.
//
//  Mood → Expression mapping:
//    .cold       → .idle (with occasional shiver)
//    .warming    → .idle → .happy (transition)
//    .productive → .happy / .nudging (proactive)
//    .golden     → .celebrating (dance!)
//    .stormy     → .confused / .worried
//
//  The reactor also triggers contextual micro-animations:
//    - Nudgy shivers in cold weather (night + cold mood)
//    - Nudgy looks at the fish bucket when fish count changes
//    - Nudgy celebrates when a streak milestone is hit
//    - Nudgy sleeps when idle for too long at night
//

import SwiftUI

// MARK: - Penguin Mood Reactor

@Observable
final class PenguinMoodReactor {
    static let shared = PenguinMoodReactor()

    /// The recommended expression based on current state.
    private(set) var recommendedExpression: PenguinExpression = .idle

    /// Whether the penguin should show a shiver animation.
    private(set) var isShivering = false

    /// Whether the penguin should show a sleeping z-bubble.
    private(set) var isSleeping = false

    /// Micro-reaction text (short bubble that appears briefly).
    private(set) var microReaction: String?

    private var lastMood: EnvironmentMood = .cold
    private var lastStreak: Int = 0
    private var lastFishCount: Int = 0
    private var lastInteraction: Date = .now
    private var idleTimer: Timer?

    private init() {}

    // MARK: - Update

    /// Call this periodically (e.g., in a TimelineView or onChange) to update
    /// the penguin's mood-reactive state.
    func update(
        mood: EnvironmentMood,
        timeOfDay: AntarcticTimeOfDay,
        streak: Int,
        fishCount: Int,
        tasksToday: Int,
        isUserActive: Bool
    ) {
        // Track last interaction
        if isUserActive {
            lastInteraction = .now
            isSleeping = false
        }

        // Mood → expression mapping
        let newExpression = expression(for: mood, time: timeOfDay, isActive: isUserActive)
        if newExpression != recommendedExpression {
            recommendedExpression = newExpression
        }

        // Shiver in cold (night + cold mood)
        isShivering = (mood == .cold && (timeOfDay == .night || timeOfDay == .dusk))

        // Sleep check: idle for 5+ minutes at night
        if timeOfDay == .night && !isUserActive {
            let idleMinutes = Date.now.timeIntervalSince(lastInteraction) / 60
            if idleMinutes >= 5 {
                isSleeping = true
                recommendedExpression = .sleeping
            }
        }

        // Micro-reactions to state changes
        checkMicroReactions(mood: mood, streak: streak, fishCount: fishCount, tasksToday: tasksToday)

        // Update tracking
        lastMood = mood
        lastStreak = streak
        lastFishCount = fishCount
    }

    // MARK: - Expression Mapping

    private func expression(for mood: EnvironmentMood, time: AntarcticTimeOfDay, isActive: Bool) -> PenguinExpression {
        if isSleeping { return .sleeping }

        switch mood {
        case .cold:
            return time == .night ? .sleeping : .idle
        case .warming:
            return .idle
        case .productive:
            return .happy
        case .golden:
            return .celebrating
        case .stormy:
            return .confused
        }
    }

    // MARK: - Micro-Reactions

    private func checkMicroReactions(mood: EnvironmentMood, streak: Int, fishCount: Int, tasksToday: Int) {
        // Mood transition reactions
        if mood != lastMood {
            switch (lastMood, mood) {
            case (.cold, .warming):
                microReaction = moodTransitionLines.coldToWarming.randomElement()
            case (.warming, .productive):
                microReaction = moodTransitionLines.warmingToProductive.randomElement()
            case (.productive, .golden):
                microReaction = moodTransitionLines.productiveToGolden.randomElement()
            case (_, .stormy):
                microReaction = moodTransitionLines.anyToStormy.randomElement()
            default:
                break
            }
        }

        // Streak milestone reactions
        if streak > lastStreak && streak > 0 {
            if streak == 3 {
                microReaction = "🔥 3-day streak! You're on fire!"
            } else if streak == 7 {
                microReaction = "🔥🔥 7-day streak! Legendary!"
            } else if streak == 14 {
                microReaction = "🔥🔥🔥 14 DAYS! You're unstoppable!"
            } else if streak == 30 {
                microReaction = "👑 30-day streak. You are a KING."
            }
        }

        // Fish milestone reactions
        if fishCount > lastFishCount {
            let gained = fishCount - lastFishCount
            if fishCount >= 100 && lastFishCount < 100 {
                microReaction = "🐟 100 fish! The bucket overflows!"
            } else if fishCount >= 50 && lastFishCount < 50 {
                microReaction = "🐟 50 fish! That's a full bucket!"
            } else if gained >= 5 {
                microReaction = "🐟 Nice haul! +\(gained) fish!"
            }
        }

        // Clear micro-reaction after a delay
        if microReaction != nil {
            Task {
                try? await Task.sleep(for: .seconds(4.0))
                self.microReaction = nil
            }
        }
    }

    /// Acknowledge user interaction (resets idle timer).
    func userDidInteract() {
        lastInteraction = .now
        isSleeping = false
    }
}

// MARK: - Mood Transition Lines

private struct moodTransitionLines {
    static let coldToWarming = [
        "Brrr... oh wait, things are warming up! 🌅",
        "Is that... productivity I sense? Let's go!",
        "The ice is thawing! One task at a time 💪",
    ]

    static let warmingToProductive = [
        "Now we're cooking! The aurora's coming out! ✨",
        "Look at you go! The mountains are glowing! 🏔️",
        "Productive mode: ACTIVATED 🐧💨",
    ]

    static let productiveToGolden = [
        "GOLDEN HOUR! You've cleared everything! 🌅✨",
        "The cliff has never looked this beautiful! 🎉",
        "Everything done! Time to celebrate! 🐧🎊",
    ]

    static let anyToStormy = [
        "Uh oh... storm clouds. Some tasks need attention ⛈️",
        "It's getting stormy... let's tackle those overdue tasks",
        "The wind's picking up — time to check those stale tasks 🌬️",
    ]
}

// MARK: - Shiver Effect Modifier

/// A view modifier that adds a subtle shiver animation to the penguin.
struct ShiverEffect: ViewModifier {
    let isActive: Bool
    @State private var shiverOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: isActive ? shiverOffset : 0)
            .onAppear {
                guard isActive else { return }
                startShiver()
            }
            .onChange(of: isActive) { _, active in
                if active { startShiver() } else { shiverOffset = 0 }
            }
    }

    private func startShiver() {
        withAnimation(
            .easeInOut(duration: 0.08)
            .repeatForever(autoreverses: true)
        ) {
            shiverOffset = 1.5
        }
    }
}

extension View {
    func shiverEffect(_ isActive: Bool) -> some View {
        modifier(ShiverEffect(isActive: isActive))
    }
}

// MARK: - Sleep Bubble

/// Floating "Z" bubbles that appear when Nudgy is sleeping.
struct SleepBubble: View {
    @State private var showZ1 = false
    @State private var showZ2 = false
    @State private var showZ3 = false

    var body: some View {
        ZStack {
            zBubble(text: "z", size: 10, show: showZ1)
                .offset(x: 20, y: -30)

            zBubble(text: "Z", size: 14, show: showZ2)
                .offset(x: 30, y: -50)

            zBubble(text: "Z", size: 18, show: showZ3)
                .offset(x: 40, y: -75)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                showZ1 = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.3)) {
                showZ2 = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.6)) {
                showZ3 = true
            }
        }
    }

    private func zBubble(text: String, size: CGFloat, show: Bool) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(DesignTokens.textTertiary.opacity(0.4))
            .opacity(show ? 1.0 : 0.0)
            .offset(y: show ? -5 : 5)
    }
}

// MARK: - Preview

#Preview("Mood Reactor States") {
    VStack(spacing: 20) {
        Text("Shivering Penguin")
            .foregroundStyle(.white)
        Circle()
            .fill(Color.blue)
            .frame(width: 80, height: 80)
            .shiverEffect(true)

        Text("Sleeping Penguin")
            .foregroundStyle(.white)
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 80, height: 80)
            SleepBubble()
        }
    }
    .background(Color.black)
}
