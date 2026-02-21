//
//  NudgyChatView.swift
//  Nudge
//
//  Conversational chat UI with Nudgy the penguin.
//  Users can talk to Nudgy about their tasks, ask for help,
//  and Nudgy can look up and act on real task data via tools.
//
//  Features:
//  • Real-time streaming responses
//  • Contextual suggestion chips based on current task state
//  • Tool action notifications (task created, completed, etc.)
//  • AI status indicator
//
//  Presented as a sheet from the main screen.
//

import SwiftUI
import SwiftData
import SafariServices

struct NudgyChatView: View {
    
    /// Optional dismiss handler for inline mode (when not presented as sheet)
    var onDismiss: (() -> Void)?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var inputText = ""
    @State private var browserURL: URL?
    @State private var isVoiceEnabled: Bool = NudgyConfig.Voice.isEnabled
    @State private var chatError: String?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            Divider()
                .overlay(DesignTokens.cardBorder)
            
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DesignTokens.spacingMD) {
                        // Empty state welcome
                        if penguinState.chatMessages.isEmpty && !penguinState.isChatGenerating {
                            chatWelcome
                                .padding(.top, DesignTokens.spacingXXL)
                        }
                        
                        ForEach(penguinState.chatMessages) { message in
                            chatBubble(for: message)
                                .id(message.id)
                        }
                        
                        // Streaming indicator
                        if penguinState.isChatGenerating {
                            streamingBubble
                                .id("streaming")
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingMD)
                }
                .onChange(of: penguinState.chatMessages.count) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if penguinState.isChatGenerating {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        } else if let last = penguinState.chatMessages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: penguinState.streamingText) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            
            Divider()
                .overlay(DesignTokens.cardBorder)
            
            // Error banner
            if let chatError {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.accentOverdue)
                    
                    Text(chatError)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.accentOverdue)
                    
                    Spacer()
                    
                    Button {
                        self.chatError = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .nudgeAccessibility(label: String(localized: "Dismiss error"), hint: nil, traits: .isButton)
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.vertical, DesignTokens.spacingSM)
                .background(DesignTokens.accentOverdue.opacity(0.08))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Suggestion chips (show when conversation is short or idle)
            if penguinState.chatMessages.count <= 4 && !penguinState.isChatGenerating {
                suggestionChipRow
            }
            
            // Input bar
            chatInputBar
        }
        .background {
            ZStack {
                Color.black
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DesignTokens.accentActive.opacity(0.04), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .offset(x: -80, y: -160)
                    .blur(radius: 50)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .inAppBrowser(url: $browserURL)
        .onReceive(NotificationCenter.default.publisher(for: .nudgeOpenBrowser)) { notif in
            if let url = notif.userInfo?["url"] as? URL {
                browserURL = url
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeChatExecuteAction)) { notif in
            handleChatAction(notif.userInfo ?? [:])
        }
        .onAppear {
            // Only start chatting if not already in chat mode
            // (NudgyHomeView may have already started it)
            if penguinState.interactionMode != .chatting {
                NudgyEngine.shared.startChat()
            }
            isInputFocused = true
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack {
            // Mini penguin avatar
            NudgySprite(
                expression: penguinState.isChatGenerating ? .thinking : penguinState.expression,
                size: 36,
                accentColor: DesignTokens.accentActive
            )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.spacingXS) {
                    Text(String(localized: "Nudgy"))
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    // AI status dot
                    Circle()
                        .fill(NudgyEngine.shared.isAvailable
                              ? DesignTokens.accentComplete
                              : DesignTokens.textTertiary)
                        .frame(width: 6, height: 6)
                }
                
                Text(penguinState.isChatGenerating
                     ? String(localized: "*thinking noises*")
                     : NudgyEngine.shared.isAvailable
                        ? String(localized: "your penguin • AI-powered")
                        : String(localized: "your penguin buddy"))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            
            Spacer()
            
            // Mute/unmute toggle — stops speaker in both directions
            Button {
                HapticService.shared.prepare()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isVoiceEnabled.toggle()
                    NudgyConfig.Voice.isEnabled = isVoiceEnabled
                    if !isVoiceEnabled {
                        NudgyVoiceOutput.shared.stop()
                    }
                }
            } label: {
                Image(systemName: isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isVoiceEnabled ? DesignTokens.accentActive : DesignTokens.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.ultraThinMaterial))
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: isVoiceEnabled
                    ? String(localized: "Mute Nudgy")
                    : String(localized: "Unmute Nudgy"),
                hint: String(localized: "Toggle Nudgy's voice on or off"),
                traits: .isButton
            )
            
            // Clear chat button
            if !penguinState.chatMessages.isEmpty {
                Button {
                    NudgyEngine.shared.clearChat()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 32, height: 32)
                }
                .nudgeAccessibility(
                    label: String(localized: "Clear chat"),
                    hint: String(localized: "Clears the conversation history"),
                    traits: .isButton
                )
            }
            
            // Close button
            Button {
                if let onDismiss {
                    onDismiss()
                } else {
                    NudgyEngine.shared.exitChat()
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .nudgeAccessibility(
                label: String(localized: "Close chat"),
                hint: String(localized: "Returns to the main screen"),
                traits: .isButton
            )
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.vertical, DesignTokens.spacingMD)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }
    
    // MARK: - Chat Welcome
    
    private var chatWelcome: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            NudgySprite(
                expression: .waving,
                size: DesignTokens.penguinSizeMedium,
                accentColor: DesignTokens.accentActive
            )
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text(String(localized: "Oh, hello there 🐧"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(String(localized: "Tell me what's on your mind… tasks, feelings, whatever. I'm just a small penguin, but I'm good at sitting with things."))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            .padding(.horizontal, DesignTokens.spacingXL)
        }
    }
    
    // MARK: - Chat Bubbles
    
    @ViewBuilder
    private func chatBubble(for message: ChatMessage) -> some View {
        if message.role == .system {
            // System messages: compact centered pill (like iMessage timestamps)
            HStack {
                Spacer()
                Text(message.text)
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingXS)
                    .background {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    }
                Spacer()
            }
        } else {
            HStack {
                if message.role == .user {
                    Spacer(minLength: 60)
                }
                
                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                    Text(message.text)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .multilineTextAlignment(message.role == .user ? .trailing : .leading)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM + 2)
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(message.role == .user
                                      ? DesignTokens.accentActive.opacity(0.12)
                                      : Color.white.opacity(0.02))
                        }
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    
                    // Rich attachment rendering
                    if let attachment = message.attachment {
                        chatAttachmentView(attachment)
                    }
                }
                .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
                
                if message.role == .nudgy {
                    Spacer(minLength: 60)
                }
            }
        }
    }
    
    // MARK: - Rich Attachment Views
    
    @ViewBuilder
    private func chatAttachmentView(_ attachment: ChatAttachment) -> some View {
        switch attachment {
        case .draft(let draft):
            draftPreviewBubble(draft)
        case .actions(let actions):
            actionButtonsRow(actions)
        case .taskCard(let card):
            taskCardBubble(card)
        case .urlActions(let urlActions):
            urlActionButtonsRow(urlActions)
        }
    }
    
    /// Draft preview card with "Send" button
    private func draftPreviewBubble(_ draft: DraftAttachment) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            draftHeader(draft)
            
            if let subject = draft.subject, !subject.isEmpty {
                Text(String(localized: "Subject: \(subject)"))
                    .font(AppTheme.captionBold)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            
            // Body preview
            Text(draft.body)
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(6)
            
            draftActionButtons(draft)
        }
        .padding(DesignTokens.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(DesignTokens.accentActive.opacity(0.2), lineWidth: 0.5)
                )
        }
    }
    
    private func draftHeader(_ draft: DraftAttachment) -> some View {
        HStack(spacing: DesignTokens.spacingXS) {
            Image(systemName: draft.draftType == "email" ? "envelope.fill" : "message.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.accentActive)
            Text(draft.draftType == "email" ? String(localized: "Email Draft") : String(localized: "Text Draft"))
                .font(AppTheme.captionBold)
                .foregroundStyle(DesignTokens.accentActive)
            Spacer()
            Text(String(localized: "To: \(draft.recipientName)"))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
        }
    }
    
    private func draftActionButtons(_ draft: DraftAttachment) -> some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Button {
                executeDraftAction(draft)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 11))
                    Text(String(localized: "Send Now"))
                        .font(AppTheme.captionBold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .background(Capsule().fill(DesignTokens.accentActive))
            }
            .buttonStyle(.plain)
            
            Button {
                inputText = "Make it more casual"
                sendMessage()
            } label: {
                Text(String(localized: "Edit"))
                    .font(AppTheme.captionBold)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
    }
    
    /// Row of action buttons (Call, Text, Search, etc.)
    private func actionButtonsRow(_ actions: [ActionAttachment]) -> some View {
        VStack(spacing: DesignTokens.spacingXS) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                Button {
                    executeActionAttachment(action)
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: action.icon)
                            .font(.system(size: 14))
                        Text(action.label)
                            .font(AppTheme.captionBold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(DesignTokens.accentActive)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DesignTokens.accentActive.opacity(0.08))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// Task card bubble (for task creation confirmations)
    private func taskCardBubble(_ card: TaskCardAttachment) -> some View {
        HStack(spacing: DesignTokens.spacingSM) {
            StepIconView(emoji: card.emoji, size: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.content)
                    .font(AppTheme.captionBold)
                    .foregroundStyle(DesignTokens.textPrimary)
                HStack(spacing: 4) {
                    if let priority = card.priority {
                        Text(priority.capitalized)
                            .font(AppTheme.caption)
                            .foregroundStyle(priority == "high" ? DesignTokens.accentOverdue : DesignTokens.textTertiary)
                    }
                    if let due = card.dueDate {
                        Text(due)
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
            }
        }
        .padding(DesignTokens.spacingSM)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
    }
    
    /// URL action buttons (Search Amazon, Get Directions, etc.)
    private func urlActionButtonsRow(_ actions: [URLActionAttachment]) -> some View {
        VStack(spacing: DesignTokens.spacingXS) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                Button {
                    if action.openInApp, let url = URL(string: action.urlString) {
                        browserURL = url
                    } else if let url = URL(string: action.urlString) {
                        UIApplication.shared.open(url)
                    }
                    HapticService.shared.actionButtonTap()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: action.icon)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(action.label)
                                .font(AppTheme.captionBold)
                            Text(action.domain)
                                .font(.system(size: 9))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        Spacer()
                        Image(systemName: action.openInApp ? "arrow.up.right.square" : "safari")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(DesignTokens.accentActive)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DesignTokens.accentActive.opacity(0.08))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Chat Action Execution
    
    /// Handle actions triggered from Nudgy's chat tools
    private func handleChatAction(_ userInfo: [AnyHashable: Any]) {
        let actionType = userInfo["actionType"] as? String ?? ""
        let target = userInfo["target"] as? String ?? ""
        let contactName = userInfo["contactName"] as? String ?? ""
        let draftBody = userInfo["draftBody"] as? String ?? ""
        let draftSubject = userInfo["draftSubject"] as? String ?? ""
        
        switch actionType {
        case "CALL":
            if !target.isEmpty {
                ActionService.openCall(number: target)
            } else if !contactName.isEmpty {
                // Resolve contact then call
                Task {
                    let (resolved, _) = await ContactResolver.shared.resolveActionTarget(name: contactName, for: .call)
                    if let number = resolved {
                        ActionService.openCall(number: number)
                    } else {
                        HapticService.shared.error()
                        NotificationCenter.default.post(name: .nudgeNeedsContactPicker, object: nil)
                    }
                }
            }
        case "TEXT":
            NotificationCenter.default.post(
                name: .nudgeComposeMessage,
                object: nil,
                userInfo: ["recipient": target, "body": draftBody, "itemID": ""]
            )
        case "EMAIL":
            if !target.isEmpty {
                ActionService.openEmail(to: target, subject: draftSubject.isEmpty ? nil : draftSubject, body: draftBody.isEmpty ? nil : draftBody)
            } else if !contactName.isEmpty {
                Task {
                    let (resolved, _) = await ContactResolver.shared.resolveActionTarget(name: contactName, for: .email)
                    if let email = resolved {
                        ActionService.openEmail(to: email, subject: draftSubject.isEmpty ? nil : draftSubject, body: draftBody.isEmpty ? nil : draftBody)
                    } else {
                        HapticService.shared.error()
                        NotificationCenter.default.post(name: .nudgeNeedsContactPicker, object: nil)
                    }
                }
            }
        case "SEARCH":
            let actions = URLActionGenerator.generateActions(for: target, actionType: .search)
            if let first = actions.first {
                browserURL = first.url
            }
        case "NAVIGATE":
            if let url = URLActionGenerator.buildMapsDirectionsURL(destination: target) {
                UIApplication.shared.open(url)
            }
        case "LINK":
            if let url = URL(string: target) {
                browserURL = url
            }
        case "ALARM":
            NotificationCenter.default.post(
                name: .nudgeSetAlarm,
                object: nil,
                userInfo: ["content": target, "itemID": ""]
            )
        case "EMAIL_DRAFT", "TEXT_DRAFT":
            // Draft already shown via side effect — no additional action needed
            break
        default:
            break
        }
    }
    
    /// Execute a draft action (send email or text)
    private func executeDraftAction(_ draft: DraftAttachment) {
        HapticService.shared.actionButtonTap()
        if draft.draftType == "email" {
            if let target = draft.contactTarget, !target.isEmpty {
                ActionService.openEmail(to: target, subject: draft.subject, body: draft.body)
            } else {
                // Resolve contact
                Task {
                    let (resolved, _) = await ContactResolver.shared.resolveActionTarget(name: draft.recipientName, for: .email)
                    if let email = resolved {
                        ActionService.openEmail(to: email, subject: draft.subject, body: draft.body)
                    } else {
                        HapticService.shared.error()
                        NotificationCenter.default.post(name: .nudgeNeedsContactPicker, object: nil)
                    }
                }
            }
        } else {
            if let target = draft.contactTarget, !target.isEmpty {
                NotificationCenter.default.post(
                    name: .nudgeComposeMessage,
                    object: nil,
                    userInfo: ["recipient": target, "body": draft.body, "itemID": ""]
                )
            } else {
                Task {
                    let (resolved, _) = await ContactResolver.shared.resolveActionTarget(name: draft.recipientName, for: .text)
                    if let phone = resolved {
                        NotificationCenter.default.post(
                            name: .nudgeComposeMessage,
                            object: nil,
                            userInfo: ["recipient": phone, "body": draft.body, "itemID": ""]
                        )
                    } else {
                        HapticService.shared.error()
                        NotificationCenter.default.post(name: .nudgeNeedsContactPicker, object: nil)
                    }
                }
            }
        }
    }
    
    /// Execute an action attachment button tap
    private func executeActionAttachment(_ action: ActionAttachment) {
        HapticService.shared.actionButtonTap()
        handleChatAction([
            "actionType": action.actionType,
            "target": action.target,
            "contactName": action.contactName ?? ""
        ])
    }
    
    // MARK: - Streaming Bubble
    
    private var streamingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if penguinState.streamingText.isEmpty {
                    // Thinking dots
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(DesignTokens.textTertiary)
                                .frame(width: 6, height: 6)
                                .opacity(0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(i) * 0.2),
                                    value: penguinState.isChatGenerating
                                )
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingMD)
                } else {
                    Text(penguinState.streamingText)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM + 2)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.02))
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .frame(maxWidth: 280, alignment: .leading)
            
            Spacer(minLength: 60)
        }
    }
    
    // MARK: - Suggestion Chips
    
    private var suggestionChipRow: some View {
        let chips = SuggestionChipEngine.generateChips(
            modelContext: modelContext,
            conversationContext: penguinState.chatMessages.isEmpty ? .idle : .chatting,
            limit: 5
        )
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(chips) { chip in
                    suggestionChip(chip.label, icon: chip.icon) {
                        switch chip.action {
                        case .sendMessage(let text):
                            inputText = text
                            sendMessage()
                        case .openBrainDump:
                            NotificationCenter.default.post(name: .nudgeOpenBrainDump, object: nil)
                        case .openQuickAdd:
                            NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
                        case .startVoice:
                            // Can't start voice from chat sheet — dismiss first
                            if let onDismiss {
                                onDismiss()
                            } else {
                                dismiss()
                            }
                        default:
                            break
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
        }
        .padding(.vertical, DesignTokens.spacingSM)
    }
    
    private func suggestionChip(_ text: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingXS) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(text)
                    .font(AppTheme.caption)
            }
            .foregroundStyle(DesignTokens.accentActive)
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .background(
                Capsule()
                    .fill(DesignTokens.accentActive.opacity(0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(DesignTokens.accentActive.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Input Bar
    
    private var chatInputBar: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            TextField(
                String(localized: "Talk to Nudgy..."),
                text: $inputText,
                axis: .vertical
            )
            .font(AppTheme.body)
            .foregroundStyle(DesignTokens.textPrimary)
            .lineLimit(1...4)
            .focused($isInputFocused)
            .onSubmit { sendMessage() }
            .textFieldStyle(.plain)
            
            // Send button
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? DesignTokens.textTertiary
                            : DesignTokens.accentActive
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || penguinState.isChatGenerating)
            .nudgeAccessibility(
                label: String(localized: "Send message"),
                hint: String(localized: "Sends your message to Nudgy"),
                traits: .isButton
            )
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.vertical, DesignTokens.spacingMD)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
    
    // MARK: - Send
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !penguinState.isChatGenerating else { return }
        
        inputText = ""
        chatError = nil
        HapticService.shared.prepare()
        
        // Check AI availability before sending
        guard NudgyEngine.shared.isAvailable else {
            chatError = String(localized: "AI is unavailable right now. Check your connection and try again.")
            penguinState.addSystemMessage("⚠️ " + (chatError ?? ""))
            return
        }

        // ADHD: Detect mood and adjust penguin expression before sending
        let mood = NudgyEngine.shared.detectMood(from: text)
        switch mood {
        case .overwhelmed, .anxious, .sad:
            penguinState.expression = .confused
        case .frustrated:
            penguinState.expression = .confused
        default:
            break
        }

        // Route through NudgyEngine for OpenAI-powered conversation
        NudgyEngine.shared.chat(text, modelContext: modelContext)
    }
}

// MARK: - Preview

#Preview {
    let state = PenguinState()
    state.startChatting()
    
    return NudgyChatView()
        .modelContainer(for: [NudgeItem.self, BrainDump.self], inMemory: true)
        .environment(state)
        .environment(AppSettings())
}
