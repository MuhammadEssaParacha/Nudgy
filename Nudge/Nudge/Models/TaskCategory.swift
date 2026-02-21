//
//  TaskCategory.swift
//  Nudge
//
//  20-category system that drives category-specific expanded card templates,
//  tools, timers, checklists, and Nudgy personality per task type.
//
//  Each category maps to a CategoryTemplate with:
//    - Default tools (timer, checklist, draft, maps, etc.)
//    - Nudgy whisper bank (10+ encouragement lines per category)
//    - Quick-add prefill suggestions
//    - Estimated duration defaults
//    - Energy level defaults
//
//  Auto-categorization flows: NudgyTaskExtractor → keyword scan → CategoryMatcher
//  Users can override via manual picker in quick-add or detail view.
//

import SwiftUI

// MARK: - Task Category

/// The 20 task categories that drive template behavior.
/// Raw values are lowercase strings stored in SwiftData.
enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case call        = "call"
    case text        = "text"
    case email       = "email"
    case link        = "link"
    case homework    = "homework"
    case cooking     = "cooking"
    case alarm       = "alarm"
    case exercise    = "exercise"
    case cleaning    = "cleaning"
    case shopping    = "shopping"
    case appointment = "appointment"
    case finance     = "finance"
    case health      = "health"
    case creative    = "creative"
    case errand      = "errand"
    case selfCare    = "selfcare"
    case work        = "work"
    case social      = "social"
    case maintenance = "maintenance"
    case general     = "general"
    
    var id: String { rawValue }
    
    // MARK: - Display
    
    var label: String {
        switch self {
        case .call:        return String(localized: "Call")
        case .text:        return String(localized: "Text")
        case .email:       return String(localized: "Email")
        case .link:        return String(localized: "Link")
        case .homework:    return String(localized: "Study")
        case .cooking:     return String(localized: "Cooking")
        case .alarm:       return String(localized: "Alarm")
        case .exercise:    return String(localized: "Exercise")
        case .cleaning:    return String(localized: "Cleaning")
        case .shopping:    return String(localized: "Shopping")
        case .appointment: return String(localized: "Appointment")
        case .finance:     return String(localized: "Finance")
        case .health:      return String(localized: "Health")
        case .creative:    return String(localized: "Creative")
        case .errand:      return String(localized: "Errand")
        case .selfCare:    return String(localized: "Self-Care")
        case .work:        return String(localized: "Work")
        case .social:      return String(localized: "Social")
        case .maintenance: return String(localized: "Fix & Build")
        case .general:     return String(localized: "General")
        }
    }
    
    var emoji: String {
        switch self {
        case .call:        return "📞"
        case .text:        return "💬"
        case .email:       return "📧"
        case .link:        return "🔗"
        case .homework:    return "📚"
        case .cooking:     return "🍳"
        case .alarm:       return "⏰"
        case .exercise:    return "🏃"
        case .cleaning:    return "🧹"
        case .shopping:    return "🛒"
        case .appointment: return "📅"
        case .finance:     return "💰"
        case .health:      return "💊"
        case .creative:    return "🎨"
        case .errand:      return "🚗"
        case .selfCare:    return "🧘"
        case .work:        return "💼"
        case .social:      return "👥"
        case .maintenance: return "🔧"
        case .general:     return "📌"
        }
    }
    
    var icon: String {
        switch self {
        case .call:        return "phone.fill"
        case .text:        return "message.fill"
        case .email:       return "envelope.fill"
        case .link:        return "link"
        case .homework:    return "book.fill"
        case .cooking:     return "frying.pan.fill"
        case .alarm:       return "alarm.fill"
        case .exercise:    return "dumbbell.fill"
        case .cleaning:    return "bubbles.and.sparkles.fill"
        case .shopping:    return "cart.fill"
        case .appointment: return "calendar.badge.clock"
        case .finance:     return "creditcard.fill"
        case .health:      return "heart.fill"
        case .creative:    return "paintbrush.fill"
        case .errand:      return "car.fill"
        case .selfCare:    return "sparkles"
        case .work:        return "briefcase.fill"
        case .social:      return "person.2.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .general:     return "pin.fill"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .call:        return [Color(hex: "34D399"), Color(hex: "10B981")]
        case .text:        return [Color(hex: "60A5FA"), Color(hex: "3B82F6")]
        case .email:       return [Color(hex: "818CF8"), Color(hex: "6366F1")]
        case .link:        return [Color(hex: "38BDF8"), Color(hex: "0EA5E9")]
        case .homework:    return [Color(hex: "818CF8"), Color(hex: "6366F1")]
        case .cooking:     return [Color(hex: "FBBF24"), Color(hex: "F59E0B")]
        case .alarm:       return [Color(hex: "F87171"), Color(hex: "EF4444")]
        case .exercise:    return [Color(hex: "FB923C"), Color(hex: "F97316")]
        case .cleaning:    return [Color(hex: "7DD3FC"), Color(hex: "38BDF8")]
        case .shopping:    return [Color(hex: "4ADE80"), Color(hex: "22C55E")]
        case .appointment: return [Color(hex: "F87171"), Color(hex: "EF4444")]
        case .finance:     return [Color(hex: "4ADE80"), Color(hex: "22C55E")]
        case .health:      return [Color(hex: "34D399"), Color(hex: "10B981")]
        case .creative:    return [Color(hex: "C084FC"), Color(hex: "A855F7")]
        case .errand:      return [Color(hex: "9CA3AF"), Color(hex: "6B7280")]
        case .selfCare:    return [Color(hex: "A78BFA"), Color(hex: "8B5CF6")]
        case .work:        return [Color(hex: "60A5FA"), Color(hex: "3B82F6")]
        case .social:      return [Color(hex: "A78BFA"), Color(hex: "8B5CF6")]
        case .maintenance: return [Color(hex: "FB923C"), Color(hex: "F97316")]
        case .general:     return [Color(hex: "9CA3AF"), Color(hex: "6B7280")]
        }
    }
    
    var primaryColor: Color { gradientColors[0] }
    
    /// Primary color as hex string (for storing in model fields).
    var primaryColorHex: String {
        switch self {
        case .call:        return "34C759"
        case .text:        return "007AFF"
        case .email:       return "5E5CE6"
        case .link:        return "007AFF"
        case .homework:    return "818CF8"
        case .cooking:     return "FB923C"
        case .alarm:       return "FF453A"
        case .exercise:    return "F97316"
        case .cleaning:    return "38BDF8"
        case .shopping:    return "34D399"
        case .appointment: return "FFD60A"
        case .finance:     return "FBBF24"
        case .health:      return "34D399"
        case .creative:    return "C084FC"
        case .errand:      return "9CA3AF"
        case .selfCare:    return "A78BFA"
        case .work:        return "60A5FA"
        case .social:      return "A78BFA"
        case .maintenance: return "FB923C"
        case .general:     return "9CA3AF"
        }
    }
    
    // MARK: - Template Capabilities
    
    /// What tools/features this category's expanded card shows.
    var capabilities: Set<CategoryCapability> {
        switch self {
        case .call:        return [.contactCard, .draftTalkingPoints, .callTimer, .dialButton]
        case .text:        return [.contactCard, .aiDraft, .sendButton]
        case .email:       return [.contactCard, .aiDraft, .subjectLine, .sendButton]
        case .link:        return [.urlPreview, .openButton]
        case .homework:    return [.pomodoroTimer, .subjectTag, .progressBar, .breakReminder, .microSteps]
        case .cooking:     return [.multiTimer, .stepByStep, .ingredientChecklist]
        case .alarm:       return [.alarmPicker, .soundPicker, .recurringToggle]
        case .exercise:    return [.workoutTimer, .repCounter, .restTimer, .routineBuilder]
        case .cleaning:    return [.zonePicker, .speedCleanTimer, .zoneChecklist]
        case .shopping:    return [.shoppingList, .storeSections, .budgetTracker]
        case .appointment: return [.calendarAdd, .travelTime, .prepChecklist, .countdown]
        case .finance:     return [.amountField, .dueDateCountdown, .payLink, .recurringToggle]
        case .health:      return [.dosageInfo, .recurringToggle, .adherenceStreak, .logHistory]
        case .creative:    return [.distractionFree, .inspirationPrompt, .progressJournal, .wordCounter]
        case .errand:      return [.addressField, .mapsLink, .multiStopRoute]
        case .selfCare:    return [.guidedBreathing, .journalPrompt, .moodSlider]
        case .work:        return [.meetingAgenda, .prepChecklist, .talkingPoints, .timeBlock]
        case .social:      return [.contactCard, .planDetails, .rsvpTracker, .calendarAdd]
        case .maintenance: return [.howToLink, .toolChecklist, .photoCapture, .recurringToggle]
        case .general:     return [.microSteps, .notesField, .flexibleTimer]
        }
    }
    
    /// Maps from ActionType for backward compatibility.
    static func from(actionType: ActionType) -> TaskCategory {
        switch actionType {
        case .call:          return .call
        case .text:          return .text
        case .email:         return .email
        case .openLink:      return .link
        case .search:        return .link
        case .navigate:      return .errand
        case .addToCalendar: return .appointment
        case .setAlarm:      return .alarm
        }
    }
    
    /// Default estimated minutes for this category.
    var defaultDuration: Int? {
        switch self {
        case .call:        return 10
        case .text:        return 2
        case .email:       return 10
        case .link:        return 5
        case .homework:    return 45
        case .cooking:     return 30
        case .alarm:       return nil
        case .exercise:    return 30
        case .cleaning:    return 20
        case .shopping:    return 30
        case .appointment: return 60
        case .finance:     return 5
        case .health:      return 2
        case .creative:    return 60
        case .errand:      return 30
        case .selfCare:    return 15
        case .work:        return 45
        case .social:      return nil
        case .maintenance: return 30
        case .general:     return nil
        }
    }
    
    /// Default energy level for this category.
    var defaultEnergy: EnergyLevel {
        switch self {
        case .call, .email, .work, .homework, .creative:   return .high
        case .exercise, .cooking, .maintenance, .errand:    return .medium
        case .text, .link, .shopping, .cleaning, .selfCare,
             .health, .finance, .social, .alarm, .general,
             .appointment:                                  return .low
        }
    }
}

// MARK: - Category Capability

/// Individual tools/features a category card can include.
enum CategoryCapability: String, CaseIterable {
    // Communication
    case contactCard
    case draftTalkingPoints
    case aiDraft
    case subjectLine
    case callTimer
    case dialButton
    case sendButton
    
    // Links
    case urlPreview
    case openButton
    
    // Timers
    case pomodoroTimer
    case multiTimer
    case workoutTimer
    case restTimer
    case speedCleanTimer
    case flexibleTimer
    case timeBlock
    
    // Counters & Progress
    case repCounter
    case progressBar
    case wordCounter
    case budgetTracker
    case adherenceStreak
    
    // Checklists
    case ingredientChecklist
    case shoppingList
    case zoneChecklist
    case prepChecklist
    case toolChecklist
    case routineBuilder
    
    // Step-by-step
    case stepByStep
    case microSteps
    
    // Scheduling
    case alarmPicker
    case soundPicker
    case recurringToggle
    case calendarAdd
    case countdown
    case dueDateCountdown
    case breakReminder
    
    // Content
    case subjectTag
    case amountField
    case dosageInfo
    case logHistory
    case notesField
    case planDetails
    case rsvpTracker
    case meetingAgenda
    case talkingPoints
    case inspirationPrompt
    case journalPrompt
    case progressJournal
    
    // Location
    case addressField
    case mapsLink
    case travelTime
    case multiStopRoute
    
    // Media
    case photoCapture
    case howToLink
    
    // Modes
    case distractionFree
    case guidedBreathing
    case moodSlider
    case zonePicker
    case storeSections
    case payLink
}

// MARK: - Category Keyword Matcher

/// Maps natural language keywords to TaskCategory for auto-categorization.
/// Leverages the existing 200+ keywords from CategoryIllustration but returns
/// a typed TaskCategory instead of just a visual style.
nonisolated enum CategoryClassifier {
    
    /// Classify a task from its content text. Returns nil if no strong match.
    static func classify(content: String, actionType: ActionType? = nil) -> TaskCategory {
        // 1. ActionType takes priority (backward compat)
        if let actionType {
            return TaskCategory.from(actionType: actionType)
        }
        
        let text = content.lowercased()
        
        // 2. Keyword scan — ordered by specificity (most specific first)
        for (category, keywords) in keywordMap {
            for keyword in keywords {
                if text.contains(keyword) {
                    return category
                }
            }
        }
        
        // 3. Default
        return .general
    }
    
    // Most specific keywords first to avoid false matches
    private static let keywordMap: [(TaskCategory, [String])] = [
        // Homework / Study — check before work
        (.homework, [
            "homework", "assignment", "study", "exam", "quiz", "test ", "essay",
            "lecture", "class ", "course", "textbook", "chapter", "reading",
            "math", "science", "history", "english", "calculus", "algebra",
            "biology", "chemistry", "physics", "thesis", "dissertation",
            "flashcard", "tutor", "gpa", "semester", "grade ", "midterm", "final exam",
            "research paper", "lab report", "pomodoro", "school", "university",
            "college", "learn ", "practice problem"
        ]),
        
        // Cooking — check before shopping
        (.cooking, [
            "cook", "recipe", "bake", "boil", "pasta", "chicken", "dinner",
            "lunch", "breakfast", "meal prep", "oven", "grill", "fry",
            "marinade", "sauce", "soup", "stew", "roast", "chop",
            "ingredient", "kitchen timer", "preheat", "simmer", "sauté"
        ]),
        
        // Exercise — check before health
        (.exercise, [
            "workout", "exercise", "gym", "running", "jog", "swim",
            "yoga", "stretch", "push-up", "pushup", "pull-up", "pullup",
            "squat", "plank", "cardio", "hiit",
            "bench press", "deadlift", "treadmill", "bike ride",
            "cycling", "hike", "hiking", "sport",
            "go for a run", "go run", "mile run",
            "lift weights", "weight training", "weightlift",
            "reps", "sets of", "ab workout", "core workout",
            "go for a walk", "take a walk"
        ]),
        
        // Health / Medication — specific health
        (.health, [
            "medication", "medicine", "pill", "prescription", "doctor",
            "dentist", "therapist", "therapy", "appointment dr", "checkup",
            "blood test", "x-ray", "mri", "vaccine", "vitamin",
            "refill", "pharmacy", "dosage", "health check", "eye exam"
        ]),
        
        // Self-Care
        (.selfCare, [
            "meditat", "breathe", "breathing", "journal", "self-care", "selfcare",
            "self care", "relax", "spa", "bath", "skincare", "facial",
            "nap", "rest", "mindful", "gratitude", "affirmation",
            "mental health", "decompress", "unwind", "pamper"
        ]),
        
        // Cleaning
        (.cleaning, [
            "clean", "vacuum", "mop", "sweep", "dust", "scrub",
            "organize", "declutter", "tidy", "laundry", "dishes",
            "bathroom", "kitchen clean", "bedroom", "trash", "garbage",
            "recycle", "wipe", "sanitize", "deep clean", "spring clean"
        ]),
        
        // Shopping
        (.shopping, [
            "buy ", "shop", "grocery", "groceries", "store", "market",
            "order", "amazon", "target", "walmart", "costco",
            "pick up", "pickup", "delivery", "cart", "list ",
            "return ", "exchange", "coupon", "sale", "mall"
        ]),
        
        // Finance
        (.finance, [
            "pay ", "payment", "bill", "invoice", "rent", "mortgage",
            "budget", "bank", "transfer", "invest", "tax",
            "insurance", "subscription", "cancel sub", "credit card",
            "debt", "loan", "save money", "expense", "receipt", "refund"
        ]),
        
        // Appointment / Calendar
        (.appointment, [
            "appointment", "meeting", "schedule", "book ", "reservation",
            "dentist appt", "doctor appt", "interview", "conference",
            "rsvp", "attend", "event", "wedding", "party",
            "birthday", "anniversary", "ceremony"
        ]),
        
        // Alarm / Reminder
        (.alarm, [
            "alarm", "wake up", "wake me", "remind me at", "timer for",
            "set timer", "set alarm", "reminder at", "alert at"
        ]),
        
        // Work
        (.work, [
            "meeting", "standup", "sprint", "jira", "slack", "email boss",
            "presentation", "slide", "deck", "report", "deadline",
            "project", "client", "proposal", "quarterly", "review",
            "one-on-one", "1:1", "feedback", "performance"
        ]),
        
        // Creative
        (.creative, [
            "paint", "draw", "sketch", "design", "music", "song",
            "guitar", "piano", "sing", "compose", "photograph",
            "video edit", "film", "podcast", "blog", "write story",
            "novel", "script", "poetry", "craft", "knit", "sew",
            "crochet", "diy", "create", "art "
        ]),
        
        // Social
        (.social, [
            "hang out", "hangout", "catch up", "dinner with",
            "lunch with", "coffee with", "plans with", "meet up",
            "meetup", "visit ", "invite", "host",
            "game night", "movie night", "double date"
        ]),
        
        // Errand
        (.errand, [
            "errand", "drop off", "dropoff", "pick up from",
            "post office", "dry clean", "car wash", "dmv",
            "bank ", "library", "return book", "gas station",
            "fill up", "notary", "passport", "license"
        ]),
        
        // Maintenance / Fix
        (.maintenance, [
            "fix", "repair", "replace", "install", "assemble",
            "plumber", "electrician", "handyman", "oil change",
            "tire", "filter", "battery", "paint wall", "drill",
            "hang ", "mount", "build ", "shed", "fence"
        ]),
        
        // Link (generic URL tasks)
        (.link, [
            "check link", "open link", "browse", "website",
            "look up", "lookup", "google", "search for",
            "find online", "watch video", "youtube"
        ]),
    ]
}
