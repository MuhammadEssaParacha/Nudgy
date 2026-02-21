//
//  NudgyChatOverlay.swift
//  Nudge
//
//  Glassmorphic chat overlay sheet — opened from NudgyHomeView "Chat" button.
//  Replaces the old inline text field bar with a dedicated typing UI.
//

import SwiftUI

struct NudgyChatOverlay: View {

    @Binding var inputText: String
    var onSend: () -> Void
    var onClearHistory: () -> Void
    var penguinState: PenguinState

    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chatMessages: [ChatMessage] { penguinState.chatMessages }
    private var isChatGenerating: Bool { penguinState.isChatGenerating }

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar area with title
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Chat with Nudgy"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    if !chatMessages.isEmpty {
                        Text(String(localized: "\(chatMessages.count) messages"))
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }

                Spacer()

                // Close button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 32, height: 32)
                        )
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "Close chat"),
                    traits: .isButton
                )
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingSM)

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DesignTokens.spacingSM) {
                        if chatMessages.isEmpty {
                            VStack(spacing: DesignTokens.spacingMD) {
                                Image(systemName: "bubble.left.and.text.bubble.right")
                                    .font(.system(size: 36))
                                    .foregroundStyle(DesignTokens.textTertiary)
                                    .symbolRenderingMode(.hierarchical)
                                Text(String(localized: "Say hi to Nudgy!"))
                                    .font(.system(size: 14))
                                    .foregroundStyle(DesignTokens.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }

                        ForEach(chatMessages) { message in
                            chatBubble(for: message)
                                .id(message.id)
                        }

                        if isChatGenerating {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .fill(DesignTokens.accentActive.opacity(0.5))
                                        .frame(width: 6, height: 6)
                                        .offset(y: reduceMotion ? 0 : (isChatGenerating ? -3 : 3))
                                        .animation(
                                            reduceMotion ? .none :
                                            .easeInOut(duration: 0.45)
                                                .repeatForever(autoreverses: true)
                                                .delay(Double(i) * 0.12),
                                            value: isChatGenerating
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, DesignTokens.spacingLG)
                            .id("typing")
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingSM)
                }
                .onChange(of: chatMessages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        if isChatGenerating {
                            proxy.scrollTo("typing", anchor: .bottom)
                        } else {
                            proxy.scrollTo(chatMessages.last?.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isChatGenerating) { _, generating in
                    if !generating, let lastId = chatMessages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Input bar
            HStack(spacing: DesignTokens.spacingSM) {
                TextField(
                    String(localized: "Type a message..."),
                    text: $inputText,
                    axis: .vertical
                )
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendIfReady()
                }
                .textFieldStyle(.plain)

                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        sendIfReady()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .disabled(isChatGenerating)
                    .transition(.scale.combined(with: .opacity))
                    .nudgeAccessibility(
                        label: String(localized: "Send message"),
                        traits: .isButton
                    )
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM + 2)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
            )
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, DesignTokens.spacingMD)
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                isInputFocused = true
            }
        }
    }

    private func sendIfReady() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSend()
        // Stay open — user can see the response arrive
    }

    // MARK: - Chat Bubble

    @ViewBuilder
    private func chatBubble(for message: ChatMessage) -> some View {
        if message.role == .system {
            Text(message.text)
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.horizontal, DesignTokens.spacingSM)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.04)))
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            HStack {
                if message.role == .user { Spacer(minLength: 60) }

                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                    Text(message.text)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM + 2)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(message.role == .user
                                      ? DesignTokens.accentActive.opacity(0.2)
                                      : Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            message.role == .user
                                                ? DesignTokens.accentActive.opacity(0.15)
                                                : Color.white.opacity(0.06),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                }
                .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)

                if message.role == .nudgy { Spacer(minLength: 60) }
            }
        }
    }
}
