//
//  ShareExtensionView.swift
//  NudgeShareExtension
//
//  Custom SwiftUI share sheet on dark background.
//  Shows content preview + snooze picker + "Save to Nudge" button.
//

import SwiftUI

struct ShareExtensionView: View {
    let content: SharedContent
    var onSave: (Date, String?) -> Void
    var onCancel: () -> Void
    
    @State private var selectedSnoozeDate = Date().addingTimeInterval(3 * 3600) // Default: 3 hours
    @State private var showCustomPicker = false
    @State private var saved = false
    @State private var selectedCategory: String?
    @State private var showCategoryOverride = false
    
    // Snooze presets
    private let presets: [(String, String, Date)] = [
        (String(localized: "Later today"), "clock.fill", Date().addingTimeInterval(3 * 3600)),
        (String(localized: "Tomorrow morning"), "sunrise.fill", Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date().addingTimeInterval(86400)) ?? Date()),
        (String(localized: "This weekend"), "sun.max.fill", {
            let cal = Calendar.current
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            comps.weekday = 7 // Saturday
            comps.hour = 10
            let date = cal.date(from: comps) ?? Date()
            return date < Date() ? cal.date(byAdding: .weekOfYear, value: 1, to: date) ?? date : date
        }()),
        (String(localized: "Next week"), "calendar", Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()) ?? Date())
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            
            if saved {
                savedConfirmation
            } else {
                shareSheet
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Share Sheet
    
    private var shareSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(String(localized: "Cancel")) {
                    onCancel()
                }
                .foregroundStyle(Color(hex: "8E8E93"))
                
                Spacer()
                
                Text(String(localized: "Save to Nudge"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Invisible spacer for centering
                Text("Cancel").opacity(0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Content Preview
            VStack(alignment: .leading, spacing: 8) {
                if let preview = content.preview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                
                if let url = content.url {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                        Text(URL(string: url)?.host() ?? url)
                            .font(.system(size: 13))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color(hex: "007AFF"))
                } else if !content.text.isEmpty {
                    Text(content.text)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }
                
                // Category chip
                let displayCat = selectedCategory ?? content.guessedCategory
                if let catRaw = displayCat {
                    HStack(spacing: 6) {
                        Button {
                            showCategoryOverride.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: ShareCategoryEmoji.icon(for: catRaw))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(hex: ShareCategoryEmoji.colorHex(for: catRaw)))
                                Text(ShareCategoryEmoji.label(for: catRaw))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color(hex: "8E8E93"))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(hex: ShareCategoryEmoji.colorHex(for: catRaw)).opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                } else {
                    Button {
                        showCategoryOverride.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.system(size: 11))
                            Text(String(localized: "Add category"))
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                
                // Category override grid
                if showCategoryOverride {
                    shareCategoryPicker
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "1C1C1E").opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: "2C2C2E"), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .animation(.easeOut(duration: 0.2), value: showCategoryOverride)
            
            // Snooze section label
            Text(String(localized: "Remind me"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            // Quick presets
            VStack(spacing: 1) {
                ForEach(presets, id: \.0) { preset in
                    Button {
                        selectedSnoozeDate = preset.2
                        save()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: preset.1)
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "007AFF"))
                                .frame(width: 24)
                            
                            Text(preset.0)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Text(preset.2.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "8E8E93"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "1C1C1E").opacity(0.8))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            
            // Custom time
            Button {
                showCustomPicker.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "007AFF"))
                        .frame(width: 24)
                    
                    Text(String(localized: "Pick a time..."))
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Image(systemName: showCustomPicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "1C1C1E").opacity(0.8))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            if showCustomPicker {
                DatePicker(
                    "",
                    selection: $selectedSnoozeDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(Color(hex: "007AFF"))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Button {
                    save()
                } label: {
                    Text(String(localized: "Save"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "007AFF"))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Saved Confirmation
    
    private var savedConfirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "30D158"))
            
            Text(String(localized: "Saved ✓"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            
            Text(String(localized: "We'll nudge you at the right time"))
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Actions
    
    private func save() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            saved = true
        }
        let finalCategory = selectedCategory ?? content.guessedCategory
        onSave(selectedSnoozeDate, finalCategory)
    }
    // MARK: - Category Picker Grid (Lightweight — no main app dependencies)
    
    private var shareCategoryPicker: some View {
        let cats = ShareCategoryEmoji.allCategories
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            ForEach(cats, id: \.raw) { cat in
                let isSelected = (selectedCategory ?? content.guessedCategory) == cat.raw
                Button {
                    if selectedCategory == cat.raw {
                        selectedCategory = nil
                    } else {
                        selectedCategory = cat.raw
                    }
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : Color(hex: cat.colorHex))
                        Text(cat.label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(isSelected ? .white : Color(hex: "8E8E93"))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected
                                  ? Color(hex: cat.colorHex).opacity(0.25)
                                  : Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(isSelected ? Color(hex: cat.colorHex).opacity(0.5) : .clear, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Share Category Emoji Map (standalone for extension, mirrors main app TaskCategory)

enum ShareCategoryEmoji {
    struct CategoryInfo: Sendable {
        let raw: String
        let icon: String
        let label: String
        let colorHex: String
    }
    
    static let allCategories: [CategoryInfo] = [
        CategoryInfo(raw: "call", icon: "phone.fill", label: "Call", colorHex: "34C759"),
        CategoryInfo(raw: "text", icon: "message.fill", label: "Text", colorHex: "5AC8FA"),
        CategoryInfo(raw: "email", icon: "envelope.fill", label: "Email", colorHex: "007AFF"),
        CategoryInfo(raw: "link", icon: "link", label: "Link", colorHex: "AF52DE"),
        CategoryInfo(raw: "homework", icon: "book.fill", label: "Study", colorHex: "FFD60A"),
        CategoryInfo(raw: "cooking", icon: "frying.pan.fill", label: "Cook", colorHex: "FF9F0A"),
        CategoryInfo(raw: "alarm", icon: "alarm.fill", label: "Alarm", colorHex: "FF453A"),
        CategoryInfo(raw: "exercise", icon: "dumbbell.fill", label: "Fitness", colorHex: "30D158"),
        CategoryInfo(raw: "cleaning", icon: "bubbles.and.sparkles.fill", label: "Clean", colorHex: "66D4CF"),
        CategoryInfo(raw: "shopping", icon: "cart.fill", label: "Shop", colorHex: "FF6482"),
        CategoryInfo(raw: "appointment", icon: "calendar.badge.clock", label: "Appt", colorHex: "BF5AF2"),
        CategoryInfo(raw: "finance", icon: "creditcard.fill", label: "Finance", colorHex: "FFD426"),
        CategoryInfo(raw: "health", icon: "heart.fill", label: "Health", colorHex: "FF375F"),
        CategoryInfo(raw: "creative", icon: "paintbrush.fill", label: "Create", colorHex: "FF9500"),
        CategoryInfo(raw: "errand", icon: "car.fill", label: "Errand", colorHex: "64D2FF"),
        CategoryInfo(raw: "selfCare", icon: "sparkles", label: "Self-Care", colorHex: "AC8E68"),
        CategoryInfo(raw: "work", icon: "briefcase.fill", label: "Work", colorHex: "0A84FF"),
        CategoryInfo(raw: "social", icon: "person.2.fill", label: "Social", colorHex: "FF6482"),
        CategoryInfo(raw: "maintenance", icon: "wrench.and.screwdriver.fill", label: "Fix", colorHex: "8E8E93"),
        CategoryInfo(raw: "general", icon: "pin.fill", label: "General", colorHex: "8E8E93"),
    ]
    
    private static let lookup: [String: CategoryInfo] = {
        Dictionary(uniqueKeysWithValues: allCategories.map { ($0.raw, $0) })
    }()
    
    static func icon(for raw: String) -> String {
        lookup[raw]?.icon ?? "pin.fill"
    }
    
    static func label(for raw: String) -> String {
        lookup[raw]?.label ?? "General"
    }
    
    static func colorHex(for raw: String) -> String {
        lookup[raw]?.colorHex ?? "8E8E93"
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
