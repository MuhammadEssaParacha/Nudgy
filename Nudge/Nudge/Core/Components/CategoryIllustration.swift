//
//  CategoryIllustration.swift
//  Nudge
//
//  Rich category-based illustration system using Apple's native emoji
//  rendered large inside tinted gradient circles.
//
//  Apple emoji ARE the "in-house memoji" — full-color, high-res artwork
//  that scales beautifully on iOS. Each task gets a personalized emoji
//  icon based on content keyword matching against 200+ category patterns.
//
//  Architecture:
//    1. CategoryMatcher scans task content → picks best CategoryStyle
//    2. CategoryStyle has both an `emoji` (primary) and `symbol` (SF fallback)
//    3. CategoryIllustrationView renders the emoji large inside a gradient circle
//    4. If item already has an explicit emoji, it's used directly
//

import SwiftUI

// MARK: - Category Style

/// A visual category with Apple emoji icon, color palette, and personality.
struct CategoryStyle {
    let id: String
    let emoji: String                 // Apple emoji character (primary icon)
    let symbol: String                // SF Symbol fallback
    let gradientColors: [String]      // Hex pair for background gradient
    let label: String                 // Human-readable category name
    
    var primaryColor: Color { Color(hex: gradientColors[0]) }
    var secondaryColor: Color { Color(hex: gradientColors.count > 1 ? gradientColors[1] : gradientColors[0]) }
}

// MARK: - Category Illustration View

/// A rich, personalized task icon using Apple emoji inside a gradient circle.
/// Apple emoji at 22pt+ render as full-color bitmap artwork — stunning on iOS.
struct CategoryIllustrationView: View {
    
    let item: NudgeItem
    var size: CGFloat = 44
    
    private var style: CategoryStyle {
        CategoryMatcher.match(
            content: item.content,
            emoji: item.emoji,
            actionType: item.actionType,
            contactName: item.contactName
        )
    }
    
    /// If the item has an explicit emoji, resolve its SF Symbol
    private var displaySymbol: String {
        if let itemEmoji = item.emoji, !itemEmoji.isEmpty {
            return TaskIconResolver.resolveSymbol(for: itemEmoji)
        }
        return style.symbol
    }
    
    var body: some View {
        let s = style
        let iconSize = size * 0.45
        
        ZStack {
            // Background gradient circle with subtle glow
            Circle()
                .fill(
                    LinearGradient(
                        colors: [s.primaryColor.opacity(0.22), s.secondaryColor.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [s.primaryColor.opacity(0.25), s.secondaryColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                )
            
            // SF Symbol rendered crisp at any size
            Image(systemName: displaySymbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(s.primaryColor)
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
        .nudgeAccessibility(
            label: s.label,
            hint: "",
            traits: .isImage
        )
    }
}

// MARK: - Compact variant (for inline use)

struct CategoryIllustrationCompact: View {
    let content: String
    let emoji: String?
    var actionType: ActionType? = nil
    var size: CGFloat = 36
    
    private var style: CategoryStyle {
        CategoryMatcher.match(content: content, emoji: emoji, actionType: actionType, contactName: nil)
    }
    
    private var displaySymbol: String {
        if let emoji, !emoji.isEmpty { return TaskIconResolver.resolveSymbol(for: emoji) }
        return style.symbol
    }
    
    var body: some View {
        let s = style
        let iconSize = size * 0.42
        
        Image(systemName: displaySymbol)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(s.primaryColor)
            .minimumScaleFactor(0.7)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [s.primaryColor.opacity(0.18), s.secondaryColor.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}

// MARK: - Category Matcher

/// Scans task content and metadata to find the best visual category.
/// 200+ keyword patterns organized by life domain.
nonisolated enum CategoryMatcher {
    
    static func match(
        content: String,
        emoji: String?,
        actionType: ActionType?,
        contactName: String?
    ) -> CategoryStyle {
        let text = content.lowercased()
        
        // 1. If item has an explicit emoji, find a matching category style for color
        if let emoji, let style = emojiToCategoryStyle[emoji] {
            return style
        }
        
        // 2. Try action type
        if let actionType {
            switch actionType {
            case .call:          return categories["call"]!
            case .text:          return categories["text"]!
            case .email:         return categories["email"]!
            case .openLink:      return categories["browse"]!
            case .search:        return categories["search"]!
            case .navigate:      return categories["navigate"]!
            case .addToCalendar: return categories["calendar"]!
            case .setAlarm:      return categories["deadline"]!
            }
        }
        
        // 3. Keyword scanning — check each category's keywords
        for (id, keywords) in keywordMap {
            for keyword in keywords {
                if text.contains(keyword) {
                    return categories[id]!
                }
            }
        }
        
        // 4. Contact-based fallback
        if contactName != nil {
            return categories["people"]!
        }
        
        // 5. Default
        return categories["general"]!
    }
    
    // MARK: - Category Definitions (Apple emoji + gradient colors)
    
    static let categories: [String: CategoryStyle] = [
        // ── Communication ──────────────────────────
        "call":       CategoryStyle(id: "call", emoji: "📞", symbol: "phone.fill", gradientColors: ["34D399", "10B981"], label: "Phone Call"),
        "text":       CategoryStyle(id: "text", emoji: "💬", symbol: "message.fill", gradientColors: ["60A5FA", "3B82F6"], label: "Message"),
        "email":      CategoryStyle(id: "email", emoji: "📧", symbol: "envelope.fill", gradientColors: ["818CF8", "6366F1"], label: "Email"),
        "voicemail":  CategoryStyle(id: "voicemail", emoji: "📼", symbol: "recordingtape", gradientColors: ["F472B6", "EC4899"], label: "Voicemail"),
        "reply":      CategoryStyle(id: "reply", emoji: "↩️", symbol: "arrowshape.turn.up.left.fill", gradientColors: ["60A5FA", "3B82F6"], label: "Reply"),
        
        // ── People & Social ────────────────────────
        "people":     CategoryStyle(id: "people", emoji: "👥", symbol: "person.2.fill", gradientColors: ["A78BFA", "8B5CF6"], label: "People"),
        "family":     CategoryStyle(id: "family", emoji: "👨‍👩‍👧", symbol: "figure.2.and.child.holdinghands", gradientColors: ["F9A8D4", "F472B6"], label: "Family"),
        "friend":     CategoryStyle(id: "friend", emoji: "🤗", symbol: "heart.circle.fill", gradientColors: ["FB923C", "F97316"], label: "Friends"),
        "birthday":   CategoryStyle(id: "birthday", emoji: "🎂", symbol: "gift.fill", gradientColors: ["F472B6", "EC4899"], label: "Birthday"),
        "wedding":    CategoryStyle(id: "wedding", emoji: "💍", symbol: "heart.text.clipboard.fill", gradientColors: ["FDE68A", "F59E0B"], label: "Wedding"),
        "date":       CategoryStyle(id: "date", emoji: "💕", symbol: "heart.fill", gradientColors: ["FB7185", "F43F5E"], label: "Date Night"),
        "baby":       CategoryStyle(id: "baby", emoji: "👶", symbol: "stroller.fill", gradientColors: ["93C5FD", "60A5FA"], label: "Baby"),
        "gift":       CategoryStyle(id: "gift", emoji: "🎁", symbol: "gift.fill", gradientColors: ["C084FC", "A855F7"], label: "Gift"),
        "party":      CategoryStyle(id: "party", emoji: "🎉", symbol: "party.popper.fill", gradientColors: ["FDE68A", "F59E0B"], label: "Party"),
        
        // ── Health & Wellness ──────────────────────
        "medication": CategoryStyle(id: "medication", emoji: "💊", symbol: "pills.fill", gradientColors: ["34D399", "10B981"], label: "Medication"),
        "doctor":     CategoryStyle(id: "doctor", emoji: "🩺", symbol: "stethoscope", gradientColors: ["6EE7B7", "34D399"], label: "Doctor"),
        "dentist":    CategoryStyle(id: "dentist", emoji: "🦷", symbol: "mouth.fill", gradientColors: ["93C5FD", "60A5FA"], label: "Dentist"),
        "therapy":    CategoryStyle(id: "therapy", emoji: "🧠", symbol: "brain.head.profile.fill", gradientColors: ["C4B5FD", "A78BFA"], label: "Therapy"),
        "workout":    CategoryStyle(id: "workout", emoji: "🏋️", symbol: "dumbbell.fill", gradientColors: ["FB923C", "F97316"], label: "Workout"),
        "yoga":       CategoryStyle(id: "yoga", emoji: "🧘", symbol: "figure.mind.and.body", gradientColors: ["A78BFA", "8B5CF6"], label: "Yoga"),
        "meditation": CategoryStyle(id: "meditation", emoji: "✨", symbol: "sparkles", gradientColors: ["C4B5FD", "A78BFA"], label: "Meditation"),
        "sleep":      CategoryStyle(id: "sleep", emoji: "😴", symbol: "moon.zzz.fill", gradientColors: ["818CF8", "6366F1"], label: "Sleep"),
        "nutrition":  CategoryStyle(id: "nutrition", emoji: "🥗", symbol: "leaf.fill", gradientColors: ["6EE7B7", "34D399"], label: "Nutrition"),
        "hydrate":    CategoryStyle(id: "hydrate", emoji: "💧", symbol: "drop.fill", gradientColors: ["7DD3FC", "38BDF8"], label: "Hydration"),
        "walk":       CategoryStyle(id: "walk", emoji: "🚶", symbol: "figure.walk", gradientColors: ["86EFAC", "4ADE80"], label: "Walk"),
        "run":        CategoryStyle(id: "run", emoji: "🏃", symbol: "figure.run", gradientColors: ["FB923C", "F97316"], label: "Run"),
        "swim":       CategoryStyle(id: "swim", emoji: "🏊", symbol: "figure.pool.swim", gradientColors: ["38BDF8", "0EA5E9"], label: "Swim"),
        "cycle":      CategoryStyle(id: "cycle", emoji: "🚴", symbol: "figure.outdoor.cycle", gradientColors: ["4ADE80", "22C55E"], label: "Cycling"),
        "stretch":    CategoryStyle(id: "stretch", emoji: "🤸", symbol: "figure.flexibility", gradientColors: ["FBBF24", "F59E0B"], label: "Stretch"),
        "skincare":   CategoryStyle(id: "skincare", emoji: "🧴", symbol: "face.smiling.inverse", gradientColors: ["F9A8D4", "F472B6"], label: "Skincare"),
        "vitamins":   CategoryStyle(id: "vitamins", emoji: "💉", symbol: "pill.fill", gradientColors: ["FCD34D", "FBBF24"], label: "Vitamins"),
        
        // ── Home & Chores ──────────────────────────
        "clean":      CategoryStyle(id: "clean", emoji: "🧹", symbol: "bubbles.and.sparkles.fill", gradientColors: ["7DD3FC", "38BDF8"], label: "Cleaning"),
        "laundry":    CategoryStyle(id: "laundry", emoji: "👕", symbol: "washer.fill", gradientColors: ["93C5FD", "60A5FA"], label: "Laundry"),
        "dishes":     CategoryStyle(id: "dishes", emoji: "🍽️", symbol: "sink.fill", gradientColors: ["6EE7B7", "34D399"], label: "Dishes"),
        "cook":       CategoryStyle(id: "cook", emoji: "🍳", symbol: "frying.pan.fill", gradientColors: ["FBBF24", "F59E0B"], label: "Cooking"),
        "grocery":    CategoryStyle(id: "grocery", emoji: "🛒", symbol: "cart.fill", gradientColors: ["4ADE80", "22C55E"], label: "Grocery"),
        "plant":      CategoryStyle(id: "plant", emoji: "🪴", symbol: "leaf.fill", gradientColors: ["34D399", "10B981"], label: "Plants"),
        "trash":      CategoryStyle(id: "trash", emoji: "🗑️", symbol: "trash.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Trash"),
        "organize":   CategoryStyle(id: "organize", emoji: "📦", symbol: "square.stack.3d.up.fill", gradientColors: ["C084FC", "A855F7"], label: "Organize"),
        "repair":     CategoryStyle(id: "repair", emoji: "🔧", symbol: "wrench.and.screwdriver.fill", gradientColors: ["FB923C", "F97316"], label: "Repair"),
        "decor":      CategoryStyle(id: "decor", emoji: "🛋️", symbol: "lamp.table.fill", gradientColors: ["FDE68A", "FBBF24"], label: "Home Decor"),
        "move":       CategoryStyle(id: "move", emoji: "📦", symbol: "shippingbox.fill", gradientColors: ["A78BFA", "8B5CF6"], label: "Moving"),
        "garden":     CategoryStyle(id: "garden", emoji: "🌳", symbol: "tree.fill", gradientColors: ["4ADE80", "22C55E"], label: "Garden"),
        "vacuum":     CategoryStyle(id: "vacuum", emoji: "🧽", symbol: "humidifier.and.droplets.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Vacuum"),
        "mow":        CategoryStyle(id: "mow", emoji: "🌿", symbol: "leaf.fill", gradientColors: ["86EFAC", "4ADE80"], label: "Lawn"),
        
        // ── Pets ───────────────────────────────────
        "pet":        CategoryStyle(id: "pet", emoji: "🐾", symbol: "pawprint.fill", gradientColors: ["FBBF24", "F59E0B"], label: "Pet Care"),
        "dog":        CategoryStyle(id: "dog", emoji: "🐶", symbol: "dog.fill", gradientColors: ["FB923C", "F97316"], label: "Dog"),
        "cat":        CategoryStyle(id: "cat", emoji: "🐱", symbol: "cat.fill", gradientColors: ["A78BFA", "8B5CF6"], label: "Cat"),
        "vet":        CategoryStyle(id: "vet", emoji: "🏥", symbol: "cross.case.fill", gradientColors: ["34D399", "10B981"], label: "Vet"),
        "walk_dog":   CategoryStyle(id: "walk_dog", emoji: "🐕‍🦺", symbol: "figure.walk.motion", gradientColors: ["86EFAC", "4ADE80"], label: "Dog Walk"),
        
        // ── Work & Career ──────────────────────────
        "meeting":    CategoryStyle(id: "meeting", emoji: "🤝", symbol: "person.3.fill", gradientColors: ["60A5FA", "3B82F6"], label: "Meeting"),
        "deadline":   CategoryStyle(id: "deadline", emoji: "⏰", symbol: "alarm.fill", gradientColors: ["F87171", "EF4444"], label: "Deadline"),
        "present":    CategoryStyle(id: "present", emoji: "📊", symbol: "chart.bar.doc.horizontal.fill", gradientColors: ["818CF8", "6366F1"], label: "Presentation"),
        "report":     CategoryStyle(id: "report", emoji: "📝", symbol: "doc.text.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Report"),
        "review":     CategoryStyle(id: "review", emoji: "✅", symbol: "checkmark.rectangle.stack.fill", gradientColors: ["60A5FA", "3B82F6"], label: "Review"),
        "apply":      CategoryStyle(id: "apply", emoji: "📮", symbol: "paperplane.fill", gradientColors: ["818CF8", "6366F1"], label: "Application"),
        "interview":  CategoryStyle(id: "interview", emoji: "🎤", symbol: "person.badge.clock.fill", gradientColors: ["A78BFA", "8B5CF6"], label: "Interview"),
        "resign":     CategoryStyle(id: "resign", emoji: "🚪", symbol: "rectangle.portrait.and.arrow.right.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Work Transition"),
        "salary":     CategoryStyle(id: "salary", emoji: "💵", symbol: "banknote.fill", gradientColors: ["34D399", "10B981"], label: "Salary"),
        "project":    CategoryStyle(id: "project", emoji: "💼", symbol: "folder.fill.badge.gearshape", gradientColors: ["60A5FA", "3B82F6"], label: "Project"),
        "slack":      CategoryStyle(id: "slack", emoji: "💻", symbol: "bubble.left.and.text.bubble.right.fill", gradientColors: ["C084FC", "A855F7"], label: "Chat"),
        
        // ── Finance ────────────────────────────────
        "pay":        CategoryStyle(id: "pay", emoji: "💳", symbol: "creditcard.fill", gradientColors: ["4ADE80", "22C55E"], label: "Payment"),
        "bill":       CategoryStyle(id: "bill", emoji: "🧾", symbol: "doc.text.fill", gradientColors: ["FB923C", "F97316"], label: "Bill"),
        "budget":     CategoryStyle(id: "budget", emoji: "📉", symbol: "chart.pie.fill", gradientColors: ["818CF8", "6366F1"], label: "Budget"),
        "invest":     CategoryStyle(id: "invest", emoji: "📈", symbol: "chart.line.uptrend.xyaxis", gradientColors: ["34D399", "10B981"], label: "Investing"),
        "tax":        CategoryStyle(id: "tax", emoji: "🏛️", symbol: "building.columns.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Tax"),
        "bank":       CategoryStyle(id: "bank", emoji: "🏦", symbol: "building.columns.fill", gradientColors: ["60A5FA", "3B82F6"], label: "Banking"),
        "insurance":  CategoryStyle(id: "insurance", emoji: "🛡️", symbol: "shield.checkered", gradientColors: ["818CF8", "6366F1"], label: "Insurance"),
        "subscribe":  CategoryStyle(id: "subscribe", emoji: "🔄", symbol: "arrow.triangle.2.circlepath", gradientColors: ["C084FC", "A855F7"], label: "Subscription"),
        "refund":     CategoryStyle(id: "refund", emoji: "💸", symbol: "arrow.uturn.backward.circle.fill", gradientColors: ["34D399", "10B981"], label: "Refund"),
        "rent":       CategoryStyle(id: "rent", emoji: "🏠", symbol: "house.fill", gradientColors: ["FB923C", "F97316"], label: "Rent"),
        
        // ── Shopping ───────────────────────────────
        "shop":       CategoryStyle(id: "shop", emoji: "🛍️", symbol: "bag.fill", gradientColors: ["F472B6", "EC4899"], label: "Shopping"),
        "order":      CategoryStyle(id: "order", emoji: "📦", symbol: "shippingbox.fill", gradientColors: ["FB923C", "F97316"], label: "Order"),
        "return":     CategoryStyle(id: "return", emoji: "↩️", symbol: "arrow.uturn.backward.square.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Return"),
        "pickup":     CategoryStyle(id: "pickup", emoji: "🏪", symbol: "bag.fill.badge.plus", gradientColors: ["60A5FA", "3B82F6"], label: "Pickup"),
        "amazon":     CategoryStyle(id: "amazon", emoji: "📬", symbol: "shippingbox.and.arrow.backward.fill", gradientColors: ["FBBF24", "F59E0B"], label: "Delivery"),
        
        // ── Education & Learning ───────────────────
        "study":      CategoryStyle(id: "study", emoji: "📚", symbol: "book.fill", gradientColors: ["818CF8", "6366F1"], label: "Study"),
        "read":       CategoryStyle(id: "read", emoji: "📖", symbol: "book.fill", gradientColors: ["A78BFA", "8B5CF6"], label: "Reading"),
        "homework":   CategoryStyle(id: "homework", emoji: "📝", symbol: "pencil.and.list.clipboard", gradientColors: ["60A5FA", "3B82F6"], label: "Homework"),
        "course":     CategoryStyle(id: "course", emoji: "🎓", symbol: "graduationcap.fill", gradientColors: ["C084FC", "A855F7"], label: "Course"),
        "practice":   CategoryStyle(id: "practice", emoji: "🎶", symbol: "music.note.list", gradientColors: ["FBBF24", "F59E0B"], label: "Practice"),
        "write":      CategoryStyle(id: "write", emoji: "✍️", symbol: "pencil.line", gradientColors: ["A78BFA", "8B5CF6"], label: "Writing"),
        "research":   CategoryStyle(id: "research", emoji: "🔬", symbol: "magnifyingglass.circle.fill", gradientColors: ["818CF8", "6366F1"], label: "Research"),
        "podcast":    CategoryStyle(id: "podcast", emoji: "🎙️", symbol: "antenna.radiowaves.left.and.right", gradientColors: ["C084FC", "A855F7"], label: "Podcast"),
        "language":   CategoryStyle(id: "language", emoji: "🌍", symbol: "globe", gradientColors: ["38BDF8", "0EA5E9"], label: "Language"),
        
        // ── Tech & Digital ─────────────────────────
        "code":       CategoryStyle(id: "code", emoji: "👨‍💻", symbol: "chevron.left.forwardslash.chevron.right", gradientColors: ["34D399", "10B981"], label: "Code"),
        "update":     CategoryStyle(id: "update", emoji: "⬇️", symbol: "arrow.down.circle.fill", gradientColors: ["60A5FA", "3B82F6"], label: "Update"),
        "password":   CategoryStyle(id: "password", emoji: "🔑", symbol: "key.fill", gradientColors: ["FBBF24", "F59E0B"], label: "Password"),
        "backup":     CategoryStyle(id: "backup", emoji: "💾", symbol: "externaldrive.fill.badge.timemachine", gradientColors: ["9CA3AF", "6B7280"], label: "Backup"),
        "download":   CategoryStyle(id: "download", emoji: "📥", symbol: "arrow.down.to.line.circle.fill", gradientColors: ["60A5FA", "3B82F6"], label: "Download"),
        "print":      CategoryStyle(id: "print", emoji: "🖨️", symbol: "printer.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Print"),
        "photo":      CategoryStyle(id: "photo", emoji: "📸", symbol: "photo.fill", gradientColors: ["F472B6", "EC4899"], label: "Photo"),
        "browse":     CategoryStyle(id: "browse", emoji: "🌐", symbol: "safari.fill", gradientColors: ["38BDF8", "0EA5E9"], label: "Browse"),
        "search":     CategoryStyle(id: "search", emoji: "🔍", symbol: "magnifyingglass", gradientColors: ["60A5FA", "3B82F6"], label: "Search"),
        "app":        CategoryStyle(id: "app", emoji: "📱", symbol: "app.badge.fill", gradientColors: ["818CF8", "6366F1"], label: "App"),
        
        // ── Travel & Transport ─────────────────────
        "travel":     CategoryStyle(id: "travel", emoji: "✈️", symbol: "airplane", gradientColors: ["38BDF8", "0EA5E9"], label: "Travel"),
        "navigate":   CategoryStyle(id: "navigate", emoji: "📍", symbol: "location.fill", gradientColors: ["F87171", "EF4444"], label: "Navigation"),
        "car":        CategoryStyle(id: "car", emoji: "🚗", symbol: "car.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Car"),
        "gas":        CategoryStyle(id: "gas", emoji: "⛽", symbol: "fuelpump.fill", gradientColors: ["FB923C", "F97316"], label: "Gas"),
        "flight":     CategoryStyle(id: "flight", emoji: "🛫", symbol: "airplane.departure", gradientColors: ["60A5FA", "3B82F6"], label: "Flight"),
        "hotel":      CategoryStyle(id: "hotel", emoji: "🏨", symbol: "building.2.fill", gradientColors: ["818CF8", "6366F1"], label: "Hotel"),
        "pack":       CategoryStyle(id: "pack", emoji: "🧳", symbol: "suitcase.fill", gradientColors: ["FBBF24", "F59E0B"], label: "Pack"),
        "uber":       CategoryStyle(id: "uber", emoji: "🚕", symbol: "car.side.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Ride"),
        "passport":   CategoryStyle(id: "passport", emoji: "🛂", symbol: "person.text.rectangle.fill", gradientColors: ["818CF8", "6366F1"], label: "Passport"),
        
        // ── Calendar & Scheduling ──────────────────
        "calendar":   CategoryStyle(id: "calendar", emoji: "📅", symbol: "calendar.badge.clock", gradientColors: ["F87171", "EF4444"], label: "Calendar"),
        "schedule":   CategoryStyle(id: "schedule", emoji: "🕐", symbol: "clock.fill", gradientColors: ["60A5FA", "3B82F6"], label: "Schedule"),
        "remind":     CategoryStyle(id: "remind", emoji: "🔔", symbol: "bell.badge.fill", gradientColors: ["FBBF24", "F59E0B"], label: "Reminder"),
        "appt":       CategoryStyle(id: "appt", emoji: "📋", symbol: "calendar.badge.checkmark", gradientColors: ["34D399", "10B981"], label: "Appointment"),
        "rsvp":       CategoryStyle(id: "rsvp", emoji: "💌", symbol: "envelope.open.fill", gradientColors: ["C084FC", "A855F7"], label: "RSVP"),
        
        // ── Creative ───────────────────────────────
        "music":      CategoryStyle(id: "music", emoji: "🎵", symbol: "music.note", gradientColors: ["F472B6", "EC4899"], label: "Music"),
        "art":        CategoryStyle(id: "art", emoji: "🎨", symbol: "paintbrush.fill", gradientColors: ["C084FC", "A855F7"], label: "Art"),
        "design":     CategoryStyle(id: "design", emoji: "🖌️", symbol: "paintpalette.fill", gradientColors: ["F472B6", "EC4899"], label: "Design"),
        "video":      CategoryStyle(id: "video", emoji: "🎬", symbol: "video.fill", gradientColors: ["F87171", "EF4444"], label: "Video"),
        "stream":     CategoryStyle(id: "stream", emoji: "📺", symbol: "play.rectangle.fill", gradientColors: ["C084FC", "A855F7"], label: "Stream"),
        "guitar":     CategoryStyle(id: "guitar", emoji: "🎸", symbol: "guitars.fill", gradientColors: ["FBBF24", "F59E0B"], label: "Guitar"),
        "piano":      CategoryStyle(id: "piano", emoji: "🎹", symbol: "pianokeys", gradientColors: ["9CA3AF", "6B7280"], label: "Piano"),
        "sing":       CategoryStyle(id: "sing", emoji: "🎤", symbol: "mic.fill", gradientColors: ["F472B6", "EC4899"], label: "Singing"),
        "craft":      CategoryStyle(id: "craft", emoji: "🧶", symbol: "scissors", gradientColors: ["FB923C", "F97316"], label: "Craft"),
        
        // ── Self Care & Routine ────────────────────
        "shower":     CategoryStyle(id: "shower", emoji: "🚿", symbol: "shower.fill", gradientColors: ["7DD3FC", "38BDF8"], label: "Shower"),
        "haircut":    CategoryStyle(id: "haircut", emoji: "💇", symbol: "scissors", gradientColors: ["FB923C", "F97316"], label: "Haircut"),
        "morning":    CategoryStyle(id: "morning", emoji: "🌅", symbol: "sunrise.fill", gradientColors: ["FDE68A", "FBBF24"], label: "Morning Routine"),
        "evening":    CategoryStyle(id: "evening", emoji: "🌙", symbol: "moon.stars.fill", gradientColors: ["818CF8", "6366F1"], label: "Evening Routine"),
        "journal":    CategoryStyle(id: "journal", emoji: "📓", symbol: "book.closed.fill", gradientColors: ["A78BFA", "8B5CF6"], label: "Journal"),
        "breathe":    CategoryStyle(id: "breathe", emoji: "🌬️", symbol: "wind", gradientColors: ["7DD3FC", "38BDF8"], label: "Breathing"),
        "nap":        CategoryStyle(id: "nap", emoji: "😴", symbol: "zzz", gradientColors: ["C4B5FD", "A78BFA"], label: "Nap"),
        
        // ── Admin & Errands ────────────────────────
        "dmv":        CategoryStyle(id: "dmv", emoji: "🪪", symbol: "car.circle.fill", gradientColors: ["9CA3AF", "6B7280"], label: "DMV"),
        "post":       CategoryStyle(id: "post", emoji: "📮", symbol: "envelope.fill", gradientColors: ["F87171", "EF4444"], label: "Post Office"),
        "form":       CategoryStyle(id: "form", emoji: "📋", symbol: "doc.on.clipboard.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Paperwork"),
        "sign":       CategoryStyle(id: "sign", emoji: "🖊️", symbol: "signature", gradientColors: ["818CF8", "6366F1"], label: "Sign"),
        "scan":       CategoryStyle(id: "scan", emoji: "📄", symbol: "doc.viewfinder.fill", gradientColors: ["60A5FA", "3B82F6"], label: "Scan"),
        "copy":       CategoryStyle(id: "copy", emoji: "📑", symbol: "doc.on.doc.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Copy"),
        "notarize":   CategoryStyle(id: "notarize", emoji: "🏛️", symbol: "building.columns.fill", gradientColors: ["FB923C", "F97316"], label: "Notarize"),
        "renew":      CategoryStyle(id: "renew", emoji: "🔄", symbol: "arrow.triangle.2.circlepath.circle.fill", gradientColors: ["4ADE80", "22C55E"], label: "Renewal"),
        
        // ── Automotive ─────────────────────────────
        "oil":        CategoryStyle(id: "oil", emoji: "🛢️", symbol: "oilcan.fill", gradientColors: ["9CA3AF", "6B7280"], label: "Oil Change"),
        "tire":       CategoryStyle(id: "tire", emoji: "🛞", symbol: "circle.circle.fill", gradientColors: ["6B7280", "4B5563"], label: "Tires"),
        "carwash":    CategoryStyle(id: "carwash", emoji: "🚿", symbol: "car.fill", gradientColors: ["38BDF8", "0EA5E9"], label: "Car Wash"),
        "mechanic":   CategoryStyle(id: "mechanic", emoji: "🔩", symbol: "wrench.adjustable.fill", gradientColors: ["FB923C", "F97316"], label: "Mechanic"),
        
        // ── Spiritual & Mindfulness ────────────────
        "pray":       CategoryStyle(id: "pray", emoji: "🙏", symbol: "hands.sparkles.fill", gradientColors: ["FDE68A", "FBBF24"], label: "Prayer"),
        "church":     CategoryStyle(id: "church", emoji: "⛪", symbol: "building.fill", gradientColors: ["C4B5FD", "A78BFA"], label: "Worship"),
        "gratitude":  CategoryStyle(id: "gratitude", emoji: "🙏", symbol: "heart.fill", gradientColors: ["F9A8D4", "F472B6"], label: "Gratitude"),
        
        // ── Food & Drink ───────────────────────────
        "coffee":     CategoryStyle(id: "coffee", emoji: "☕", symbol: "cup.and.saucer.fill", gradientColors: ["A78BFA", "8B5CF6"], label: "Coffee"),
        "meal":       CategoryStyle(id: "meal", emoji: "🍽️", symbol: "fork.knife", gradientColors: ["FB923C", "F97316"], label: "Meal"),
        "recipe":     CategoryStyle(id: "recipe", emoji: "👩‍🍳", symbol: "book.fill", gradientColors: ["FBBF24", "F59E0B"], label: "Recipe"),
        "bake":       CategoryStyle(id: "bake", emoji: "🧁", symbol: "oven.fill", gradientColors: ["FB923C", "F97316"], label: "Baking"),
        "reserve":    CategoryStyle(id: "reserve", emoji: "🍷", symbol: "fork.knife.circle.fill", gradientColors: ["F472B6", "EC4899"], label: "Reservation"),
        
        // ── General / Fallback ─────────────────────
        "general":    CategoryStyle(id: "general", emoji: "📌", symbol: "circle.hexagongrid.fill", gradientColors: ["60A5FA", "3B82F6"], label: "Task"),
        "checklist":  CategoryStyle(id: "checklist", emoji: "✅", symbol: "checklist", gradientColors: ["60A5FA", "3B82F6"], label: "Checklist"),
        "idea":       CategoryStyle(id: "idea", emoji: "💡", symbol: "lightbulb.fill", gradientColors: ["FDE68A", "FBBF24"], label: "Idea"),
        "goal":       CategoryStyle(id: "goal", emoji: "🎯", symbol: "target", gradientColors: ["F87171", "EF4444"], label: "Goal"),
        "habit":      CategoryStyle(id: "habit", emoji: "🔁", symbol: "repeat.circle.fill", gradientColors: ["4ADE80", "22C55E"], label: "Habit"),
        "plan":       CategoryStyle(id: "plan", emoji: "🗺️", symbol: "map.fill", gradientColors: ["818CF8", "6366F1"], label: "Plan"),
        "focus":      CategoryStyle(id: "focus", emoji: "🎯", symbol: "scope", gradientColors: ["FBBF24", "F59E0B"], label: "Focus"),
        "urgent":     CategoryStyle(id: "urgent", emoji: "🚨", symbol: "bolt.fill", gradientColors: ["F87171", "EF4444"], label: "Urgent"),
    ]
    
    // MARK: - Keyword Map (200+ keywords → category ID)
    
    private static let keywordMap: [(String, [String])] = [
        // Communication
        ("call",       ["call ", "phone", "ring ", "dial"]),
        ("text",       ["text ", "message ", "sms", "imessage", "whatsapp"]),
        ("email",      ["email", "e-mail", "inbox", "send mail", "gmail", "outlook"]),
        ("voicemail",  ["voicemail", "voice mail"]),
        ("reply",      ["reply", "respond", "get back to", "follow up", "follow-up"]),
        
        // People & Social
        ("family",     ["mom", "dad", "brother", "sister", "parent", "grandma", "grandpa", "aunt", "uncle", "cousin", "family"]),
        ("friend",     ["friend", "buddy", "hang out", "hangout", "catch up"]),
        ("birthday",   ["birthday", "bday", "b-day"]),
        ("wedding",    ["wedding", "engaged", "bridal"]),
        ("date",       ["date night", "anniversary", "valentine"]),
        ("baby",       ["baby", "newborn", "nursery", "diaper"]),
        ("gift",       ["gift", "present for", "buy for"]),
        ("party",      ["party", "celebrate", "celebration"]),
        
        // Health & Wellness
        ("medication", ["medication", "medicine", "pill", "prescription", "pharmacy", "refill", "rx"]),
        ("doctor",     ["doctor", "dr.", "physician", "appointment", "checkup", "check-up", "physical"]),
        ("dentist",    ["dentist", "dental", "teeth", "cavity", "braces"]),
        ("therapy",    ["therapy", "therapist", "counselor", "counseling", "psychologist", "psychiatrist"]),
        ("workout",    ["workout", "gym", "exercise", "lift", "weights", "crossfit", "fitness"]),
        ("yoga",       ["yoga", "pilates"]),
        ("meditation", ["meditat", "mindful"]),
        ("sleep",      ["sleep", "bedtime", "insomnia"]),
        ("nutrition",  ["nutrition", "diet", "healthy eating", "macro", "calories"]),
        ("hydrate",    ["water", "hydrat", "drink water"]),
        ("walk",       ["walk", "hike", "hiking", "steps"]),
        ("run",        ["run ", "running", "jog ", "jogging", "marathon", "5k", "10k"]),
        ("swim",       ["swim", "pool", "lap"]),
        ("cycle",      ["bike", "cycling", "bicycle"]),
        ("stretch",    ["stretch", "mobility", "foam roll"]),
        ("skincare",   ["skincare", "skin care", "moisturize", "sunscreen", "spf"]),
        ("vitamins",   ["vitamin", "supplement", "probiotic"]),
        
        // Home & Chores
        ("clean",      ["clean", "tidy", "dust", "mop", "scrub", "wipe"]),
        ("laundry",    ["laundry", "wash clothes", "dry clean", "iron clothes"]),
        ("dishes",     ["dish", "dishwasher", "unload", "silverware"]),
        ("cook",       ["cook", "make dinner", "make lunch", "prep food", "meal prep"]),
        ("grocery",    ["grocery", "groceries", "supermarket", "trader joe", "whole foods", "costco", "walmart", "target"]),
        ("plant",      ["plant", "water the", "succulent", "garden"]),
        ("trash",      ["trash", "garbage", "recycl", "compost", "take out the"]),
        ("organize",   ["organize", "declutter", "sort through", "konmari", "donate"]),
        ("repair",     ["fix ", "repair", "plumber", "electrician", "handyman", "broken"]),
        ("decor",      ["decorate", "furniture", "ikea", "curtain", "paint room"]),
        ("move",       ["moving", "move out", "move in", "new apartment", "new house"]),
        ("vacuum",     ["vacuum", "roomba", "carpet"]),
        ("mow",        ["mow", "lawn", "yard", "weed"]),
        
        // Pets
        ("walk_dog",   ["walk dog", "walk the dog", "dog walk"]),
        ("dog",        ["dog", "puppy", "pup ", "doggo"]),
        ("cat",        ["cat ", "kitten", "kitty", "litter"]),
        ("vet",        ["vet ", "veterinar", "animal hospital"]),
        ("pet",        ["pet ", "pet food", "petco", "petsmart", "fish", "hamster", "bird"]),
        
        // Work & Career
        ("meeting",    ["meeting", "standup", "stand-up", "sync ", "1:1", "one-on-one", "huddle"]),
        ("deadline",   ["deadline", "due date", "due by", "submit by", "turn in"]),
        ("present",    ["presentation", "slide", "keynote", "powerpoint", "pitch"]),
        ("report",     ["report", "writeup", "write-up", "document", "brief"]),
        ("review",     ["review", "feedback", "critique", "evaluate", "assess"]),
        ("apply",      ["apply", "application", "resume", "cover letter", "linkedin"]),
        ("interview",  ["interview", "phone screen"]),
        ("salary",     ["salary", "paycheck", "payroll", "raise", "bonus"]),
        ("project",    ["project", "sprint", "kanban", "jira", "trello", "asana"]),
        ("slack",      ["slack", "teams", "discord"]),
        
        // Finance
        ("pay",        ["pay ", "payment", "venmo", "zelle", "paypal", "charge", "credit card"]),
        ("bill",       ["bill", "invoice", "utilities", "electric bill", "phone bill", "internet bill"]),
        ("budget",     ["budget", "spending", "expense"]),
        ("invest",     ["invest", "stock", "crypto", "401k", "ira", "portfolio", "etf"]),
        ("tax",        ["tax", "irs", "w-2", "w2", "1099", "cpa", "accountant"]),
        ("bank",       ["bank", "wire", "deposit", "withdraw", "atm"]),
        ("insurance",  ["insurance", "coverage", "deductible", "premium", "claim"]),
        ("subscribe",  ["subscription", "cancel sub", "renew sub", "netflix", "spotify", "hulu"]),
        ("refund",     ["refund", "reimburse", "return money", "cashback"]),
        ("rent",       ["rent", "lease", "landlord", "tenant", "mortgage"]),
        
        // Shopping
        ("shop",       ["shop", "buy", "purchase", "get ", "pick up"]),
        ("order",      ["order", "amazon", "deliver", "package", "tracking", "shipment"]),
        ("return",     ["return ", "exchange", "send back"]),
        ("pickup",     ["pick up", "pickup", "curbside"]),
        
        // Education
        ("study",      ["study", "exam", "test ", "quiz", "flashcard", "review notes"]),
        ("read",       ["read ", "reading", "book ", "article", "blog post"]),
        ("homework",   ["homework", "assignment", "essay", "paper", "thesis"]),
        ("course",     ["course", "class", "lecture", "udemy", "coursera", "tutorial"]),
        ("practice",   ["practice", "rehearse", "drill"]),
        ("write",      ["write", "writing", "draft", "blog", "content"]),
        ("research",   ["research", "look into", "find out", "investigate"]),
        ("podcast",    ["podcast", "listen to", "audiobook"]),
        ("language",   ["spanish", "french", "japanese", "duolingo", "language"]),
        
        // Tech & Digital
        ("code",       ["code", "coding", "programming", "github", "deploy", "debug", "commit"]),
        ("update",     ["update", "upgrade", "install", "patch"]),
        ("password",   ["password", "login", "credential", "2fa", "authenticator"]),
        ("backup",     ["backup", "back up", "icloud", "restore"]),
        ("download",   ["download", "sync"]),
        ("print",      ["print", "printout", "printer"]),
        ("photo",      ["photo", "picture", "selfie", "album", "camera"]),
        ("app",        ["app ", "notification"]),
        
        // Travel & Transport
        ("flight",     ["flight", "fly", "airline", "airport", "boarding pass", "tsa"]),
        ("hotel",      ["hotel", "airbnb", "resort", "check in", "check out", "checkout"]),
        ("pack",       ["pack", "packing", "suitcase", "luggage"]),
        ("uber",       ["uber", "lyft", "taxi", "rideshare"]),
        ("passport",   ["passport", "visa", "travel document"]),
        ("car",        ["car ", "drive", "vehicle", "registration"]),
        ("gas",        ["gas ", "fuel", "fill up"]),
        
        // Calendar & Scheduling
        ("schedule",   ["schedule", "reschedule", "plan for", "set up", "arrange"]),
        ("remind",     ["remind", "reminder", "don't forget", "remember to"]),
        ("appt",       ["appointment", "appt", "consultation"]),
        ("rsvp",       ["rsvp", "r.s.v.p"]),
        
        // Creative
        ("music",      ["music", "song", "album", "playlist", "spotify"]),
        ("art",        ["art", "draw", "sketch", "paint", "canvas"]),
        ("design",     ["design", "figma", "photoshop", "canva", "logo"]),
        ("video",      ["video", "youtube", "tiktok", "reel", "edit video", "film"]),
        ("stream",     ["stream", "twitch", "watch "]),
        ("guitar",     ["guitar", "ukulele", "bass"]),
        ("piano",      ["piano", "keyboard", "keys"]),
        ("sing",       ["sing", "karaoke", "vocal"]),
        ("craft",      ["craft", "knit", "sew", "crochet", "diy"]),
        
        // Self Care
        ("shower",     ["shower", "bath"]),
        ("haircut",    ["haircut", "hair cut", "barber", "salon", "stylist"]),
        ("morning",    ["morning routine", "wake up"]),
        ("evening",    ["evening routine", "night routine", "wind down"]),
        ("journal",    ["journal", "diary"]),
        ("breathe",    ["breathe", "breathing", "box breathing"]),
        ("nap",        ["nap", "power nap", "rest"]),
        
        // Admin
        ("dmv",        ["dmv", "license", "registration", "id card"]),
        ("post",       ["post office", "mail ", "stamps", "usps", "fedex", "ups"]),
        ("form",       ["form", "paperwork", "document", "fill out"]),
        ("sign",       ["sign ", "signature", "notary", "notarize"]),
        ("scan",       ["scan", "photocopy"]),
        ("renew",      ["renew", "renewal"]),
        
        // Automotive
        ("oil",        ["oil change", "oil filter"]),
        ("tire",       ["tire", "tyre", "rotation"]),
        ("carwash",    ["car wash", "carwash", "detail"]),
        ("mechanic",   ["mechanic", "auto shop", "body shop"]),
        
        // Spiritual
        ("pray",       ["pray", "prayer"]),
        ("church",     ["church", "mosque", "temple", "synagogue", "worship", "service"]),
        ("gratitude",  ["grateful", "gratitude", "thankful"]),
        
        // Food & Drink
        ("coffee",     ["coffee", "latte", "espresso", "starbucks", "cafe"]),
        ("meal",       ["lunch", "dinner", "breakfast", "brunch", "supper", "eat"]),
        ("recipe",     ["recipe", "ingredient"]),
        ("bake",       ["bake", "baking", "cookie", "cake", "bread"]),
        ("reserve",    ["reservat", "book a table", "opentable"]),
        
        // General
        ("idea",       ["idea", "brainstorm", "think about"]),
        ("goal",       ["goal", "objective", "milestone"]),
        ("habit",      ["habit", "streak", "daily", "routine"]),
        ("plan",       ["plan ", "planning"]),
        ("focus",      ["focus", "concentrate", "deep work"]),
        ("urgent",     ["urgent", "asap", "immediately", "right now", "emergency"]),
    ]
    
    // MARK: - Emoji → Category Style Map
    // Maps explicit emoji on NudgeItems to the right category for colors
    
    private static let emojiToCategoryStyle: [String: CategoryStyle] = [
        // Communication
        "📞": categories["call"]!,
        "📱": categories["text"]!,
        "💬": categories["text"]!,
        "📧": categories["email"]!,
        "📬": categories["email"]!,
        "📩": categories["email"]!,
        "✉️": categories["email"]!,
        "📼": categories["voicemail"]!,
        
        // People & Social
        "🎂": categories["birthday"]!,
        "👤": categories["people"]!,
        "👥": categories["people"]!,
        "🤝": categories["meeting"]!,
        "👨‍👩‍👧": categories["family"]!,
        "🤗": categories["friend"]!,
        "💍": categories["wedding"]!,
        "💕": categories["date"]!,
        "👶": categories["baby"]!,
        "🎁": categories["gift"]!,
        "🎉": categories["party"]!,
        
        // Health & Wellness
        "💊": categories["medication"]!,
        "🏥": categories["doctor"]!,
        "🩺": categories["doctor"]!,
        "🦷": categories["dentist"]!,
        "🧘": categories["yoga"]!,
        "🏋️": categories["workout"]!,
        "🏋️‍♂️": categories["workout"]!,
        "🏋️‍♀️": categories["workout"]!,
        "🧠": categories["therapy"]!,
        "😴": categories["sleep"]!,
        "💧": categories["hydrate"]!,
        "🚶": categories["walk"]!,
        "🏃": categories["run"]!,
        "🏊": categories["swim"]!,
        "🚴": categories["cycle"]!,
        "🤸": categories["stretch"]!,
        "🥗": categories["nutrition"]!,
        
        // Home & Chores
        "🧹": categories["clean"]!,
        "👕": categories["laundry"]!,
        "🍽️": categories["dishes"]!,
        "🍳": categories["cook"]!,
        "🛒": categories["grocery"]!,
        "🪴": categories["plant"]!,
        "🌱": categories["plant"]!,
        "🗑️": categories["trash"]!,
        "📦": categories["organize"]!,
        "🔧": categories["repair"]!,
        "🏠": categories["repair"]!,
        
        // Pets
        "🐶": categories["dog"]!,
        "🐕": categories["dog"]!,
        "🐱": categories["cat"]!,
        "🐾": categories["pet"]!,
        "🐕‍🦺": categories["walk_dog"]!,
        
        // Work
        "💼": categories["project"]!,
        "📊": categories["present"]!,
        "📝": categories["report"]!,
        "⏰": categories["deadline"]!,
        "✅": categories["review"]!,
        "🎤": categories["interview"]!,
        "💵": categories["salary"]!,
        "💻": categories["code"]!,
        "🖥️": categories["code"]!,
        
        // Finance
        "💳": categories["pay"]!,
        "💰": categories["pay"]!,
        "🧾": categories["bill"]!,
        "📈": categories["invest"]!,
        "📉": categories["budget"]!,
        "🏛️": categories["tax"]!,
        "🏦": categories["bank"]!,
        "🛡️": categories["insurance"]!,
        "💸": categories["refund"]!,
        
        // Shopping
        "🛍️": categories["shop"]!,
        "🏪": categories["pickup"]!,
        
        // Education
        "📚": categories["study"]!,
        "📖": categories["read"]!,
        "🎓": categories["course"]!,
        "✍️": categories["write"]!,
        "🔬": categories["research"]!,
        "🎙️": categories["podcast"]!,
        "🌍": categories["language"]!,
        
        // Tech
        "👨‍💻": categories["code"]!,
        "🔑": categories["password"]!,
        "📸": categories["photo"]!,
        "🌐": categories["browse"]!,
        "🔍": categories["search"]!,
        "🔎": categories["research"]!,
        
        // Travel
        "✈️": categories["travel"]!,
        "🏖️": categories["travel"]!,
        "📍": categories["navigate"]!,
        "🗺️": categories["navigate"]!,
        "🚗": categories["car"]!,
        "⛽": categories["gas"]!,
        "🧳": categories["pack"]!,
        "🚕": categories["uber"]!,
        
        // Calendar
        "📅": categories["calendar"]!,
        "🗓️": categories["calendar"]!,
        "🕐": categories["schedule"]!,
        "🔔": categories["remind"]!,
        "📋": categories["appt"]!,
        "💌": categories["rsvp"]!,
        
        // Creative
        "🎵": categories["music"]!,
        "🎨": categories["art"]!,
        "🎬": categories["video"]!,
        "📺": categories["stream"]!,
        "🎸": categories["guitar"]!,
        "🎹": categories["piano"]!,
        "🧶": categories["craft"]!,
        
        // Self Care
        "🚿": categories["shower"]!,
        "💇": categories["haircut"]!,
        "🌅": categories["morning"]!,
        "🌙": categories["evening"]!,
        "📓": categories["journal"]!,
        
        // Admin
        "🪪": categories["dmv"]!,
        "📮": categories["post"]!,
        "🖊️": categories["sign"]!,
        
        // Spiritual
        "🙏": categories["pray"]!,
        "⛪": categories["church"]!,
        
        // Food
        "☕": categories["coffee"]!,
        "🧁": categories["bake"]!,
        "🍷": categories["reserve"]!,
        "👩‍🍳": categories["recipe"]!,
        
        // General
        "📌": categories["general"]!,
        "💡": categories["idea"]!,
        "🎯": categories["goal"]!,
        "🔁": categories["habit"]!,
        "🚨": categories["urgent"]!,
        "⭐": categories["goal"]!,
        "❤️": categories["gratitude"]!,
    ]
}

// MARK: - Preview

#Preview("Category Emoji Icons") {
    let sampleTasks = [
        "Call mom about Thanksgiving",
        "Text Sarah back about Saturday",
        "Email landlord about lease renewal",
        "Buy dog food at PetSmart",
        "Gym — leg day",
        "Take medication at 9am",
        "Grocery run — Trader Joe's",
        "Schedule dentist appointment",
        "Book flight to Denver",
        "Pay electric bill",
        "Clean the kitchen",
        "Water the plants",
        "Study for midterm exam",
        "Write blog post about ADHD",
        "Guitar practice — 30 min",
        "Walk the dog",
        "Budget review for March",
        "Morning routine",
        "Fix leaky faucet",
        "Order new headphones",
        "Yoga at 7am",
        "Coffee with Lisa",
        "Bake cookies for party",
        "Pray before bed",
        "Pack suitcase for trip",
    ]
    
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sampleTasks, id: \.self) { task in
                    let style = CategoryMatcher.match(content: task, emoji: nil, actionType: nil, contactName: nil)
                    HStack(spacing: 12) {
                        CategoryIllustrationView(
                            item: {
                                let i = NudgeItem(content: task)
                                return i
                            }(),
                            size: 44
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            HStack(spacing: 4) {
                                Image(systemName: style.symbol)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(style.primaryColor)
                                Text(style.label)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                }
            }
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}
