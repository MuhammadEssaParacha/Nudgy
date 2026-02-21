# Nudge — Copilot Instructions

> **Owner:** Essa Paracha (@MuhammadEssaParacha)
> **Bundle ID:** `com.essaparacha.nudge`
> **App Group:** `group.com.essaparacha.nudge`
> **iCloud Container:** `iCloud.com.essaparacha.nudge`
> **Repo:** github.com/MuhammadEssaParacha/Nudgy

---

## Product Intent
iOS 26+ SwiftUI app for ADHD-friendly task management. Core UX: **one card at a time** — avoid lists when a single card view will do. A conversational AI penguin companion named **Nudgy** that understands ADHD patterns.

## Architecture Overview

**Targets:** `Nudge` (main), `NudgeShareExtension`, `NudgeWidgetExtension` (Live Activity + Home Screen), `NudgeWatchApp`, `NudgeTests`, `NudgeUITests`. All share data via App Group `group.com.essaparacha.nudge`.

**App lifecycle (NudgeApp.swift):** 4-tier routing: Intro → Auth → Onboarding → ContentView. `ModelContainer` is **nil until auth completes** (per-user store: `nudge_{userID}.store` in App Group). Falls back to in-memory on corruption. On foreground: resets daily counters, ingests share extension items, resurfaces expired snoozes, schedules notifications, syncs CloudKit.

**Key services** are singletons (`HapticService.shared`, `AIService.shared`, `SoundService.shared`, etc.). **Exception:** `NudgeRepository` is NOT a singleton — instantiated per-use from a `ModelContext`.

**Environment injection at root:** `AppSettings`, `AccentColorSystem`, `PenguinState`, `AuthSession` — all `@Observable`, injected via `.environment()`. `modelContainer` is injected only after auth, not at root.

## Project Structure

```
Nudgy/
├── Nudge/Nudge.xcodeproj         # Xcode project
├── Nudge/Nudge/                  # Main app target (203 Swift files)
│   ├── NudgeApp.swift            # Entry point (1,055 lines)
│   ├── ContentView.swift         # 3-tab router (~310 lines)
│   ├── Core/                     # Logger, Constants, Theme, Accessibility (27 files)
│   ├── Models/                   # NudgeItem, AppSettings, etc. (8 files)
│   ├── Features/                 # 24 feature modules (see below)
│   ├── Services/                 # 42 service files
│   └── NudgyEngine/              # AI brain (16 files)
├── Nudge/NudgeWidgetExtension/   # Widgets + Live Activity (3 files)
├── Nudge/NudgeShareExtension/    # Share sheet (2 files)
├── Nudge/NudgeWatchApp/          # Watch companion (1 file)
├── lottie_downloads/             # 6 penguin Lottie animations
├── .github/workflows/ci.yml     # CI pipeline
└── Secrets.xcconfig              # API keys (GITIGNORED)
```

### Feature Modules (Nudge/Features/)
AllItems, Aquarium, BrainDump, Browser, CaptureBar, Categories, DailyReview, FocusTimer, Inbox, LiveActivity, MoodCheckIn, Nudges, NudgesPage, Onboarding, OneThing, Penguin, Persona, QuickAdd, Routines, Settings, Snooze, Timeline, You

### Key Services (Nudge/Services/)
CloudKitManager, CloudKitSyncEngine, NudgeRepository, AIService, ActionService, WidgetDataService, HealthService, HandoffService, SpeechService, RoutineService, SpotlightIndexer, LocationService, FishEconomy, SmartPickEngine, NotificationService, PurchaseService, HapticService, SoundService, DraftService, EnergyScheduler, ProactiveNudgyService, RewardService, MilestoneService, SuggestionChipEngine, and AppIntents (6 files)

### NudgyEngine (AI Brain — 16 files)
NudgyEngine, NudgyConfig, NudgyConversationManager, NudgyDialogueEngine, NudgyLLMService, NudgyPersonality, NudgyEmotionMapper, NudgyReactionEngine, NudgyMemory, NudgyStateAdapter, NudgyTaskExtractor, NudgyToolDefinitions, NudgyToolExecutor, NudgyVoiceOutput, NudgyADHDKnowledge, ConversationStore

## Data Layer (SwiftData)

- **Models:** `NudgeItem`, `BrainDump` (1-to-many), `NudgyWardrobe`, `Routine`, `MoodEntry`. Schema includes all five.
- **Views never touch ModelContext directly** — always go through `NudgeRepository(modelContext:)`.
- **Enum storage:** Models store enums as raw strings (`statusRaw`, `actionTypeRaw`). `#Predicate` must compare raw strings:
  ```swift
  // ✅ #Predicate<NudgeItem> { $0.statusRaw == "active" }
  // ❌ #Predicate<NudgeItem> { $0.status == .active }  — won't compile
  ```
- **⚠️ ActionType raw values are UPPERCASE** (`"CALL"`, `"TEXT"`, `"EMAIL"`, `"LINK"`); all other enums use lowercase.
- **Optional dates in predicates:** Cannot unwrap `Date?` inside `#Predicate`. Fetch broader, filter in-memory.
- **`createFromBrainDump()` does NOT call `save()`** — caller must batch-save. All other create methods auto-save.

## Auth Flow

- **3 auth methods:** Apple Sign In, email/password (local-only, SHA-256 hash in Keychain), debug bypass (`-skipAuth` launch arg).
- `AuthSession` state machine: `.checking` → `.signedOut(reason:)` | `.signedIn(UserContext)`.
- `AppSettings` scopes per-user keys with `{userID}:` prefix. Some keys (quiet hours, `hasSeenIntro`) are global.
- For two-way bindings in views: `@Bindable var settings = settings`.

## View Patterns

- **No ViewModel for most views** — work directly with `NudgeRepository` + `@State`. Only `BrainDumpView` has a dedicated `BrainDumpViewModel`.
- **Sheet presentation:** Brain dump → `.fullScreenCover`. Others → `.sheet` with `.presentationDetents([.medium])`.
- **`.preferredColorScheme(.dark)`** enforced at TabView level.
- **Deep links:** `nudge://brainDump`, `nudge://quickAdd`, `nudge://viewTask?id=`, `nudge://markDone?id=`, `nudge://snooze?id=`, `nudge://allItems`, `nudge://settings`, `nudge://chat`, `nudge://nudgy`
- **3 tabs:** `.nudgy` (penguin home), `.nudges` (task cards), `.you` (profile/settings).

## Design System

All colors from `DesignTokens` in `Nudge/Core/Constants.swift`. **Never use raw color literals.**
- Canvas: `#000000` (OLED). Cards: `#1C1C1E` @ 80% opacity + 0.5px border. Use `DarkCard` component.
- Accent colors are **status-driven**: blue=active, green=done, amber=stale(3+days), red=overdue.
- Typography: `AppTheme` static properties, not raw `.font()`.
- Spacing: 4pt grid via `DesignTokens.spacingXS/SM/MD/LG/XL/XXL/XXXL`.
- Animation: `AnimationConstants` — springs for motion, `.easeOut` for fades, never `.linear`. Respect `@Environment(\.accessibilityReduceMotion)`.
- Mark constant enums as `nonisolated` for safe cross-concurrency access.

## Accessibility

Every custom view must use helpers from `Core/Accessibility/VoiceOverHelpers.swift`:
- `.nudgeAccessibility(label:hint:traits:)`, `.nudgeAccessibilityElement(label:hint:value:)`, `.nudgeAccessibilityAction(name:action:)`.
- Use `.scaledPadding()` / `.scaledFrame()` for Dynamic Type.

## Haptics & Sound

Every interaction maps to a specific `HapticService` method — never call `UIImpactFeedbackGenerator` directly. Sound via `SoundService`. Both pre-warmed at launch. **Exception:** Share Extension creates its own feedback generator.

## AI Integration

**Dual-provider architecture:**
- **Apple Foundation Models** (on-device) via `AIService` — `@Generable` structs with `@Guide` annotations. Guarded by `#if canImport(FoundationModels)`.
- **OpenAI API** (GPT-4o-mini) via `NudgyConfig` — key from `Secrets.xcconfig` → `Info.plist`. Conversation temp 0.85, extraction temp 0.3, max 500 tokens.
- **Voice:** OpenAI TTS (echo voice), pitch 0.92, rate 0.82, speed 0.87.
- **Memory:** 30 context turns, auto-summarize after 20, 50 stored conversations, 30-day retention.
- **Personality:** Max 50 words / 3 sentences, idle chatter every 45-90s, max 3 per session.
- **`NudgyEngine.shared`** is the **only** AI entry point for views. Never call sub-engines directly.
- Always check `NudgyEngine.shared.isAvailable` — app must work fully without AI.

## Cross-Component Communication

`ContentView` is the central router. 7 `Notification.Name` values in `ActionService.swift`:

| Notification | Purpose |
|---|---|
| `.nudgeOpenBrainDump` | Present brain dump overlay |
| `.nudgeOpenQuickAdd` | Present quick-add sheet |
| `.nudgeOpenChat` | Switch to nudgy tab |
| `.nudgeComposeMessage` | Trigger SMS compose |
| `.nudgeDataChanged` | Refresh active count + Live Activity |
| `.nudgeNotificationAction` | Route push notification tap actions |
| `.nudgeNeedsContactPicker` | Contact auto-resolution failed |

## Duplicated Types — Keep in Sync

Defined in **multiple targets** (can't share between app and extensions):
- `ShareExtensionPayload` → `NudgeRepository.swift` + `ShareViewController.swift`
- `NudgeActivityAttributes`, `TimeOfDay`, `Color(hex:)` → main app + `NudgeLiveActivityWidget.swift`

## CloudKit Sync

- `CloudKitSyncEngine` handles bidirectional task sync (last-write-wins by `updatedAt`). Also syncs `NudgyMemory` as JSON blob.
- `CloudKitManager` checks entitlements before creating `CKContainer`.
- CloudKit mirroring is **disabled** (`.cloudKitDatabase: .none`) — uses own sync engine.

## Fish Economy & Gamification

- `FishEconomy` manages virtual fish currency earned by completing tasks
- Fish evolve through stages, collectible in the Aquarium
- `RewardService` + `MilestoneService` track achievements and streaks
- Penguin companion has wardrobe items, stages, and mood reactions

## Personas & Personality

- **UserPersona** (focus area): `.adhd`, `.student`, `.creative`, `.parent`, `.general` → `AppSettings.selectedPersona`
- **NudgyPersonalityMode** (tone): `.gentle`, `.coach`, `.silly`, `.quiet` → `AppSettings.nudgyPersonalityMode`
- Both influence NudgyEngine prompt construction and dialogue style

## Build & Deploy

```sh
# Simulator
cd Nudge && xcodebuild -scheme Nudge -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Device
cd Nudge && xcodebuild -scheme Nudge -destination 'generic/platform=iOS' -allowProvisioningUpdates build
```

- Deployment target: iOS 26.0, iPhone only.
- Never commit `Secrets.xcconfig` or API keys.
- Debug launch args: `-seedTasks` (test data), `-skipAuth` (bypass auth).
- **SPM dependency:** Lottie (airbnb/lottie-ios @ 4.6.0).

## Localization

All user-facing strings: `String(localized:)`. No hardcoded text.
