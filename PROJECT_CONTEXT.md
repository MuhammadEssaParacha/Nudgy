# Nudgy — Project Context

> **Owner**: Essa Paracha ([@MuhammadEssaParacha](https://github.com/MuhammadEssaParacha))
> **Repo**: [github.com/MuhammadEssaParacha/Nudgy](https://github.com/MuhammadEssaParacha/Nudgy)
> **Last Updated**: February 20, 2026

---

## What is Nudgy?

Nudgy is a **native iOS app** — an ADHD-friendly task manager with a conversational AI penguin companion named Nudgy. It combines task management with emotional intelligence, gentle nudges, and a personality-driven AI that understands ADHD patterns.

**Target Audience**: People with ADHD who struggle with traditional task managers.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Platform | iOS 18+ (native Swift/SwiftUI) |
| IDE | Xcode 26.2 |
| Language | Swift (96.1%), Python (3.9% — generators/tools) |
| UI | SwiftUI + Lottie animations + Rive assets |
| AI Engine | OpenAI API via custom NudgyEngine |
| Data | SwiftData + CloudKit sync |
| Auth | Sign in with Apple |
| Extensions | Widget, Share, Watch, Live Activity |
| CI/CD | GitHub Actions |

---

## Bundle ID & Identifiers

| Identifier | Value |
|-----------|-------|
| Bundle ID | `com.essaparacha.nudge` |
| App Group | `group.com.essaparacha.nudge` |
| iCloud Container | `iCloud.com.essaparacha.nudge` |
| Widget Extension | `com.essaparacha.nudge.NudgeWidgetExtension` |
| Share Extension | (inherits from main) |
| Tests | `com.essaparacha.nudge.NudgeTests` |
| UI Tests | `com.essaparacha.nudge.NudgeUITests` |

---

## Project Structure

```
Nudgy/
├── Nudge/                          # Xcode project root
│   ├── Nudge.xcodeproj/           # Xcode project file
│   ├── Nudge/                     # Main app target
│   │   ├── NudgeApp.swift         # App entry point
│   │   ├── Nudge.entitlements     # CloudKit, App Groups, Push, Sign in with Apple
│   │   ├── Info.plist             # App config
│   │   ├── Secrets.xcconfig       # API keys (gitignored)
│   │   ├── Core/                  # Logger, App Delegate, Constants
│   │   ├── Models/                # NudgeItem, Category, Routine, MoodEntry, etc.
│   │   ├── Features/              # 20+ feature modules (see below)
│   │   ├── Services/              # 30+ services (see below)
│   │   ├── NudgyEngine/           # AI brain (LLM, personality, dialogue, ADHD knowledge)
│   │   └── Components/            # Shared UI components
│   ├── NudgeWidgetExtension/      # Home screen & Live Activity widgets
│   ├── NudgeShareExtension/       # Share extension
│   └── build/                     # Build artifacts (gitignored)
├── lottie_downloads/              # Penguin Lottie animations
├── docs/                          # 11 markdown docs
├── generators/                    # Python animation/asset generators
├── proof-of-work/                 # Chat session backups (local only, gitignored)
└── PROJECT_CONTEXT.md             # This file
```

### Feature Modules (`Nudge/Features/`)
Aquarium, BrainDump, CaptureBar, Categories, DailyReview, FocusTimer, Inbox, LiveActivity, MoodCheckIn, Nudges, Onboarding, OneThing, Penguin, Persona, QuickAdd, Routines, Settings, Snooze, Timeline, You

### Key Services (`Nudge/Services/`)
CloudKitManager, NudgeRepository, WidgetDataService, HealthService, HandoffService, SpeechService, RoutineService, SpotlightIndexer, LocationService, AppIntents, FocusFilter

### NudgyEngine (AI Brain)
- `NudgyConfig.swift` — Engine configuration, app group refs
- Conversational AI via OpenAI API
- ADHD-aware personality and dialogue system
- Emotional intelligence & mood tracking integration

---

## Xcode Targets (6)

1. **Nudge** — Main iOS app
2. **NudgeShareExtension** — Share sheet extension
3. **NudgeWatchApp** — Apple Watch companion
4. **NudgeWidgetExtension** — Home screen widgets + Live Activities
5. **NudgeTests** — Unit tests
6. **NudgeUITests** — UI tests

---

## Stats

- **202 Swift files**, ~76,000 lines of code
- **6 Xcode targets**
- **20+ feature modules**
- **30+ services**
- **8 data models**
- **Lottie animations** for penguin companion
- **Rive design assets**

---

## Setup Instructions

### Prerequisites
- macOS with Xcode 26.2+
- Apple Developer account (free or paid)
- OpenAI API key

### First Time Setup
1. Open `Nudge/Nudge.xcodeproj` in Xcode
2. Select your **Signing Team** (your Apple ID) for all targets
3. Add your OpenAI API key to `Nudge/Secrets.xcconfig`:
   ```
   OPENAI_API_KEY = sk-proj-your-key-here
   ```
4. Build & run on simulator or device

### If Xcode Asks About CloudKit
- The app uses CloudKit with container `iCloud.com.essaparacha.nudge`
- You may need to create this container in your Apple Developer portal
- Or temporarily disable CloudKit in capabilities for local dev

---

## Git Setup

- **origin**: `github.com/MuhammadEssaParacha/Nudgy.git` (your fork)
- **upstream**: `github.com/aimran6775/Nudgy.git` (Abdullah's original)
- **Author**: Essa Paracha
- All commits from Feb 20, 2026 onward are under your name

---

## What's Working
- Full app architecture and UI
- All 20+ feature modules
- NudgyEngine AI integration
- CloudKit sync setup
- Widget and Share extensions
- Lottie penguin animations
- GitHub Actions CI pipeline

## TODO / Next Steps
- [ ] Open in Xcode and verify build
- [ ] Add your OpenAI API key to Secrets.xcconfig
- [ ] Set up CloudKit container in Apple Developer portal
- [ ] Test on physical device
- [ ] Get VS Code chat history from Abdullah's Mac (when visiting)
- [ ] Submit to App Store under your own Apple ID
