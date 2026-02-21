//
//  NudgeLogger.swift
//  Nudge
//
//  Structured logging via os.Logger — replaces all print() calls.
//  Categories match the app's architecture for easy Console.app filtering.
//
//  Usage:
//    Log.app.info("User signed in")
//    Log.ai.debug("Token count: \(tokens)")
//    Log.data.error("Failed to save: \(error)")
//
//  Filter in Console.app:  subsystem:com.tarsitgroup.nudge  category:ai
//

import os

/// Centralized loggers for the Nudge app — one per subsystem area.
/// All logs use the unified `os.Logger` API for structured, privacy-aware output.
/// In release builds, `.debug` messages are suppressed automatically by the OS.
nonisolated enum Log {
    
    private static let subsystem = "com.tarsitgroup.nudge"
    
    // MARK: - App Lifecycle
    
    /// App launch, foreground/background, container setup
    static let app = Logger(subsystem: subsystem, category: "app")
    
    // MARK: - Authentication
    
    /// Sign in/out, keychain, auth state machine
    static let auth = Logger(subsystem: subsystem, category: "auth")
    
    // MARK: - Data Layer
    
    /// SwiftData, NudgeRepository, migrations, ingestion
    static let data = Logger(subsystem: subsystem, category: "data")
    
    // MARK: - AI / NudgyEngine
    
    /// LLM calls, task extraction, conversation, Foundation Models
    static let ai = Logger(subsystem: subsystem, category: "ai")
    
    // MARK: - CloudKit Sync
    
    /// Sync engine, record push/pull, conflict resolution
    static let sync = Logger(subsystem: subsystem, category: "sync")
    
    // MARK: - Notifications
    
    /// Scheduling, permissions, stale nudges, actions
    static let notify = Logger(subsystem: subsystem, category: "notify")
    
    // MARK: - UI / Views
    
    /// View lifecycle, navigation, deep links, animations
    static let ui = Logger(subsystem: subsystem, category: "ui")
    
    // MARK: - Services
    
    /// Haptics, sounds, contacts, calendar, Spotlight, rewards
    static let services = Logger(subsystem: subsystem, category: "services")
    
    // MARK: - Purchases
    
    /// StoreKit, entitlements, paywall
    static let purchase = Logger(subsystem: subsystem, category: "purchase")
}
