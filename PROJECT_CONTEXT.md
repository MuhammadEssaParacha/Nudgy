# Nudgy — Project Context

> **Owner**: Essa Paracha ([@MuhammadEssaParacha](https://github.com/MuhammadEssaParacha))
> **Repo**: [github.com/MuhammadEssaParacha/Nudgy](https://github.com/MuhammadEssaParacha/Nudgy)
> **Last Updated**: February 21, 2026

---

## What is Nudgy?

Nudgy is a **native iOS app** — an ADHD-friendly task manager with a conversational AI penguin companion named Nudgy. It combines task management with emotional intelligence, gentle nudges, and a personality-driven AI that understands ADHD patterns.

**Target Audience**: People with ADHD who struggle with traditional task managers.

**Core UX Principle**: One card at a time — never overwhelm with lists.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Platform | iOS 26+ (native Swift/SwiftUI) |
| IDE | Xcode 26.2 |
| Language | Swift (96%), Python (4% — generators/tools) |
| UI | SwiftUI + Lottie animations (airbnb/lottie-ios 4.6.0) |
| Data | SwiftData (per-user stores) + CloudKit sync |
| AI (on-device) | Apple Foundation Models (`@Generable`) |
| AI (cloud) | OpenAI GPT-4o-mini via NudgyEngine |
| Auth | Sign in with Apple + local email/password |
| Extensions | Widget, Share, Watch, Live Activity |
| CI/CD | GitHub Actions (build, lint, test, archive) |

---

## Bundle ID & Identifiers

| Identifier | Value |
|-----------|-------|
| Bundle ID | `com.essaparacha.nudge` |
| App Group | `group.com.essaparacha.nudge` |
| iCloud Container | `iCloud.com.essaparacha.nudge` |
| Widget Extension | `com.essaparacha.nudge.NudgeWidgetExtension` |
| Tests | `com.essaparacha.nudge.NudgeTests` |
| UI Tests | `com.essaparacha.nudge.NudgeUITests` |

---

## Project Structure

```
Nudgy/
├── Nudge/                              # Xcode project root
│   ├── Nudge.xcodeproj/               # Xcode project file (folder-based sources)
│   ├── Nudge/                          # Main app target
│   │   ├── NudgeApp.swift              # Entry point (1,055 lines, 4-tier routing)
│   │   ├── ContentView.swift           # 3-tab router (~310 lines)
│   │   ├── Nudge.entitlements          # CloudKit, App Groups, Push, SIWA
│   │   ├── Info.plist                  # App config
│   │   ├── Secrets.xcconfig            # API keys (GITIGNORED)
│   │   ├── Assets.xcassets/            # App icon, accent color, mascot images
│   │   ├── Core/                       # 27 files
│   │   │   ├── Constants.swift         # DesignTokens (colors, spacing, sizing)
│   │   │   ├── NudgeLogger.swift       # OSLog subsystem logger
│   │   │   ├── PersonaSystem.swift     # Persona adapter
│   │   │   ├── ADHDProfileTypes.swift  # ADHD subtypes, personality modes
│   │   │   ├── Accessibility/          # VoiceOver helpers, Dynamic Type
│   │   │   ├── Components/             # CategoryIllustration, NudgeIcon, TaskIconView
│   │   │   ├── Extensions/             # Swift extensions
│   │   │   ├── Theme/                  # AppTheme, DarkCard, Penguin sprites, Lottie views
│   │   │   └── Tips/                   # TipKit definitions
│   │   ├── Models/                     # 8 files
│   │   │   ├── NudgeItem.swift         # Main task model (582 lines, SwiftData @Model)
│   │   │   ├── AppSettings.swift       # @Observable UserDefaults wrapper (369 lines)
│   │   │   ├── BrainDump.swift         # Brain dump entries
│   │   │   ├── CategoryTemplate.swift  # Task categories
│   │   │   ├── MoodEntry.swift         # Mood check-in data
│   │   │   ├── NudgyWardrobe.swift     # Penguin customization
│   │   │   ├── Routine.swift           # Recurring routines
│   │   │   └── TaskCategory.swift      # Category definitions
│   │   ├── Features/                   # 24 modules
│   │   │   ├── AllItems/               # Full task list view
│   │   │   ├── Aquarium/               # Fish collection & tank (5 files)
│   │   │   ├── BrainDump/              # Quick thought capture (2 files)
│   │   │   ├── Browser/                # In-app web browser
│   │   │   ├── CaptureBar/             # Always-visible capture input
│   │   │   ├── Categories/             # Task categorization (3 files)
│   │   │   ├── DailyReview/            # End-of-day reflection
│   │   │   ├── FocusTimer/             # Pomodoro-style timer
│   │   │   ├── Inbox/                  # Nudgy inbox view
│   │   │   ├── LiveActivity/           # Dynamic Island + Lock Screen
│   │   │   ├── MoodCheckIn/            # Emotional check-ins (2 files)
│   │   │   ├── Nudges/                 # Card-based task views (20 files)
│   │   │   ├── NudgesPage/             # Main task page (15 files)
│   │   │   ├── Onboarding/             # First-run flow (6 files)
│   │   │   ├── OneThing/               # Single-task focus (3 files)
│   │   │   ├── Penguin/                # Nudgy companion home (18 files)
│   │   │   ├── Persona/                # User persona picker (2 files)
│   │   │   ├── QuickAdd/               # Quick task creation
│   │   │   ├── Routines/               # Recurring tasks (2 files)
│   │   │   ├── Settings/               # App settings + paywall (2 files)
│   │   │   ├── Snooze/                 # Task snoozing
│   │   │   ├── Timeline/               # Timeline view
│   │   │   └── You/                    # Profile tab (7 files)
│   │   ├── Services/                   # 42 files
│   │   │   ├── NudgeRepository.swift   # THE data access layer (not singleton)
│   │   │   ├── AIService.swift         # Apple Foundation Models bridge
│   │   │   ├── ActionService.swift     # Notification-based cross-view router
│   │   │   ├── CloudKit/               # CloudKitManager + CloudKitSyncEngine
│   │   │   ├── Auth/                   # AuthSession
│   │   │   ├── Security/               # KeychainService
│   │   │   ├── AppIntents/             # Shortcuts, Focus Filter, Widgets, Control Center (6 files)
│   │   │   └── ...                     # 30+ more services
│   │   └── NudgyEngine/               # AI brain (16 files)
│   │       ├── NudgyEngine.swift       # Main singleton entry point
│   │       ├── NudgyConfig.swift       # Dual LLM config (OpenAI + on-device)
│   │       ├── NudgyConversationManager.swift
│   │       ├── NudgyDialogueEngine.swift
│   │       ├── NudgyLLMService.swift
│   │       ├── NudgyPersonality.swift
│   │       ├── NudgyEmotionMapper.swift
│   │       ├── NudgyMemory.swift
│   │       ├── NudgyADHDKnowledge.swift
│   │       └── ...                     # 7 more engine files
│   ├── NudgeWidgetExtension/           # Home screen widgets + Live Activity (3 files)
│   ├── NudgeShareExtension/            # Share sheet extension (2 files)
│   ├── NudgeWatchApp/                  # Apple Watch (1 file)
│   └── build/                          # Build artifacts (gitignored)
├── lottie_downloads/                   # 6 penguin Lottie JSONs + tools
├── .github/
│   ├── workflows/ci.yml               # CI pipeline
│   ├── copilot-instructions.md         # Agent instructions (THIS IS KEY)
│   └── celestial-button-guidelines.md  # CelestialButton reference
├── docs/                               # 11 design/architecture docs
├── proof-of-work/                      # Chat backups (local only, gitignored)
├── PROJECT_CONTEXT.md                  # This file
└── Nudgy.code-workspace               # VS Code workspace file
```

---

## Stats

| Metric | Value |
|--------|-------|
| Swift files | 203 |
| Lines of Swift | ~80,700 |
| Feature modules | 24 |
| Services | 42 |
| NudgyEngine files | 16 |
| Data models | 8 |
| Xcode targets | 6 |
| SPM dependencies | 1 (Lottie) |
| Lottie animations | 6 |
| Python utilities | 7 |

---

## Setup Instructions

### Prerequisites
- macOS with Xcode 26.2+
- Apple Developer account (free or paid)
- OpenAI API key

### First Time Setup
1. Open `Nudge/Nudge.xcodeproj` in Xcode
2. Select your **Signing Team** (your Apple ID) for ALL 6 targets
3. Add your OpenAI API key to `Nudge/Secrets.xcconfig`:
   ```
   OPENAI_API_KEY = sk-proj-your-key-here
   ```
4. Build & run on simulator: `iPhone 17 Pro`
5. Use `-seedTasks` launch arg for test data, `-skipAuth` to bypass auth

### If CloudKit Doesn't Work
- Create container `iCloud.com.essaparacha.nudge` in Apple Developer portal
- Or temporarily disable CloudKit in Xcode capabilities for local dev

---

## Git Setup

- **origin**: `github.com/MuhammadEssaParacha/Nudgy.git` (your fork)
- **upstream**: `github.com/aimran6775/Nudgy.git` (original)
- **Author**: Essa Paracha
- All commits from Feb 20, 2026 onward are under your name

---

## Key Architecture Decisions

1. **SwiftData with raw string enums** — `#Predicate` can't compare enums, so models store `statusRaw`, `actionTypeRaw` etc. ActionType values are UPPERCASE.
2. **Per-user data stores** — `nudge_{userID}.store` in App Group. ModelContainer created after auth.
3. **NudgyEngine.shared is the only AI entry point** — views never call sub-engines directly. Always check `.isAvailable`.
4. **Dual AI providers** — Apple Foundation Models (on-device) + OpenAI API (cloud). App works fully without AI.
5. **No ViewModels** — views use `NudgeRepository` + `@State` directly. Exception: `BrainDumpViewModel`.
6. **Notification-based routing** — `ActionService` defines 7 notification names for cross-view communication.
7. **Duplicated types in extensions** — `ShareExtensionPayload`, `NudgeActivityAttributes`, `Color(hex:)` exist in multiple targets.
8. **Custom sync engine** — CloudKit mirroring disabled, own `CloudKitSyncEngine` with last-write-wins.

---

## Development Workflow

```sh
# Build for simulator
cd Nudge && xcodebuild -scheme Nudge -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
cd Nudge && xcodebuild -scheme Nudge -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Open in Xcode
open Nudge/Nudge.xcodeproj
```

---

## TODO / Roadmap
- [ ] Set signing team in Xcode (open project, select your Apple ID)
- [ ] Add your own OpenAI API key to Secrets.xcconfig
- [ ] Set up CloudKit container in Apple Developer portal
- [ ] Test on physical device
- [ ] Get VS Code chat history from Abdullah's Mac (when visiting)
- [ ] App Store submission under your Apple ID
- [ ] Consider renaming the app or keeping Nudgy brand
