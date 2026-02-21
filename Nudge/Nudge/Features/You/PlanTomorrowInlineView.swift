//
//  PlanTomorrowInlineView.swift
//  Nudge
//
//  Inline 4-phase planning ritual — lives directly in the You page scroll.
//  No navigation, no sheet, no full-screen cover.
//
//  ADHD rationale: removing the extra navigation step (cover dismiss barrier)
//  lowers activation energy. Tap the section header, plan in place, done.
//

import SwiftUI
import SwiftData

// MARK: - Phase (file-private, mirrors PlanTomorrowView)

private enum InlinePlanPhase: Int, CaseIterable {
    case windDown      = 0
    case carryForward  = 1
    case setIntention  = 2
    case energyCheck   = 3

    var label: String {
        switch self {
        case .windDown:     return String(localized: "Wind Down")
        case .carryForward: return String(localized: "Carry Forward")
        case .setIntention: return String(localized: "One Thing")
        case .energyCheck:  return String(localized: "Energy")
        }
    }
}

// MARK: - Main View

struct PlanTomorrowInlineView: View {

    @Binding var isExpanded: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: InlinePlanPhase = .windDown
    @State private var appeared  = false

    // Phase 2 state
    @State private var keptIDs: Set<String> = []
    @State private var activeItems: [NudgeItem] = []

    // Phase 3 state
    @State private var intentionText: String = ""
    @FocusState private var intentionFocused: Bool

    // Phase 4 state
    @State private var selectedEnergy: TomorrowEnergyMode? = nil

    // Completed tasks (Phase 1)
    @State private var completedToday: [NudgeItem] = []

    var body: some View {
        VStack(spacing: 0) {
            // ── Phase progress dots ────────────────────────────────────
            phaseDots
                .padding(.top, DesignTokens.spacingMD)
                .padding(.horizontal, DesignTokens.spacingLG)

            // ── Phase content ──────────────────────────────────────────
            Group {
                switch phase {
                case .windDown:     windDownPhase
                case .carryForward: carryForwardPhase
                case .setIntention: setIntentionPhase
                case .energyCheck:  energyCheckPhase
                }
            }
            .transition(reduceMotion ? .opacity : pageTransition)
            .animation(AnimationConstants.pageTransition, value: phase)
        }
        .padding(.bottom, DesignTokens.spacingLG)
        .onAppear {
            loadData()
            withAnimation(AnimationConstants.cardAppear.delay(0.1)) { appeared = true }
        }
    }

    // MARK: - Phase Dots

    private var phaseDots: some View {
        HStack(spacing: 6) {
            ForEach(InlinePlanPhase.allCases, id: \.rawValue) { p in
                Capsule()
                    .fill(p.rawValue <= phase.rawValue
                          ? Color.white.opacity(0.85)
                          : Color.white.opacity(0.15))
                    .frame(width: p == phase ? 20 : 6, height: 4)
                    .animation(AnimationConstants.springSnappy, value: phase)
            }
            Spacer()
            Text(phase.label)
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textTertiary)
                .animation(AnimationConstants.springSnappy, value: phase)
        }
    }

    // MARK: - Phase 1: Wind Down

    private var windDownPhase: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            // Header
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                Text(String(localized: "Time to wind down."))
                    .font(AppTheme.title)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(AnimationConstants.cardAppear, value: appeared)

                Text(completedToday.isEmpty
                     ? String(localized: "Nothing marked done today — tomorrow's a fresh start.")
                     : String(localized: "You finished \(completedToday.count) \(completedToday.count == 1 ? "thing" : "things") today."))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)

            // Completed task rows
            if !completedToday.isEmpty {
                VStack(spacing: DesignTokens.spacingXS) {
                    ForEach(completedToday.prefix(6)) { item in
                        windDownRow(item)
                    }
                    if completedToday.count > 6 {
                        Text(String(localized: "… and \(completedToday.count - 6) more"))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                            .padding(.leading, DesignTokens.spacingLG)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingLG)
            }

            // CTA
            inlineCTA(
                label: completedToday.isEmpty
                    ? String(localized: "Plan anyway")
                    : String(localized: "Keep going"),
                color: DesignTokens.accentComplete
            ) { advance() }
        }
    }

    private func windDownRow(_ item: NudgeItem) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.accentComplete)
            Text(item.content)
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(1)
                .strikethrough(true, color: DesignTokens.textTertiary)
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Phase 2: Carry Forward

    private var carryForwardPhase: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                Text(String(localized: "What crosses over?"))
                    .font(AppTheme.title)
                    .foregroundStyle(DesignTokens.textPrimary)

                Text(String(localized: "Pick up to 3. Let the rest go."))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)

            if activeItems.isEmpty {
                Text(String(localized: "No active tasks — tomorrow's a blank slate."))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingMD)
            } else {
                VStack(spacing: DesignTokens.spacingXS) {
                    ForEach(activeItems.prefix(10)) { item in
                        carryForwardRow(item)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingLG)

                if keptIDs.count >= 3 {
                    Text(String(localized: "Max 3 — ruthless priorities only."))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.accentStale)
                        .padding(.horizontal, DesignTokens.spacingLG)
                }
            }

            inlineCTA(
                label: keptIDs.isEmpty
                    ? String(localized: "Start fresh")
                    : String(localized: "Carrying \(keptIDs.count) forward"),
                color: DesignTokens.accentStale
            ) { advance() }
        }
    }

    private func carryForwardRow(_ item: NudgeItem) -> some View {
        let isKept = keptIDs.contains(item.id.uuidString)
        let canAdd  = keptIDs.count < 3 || isKept

        return Button {
            guard canAdd else { return }
            HapticService.shared.actionButtonTap()
            withAnimation(AnimationConstants.springSnappy) {
                if isKept { keptIDs.remove(item.id.uuidString) }
                else       { keptIDs.insert(item.id.uuidString) }
            }
        } label: {
            HStack(spacing: DesignTokens.spacingMD) {
                ZStack {
                    Circle()
                        .stroke(isKept ? DesignTokens.accentStale : Color.white.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isKept {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DesignTokens.accentStale)
                    }
                }
                Text(item.content)
                    .font(AppTheme.caption)
                    .foregroundStyle(canAdd ? DesignTokens.textPrimary : DesignTokens.textTertiary)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(isKept ? DesignTokens.accentStale.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .strokeBorder(isKept ? DesignTokens.accentStale.opacity(0.4) : Color.clear, lineWidth: 1)
                    }
            )
            .animation(AnimationConstants.springSnappy, value: isKept)
        }
        .buttonStyle(.plain)
        .disabled(!canAdd)
    }

    // MARK: - Phase 3: Set Intention

    private var setIntentionPhase: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                Text(String(localized: "One thing."))
                    .font(AppTheme.title)
                    .foregroundStyle(DesignTokens.textPrimary)
                Text(String(localized: "What makes tomorrow a win?"))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)

            // Quick-pick from carry-forwards
            if !keptIDs.isEmpty {
                let carryItems = activeItems.filter { keptIDs.contains($0.id.uuidString) }
                if !carryItems.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                        ForEach(carryItems) { item in
                            Button {
                                HapticService.shared.actionButtonTap()
                                withAnimation(AnimationConstants.springSnappy) {
                                    intentionText = item.content
                                }
                            } label: {
                                HStack(spacing: DesignTokens.spacingSM) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(DesignTokens.accentActive)
                                    Text(item.content)
                                        .font(AppTheme.caption)
                                        .foregroundStyle(intentionText == item.content
                                                         ? DesignTokens.accentActive
                                                         : DesignTokens.textPrimary)
                                        .lineLimit(2)
                                    Spacer()
                                    if intentionText == item.content {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(DesignTokens.accentActive)
                                    }
                                }
                                .padding(.horizontal, DesignTokens.spacingMD)
                                .padding(.vertical, DesignTokens.spacingSM)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                        .fill(intentionText == item.content
                                              ? DesignTokens.accentActive.opacity(0.10)
                                              : Color.white.opacity(0.04))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                                .strokeBorder(intentionText == item.content
                                                              ? DesignTokens.accentActive.opacity(0.4)
                                                              : Color.clear, lineWidth: 1)
                                        }
                                )
                                .animation(AnimationConstants.springSnappy, value: intentionText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                }
            }

            // Free-text entry
            TextField(String(localized: "Tomorrow I will…"), text: $intentionText, axis: .vertical)
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textPrimary)
                .tint(DesignTokens.accentActive)
                .lineLimit(3)
                .submitLabel(.done)
                .focused($intentionFocused)
                .padding(DesignTokens.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(Color.white.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                .strokeBorder(intentionFocused
                                              ? DesignTokens.accentActive.opacity(0.6)
                                              : Color.white.opacity(0.10), lineWidth: 1)
                        }
                )
                .padding(.horizontal, DesignTokens.spacingLG)
                .animation(AnimationConstants.springSnappy, value: intentionFocused)

            inlineCTA(
                label: String(localized: "That's my intention"),
                color: DesignTokens.accentActive,
                enabled: !intentionText.trimmingCharacters(in: .whitespaces).isEmpty
            ) { advance() }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Phase 4: Energy Check

    private var energyCheckPhase: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                Text(String(localized: "How does tomorrow feel?"))
                    .font(AppTheme.title)
                    .foregroundStyle(DesignTokens.textPrimary)
                Text(String(localized: "Pick a headspace — not a schedule."))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)

            VStack(spacing: DesignTokens.spacingXS) {
                ForEach(TomorrowEnergyMode.allCases, id: \.rawValue) { mode in
                    energyRow(mode)
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)

            inlineCTA(
                label: String(localized: "Lock it in"),
                color: selectedEnergy?.accentColor ?? DesignTokens.accentActive,
                enabled: selectedEnergy != nil
            ) { advance() }
        }
    }

    private func energyRow(_ mode: TomorrowEnergyMode) -> some View {
        let isSelected = selectedEnergy == mode
        return Button {
            HapticService.shared.actionButtonTap()
            withAnimation(AnimationConstants.springSnappy) { selectedEnergy = mode }
        } label: {
            HStack(spacing: DesignTokens.spacingMD) {
                ZStack {
                    Circle()
                        .fill(mode.accentColor.opacity(isSelected ? 0.2 : 0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: mode.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(mode.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label)
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? mode.accentColor : DesignTokens.textPrimary)
                    Text(mode.subtitle)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(mode.accentColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(isSelected ? mode.accentColor.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .strokeBorder(isSelected ? mode.accentColor.opacity(0.5) : Color.white.opacity(0.08),
                                          lineWidth: isSelected ? 1.5 : 0.5)
                    }
            )
            .animation(AnimationConstants.springSnappy, value: isSelected)
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: "\(mode.label). \(mode.subtitle)",
            hint: String(localized: "Select this energy mode for tomorrow"),
            traits: .isButton
        )
    }

    // MARK: - Reusable inline CTA

    private func inlineCTA(label: String, color: Color, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(enabled ? .black : DesignTokens.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                        .fill(enabled ? color : Color.white.opacity(0.10))
                )
        }
        .disabled(!enabled)
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.top, DesignTokens.spacingXS)
        .animation(AnimationConstants.springSnappy, value: enabled)
        .nudgeAccessibility(label: label, hint: String(localized: "Continue to next step"), traits: .isButton)
    }

    // MARK: - Helpers

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 28, y: 0)),
            removal:   .opacity.combined(with: .offset(x: -28, y: 0))
        )
    }

    private func loadData() {
        let repo = NudgeRepository(modelContext: modelContext)
        completedToday = repo.fetchCompletedToday()
        activeItems    = repo.fetchActiveQueue()
    }

    private func advance() {
        HapticService.shared.actionButtonTap()
        withAnimation(AnimationConstants.pageTransition) {
            switch phase {
            case .windDown:
                phase = .carryForward
            case .carryForward:
                phase = .setIntention
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    intentionFocused = true
                }
            case .setIntention:
                intentionFocused = false
                phase = .energyCheck
            case .energyCheck:
                commitPlan()
            }
        }
    }

    private func commitPlan() {
        guard let energy = selectedEnergy else { return }
        TomorrowPlanStore.shared.savePlan(
            intention: intentionText.trimmingCharacters(in: .whitespaces),
            energy: energy,
            carryForwardIDs: Array(keptIDs)
        )
        HapticService.shared.swipeDone()
        withAnimation(AnimationConstants.springSmooth) {
            isExpanded = false
        }
    }
}
