//
//  CategoryTemplate.swift
//  Nudge
//
//  Templates define the expanded card behavior for each TaskCategory.
//  Each template includes: default tools, Nudgy whispers, quick presets,
//  and category-specific UI configuration.
//
//  ADHD-optimized: templates reduce decision fatigue by pre-configuring
//  the right tools for each task type (no need to hunt for settings).
//

import SwiftUI

// MARK: - Category Template

/// A template defining the expanded card behavior for a task category.
nonisolated struct CategoryTemplate: Sendable {
    let category: TaskCategory
    let nudgyWhispers: [String]            // 10+ encouragement lines
    let quickPresets: [QuickPreset]         // Pre-built quick action buttons
    let defaultMicroSteps: [String]        // Fallback micro-steps if AI unavailable
    let timerPresets: [TimerPreset]?        // For timer-capable categories
    let checklistSections: [String]?       // For checklist categories (section headers)
    
    /// Pick a random Nudgy whisper for this category.
    func randomWhisper() -> String {
        nudgyWhispers.randomElement() ?? "you got this"
    }
}

// MARK: - Quick Preset

/// A pre-built quick action button shown in the category card.
nonisolated struct QuickPreset: Identifiable, Sendable {
    let id: String
    let label: String
    let icon: String
    let action: QuickPresetAction
}

/// What a quick preset does when tapped.
enum QuickPresetAction: Sendable {
    case startTimer(minutes: Int)
    case addToCalendar
    case openMaps
    case startFocus(focusMinutes: Int, breakMinutes: Int)
    case setAlarm
    case startBreathing(pattern: BreathingPattern)
    case openURL
    case dial
    case compose
    case custom(String)  // Custom action identifier
}

/// Breathing exercise patterns for self-care category.
enum BreathingPattern: String, Sendable {
    case box478 = "4-7-8"
    case box444 = "4-4-4"
    case calm = "calm"
}

// MARK: - Timer Preset

/// Pre-configured timer option for category cards.
nonisolated struct TimerPreset: Identifiable, Sendable {
    let id: String
    let label: String
    let icon: String
    let minutes: Int
    let color: String  // Hex color
}

// MARK: - Category Template Registry

/// Central registry of all 20 category templates.
/// Each template drives the expanded card UI for its category.
nonisolated enum CategoryTemplateRegistry {
    
    static func template(for category: TaskCategory) -> CategoryTemplate {
        switch category {
        case .call:        return callTemplate
        case .text:        return textTemplate
        case .email:       return emailTemplate
        case .link:        return linkTemplate
        case .homework:    return homeworkTemplate
        case .cooking:     return cookingTemplate
        case .alarm:       return alarmTemplate
        case .exercise:    return exerciseTemplate
        case .cleaning:    return cleaningTemplate
        case .shopping:    return shoppingTemplate
        case .appointment: return appointmentTemplate
        case .finance:     return financeTemplate
        case .health:      return healthTemplate
        case .creative:    return creativeTemplate
        case .errand:      return errandTemplate
        case .selfCare:    return selfCareTemplate
        case .work:        return workTemplate
        case .social:      return socialTemplate
        case .maintenance: return maintenanceTemplate
        case .general:     return generalTemplate
        }
    }
    
    // MARK: - 📞 Call
    
    private static let callTemplate = CategoryTemplate(
        category: .call,
        nudgyWhispers: [
            "just hit dial — 10 seconds of courage 🐧",
            "they'll be glad you called, promise",
            "deep breath, then press the button",
            "the hardest part is starting the call",
            "you've rehearsed this in your head 100x — time to actually do it",
            "phone calls feel huge but they're usually 3 minutes",
            "what's the worst that happens? voicemail 📞",
            "your future self will thank you for this call",
            "pretend you're calling to order pizza — same energy",
            "I wrote talking points for you, just read them 🐧",
        ],
        quickPresets: [
            QuickPreset(id: "dial", label: "Dial Now", icon: "phone.arrow.up.right.fill", action: .dial),
        ],
        defaultMicroSteps: [
            "Take a deep breath",
            "Review talking points",
            "Dial the number",
            "Say what you need to say",
            "Hang up and celebrate 🎉",
        ],
        timerPresets: [
            TimerPreset(id: "call5", label: "5 min call", icon: "phone.fill", minutes: 5, color: "34D399"),
            TimerPreset(id: "call15", label: "15 min call", icon: "phone.fill", minutes: 15, color: "10B981"),
        ],
        checklistSections: nil
    )
    
    // MARK: - 💬 Text
    
    private static let textTemplate = CategoryTemplate(
        category: .text,
        nudgyWhispers: [
            "here's a starter, tweak it and send 💬",
            "literally just press send — it's fine",
            "you've been composing this in your head all day",
            "the draft is ready, one tap away",
            "texting back = being a good friend ✨",
            "they texted you 3 days ago — time to reply 🐧",
            "short and sweet is totally fine",
            "you don't need the perfect words",
            "just say 'hey!' — momentum will carry the rest",
            "reply now, spiral later (jk you'll feel great)",
        ],
        quickPresets: [
            QuickPreset(id: "send", label: "Send Draft", icon: "paperplane.fill", action: .compose),
        ],
        defaultMicroSteps: [
            "Open the message thread",
            "Read the draft Nudgy wrote",
            "Edit if needed",
            "Hit send",
        ],
        timerPresets: nil,
        checklistSections: nil
    )
    
    // MARK: - 📧 Email
    
    private static let emailTemplate = CategoryTemplate(
        category: .email,
        nudgyWhispers: [
            "draft's ready, just hit send 📧",
            "emails don't have to be essays — 3 sentences is plenty",
            "the subject line is done, body is done — just. press. send.",
            "you've been avoiding this email for days 🐧",
            "professional AND fast — that's the vibe",
            "reply all? nah. reply done? yes.",
            "your inbox will feel so much lighter",
            "future you is cheering right now",
            "one email closer to inbox zero 🎯",
            "Nudgy proofread it — looks great 🐧",
        ],
        quickPresets: [
            QuickPreset(id: "compose", label: "Open Compose", icon: "envelope.open.fill", action: .compose),
        ],
        defaultMicroSteps: [
            "Review the draft",
            "Check the subject line",
            "Add any attachments",
            "Hit send",
        ],
        timerPresets: nil,
        checklistSections: nil
    )
    
    // MARK: - 🔗 Link
    
    private static let linkTemplate = CategoryTemplate(
        category: .link,
        nudgyWhispers: [
            "just click and you're done 🔗",
            "it's one tap away — literally",
            "open it, do the thing, close it ✓",
            "this will take 30 seconds tops",
            "the link isn't going to click itself 🐧",
            "tab hoarding is NOT doing the task",
            "open → read → done. that's it.",
            "you bookmarked this for a reason — now's the time",
            "don't just save it, do it 🐧",
            "the internet awaits your click",
        ],
        quickPresets: [
            QuickPreset(id: "open", label: "Open Link", icon: "safari.fill", action: .openURL),
        ],
        defaultMicroSteps: [
            "Open the link",
            "Read/review the content",
            "Take any needed action",
            "Done!",
        ],
        timerPresets: nil,
        checklistSections: nil
    )
    
    // MARK: - 📚 Homework / Study
    
    private static let homeworkTemplate = CategoryTemplate(
        category: .homework,
        nudgyWhispers: [
            "25 minutes on, 5 off — you got this 📚",
            "just open the textbook — that's step one",
            "your brain is stronger than you think 🧠",
            "one Pomodoro at a time, champ",
            "you're smarter than this homework thinks 🐧",
            "the first 5 minutes are the hardest — then flow kicks in",
            "no one said you have to enjoy it — just finish it",
            "future you will be SO relieved this is done",
            "study now, Netflix guilt-free later 🎉",
            "break it into chunks — eat the elephant bite by bite 🐧",
            "put your phone face-down. yes, even me. I'll wait.",
            "you've survived every assignment before this one",
        ],
        quickPresets: [
            QuickPreset(id: "pomo25", label: "25 min Focus", icon: "timer", action: .startFocus(focusMinutes: 25, breakMinutes: 5)),
            QuickPreset(id: "pomo50", label: "50 min Deep", icon: "brain.head.profile.fill", action: .startFocus(focusMinutes: 50, breakMinutes: 10)),
            QuickPreset(id: "quick15", label: "15 min Sprint", icon: "bolt.fill", action: .startFocus(focusMinutes: 15, breakMinutes: 3)),
        ],
        defaultMicroSteps: [
            "Gather materials (textbook, notes, laptop)",
            "Read through the instructions",
            "Outline your approach",
            "Work through section by section",
            "Review your work",
            "Submit / put away",
        ],
        timerPresets: [
            TimerPreset(id: "study15", label: "15 min sprint", icon: "bolt.fill", minutes: 15, color: "60A5FA"),
            TimerPreset(id: "study25", label: "25 min Pomodoro", icon: "timer", minutes: 25, color: "818CF8"),
            TimerPreset(id: "study50", label: "50 min deep work", icon: "brain.head.profile.fill", minutes: 50, color: "6366F1"),
            TimerPreset(id: "study90", label: "90 min session", icon: "clock.fill", minutes: 90, color: "4F46E5"),
        ],
        checklistSections: nil
    )
    
    // MARK: - 🍳 Cooking
    
    private static let cookingTemplate = CategoryTemplate(
        category: .cooking,
        nudgyWhispers: [
            "chef's kiss incoming 🍳👨‍🍳",
            "timer's running, what's next?",
            "pasta water won't boil if you don't start it 🐧",
            "mise en place — fancy for 'get your stuff ready'",
            "cooking > ordering in (but both are valid)",
            "you're basically Gordon Ramsay right now",
            "the smoke detector is NOT a cooking timer",
            "taste as you go — that's the pro move",
            "music on, apron on, let's cook 🎵",
            "homemade = love. also cheaper. 🐧",
        ],
        quickPresets: [
            QuickPreset(id: "pasta", label: "Pasta Timer", icon: "timer", action: .startTimer(minutes: 8)),
            QuickPreset(id: "oven", label: "Oven Preheat", icon: "flame.fill", action: .startTimer(minutes: 15)),
            QuickPreset(id: "boil", label: "Boil Water", icon: "drop.fill", action: .startTimer(minutes: 10)),
        ],
        defaultMicroSteps: [
            "Read through the full recipe",
            "Gather all ingredients",
            "Prep ingredients (chop, measure)",
            "Start cooking (follow steps)",
            "Plate and serve",
            "Clean up kitchen",
        ],
        timerPresets: [
            TimerPreset(id: "cook3", label: "3 min", icon: "timer", minutes: 3, color: "FBBF24"),
            TimerPreset(id: "cook5", label: "5 min", icon: "timer", minutes: 5, color: "F59E0B"),
            TimerPreset(id: "cook8", label: "8 min", icon: "timer", minutes: 8, color: "FB923C"),
            TimerPreset(id: "cook10", label: "10 min", icon: "timer", minutes: 10, color: "F97316"),
            TimerPreset(id: "cook15", label: "15 min", icon: "timer", minutes: 15, color: "EF4444"),
            TimerPreset(id: "cook20", label: "20 min", icon: "timer", minutes: 20, color: "DC2626"),
            TimerPreset(id: "cook30", label: "30 min", icon: "timer", minutes: 30, color: "B91C1C"),
            TimerPreset(id: "cook45", label: "45 min", icon: "timer", minutes: 45, color: "991B1B"),
        ],
        checklistSections: ["Ingredients", "Equipment"]
    )
    
    // MARK: - ⏰ Alarm
    
    private static let alarmTemplate = CategoryTemplate(
        category: .alarm,
        nudgyWhispers: [
            "I'll wake you up, promise ⏰🐧",
            "alarm set — now stop worrying about forgetting",
            "Nudgy never oversleeps (I'm a penguin, we're early risers)",
            "rise and grind? more like rise and waddle 🐧",
            "you asked to be reminded — here I am!",
            "sleep tight, I've got your back ⏰",
            "tomorrow-you will thank tonight-you",
            "alarm ON, anxiety OFF ✓",
            "I'll be louder than your snooze instinct 🐧",
            "wakey wakey, eggs and bakey 🍳",
        ],
        quickPresets: [
            QuickPreset(id: "alarm5", label: "5 min", icon: "alarm.fill", action: .setAlarm),
            QuickPreset(id: "alarm15", label: "15 min", icon: "alarm.fill", action: .setAlarm),
            QuickPreset(id: "alarm30", label: "30 min", icon: "alarm.fill", action: .setAlarm),
            QuickPreset(id: "alarm60", label: "1 hour", icon: "alarm.fill", action: .setAlarm),
        ],
        defaultMicroSteps: [
            "Pick the time",
            "Choose a sound",
            "Set it and forget it",
        ],
        timerPresets: [
            TimerPreset(id: "alarm5", label: "5 min", icon: "alarm.fill", minutes: 5, color: "F87171"),
            TimerPreset(id: "alarm15", label: "15 min", icon: "alarm.fill", minutes: 15, color: "EF4444"),
            TimerPreset(id: "alarm30", label: "30 min", icon: "alarm.fill", minutes: 30, color: "DC2626"),
            TimerPreset(id: "alarm60", label: "1 hour", icon: "alarm.fill", minutes: 60, color: "B91C1C"),
        ],
        checklistSections: nil
    )
    
    // MARK: - 🏃 Exercise
    
    private static let exerciseTemplate = CategoryTemplate(
        category: .exercise,
        nudgyWhispers: [
            "one more set, let's go 💪🐧",
            "your body is going to thank you tomorrow",
            "endorphins incoming in 3... 2... 1...",
            "you're already here — that's the hardest part",
            "penguins can't do push-ups, but you can 🐧",
            "rest day was yesterday — today we move",
            "sweat is just your fat crying (sorry not sorry)",
            "30 minutes and you're done. 30 minutes!",
            "you don't have to be great, just consistent",
            "post-workout you is the happiest you 🎉",
            "music louder, excuses quieter 🎵",
            "every rep counts. even the ugly ones.",
        ],
        quickPresets: [
            QuickPreset(id: "quick7", label: "7-Min Workout", icon: "figure.highintensity.intervaltraining", action: .startTimer(minutes: 7)),
            QuickPreset(id: "stretch10", label: "10-Min Stretch", icon: "figure.flexibility", action: .startTimer(minutes: 10)),
            QuickPreset(id: "workout30", label: "30-Min Session", icon: "dumbbell.fill", action: .startTimer(minutes: 30)),
        ],
        defaultMicroSteps: [
            "Change into workout clothes",
            "Warm up (5 min)",
            "Main workout",
            "Cool down & stretch (5 min)",
            "Hydrate 💧",
        ],
        timerPresets: [
            TimerPreset(id: "ex7", label: "7 min", icon: "bolt.fill", minutes: 7, color: "FB923C"),
            TimerPreset(id: "ex15", label: "15 min", icon: "figure.run", minutes: 15, color: "F97316"),
            TimerPreset(id: "ex30", label: "30 min", icon: "dumbbell.fill", minutes: 30, color: "EA580C"),
            TimerPreset(id: "ex45", label: "45 min", icon: "figure.highintensity.intervaltraining", minutes: 45, color: "C2410C"),
            TimerPreset(id: "ex60", label: "60 min", icon: "clock.fill", minutes: 60, color: "9A3412"),
        ],
        checklistSections: ["Warm Up", "Main Set", "Cool Down"]
    )
    
    // MARK: - 🧹 Cleaning
    
    private static let cleaningTemplate = CategoryTemplate(
        category: .cleaning,
        nudgyWhispers: [
            "start with the easy room 🧹",
            "15 minutes and it'll look SO much better",
            "that counter is already looking better 🐧",
            "clean space, clear mind — it's science",
            "put on a podcast and power through",
            "you're not cleaning, you're creating a vibe ✨",
            "future you loves coming home to clean",
            "the mess didn't build overnight — 15 min is enough",
            "tackle one surface at a time, not the whole room",
            "cleaning is just aggressive organizing 🐧",
        ],
        quickPresets: [
            QuickPreset(id: "speed15", label: "15-Min Blitz", icon: "bolt.fill", action: .startTimer(minutes: 15)),
            QuickPreset(id: "speed30", label: "30-Min Deep", icon: "bubbles.and.sparkles.fill", action: .startTimer(minutes: 30)),
            QuickPreset(id: "power60", label: "Power Hour", icon: "clock.fill", action: .startTimer(minutes: 60)),
        ],
        defaultMicroSteps: [
            "Pick the messiest area",
            "Gather cleaning supplies",
            "Clear surfaces first",
            "Wipe/scrub",
            "Sweep/vacuum floor",
            "Take out trash",
        ],
        timerPresets: [
            TimerPreset(id: "clean10", label: "10 min", icon: "bolt.fill", minutes: 10, color: "7DD3FC"),
            TimerPreset(id: "clean15", label: "15 min", icon: "sparkles", minutes: 15, color: "38BDF8"),
            TimerPreset(id: "clean30", label: "30 min", icon: "bubbles.and.sparkles.fill", minutes: 30, color: "0EA5E9"),
            TimerPreset(id: "clean60", label: "60 min", icon: "clock.fill", minutes: 60, color: "0284C7"),
        ],
        checklistSections: ["Kitchen", "Bathroom", "Bedroom", "Living Room"]
    )
    
    // MARK: - 🛒 Shopping
    
    private static let shoppingTemplate = CategoryTemplate(
        category: .shopping,
        nudgyWhispers: [
            "cross 'em off one by one 🛒",
            "stick to the list — your wallet will thank you 🐧",
            "almost done, just a few more items",
            "shopping is just a quest with a cart",
            "no impulse buys today (unless it's snacks for Nudgy)",
            "you'll feel so accomplished checking these off",
            "organize by aisle — you're a shopping ninja 🥷",
            "grab and go, grab and go 🐧",
            "the checkout line is the finish line 🏁",
            "you're providing for yourself — that's awesome ✨",
        ],
        quickPresets: [],
        defaultMicroSteps: [
            "Check what you already have",
            "Write out the full list",
            "Go to the store / order online",
            "Get everything on the list",
            "Checkout",
        ],
        timerPresets: nil,
        checklistSections: ["Produce", "Dairy & Eggs", "Meat & Protein", "Pantry", "Frozen", "Household", "Other"]
    )
    
    // MARK: - 📅 Appointment
    
    private static let appointmentTemplate = CategoryTemplate(
        category: .appointment,
        nudgyWhispers: [
            "add it to your calendar so you don't forget 📅",
            "leave 10 minutes early — future you will thank you",
            "prep your questions before you go 🐧",
            "you scheduled it, now show up for yourself",
            "set a reminder so you're not scrambling last minute",
            "what do you need to bring? check now",
            "parking figured out? directions set? ✓",
            "you're being responsible and I'm proud 🐧",
            "the hardest part is showing up — and you will",
            "calendar event = commitment to yourself ✨",
        ],
        quickPresets: [
            QuickPreset(id: "addcal", label: "Add to Calendar", icon: "calendar.badge.plus", action: .addToCalendar),
            QuickPreset(id: "maps", label: "Get Directions", icon: "map.fill", action: .openMaps),
        ],
        defaultMicroSteps: [
            "Add to calendar with address",
            "Set a leave-by reminder",
            "Prepare any documents/questions",
            "Confirm the appointment",
            "Go and show up!",
        ],
        timerPresets: nil,
        checklistSections: ["Prep", "Bring With"]
    )
    
    // MARK: - 💰 Finance
    
    private static let financeTemplate = CategoryTemplate(
        category: .finance,
        nudgyWhispers: [
            "one tap, bill's gone 💸",
            "adulting is just paying bills and pretending to know taxes",
            "your credit score appreciates this 🐧",
            "pay it now, peace of mind forever",
            "money management = self-care (trust me)",
            "late fees are the enemy — defeat them today",
            "future you is thanking present you right now",
            "check the amount, hit pay, done ✓",
            "financial responsibility looks good on you 🐧",
            "this is the least fun but most important task today",
        ],
        quickPresets: [],
        defaultMicroSteps: [
            "Check the amount due",
            "Verify the due date",
            "Make the payment",
            "Save the confirmation",
        ],
        timerPresets: nil,
        checklistSections: nil
    )
    
    // MARK: - 💊 Health
    
    private static let healthTemplate = CategoryTemplate(
        category: .health,
        nudgyWhispers: [
            "meds taken ✓ — streak going strong 💊",
            "taking care of yourself IS the priority",
            "your body is your first home — maintain it 🐧",
            "one small pill, one giant leap for your health",
            "consistency is the real medicine",
            "you remembered! that's the hardest part",
            "health tasks feel boring but they're pure self-love",
            "Nudgy is proud of your health streak 🐧✨",
            "refills checked? dosage right? you're a pro",
            "your future self is healthier because of today",
        ],
        quickPresets: [],
        defaultMicroSteps: [
            "Check dosage / instructions",
            "Take medication / complete task",
            "Log it as done",
        ],
        timerPresets: nil,
        checklistSections: ["Morning", "Afternoon", "Evening", "As Needed"]
    )
    
    // MARK: - 🎨 Creative
    
    private static let creativeTemplate = CategoryTemplate(
        category: .creative,
        nudgyWhispers: [
            "just start, don't judge it 🎨",
            "perfection is the enemy of done — create messy",
            "your creative brain needs play, not pressure 🐧",
            "the muse shows up AFTER you start, not before",
            "no one's watching — this is for you",
            "10 minutes of creating > 0 minutes of planning",
            "inspiration is a myth — action is real ✨",
            "every masterpiece started as a blank page",
            "create something ugly today. then make it less ugly.",
            "you're an artist even when you don't feel like one 🐧",
            "put the phone down. pick up the [tool]. go.",
            "the world needs your weird — don't hold it back",
        ],
        quickPresets: [
            QuickPreset(id: "create30", label: "30 min Create", icon: "paintbrush.fill", action: .startFocus(focusMinutes: 30, breakMinutes: 5)),
            QuickPreset(id: "freewrite", label: "Free Write", icon: "pencil.line", action: .startFocus(focusMinutes: 15, breakMinutes: 0)),
        ],
        defaultMicroSteps: [
            "Set up your workspace",
            "Silence distractions",
            "Start with anything — don't judge",
            "Work for at least 15 minutes",
            "Step back and appreciate what you made",
        ],
        timerPresets: [
            TimerPreset(id: "create15", label: "15 min sketch", icon: "pencil.tip", minutes: 15, color: "C084FC"),
            TimerPreset(id: "create30", label: "30 min session", icon: "paintbrush.fill", minutes: 30, color: "A855F7"),
            TimerPreset(id: "create60", label: "60 min deep", icon: "paintpalette.fill", minutes: 60, color: "7C3AED"),
        ],
        checklistSections: nil
    )
    
    // MARK: - 🚗 Errand
    
    private static let errandTemplate = CategoryTemplate(
        category: .errand,
        nudgyWhispers: [
            "3 stops, start with the closest 🚗",
            "errands are just side quests IRL 🐧",
            "keys, wallet, phone — let's roll",
            "batch your errands to save time and gas",
            "you'll be home before you know it",
            "one errand at a time — don't overwhelm yourself",
            "driving time = podcast time 🎧",
            "cross it off the list and keep moving",
            "adulting level: running errands unprompted ✨",
            "the couch will still be there when you're back 🐧",
        ],
        quickPresets: [
            QuickPreset(id: "directions", label: "Get Directions", icon: "map.fill", action: .openMaps),
        ],
        defaultMicroSteps: [
            "Plan your route",
            "Grab everything you need",
            "Drive to location",
            "Complete the errand",
            "Head home (or to the next stop)",
        ],
        timerPresets: nil,
        checklistSections: nil
    )
    
    // MARK: - 🧘 Self-Care
    
    private static let selfCareTemplate = CategoryTemplate(
        category: .selfCare,
        nudgyWhispers: [
            "you deserve this pause 🧘",
            "self-care isn't selfish — it's necessary",
            "breathe in calm, breathe out chaos 🐧",
            "your mental health matters more than your to-do list",
            "this moment is just for you ✨",
            "even penguins take breaks from swimming 🐧",
            "rest is productive — your brain needs it",
            "check in with yourself: how are you really feeling?",
            "you can't pour from an empty cup",
            "taking care of yourself = taking care of everything else",
        ],
        quickPresets: [
            QuickPreset(id: "breathe478", label: "4-7-8 Breathing", icon: "wind", action: .startBreathing(pattern: .box478)),
            QuickPreset(id: "breathe444", label: "Box Breathing", icon: "square.dashed", action: .startBreathing(pattern: .box444)),
            QuickPreset(id: "meditate10", label: "10 min Calm", icon: "sparkles", action: .startTimer(minutes: 10)),
        ],
        defaultMicroSteps: [
            "Find a quiet, comfortable spot",
            "Put your phone on Do Not Disturb",
            "Close your eyes and breathe",
            "Do your self-care activity",
            "Return gently — no rush",
        ],
        timerPresets: [
            TimerPreset(id: "care5", label: "5 min", icon: "sparkles", minutes: 5, color: "A78BFA"),
            TimerPreset(id: "care10", label: "10 min", icon: "moon.fill", minutes: 10, color: "8B5CF6"),
            TimerPreset(id: "care20", label: "20 min", icon: "heart.fill", minutes: 20, color: "7C3AED"),
        ],
        checklistSections: nil
    )
    
    // MARK: - 💼 Work
    
    private static let workTemplate = CategoryTemplate(
        category: .work,
        nudgyWhispers: [
            "prep done = confidence up 💼",
            "one task at a time — multitasking is a lie 🐧",
            "deep work mode: ON 🎯",
            "you're good at this — trust the process",
            "meeting prep takes 10 minutes but saves 60",
            "block your calendar, protect your focus",
            "you've done harder things than this work task",
            "professional growth happens one task at a time",
            "get this done, then reward yourself ✨",
            "your career is a marathon, not a sprint — but do this today 🐧",
        ],
        quickPresets: [
            QuickPreset(id: "focus25", label: "25 min Focus", icon: "brain.head.profile.fill", action: .startFocus(focusMinutes: 25, breakMinutes: 5)),
            QuickPreset(id: "focus50", label: "50 min Deep", icon: "clock.fill", action: .startFocus(focusMinutes: 50, breakMinutes: 10)),
        ],
        defaultMicroSteps: [
            "Review what needs to be done",
            "Gather materials / open docs",
            "Set a timer and start",
            "Complete the core work",
            "Review / send / submit",
        ],
        timerPresets: [
            TimerPreset(id: "work25", label: "25 min", icon: "timer", minutes: 25, color: "60A5FA"),
            TimerPreset(id: "work50", label: "50 min", icon: "brain.head.profile.fill", minutes: 50, color: "3B82F6"),
            TimerPreset(id: "work90", label: "90 min block", icon: "clock.fill", minutes: 90, color: "2563EB"),
        ],
        checklistSections: ["Prep", "Agenda Items", "Follow-ups"]
    )
    
    // MARK: - 👥 Social
    
    private static let socialTemplate = CategoryTemplate(
        category: .social,
        nudgyWhispers: [
            "text them back, they'll love it 👥",
            "connections are everything — water this one 🌱",
            "you're a good friend for following through 🐧",
            "social battery might be low, but this one's worth it",
            "plans with people > plans with your couch (sometimes)",
            "RSVP now before you forget and feel guilty later",
            "your people miss you — show up ✨",
            "quality time is the best time",
            "making plans is hard. keeping them is harder. you'll do both. 🐧",
            "future you will be glad you said yes",
        ],
        quickPresets: [
            QuickPreset(id: "addcal", label: "Add to Calendar", icon: "calendar.badge.plus", action: .addToCalendar),
        ],
        defaultMicroSteps: [
            "Confirm the details (when, where)",
            "Add to calendar",
            "Prepare anything needed",
            "Show up and have fun!",
        ],
        timerPresets: nil,
        checklistSections: nil
    )
    
    // MARK: - 🔧 Maintenance
    
    private static let maintenanceTemplate = CategoryTemplate(
        category: .maintenance,
        nudgyWhispers: [
            "YouTube tutorial queued up? let's go 🔧",
            "you're handier than you think 🐧",
            "before: broken. after: fixed by YOU ✨",
            "every fix saved is money in your pocket",
            "the tools are ready, the tutorial is loaded — start",
            "take a before photo — the after will be so satisfying",
            "if it's more than you can handle, calling a pro is also winning",
            "one screw at a time 🐧",
            "you're literally building your life (or at least fixing it)",
            "maintenance now = no emergency later",
        ],
        quickPresets: [],
        defaultMicroSteps: [
            "Watch a how-to video",
            "Gather tools and parts",
            "Follow the steps carefully",
            "Test the fix",
            "Clean up your workspace",
        ],
        timerPresets: nil,
        checklistSections: ["Tools Needed", "Steps"]
    )
    
    // MARK: - 📌 General
    
    private static let generalTemplate = CategoryTemplate(
        category: .general,
        nudgyWhispers: [
            "break it down, one step at a time 📌",
            "you added this for a reason — trust past you 🐧",
            "the first step is always the hardest",
            "you don't have to do it perfectly, just do it",
            "5 minutes of progress > 0 minutes of perfection",
            "whatever this is, you can handle it ✨",
            "just start — momentum will carry you",
            "your to-do list believes in you. so does Nudgy. 🐧",
            "one task at a time. that's the superpower.",
            "done is better than perfect — always",
        ],
        quickPresets: [
            QuickPreset(id: "focus15", label: "15 min Sprint", icon: "bolt.fill", action: .startFocus(focusMinutes: 15, breakMinutes: 3)),
        ],
        defaultMicroSteps: [
            "Figure out the first tiny step",
            "Do that step",
            "Figure out the next step",
            "Repeat until done",
        ],
        timerPresets: [
            TimerPreset(id: "gen10", label: "10 min", icon: "timer", minutes: 10, color: "9CA3AF"),
            TimerPreset(id: "gen15", label: "15 min", icon: "bolt.fill", minutes: 15, color: "6B7280"),
            TimerPreset(id: "gen25", label: "25 min", icon: "timer", minutes: 25, color: "4B5563"),
        ],
        checklistSections: nil
    )
}
