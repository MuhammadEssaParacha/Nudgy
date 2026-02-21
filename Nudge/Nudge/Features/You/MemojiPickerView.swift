//
//  MemojiPickerView.swift
//  Nudge
//
//  Presents the emoji keyboard so the user can tap a Memoji sticker.
//  A hidden UITextView captures the sticker image (NSTextAttachment)
//  and surfaces it as a UIImage for avatar use.
//

import SwiftUI
import UIKit

// MARK: - Memoji Picker Sheet

struct MemojiPickerView: View {
    
    @Environment(\.dismiss) private var dismiss
    var onMemojiSelected: (UIImage) -> Void
    
    @State private var capturedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Preview of selected Memoji
                    if let image = capturedImage {
                        VStack(spacing: DesignTokens.spacingMD) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 140)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(DesignTokens.accentActive.opacity(0.5), lineWidth: 2.5)
                                }
                                .shadow(color: DesignTokens.accentActive.opacity(0.25), radius: 16, y: 4)
                                .transition(.scale.combined(with: .opacity))
                            
                            Text(String(localized: "Looking good! 🐧"))
                                .font(AppTheme.body)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    } else {
                        // Hint
                        VStack(spacing: DesignTokens.spacingMD) {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 60))
                                .foregroundStyle(DesignTokens.accentActive.opacity(0.35))
                            
                            Text(String(localized: "Pick a Memoji sticker"))
                                .font(AppTheme.headline)
                                .foregroundStyle(DesignTokens.textPrimary)
                            
                            Text(String(localized: "Swipe to the Memoji section on the keyboard below and tap the sticker you want"))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    
                    Spacer()
                    
                    // Invisible capture field — the keyboard attaches to this
                    MemojiCaptureField { image in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            capturedImage = image
                        }
                    }
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle(String(localized: "Choose Memoji"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        if let image = capturedImage {
                            onMemojiSelected(image)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(capturedImage != nil ? DesignTokens.accentActive : DesignTokens.textTertiary)
                    .disabled(capturedImage == nil)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - UIKit Invisible Text View for Memoji Capture

/// An invisible UITextView that auto-becomes first responder to show the keyboard.
/// When the user taps a Memoji sticker, it arrives as an NSTextAttachment image.
/// We extract it, pass it up, and clear the text view for the next pick.
struct MemojiCaptureField: UIViewRepresentable {
    
    var onImageCaptured: (UIImage) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.allowsEditingTextAttributes = true
        textView.font = UIFont.systemFont(ofSize: 48)
        textView.textAlignment = .center
        textView.backgroundColor = .clear
        textView.textColor = .clear
        textView.tintColor = .clear
        textView.keyboardAppearance = .dark
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.autocapitalizationType = .none
        textView.isScrollEnabled = false
        
        context.coordinator.textView = textView
        
        // Auto-show keyboard after a brief delay (sheet animation)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            textView.becomeFirstResponder()
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var onImageCaptured: (UIImage) -> Void
        weak var textView: UITextView?
        
        init(onImageCaptured: @escaping (UIImage) -> Void) {
            self.onImageCaptured = onImageCaptured
        }
        
        func textViewDidChange(_ textView: UITextView) {
            var found = false
            
            // Check for image attachments (Memoji stickers arrive as NSTextAttachment)
            textView.attributedText.enumerateAttribute(
                .attachment,
                in: NSRange(location: 0, length: textView.attributedText.length),
                options: []
            ) { value, _, stop in
                if let attachment = value as? NSTextAttachment {
                    var image: UIImage?
                    
                    if let attachmentImage = attachment.image {
                        image = attachmentImage
                    } else if let data = attachment.fileWrapper?.regularFileContents {
                        image = UIImage(data: data)
                    } else if let imgFromBounds = attachment.image(
                        forBounds: CGRect(origin: .zero, size: CGSize(width: 512, height: 512)),
                        textContainer: nil,
                        characterIndex: 0
                    ) {
                        image = imgFromBounds
                    }
                    
                    if let image {
                        let rendered = self.renderAtSize(image, size: CGSize(width: 512, height: 512))
                        found = true
                        DispatchQueue.main.async {
                            self.onImageCaptured(rendered)
                        }
                        stop.pointee = true
                    }
                }
            }
            
            // Clear the text view after capture so it's ready for another pick
            if found {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.1))
                    textView.attributedText = NSAttributedString(string: "")
                }
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Block return key — don't dismiss keyboard
            if text == "\n" { return false }
            // Block plain text input — only allow rich content (stickers)
            if !text.isEmpty {
                // Allow if it might be an emoji (single character)
                // Block multi-character text strings (typing)
                if text.count > 2 { return false }
            }
            return true
        }
        
        private func renderAtSize(_ image: UIImage, size: CGSize) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MemojiPickerView { image in
        print("Selected Memoji: \(image.size)")
    }
}
