//
//  YouView.swift
//  Nudge
//
//  The "You" tab — your experience page.
//  Hero: aquarium tank with vector fish (Phase 2).
//  Quick mood check-in + AI insights (Phase 3-4).
//  Settings extracted to YouSettingsView (gear icon).
//

import SwiftUI
import PhotosUI
import SwiftData

struct YouView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    @Environment(AuthSession.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Environment(\.selectedTab) private var selectedTab

    // Avatar
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarService = AvatarService.shared
    @State private var showMemojiPicker = false
    @State private var showPhotoPicker = false

    // Sheets
    @State private var showSettings = false
    @State private var showDailyReview = false
    @State private var showPlanTomorrow = false   // kept for deep-link back-compat

    // Plan Tomorrow inline expand state
    @State private var planTomorrowExpanded = false

    // Mood (quick check-in)
    @State private var todayMood: MoodLevel?
    @State private var moodSaved = false

    // Reward service for aquarium data
    private var rewardService: RewardService { RewardService.shared }

    // AI insight
    @State private var moodInsightText: String?
    @State private var isLoadingInsight = false

    // Catch ceremony
    @State private var showCatchCeremony = false
    @State private var ceremonyCatch: FishCatch?

    // Ambient background
    @State private var breatheAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Mood entries for insight generation
    @Query(sort: \MoodEntry.loggedAt, order: .reverse) private var recentMoodEntries: [MoodEntry]

    // Today's task stats (loaded on appear)
    @State private var todayCompleted: Int = 0
    @State private var todayTotal: Int = 0
    @State private var longestStreak: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                youAmbientBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignTokens.spacingLG) {

                        // ── ZONE 1: YOU ───────────────────────────────────────
                        avatarHeader
                            .padding(.top, DesignTokens.spacingLG)

                        // ── ZONE 2: TODAY / TOMORROW ─────────────────────────
                        TomorrowCard {
                            NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
                        }
                        .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                            content.opacity(phase.isIdentity ? 1 : 0.4).offset(y: phase.isIdentity ? 0 : 16)
                        }

                        todayAtAGlanceCard
                            .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                                content.opacity(phase.isIdentity ? 1 : 0.4).offset(y: phase.isIdentity ? 0 : 16)
                            }

                        planTomorrowSection
                            .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                                content.opacity(phase.isIdentity ? 1 : 0.4).offset(y: phase.isIdentity ? 0 : 16)
                            }

                        // ── ZONE 3: YOUR AQUARIUM ─────────────────────────────
                        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                            HStack {
                                Text(String(localized: "Your Aquarium"))
                                    .font(AppTheme.caption.weight(.semibold))
                                    .foregroundStyle(DesignTokens.textSecondary)
                                    .textCase(.uppercase)
                                Spacer()
                                NavigationLink {
                                    AquariumView(
                                        catches: rewardService.fishCatches,
                                        level: rewardService.level,
                                        streak: rewardService.currentStreak
                                    )
                                } label: {
                                    HStack(spacing: 3) {
                                        Text(String(localized: "See All"))
                                            .font(AppTheme.hudFont)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .foregroundStyle(DesignTokens.accentActive)
                                }
                            }

                            AquariumTankView(
                                catches: rewardService.fishCatches,
                                level: rewardService.level,
                                streak: rewardService.currentStreak,
                                height: 260
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard))
                        }
                        .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                            content.opacity(phase.isIdentity ? 1 : 0.4).offset(y: phase.isIdentity ? 0 : 16)
                        }

                        aquariumIdentityCard
                            .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                                content.opacity(phase.isIdentity ? 1 : 0.4).offset(y: phase.isIdentity ? 0 : 16)
                            }

                        momentumCard
                            .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                                content.opacity(phase.isIdentity ? 1 : 0.4).offset(y: phase.isIdentity ? 0 : 16)
                            }

                        // ── MOOD ─────────────────────────────────────────────
                        youSection(title: String(localized: "How are you feeling?")) {
                            quickMoodRow
                        }
                        .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                            content.opacity(phase.isIdentity ? 1 : 0.4).offset(y: phase.isIdentity ? 0 : 16)
                        }

                        moodInsightCard
                            .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                                content.opacity(phase.isIdentity ? 1 : 0.4).offset(y: phase.isIdentity ? 0 : 16)
                            }

                        Spacer(minLength: DesignTokens.spacingXXXL)
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                }
            }
            .navigationTitle(String(localized: "You"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    .nudgeAccessibility(
                        label: String(localized: "Settings"),
                        hint: String(localized: "Open app settings"),
                        traits: .isButton
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            YouSettingsView()
        }
        .sheet(isPresented: $showMemojiPicker) {
            MemojiPickerView { memojiImage in
                avatarService.setCustomAvatar(memojiImage)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showDailyReview) {
            DailyReviewView()
        }
        .onChange(of: showPlanTomorrow) { _, newValue in
            // Deep-link compatibility: opening via nudge://planTomorrow expands inline
            if newValue {
                withAnimation(AnimationConstants.springSmooth) {
                    planTomorrowExpanded = true
                }
                showPlanTomorrow = false
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .overlay {
            if showCatchCeremony, let catchItem = ceremonyCatch {
                CatchCeremonyOverlay(fishCatch: catchItem) {
                    showCatchCeremony = false
                    ceremonyCatch = nil
                }
                .transition(.opacity)
            }
        }
        .onChange(of: rewardService.lastFishCatch?.id) { _, _ in
            guard let catchItem = rewardService.lastFishCatch else { return }
            ceremonyCatch = catchItem
            rewardService.clearLastFishCatch()
            withAnimation(.easeOut(duration: 0.2)) {
                showCatchCeremony = true
            }
        }
        .onAppear {
            avatarService.loadFromMeCard()
            loadTodayMood()
            loadMoodInsight()
            loadTodayStats()
            breatheAnimation = true
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    avatarService.setCustomAvatar(image)
                }
                selectedPhotoItem = nil
            }
        }
    }

    // MARK: - Scene Overlays

    /// Compact avatar — ring + first name, overlaid top-left on the scene.
    private var youAvatarOverlay: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            avatarRing
            if !settings.userName.isEmpty {
                Text(settings.userName.components(separatedBy: " ").first ?? settings.userName)
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
            Spacer()
        }
    }

    /// Single-line intention note — floats above tray when morning plan is fresh.
    @ViewBuilder
    private var intentionNoteOverlay: some View {
        let store = TomorrowPlanStore.shared
        HStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 12))
                .foregroundStyle(store.energyMode.accentColor)
            Text(store.intentionText)
                .font(AppTheme.caption.weight(.medium))
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(1)
            Spacer()
            Button {
                withAnimation(AnimationConstants.springSmooth) {
                    planTomorrowExpanded = true
                }
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
    }

    /// Bottom tray — one action at a time.
    /// Day → mood dots. Evening → Plan Tomorrow pill. Already planned → quiet chip.
    @ViewBuilder
    private var youBottomTray: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let isEvening = hour >= 18
        let alreadyPlanned = TomorrowPlanStore.shared.isPlannedForTonight

        if alreadyPlanned {
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.accentActive)
                Text(String(localized: "Tomorrow planned"))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Button {
                    withAnimation(AnimationConstants.springSmooth) {
                        planTomorrowExpanded = true
                    }
                } label: {
                    Text(String(localized: "Edit"))
                        .font(AppTheme.hudFont)
                        .foregroundStyle(DesignTokens.accentActive)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
        } else if isEvening {
            Button {
                HapticService.shared.actionButtonTap()
                withAnimation(AnimationConstants.springSmooth) {
                    planTomorrowExpanded = true
                }
            } label: {
                HStack(spacing: DesignTokens.spacingMD) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                    Text(String(localized: "Plan Tomorrow"))
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentActive.opacity(0.6))
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingMD)
                .background {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                        .fill(DesignTokens.accentActive.opacity(0.12))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                                .strokeBorder(DesignTokens.accentActive.opacity(0.25), lineWidth: 1)
                        }
                }
                .shadow(color: DesignTokens.accentActive.opacity(0.3), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Plan Tomorrow"),
                hint: String(localized: "Set your intention and energy for tomorrow"),
                traits: .isButton
            )
        } else {
            // Day time: mood dots — one tap, nothing to read
            HStack(spacing: 0) {
                ForEach(MoodLevel.allCases, id: \.self) { mood in
                    Button { quickLogMood(mood) } label: {
                        ZStack {
                            Circle()
                                .fill(todayMood == mood ? mood.color.opacity(0.2) : Color.white.opacity(0.05))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Circle().strokeBorder(
                                        todayMood == mood ? mood.color.opacity(0.5) : Color.white.opacity(0.08),
                                        lineWidth: todayMood == mood ? 1.5 : 0.5
                                    )
                                }
                            Image(systemName: mood.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(todayMood == mood ? mood.color : Color.white.opacity(0.45))
                                .scaleEffect(todayMood == mood ? 1.1 : 1.0)
                                .animation(AnimationConstants.springBouncy, value: todayMood)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .nudgeAccessibility(
                        label: mood.label,
                        hint: String(localized: "Log \(mood.label) mood"),
                        traits: .isButton
                    )
                }
            }
            .padding(.vertical, DesignTokens.spacingXS)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
        }
    }

    // MARK: - Avatar Header

    // MARK: - Avatar Header (contextual, time-aware)

    private var avatarHeader: some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingMD) {
            // Avatar with level ring
            avatarRing

            // Greeting + compact stat pills
            VStack(alignment: .leading, spacing: 5) {
                Text(contextualGreeting)
                    .font(AppTheme.title3)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(AnimationConstants.springSmooth, value: contextualGreeting)

                // Single compact pill row
                HStack(spacing: DesignTokens.spacingSM) {
                    statPill(
                        icon: "flame.fill",
                        label: "\(rewardService.currentStreak)d",
                        color: rewardService.currentStreak >= 3 ? DesignTokens.streakOrange : DesignTokens.textTertiary
                    )
                    statPill(
                        icon: "checkmark.circle.fill",
                        label: "\(todayCompleted)/\(todayTotal)",
                        color: todayCompleted > 0 ? DesignTokens.accentComplete : DesignTokens.textTertiary
                    )
                    statPill(
                        icon: "fish.fill",
                        label: "\(rewardService.fish)",
                        color: DesignTokens.accentActive
                    )
                }
            }

            Spacer()
        }
        .padding(.vertical, DesignTokens.spacingSM)
    }

    /// Level ring + avatar circle in one unit
    private var avatarRing: some View {
        Menu {
            Button {
                showMemojiPicker = true
            } label: {
                Label(String(localized: "Choose Memoji"), systemImage: "face.smiling")
            }
            Button {
                showPhotoPicker = true
            } label: {
                Label(String(localized: "Choose Photo"), systemImage: "photo.on.rectangle")
            }
            if avatarService.avatarImage != nil {
                Divider()
                Button(role: .destructive) {
                    avatarService.removeAvatar()
                } label: {
                    Label(String(localized: "Remove Photo"), systemImage: "trash")
                }
            }
        } label: {
            ZStack {
                let progress = levelXPFraction
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 3)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [DesignTokens.accentActive, Color(hex: "00E5FF"), DesignTokens.accentActive],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(AnimationConstants.springSmooth, value: progress)

                if let image = avatarService.avatarImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(LinearGradient(
                            colors: [DesignTokens.accentActive.opacity(0.3), DesignTokens.accentActive.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)
                        .overlay {
                            if !settings.userName.isEmpty {
                                Text(String(settings.userName.prefix(1)).uppercased())
                                    .font(AppTheme.rounded(.title3, weight: .semibold))
                                    .foregroundStyle(DesignTokens.textPrimary)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                        }
                }

                // Level badge
                Text("Lv.\(rewardService.level)")
                    .font(AppTheme.hudFont)
                    .foregroundStyle(DesignTokens.goldCurrency)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .offset(y: 26)
            }
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: String(localized: "Profile photo, Level \(rewardService.level)"),
            hint: String(localized: "Tap to change your photo"),
            traits: .isButton
        )
    }

    /// Time + data-aware greeting — changes across the day
    private var contextualGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = settings.userName.isEmpty ? nil : settings.userName
        let firstName = name.map { $0.components(separatedBy: " ").first ?? $0 }

        // Morning — show tomorrow plan if fresh
        if TomorrowPlanStore.shared.isFreshForMorning && TomorrowPlanStore.shared.hasPlan {
            if let n = firstName {
                return String(localized: "Morning, \(n). Your intention is set.")
            }
            return String(localized: "Morning. Your intention is set.")
        }

        switch hour {
        case 5..<10:
            if let n = firstName {
                return String(localized: "Good morning, \(n).")
            }
            return String(localized: "Good morning.")

        case 10..<13:
            if todayCompleted > 0 {
                return String(localized: "\(todayCompleted) \(todayCompleted == 1 ? "thing" : "things") done. Keep the momentum.")
            }
            if let n = firstName { return String(localized: "Morning, \(n). Let's go.") }
            return String(localized: "Morning. Let's go.")

        case 13..<17:
            if todayCompleted >= todayTotal && todayTotal > 0 {
                return String(localized: "All \(todayTotal) done. Impressive.")
            }
            let remaining = max(todayTotal - todayCompleted, 0)
            if remaining > 0 {
                return String(localized: "\(remaining) left today. You can do this.")
            }
            return String(localized: "Good afternoon. What's next?")

        case 17..<21:
            if todayCompleted > 0 {
                return String(localized: "You did \(todayCompleted) \(todayCompleted == 1 ? "thing" : "things") today.")
            }
            return String(localized: "Evening. Time to close the loop.")

        default: // 21+
            return String(localized: "Time to plan tomorrow.")
        }
    }

    private func statPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(AppTheme.hudFont)
                .foregroundStyle(color)
        }
        .padding(.horizontal, DesignTokens.spacingSM)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.1)))
    }

    /// Fraction of XP earned within the current level (0…1) for the ring.
    private var levelXPFraction: Double {
        rewardService.levelProgress
    }

    // MARK: - Streak & Feeding Card

    private var streakAndFeedingCard: some View {
        let taskStreak = rewardService.currentStreak
        let feedStreak = rewardService.feedingStreak
        let happiness = rewardService.fishHappiness
        let fedToday = rewardService.fishFedToday

        return HStack(spacing: DesignTokens.spacingMD) {
            // Task completion streak
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            taskStreak >= 7
                                ? Color(hex: "FF6B35")
                                : taskStreak >= 3
                                    ? Color(hex: "FFB74D")
                                    : DesignTokens.textTertiary
                        )
                    Text("\(taskStreak)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)
                }
                Text(String(localized: "Day Streak"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)

                if taskStreak >= 3 {
                    Text(String(localized: "2× ❄️"))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "4FC3F7"))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingSM)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))

            // Feeding streak
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    // Hearts for happiness
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: Double(i) < happiness * 3.0 ? "heart.fill" : "heart")
                                .font(.system(size: 10))
                                .foregroundStyle(
                                    Double(i) < happiness * 3.0
                                        ? Color(hex: "FF6B6B")
                                        : Color.white.opacity(0.2)
                                )
                        }
                    }
                }
                Text(String(localized: "Fed \(fedToday)/3 today"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)

                if feedStreak >= 2 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color(hex: "FF6B35"))
                        Text(String(localized: "\(feedStreak)d feed streak"))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "FFB74D"))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingSM)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))

            // Fish count
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignTokens.accentActive)
                    Text("\(rewardService.fish)")
                        .font(AppTheme.rounded(.title2, weight: .bold))
                        .foregroundStyle(DesignTokens.textPrimary)
                }
                Text(String(localized: "Fish"))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)

                Text(String(localized: "Lv.\(rewardService.level)"))
                    .font(AppTheme.hudFont)
                    .foregroundStyle(DesignTokens.goldCurrency)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingSM)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        }
        .nudgeAccessibility(
            label: String(localized: "Streak: \(taskStreak) days, Fed \(fedToday) of 3, \(rewardService.fish) fish"),
            hint: String(localized: "Your progress stats")
        )
    }

    // MARK: - Plan Tomorrow Section (inline, expands in-place)

    /// Inline plan-tomorrow section — three states:
    ///   alreadyPlanned → quiet confirmation chip
    ///   expanded       → `PlanTomorrowInlineView` embedded in a glass card
    ///   collapsed      → context-aware prompt row (full card in evening, quiet link by day)
    @ViewBuilder
    private var planTomorrowSection: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let isEvening = hour >= 18
        let alreadyPlanned = TomorrowPlanStore.shared.isPlannedForTonight

        if alreadyPlanned && !planTomorrowExpanded {
            // Already planned — quiet confirmation
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.accentActive)
                Text(String(localized: "Tomorrow is planned."))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Button {
                    withAnimation(AnimationConstants.springSmooth) { planTomorrowExpanded = true }
                } label: {
                    Text(String(localized: "Edit"))
                        .font(AppTheme.hudFont)
                        .foregroundStyle(DesignTokens.accentActive)
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))

        } else if planTomorrowExpanded {
            // ── Inline ritual card ────────────────────────────────────
            VStack(spacing: 0) {
                // Header bar with collapse button
                HStack(spacing: DesignTokens.spacingMD) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                    Text(String(localized: "Plan Tomorrow"))
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.textPrimary)
                    Spacer()
                    Button {
                        withAnimation(AnimationConstants.springSmooth) { planTomorrowExpanded = false }
                        HapticService.shared.actionButtonTap()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DesignTokens.textTertiary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.top, DesignTokens.spacingMD)
                .padding(.bottom, DesignTokens.spacingXS)

                Divider()
                    .background(Color.white.opacity(0.08))

                PlanTomorrowInlineView(isExpanded: $planTomorrowExpanded)
            }
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(Color(hex: "1C1C1E").opacity(0.92))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .strokeBorder(DesignTokens.accentActive.opacity(0.18), lineWidth: 0.5)
                    }
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 12)),
                removal: .opacity.combined(with: .offset(y: -8))
            ))

        } else if isEvening {
            // Evening collapsed — prominent full card prompt
            Button {
                HapticService.shared.actionButtonTap()
                withAnimation(AnimationConstants.springSmooth) { planTomorrowExpanded = true }
            } label: {
                DarkCard(accentColor: DesignTokens.accentActive) {
                    HStack(spacing: DesignTokens.spacingMD) {
                        ZStack {
                            Circle()
                                .fill(DesignTokens.accentActive.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "Plan Tomorrow"))
                                .font(AppTheme.headline)
                                .foregroundStyle(DesignTokens.textPrimary)
                            Text(String(localized: "Set your intention. Sleep easy."))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignTokens.accentActive.opacity(0.6))
                    }
                }
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Plan Tomorrow"),
                hint: String(localized: "Expand to set your intention and energy for tomorrow"),
                traits: .isButton
            )

        } else {
            // Day / afternoon collapsed — quiet text row
            Button {
                HapticService.shared.actionButtonTap()
                withAnimation(AnimationConstants.springSmooth) { planTomorrowExpanded = true }
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: hour >= 14 ? "moon.stars" : "calendar.badge.plus")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(hour >= 14
                         ? String(localized: "Plan tonight — set tomorrow's intention")
                         : String(localized: "Plan tomorrow — set your intention"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary.opacity(0.5))
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                        .fill(Color.white.opacity(0.03))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                        }
                )
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Plan Tomorrow"),
                hint: String(localized: "Expand to set your intention for tomorrow"),
                traits: .isButton
            )
        }
    }



    private var aquariumProgressBar: some View {
        let weekCatches = weeklyFishCount
        let cap = 12
        let progress = min(Double(weekCatches) / Double(cap), 1.0)

        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "4FC3F7"),
                                    Color(hex: "00B8D4")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(String(localized: "\(weekCatches) fish this week"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
                Spacer()
                Text(String(localized: "Lv.\(rewardService.level)"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "FFD54F"))
            }
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
    }

    private var weeklyFishCount: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return rewardService.fishCatches.count
        }
        return rewardService.fishCatches.filter { $0.caughtAt >= weekStart }.count
    }

    // MARK: - Aquarium Identity Card

    /// DarkCard showing the user's completion archetype based on dominant fish species last 30 days.
    @ViewBuilder
    private var aquariumIdentityCard: some View {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = rewardService.fishCatches.filter { $0.caughtAt >= thirtyDaysAgo }
        if !recent.isEmpty {
            let counts = Dictionary(grouping: recent, by: { $0.species }).mapValues(\.count)
            if let dominant = counts.max(by: { $0.value < $1.value }) {
                identityCardContent(species: dominant.key, monthCount: recent.count)
            }
        }
    }

    private func archetypeInfo(for species: FishSpecies) -> (title: String, detail: String) {
        switch species {
        case .whale:
            return (String(localized: "Milestone Crusher"), String(localized: "You go after the hard, rare work — and finish it."))
        case .swordfish:
            return (String(localized: "Deep-Work Machine"), String(localized: "Long focus sessions define how you do your best work."))
        case .tropical:
            return (String(localized: "Balanced Achiever"), String(localized: "A steady rhythm of effort across different kinds of work."))
        case .catfish:
            return (String(localized: "Quick-Win Champion"), String(localized: "You stay in motion and clear the backlog with speed."))
        }
    }

    @ViewBuilder
    private func identityCardContent(species: FishSpecies, monthCount: Int) -> some View {
        let info = archetypeInfo(for: species)
        let archetypeTitle = info.title
        let archetypeDetail = info.detail

        DarkCard(accentColor: species.fishColor) {
            HStack(spacing: DesignTokens.spacingMD) {
                FishView(
                    size: 32,
                    color: species.fishColor,
                    accentColor: species.fishAccentColor
                )
                .shadow(color: species.fishColor.opacity(0.35), radius: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(archetypeTitle)
                        .font(AppTheme.headline)
                        .foregroundStyle(species.fishColor)
                    Text(archetypeDetail)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(monthCount)")
                        .font(AppTheme.title3)
                        .foregroundStyle(DesignTokens.textPrimary)
                    Text(String(localized: "this month"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
        }
        .nudgeAccessibility(
            label: String(localized: "Your archetype: \(archetypeTitle). \(archetypeDetail) \(monthCount) tasks this month."),
            hint: String(localized: "Your task completion style based on the last 30 days")
        )
    }

    // MARK: - Momentum Card

    @ViewBuilder
    private var momentumCard: some View {
        let calendar = Calendar.current
        let now = Date()
        let thisWeekStart: Date = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let lastWeekStart: Date = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)
            ?? thisWeekStart
        let thisCount = rewardService.fishCatches.filter { $0.caughtAt >= thisWeekStart }.count
        let lastCount = rewardService.fishCatches.filter {
            $0.caughtAt >= lastWeekStart && $0.caughtAt < thisWeekStart
        }.count
        if thisCount > 0 || lastCount > 0 {
            momentumCardContent(thisCount: thisCount, lastCount: lastCount)
        }
    }

    @ViewBuilder
    private func momentumCardContent(thisCount: Int, lastCount: Int) -> some View {
        let delta = thisCount - lastCount
        let isAhead = delta > 0
        let accentColor: Color = delta < 0 ? DesignTokens.accentStale : DesignTokens.accentComplete
        let headline: String = delta == 0
            ? String(localized: "Matching last week's pace")
            : isAhead
                ? String(localized: "\(delta) more fish than last week")
                : String(localized: "\(abs(delta)) fewer fish than last week")

        DarkCard(accentColor: accentColor) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Weekly Momentum"))
                            .font(AppTheme.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.textTertiary)
                            .textCase(.uppercase)
                        Text(headline)
                            .font(AppTheme.headline)
                            .foregroundStyle(DesignTokens.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if delta != 0 {
                        Text(isAhead ? "+\(delta)" : "\(delta)")
                            .font(AppTheme.title3)
                            .foregroundStyle(accentColor)
                    }
                }

                weekBar(
                    label: String(localized: "This week"),
                    count: thisCount,
                    maxCount: max(thisCount, lastCount, 1),
                    color: accentColor
                )
                weekBar(
                    label: String(localized: "Last week"),
                    count: lastCount,
                    maxCount: max(thisCount, lastCount, 1),
                    color: DesignTokens.textTertiary
                )
            }
        }
        .nudgeAccessibility(
            label: String(localized: "Weekly momentum: \(headline). \(thisCount) fish this week, \(lastCount) last week."),
            hint: String(localized: "Weekly fish catch comparison")
        )
    }

    private func weekBar(label: String, count: Int, maxCount: Int, color: Color) -> some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Text(label)
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textSecondary)
                .frame(width: 72, alignment: .leading)
            Capsule()
                .fill(Color.white.opacity(0.07))
                .frame(height: 7)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.80))
                        .scaleEffect(
                            x: maxCount > 0 ? max(CGFloat(count) / CGFloat(maxCount), 0.001) : 0.001,
                            anchor: .leading
                        )
                        .animation(AnimationConstants.springSmooth, value: count)
                }
            Text("\(count)")
                .font(AppTheme.captionBold)
                .foregroundStyle(count > 0 ? DesignTokens.textPrimary : DesignTokens.textTertiary)
                .frame(width: 22, alignment: .trailing)
        }
    }

    // MARK: - Today at a Glance Card

    private var todayAtAGlanceCard: some View {
        let completed = todayCompleted
        let progress = min(Double(completed) / Double(max(todayTotal, 1)), 1.0)
        let todayKey = "focusMinutesToday_\(Date().formatted(.dateTime.year().month().day()))"
        let focusMins = UserDefaults.standard.integer(forKey: todayKey)
        return HStack(spacing: DesignTokens.spacingLG) {
            glanceRing(completed: completed, progress: progress)
            glanceStatsColumn(completed: completed, progress: progress, focusMins: focusMins)
        }
        .padding(DesignTokens.spacingMD)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        .nudgeAccessibility(
            label: String(localized: "Today: \(completed) of \(todayTotal) tasks complete"),
            hint: String(localized: "Your daily progress summary")
        )
    }

    @ViewBuilder
    private func glanceRing(completed: Int, progress: Double) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.06), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [DesignTokens.accentComplete, Color(hex: "00E5FF"), DesignTokens.accentComplete],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(AnimationConstants.springSmooth, value: progress)
            VStack(spacing: 1) {
                Text("\(completed)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignTokens.textPrimary)
                Text(String(localized: "done"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .frame(width: 64, height: 64)
    }

    @ViewBuilder
    private func glanceStatsColumn(completed: Int, progress: Double, focusMins: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "\(completed) of \(todayTotal) tasks complete"))
                .font(AppTheme.body.weight(.semibold))
                .foregroundStyle(DesignTokens.textPrimary)
            // Progress bar — scaleEffect avoids GeometryReader complexity
            Capsule()
                .fill(Color.white.opacity(0.06))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [DesignTokens.accentComplete, Color(hex: "00E5FF")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .scaleEffect(x: max(0.001, progress), anchor: .leading)
                }
                .animation(AnimationConstants.springSmooth, value: progress)
            glanceFocusLabel(completed: completed, progress: progress, focusMins: focusMins)
        }
    }

    @ViewBuilder
    private func glanceFocusLabel(completed: Int, progress: Double, focusMins: Int) -> some View {
        if focusMins > 0 {
            Label(String(localized: "\(focusMins) min focused today"), systemImage: "timer")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "5E5CE6"))
        } else if completed == 0 {
            Text(String(localized: "Complete a task to get started 🐧"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignTokens.textTertiary)
        } else if progress >= 1.0 {
            Label(String(localized: "All done! Amazing work 🎉"), systemImage: "party.popper.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.accentComplete)
        } else {
            EmptyView()
        }
    }

    // MARK: - Quick Mood Row

    private var quickMoodRow: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            if moodSaved, let mood = todayMood {
                HStack(spacing: DesignTokens.spacingMD) {
                    Image(systemName: mood.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(mood.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Today: \(mood.label)"))
                            .font(AppTheme.body.weight(.semibold))
                            .foregroundStyle(DesignTokens.textPrimary)
                        Text(String(localized: "Tap below to update"))
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(mood.color)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(MoodLevel.allCases, id: \.self) { mood in
                    Button { quickLogMood(mood) } label: {
                        moodButtonLabel(mood)
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(
                        label: mood.label,
                        hint: String(localized: "Quick log \(mood.label) mood"),
                        traits: .isButton
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func moodButtonLabel(_ mood: MoodLevel) -> some View {
        let isSelected = todayMood == mood
        VStack(spacing: 5) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(mood.color.opacity(0.18))
                        .frame(width: 50, height: 50)
                        .blur(radius: 6)
                }
                Circle()
                    .fill(isSelected ? mood.color.opacity(0.15) : Color.white.opacity(0.05))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Circle().strokeBorder(
                            isSelected ? mood.color.opacity(0.6) : Color.white.opacity(0.08),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                    }
                Image(systemName: mood.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? mood.color : Color.white.opacity(0.55))
                    .scaleEffect(isSelected ? 1.12 : 1.0)
                    .animation(AnimationConstants.springBouncy, value: todayMood)
            }
            Text(mood.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isSelected ? mood.color : DesignTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - AI Mood Insight Card

    private var moodInsightCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(String(localized: "Mood Insight"))
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "BA68C8"), Color(hex: "7B1FA2")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text(String(localized: "AI-Powered"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignTokens.textTertiary)

                    Spacer()

                    if isLoadingInsight {
                        ProgressView()
                            .tint(DesignTokens.textTertiary)
                            .scaleEffect(0.7)
                    }
                }

                if isLoadingInsight {
                    // Shimmer placeholder
                    insightShimmer
                } else if let insight = moodInsightText {
                    Text(insight)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                } else {
                    Text(String(localized: "Check in a few more times to unlock AI mood insights."))
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .padding(DesignTokens.spacingMD)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }

    private var insightShimmer: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                ShimmerRect(maxWidth: i == 2 ? 140.0 : nil)
            }
        }
    }

    // MARK: - Mood Helpers

    private func loadTodayMood() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        if let todayEntry = recentMoodEntries.first(where: { calendar.isDate($0.loggedAt, inSameDayAs: todayStart) }) {
            todayMood = todayEntry.moodLevel
            moodSaved = true
        }
    }

    private func loadTodayStats() {
        let repo = NudgeRepository(modelContext: modelContext)
        let done = repo.fetchCompletedToday()
        let active = repo.fetchActiveQueue()
        todayCompleted = done.count
        todayTotal = done.count + active.count
    }

    private func quickLogMood(_ mood: MoodLevel) {
        HapticService.shared.actionButtonTap()

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        // Check if there's already a mood entry for today — update it
        if let existing = recentMoodEntries.first(where: { calendar.isDate($0.loggedAt, inSameDayAs: todayStart) }) {
            existing.moodLevel = mood
            existing.loggedAt = Date()
        } else {
            // Create new
            let entry = MoodEntry(mood: mood)
            modelContext.insert(entry)
        }

        withAnimation(AnimationConstants.springSmooth) {
            todayMood = mood
            moodSaved = true
        }

        // Bridge mood to UserDefaults so Nudgy can react on the Penguin tab
        let todayKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        UserDefaults.standard.set(mood.rawValue, forKey: "nudge_mood_\(todayKey)")

        // Refresh insight after mood change
        loadMoodInsight()
    }

    // MARK: - AI Insight

    private func loadMoodInsight() {
        // Need at least 3 entries for meaningful insight
        guard recentMoodEntries.count >= 3 else { return }

        // Check cache — only refresh once per day
        let cacheKey = "moodInsight_\(formattedToday)"
        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            moodInsightText = cached
            return
        }

        isLoadingInsight = true

        Task {
            let prompt = buildInsightPrompt()
            let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt)

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoadingInsight = false
                    moodInsightText = response
                }

                // Cache for the day
                if let response {
                    UserDefaults.standard.set(response, forKey: cacheKey)
                }
            }
        }
    }

    private func buildInsightPrompt() -> String {
        let recent = Array(recentMoodEntries.prefix(7))
        let repo = NudgeRepository(modelContext: modelContext)
        let entries = recent.map { entry in
            let mood = entry.moodLevel
            let day = entry.loggedAt.formatted(.dateTime.weekday(.wide))
            let tasks = entry.tasksCompletedThatDay
            
            // Build category breakdown for this day
            let dayStart = Calendar.current.startOfDay(for: entry.loggedAt)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let completedItems = repo.fetchCompletedInRange(from: dayStart, to: dayEnd)
            let catCounts = Dictionary(grouping: completedItems, by: { $0.resolvedCategory.label })
                .mapValues(\.count)
                .sorted { $0.value > $1.value }
            let catSummary = catCounts.isEmpty ? "" : " [\(catCounts.map { "\($0.key) ×\($0.value)" }.joined(separator: ", "))]"
            
            return "\(day): \(mood.label) (\(mood.emoji)), \(tasks) tasks done\(catSummary)"
        }.joined(separator: "\n")

        return """
        You are Nudgy, a warm supportive ADHD productivity companion (a penguin!). \
        Analyze this user's recent mood entries and give a brief, encouraging 1-2 sentence insight. \
        Be specific to the data — notice any patterns between mood and the types of tasks completed. \
        For example, do exercise or self-care days correlate with better mood? \
        Don't use bullet points. Keep it conversational and kind.

        Recent mood data:
        \(entries)

        Respond with just the insight text, nothing else.
        """
    }

    private var formattedToday: String {
        Date().formatted(.dateTime.year().month().day())
    }

    // MARK: - Reusable Components

    // MARK: Category Stats
    
    /// Phase 7: Hot category highlight card
    private func hotCategoryBadge(stat: (category: TaskCategory, active: Int, done: Int)) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: stat.category.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(stat.category.primaryColor)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(stat.category.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                }
                Text(String(localized: "\(stat.done) done today · crushing it!"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            
            Spacer()
        }
        .padding(DesignTokens.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: stat.category.gradientColors.map { $0.opacity(0.12) },
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
    }
    
    private var categoryStats: [(category: TaskCategory, active: Int, done: Int)] {
        let repo = NudgeRepository(modelContext: modelContext)
        let active = repo.fetchActiveQueue()
        let done = repo.fetchCompletedToday()
        
        var activeCounts: [TaskCategory: Int] = [:]
        var doneCounts: [TaskCategory: Int] = [:]
        
        for item in active {
            let cat = item.resolvedCategory
            activeCounts[cat, default: 0] += 1
        }
        for item in done {
            let cat = item.resolvedCategory
            doneCounts[cat, default: 0] += 1
        }
        
        // Merge all categories that have any count
        var allCats = Set(activeCounts.keys).union(doneCounts.keys)
        allCats.remove(.general)
        
        return allCats
            .map { cat in (category: cat, active: activeCounts[cat] ?? 0, done: doneCounts[cat] ?? 0) }
            .sorted { ($0.active + $0.done) > ($1.active + $1.done) }
    }
    
    private var categoryBreakdownCard: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            ForEach(categoryStats.prefix(8), id: \.category) { stat in
                HStack(spacing: DesignTokens.spacingSM) {
                    // Category icon + label
                    Image(systemName: stat.category.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(stat.category.primaryColor)
                    
                    Text(stat.category.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    Spacer()
                    
                    // Progress bar
                    let total = stat.active + stat.done
                    let fraction = total > 0 ? CGFloat(stat.done) / CGFloat(total) : 0
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: stat.category.gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(width: 60, height: 6)
                    
                    // Count badge
                    Text("\(stat.done)/\(stat.active + stat.done)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
    }
    
    // MARK: - Category Insights Card (Phase 14)
    
    /// Shows category trends, preferred times, streaks, and neglected categories.
    @ViewBuilder
    private var categoryInsightsCard: some View {
        let memory = NudgyMemory.shared.store
        let insights = buildCategoryInsights(memory: memory)
        
        if !insights.isEmpty {
            youSection(title: String(localized: "Category Insights")) {
                VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                    ForEach(insights, id: \.id) { insight in
                        HStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: insight.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(insight.badgeColor ?? DesignTokens.textSecondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(insight.title)
                                    .font(AppTheme.body)
                                    .foregroundStyle(DesignTokens.textPrimary)
                                
                                Text(insight.subtitle)
                                    .font(AppTheme.footnote)
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                            
                            Spacer()
                            
                            if let badgeIcon = insight.badgeIcon {
                                Image(systemName: badgeIcon)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(insight.badgeColor ?? DesignTokens.textTertiary)
                                    .padding(5)
                                    .background(
                                        Circle()
                                            .fill((insight.badgeColor ?? DesignTokens.textTertiary).opacity(0.15))
                                    )
                            } else if let badge = insight.badge {
                                Text(badge)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(insight.badgeColor ?? DesignTokens.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill((insight.badgeColor ?? DesignTokens.textTertiary).opacity(0.15))
                                    )
                            }
                        }
                    }
                }
            }
        }
    }
    
    private struct CategoryInsight: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        var badge: String? = nil
        var badgeIcon: String? = nil
        var badgeColor: Color? = nil
    }
    
    private func buildCategoryInsights(memory: NudgyMemoryStore) -> [CategoryInsight] {
        var insights: [CategoryInsight] = []
        
        // 1. This week's focus (top categories)
        if !memory.lastWeekTopCategories.isEmpty {
            let topCats = memory.lastWeekTopCategories.prefix(3).compactMap { TaskCategory(rawValue: $0) }
            if let top = topCats.first {
                insights.append(CategoryInsight(
                    id: "weekFocus",
                    icon: top.icon,
                    title: String(localized: "This week's focus"),
                    subtitle: topCats.map(\.label).joined(separator: ", "),
                    badgeIcon: "flame.fill",
                    badgeColor: top.primaryColor
                ))
            }
        }
        
        // 2. Preferred times — surface when user tends to do certain categories
        let timePrefs = memory.categoryPreferredTimes.prefix(3)
        for (catRaw, timeOfDay) in timePrefs {
            guard let cat = TaskCategory(rawValue: catRaw) else { continue }
            let timeIcon: String = switch timeOfDay {
            case "morning": "sunrise.fill"
            case "afternoon": "sun.max.fill"
            case "evening": "sunset.fill"
            default: "moon.stars.fill"
            }
            insights.append(CategoryInsight(
                id: "time_\(catRaw)",
                icon: cat.icon,
                title: "\(cat.label) \(timeOfDay)",
                subtitle: String(localized: "You tend to do \(cat.label.lowercased()) tasks in the \(timeOfDay)"),
                badgeIcon: timeIcon
            ))
        }
        
        // 3. Needs attention — categories with stale items
        let staleCategories = categoryStats.filter { stat in
            // If more active than done and the active count is high
            stat.active >= 3 && stat.done == 0
        }
        if let neglected = staleCategories.first {
            insights.append(CategoryInsight(
                id: "neglected",
                icon: neglected.category.icon,
                title: String(localized: "\(neglected.category.label) needs attention"),
                subtitle: String(localized: "\(neglected.active) tasks waiting, none done today"),
                badgeIcon: "exclamationmark.triangle.fill",
                badgeColor: DesignTokens.accentStale
            ))
        }
        
        // 4. Streak — highest completion count category
        if let topCat = memory.categoryCompletionCounts.max(by: { $0.value < $1.value }),
           topCat.value >= 5,
           let cat = TaskCategory(rawValue: topCat.key) {
            insights.append(CategoryInsight(
                id: "streak",
                icon: cat.icon,
                title: String(localized: "\(cat.label) champion"),
                subtitle: String(localized: "\(topCat.value) total completions — your strongest category"),
                badge: "\(topCat.value)",
                badgeColor: DesignTokens.accentComplete
            ))
        }
        
        return insights
    }

    func youSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(title)
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
                .textCase(.uppercase)

            content()
                .padding(DesignTokens.spacingMD)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }

    /// Section variant without inner padding — for edge-to-edge content like the aquarium tank.
    func youSectionRaw(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(title)
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
                .textCase(.uppercase)

            content()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }

    func youRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        value: String? = nil
    ) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DesignTokens.accentActive)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }

            Spacer()

            if let value {
                Text(value)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Ambient Background

    private var youAmbientBackground: some View {
        GeometryReader { geo in
            ZStack {
                AntarcticEnvironment(
                    mood: RewardService.shared.environmentMood,
                    unlockedProps: RewardService.shared.unlockedProps,
                    fishCount: RewardService.shared.fish,
                    level: RewardService.shared.level,
                    stage: StageTier.from(level: RewardService.shared.level),
                    sceneWidth: geo.size.width,
                    sceneHeight: geo.size.height,
                    isActive: selectedTab == .you
                )

                // Subtle breathing glow unique to You tab
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignTokens.accentActive.opacity(breatheAnimation ? 0.04 : 0.01),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(y: -geo.size.height * 0.15)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 5).repeatForever(autoreverses: true),
                        value: breatheAnimation
                    )
            }
        }
    }
}

// MARK: - Shimmer Loading Rect

/// A simple pulsing placeholder rect for loading states.
private struct ShimmerRect: View {
    var maxWidth: CGFloat?

    @State private var phase: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(phase ? 0.08 : 0.03))
            .frame(height: 12)
            .frame(maxWidth: maxWidth ?? .infinity)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: phase
            )
            .onAppear { phase = true }
    }
}

// MARK: - Preview

#Preview {
    YouView()
        .environment(AppSettings())
        .environment(PenguinState())
        .environment(AuthSession())
}
