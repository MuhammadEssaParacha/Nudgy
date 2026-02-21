//
//  NudgyIdleActions.swift
//  Nudge
//
//  Random ambient micro-animations for Nudgy when idle.
//
//  Every 15–30 seconds (when in ambient mode), Nudgy does a random action:
//    - Look around (eyes shift left/right)
//    - Scratch head (thinking expression briefly)
//    - Yawn (sleeping expression flicker)
//    - Excited hop (happy expression + bounce)
//    - Play with fish (celebrating + micro-reaction)
//    - Adjust beanie (if wardrobe equipped)
//
//  The engine updates PenguinState expressions briefly, then returns to idle.
//  It cooperates with PenguinMoodReactor — only fires when interactionMode == .ambient.
//

import SwiftUI
import Combine

// MARK: - Idle Action Type

nonisolated enum IdleAction: CaseIterable, Sendable {
    case lookAround
    case scratchHead
    case yawn
    case excitedHop
    case playWithFish
    case wave
}

// MARK: - Nudgy Idle Actions Engine

@Observable
final class NudgyIdleActions {
    static let shared = NudgyIdleActions()

    /// Whether the idle action system is running.
    private(set) var isRunning = false

    /// The current micro-reaction text (if any).
    private(set) var idleReaction: String?

    /// Whether Nudgy is mid-hop (for view bounce animation).
    private(set) var isHopping = false

    /// The last idle action performed (for animation coordination).
    private(set) var lastAction: IdleAction?

    private var timer: Timer?
    private var penguinState: PenguinState?

    private init() {}

    // MARK: - Start / Stop

    /// Begin the idle action loop. Pass the penguin state to animate.
    func start(penguinState: PenguinState) {
        guard !isRunning else { return }
        self.penguinState = penguinState
        isRunning = true
        scheduleNext()
    }

    /// Stop the idle action loop.
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        idleReaction = nil
        isHopping = false
    }

    // MARK: - Scheduling

    private func scheduleNext() {
        guard isRunning else { return }
        let delay = Double.random(in: 5...15)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.performRandomAction()
        }
    }

    // MARK: - Action Execution

    private func performRandomAction() {
        guard isRunning,
              let penguinState,
              penguinState.interactionMode == .ambient else {
            scheduleNext()
            return
        }

        let action = IdleAction.allCases.randomElement() ?? .lookAround
        lastAction = action

        switch action {
        case .lookAround:
            performLookAround(penguinState)
        case .scratchHead:
            performScratchHead(penguinState)
        case .yawn:
            performYawn(penguinState)
        case .excitedHop:
            performExcitedHop(penguinState)
        case .playWithFish:
            performPlayWithFish(penguinState)
        case .wave:
            performWave(penguinState)
        }

        // Schedule next action after this one completes
        Task {
            try? await Task.sleep(for: .seconds(3.0))
            self.scheduleNext()
        }
    }

    // MARK: - Individual Actions

    private func performLookAround(_ state: PenguinState) {
        state.expression = .nudging

        Task {
            try? await Task.sleep(for: .seconds(2.0))
            state.expression = .idle
            self.clearReaction()
        }
    }

    private func performScratchHead(_ state: PenguinState) {
        state.expression = .thinking

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            state.expression = .idle
            self.clearReaction()
        }
    }

    private func performYawn(_ state: PenguinState) {
        state.expression = .sleeping

        Task {
            try? await Task.sleep(for: .seconds(2.0))
            state.expression = .idle
            self.clearReaction()
        }
    }

    private func performExcitedHop(_ state: PenguinState) {
        state.expression = .happy
        HapticService.shared.prepare()

        Task {
            try? await Task.sleep(for: .seconds(1.2))
            state.expression = .idle
            let _ = self // prevent warning
        }
    }

    private func performPlayWithFish(_ state: PenguinState) {
        state.expression = .celebrating
        HapticService.shared.prepare()

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            state.expression = .happy
            self.clearReaction()
            try? await Task.sleep(for: .seconds(0.5))
            state.expression = .idle
        }
    }

    private func performWave(_ state: PenguinState) {
        state.expression = .waving
        HapticService.shared.prepare()

        Task {
            try? await Task.sleep(for: .seconds(2.0))
            state.expression = .idle
            self.clearReaction()
        }
    }

    // MARK: - Helpers

    private func clearReaction() {
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            self.idleReaction = nil
        }
    }
}

// MARK: - Hop Modifier

/// Applies a springy hop bounce to the penguin during idle excited hops.
struct IdleHopModifier: ViewModifier {
    let isHopping: Bool
    @State private var bounce: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: bounce)
            .onChange(of: isHopping) { _, hopping in
                if hopping {
                    // Quick hop up
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
                        bounce = -14
                    }
                    // Settle back
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.25))
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            bounce = 0
                        }
                    }
                }
            }
    }
}

extension View {
    func idleHop(_ isHopping: Bool) -> some View {
        modifier(IdleHopModifier(isHopping: isHopping))
    }
}
