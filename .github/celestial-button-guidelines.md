# CelestialButton — Execution Guidelines

## Purpose
Self-reference file for clean execution of CelestialButton.swift changes.

## Verified Dependencies (all exist in codebase)
- ✅ `FishView` — `IntroVectorShapes.swift:81` — params: `size: CGFloat`, `color: Color`, `accentColor: Color`
- ✅ `LottieNudgyView` — `LottieNudgyView.swift:21` — params: `expression:`, `size:`, `accentColor:`
- ✅ `WardrobeView` — `WardrobeView.swift:15` — no required params
- ✅ `DailyChallenge` — `DailyChallenges.swift:25` — has `.id`, `.title`, `.icon`, `.bonusFish`, `.isCompleted`
- ✅ `StageTier` — `StageEvolution.swift:22` — enum with `.from(level:)`, `.displayName`
- ✅ `RewardService.shared` — `RewardService.swift:57` — `.snowflakes`, `.levelProgress`, `.level`, `.currentStreak`, `.tasksCompletedToday`, `.dailyChallenges`, `.environmentMood`
- ✅ `HapticService.shared` — `HapticService.swift:12` — `.cardAppear()`
- ✅ `DesignTokens` — `Constants.swift` — `.penguinSizeLarge=120`, `.spacingSM/MD/LG/XL/XXL`, `.cardSurface`, `.accentComplete`, `.textSecondary`, `.textTertiary`
- ✅ `AntarcticTimeOfDay` — `AntarcticEnvironment.swift:40` — `.dawn/.day/.dusk/.night`, `.current`
- ✅ `PenguinState` — environment object — `.expression`, `.accentColor`, `.chatMessages`
- ✅ `.glassEffect(.regular.interactive(), in:)` — iOS 26 API, used across 60+ views

## Fish Overlap Warning
NudgyHomeView already has:
- `ambientFishLayer` — full-screen `AmbientFishScene` behind Nudgy (up to 6 fish)
- `CompletionFishBurst` — celebratory burst on task completion

The overlay covers these with 0.92 black opacity, so ambient fish ARE hidden.
But orbiting fish in the overlay hero section must NOT feel like "more of the same."

### Decision: REMOVE orbiting fish from overlay
Rationale:
- User said "i already have fishes surrounding nudgy, i dont want it overwhelming"
- The overlay already covers the ambient fish; adding 4 more orbiting fish is redundant
- Keep the hero section clean: just Nudgy + subtle glow + stage badge
- Fish count is already shown in the stats strip as a number

## Quality Checklist
- [ ] No raw `.font()` except system design-specific uses (monospaced labels, etc.)
- [ ] All user-facing strings use `String(localized:)`
- [ ] All animations respect `reduceMotion`
- [ ] No hardcoded color literals — use DesignTokens or hex via `Color(hex:)`
- [ ] `.nudgeAccessibility()` on interactive elements
- [ ] Particle loop cancels when view disappears (avoid leaks)
- [ ] No orphaned @State vars
- [ ] Canvas uses `.allowsHitTesting(false)`

## Known Issues to Fix
1. **Orbiting fish** — Remove from hero section (user's request)
2. **Particle task leak** — `startParticleLoop()` spawns a `Task` that never cancels. Needs `task.cancel()` in `.onDisappear`
3. **`UIScreen.main.bounds`** — deprecated in iOS 16+. Use `GeometryReader` instead
4. **Dismiss animation** — uses `DispatchQueue.main.asyncAfter` instead of animation completion; acceptable but not ideal
5. **AnimatedCounter `DispatchQueue` flood** — 30 dispatches is fine for small numbers, but if `target` is 10000+, the interval gets sub-millisecond. Cap the step interval at 16ms minimum
6. **Missing `.onDisappear`** — overlay should clean up particle task
7. **Missing accessibility** — overlay dismiss area needs accessibility label

## Build Info
- Simulator: `80F84FEC-B3C7-400C-8F73-8A3D888A5A0E` (iPhone 17 Pro, iOS 26.2)
- Build: `cd "/Users/abdullahimran/Desktop/untitled folder/Nudge" && xcodebuild -scheme Nudge -destination 'platform=iOS Simulator,id=80F84FEC-B3C7-400C-8F73-8A3D888A5A0E' build 2>&1 | tail -5`
- Deploy: `xcrun simctl terminate 80F84FEC-B3C7-400C-8F73-8A3D888A5A0E com.essaparacha.nudge 2>/dev/null; xcrun simctl install 80F84FEC-B3C7-400C-8F73-8A3D888A5A0E ~/Library/Developer/Xcode/DerivedData/Nudge-hiursflqkxedchggqbbxpgjdebru/Build/Products/Debug-iphonesimulator/Nudge.app && xcrun simctl launch 80F84FEC-B3C7-400C-8F73-8A3D888A5A0E com.essaparacha.nudge -skipAuth -seedTasks`
