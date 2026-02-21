//
//  InAppBrowserView.swift
//  Nudge
//
//  SFSafariViewController wrapper so users never leave Nudge.
//  "Order towels" → Amazon opens INSIDE Nudge → shop → return to tasks.
//  Nudge becomes the shell around everything.
//

import SwiftUI
import SafariServices

// MARK: - InAppBrowserView (UIViewControllerRepresentable)

/// Wraps SFSafariViewController for in-app browsing.
/// Users stay inside Nudge while shopping, researching, booking, etc.
struct InAppBrowserView: UIViewControllerRepresentable {
    let url: URL
    var tintColor: UIColor = UIColor(DesignTokens.accentActive)
    var onDismiss: (() -> Void)?
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.dismissButtonStyle = .done
        if #unavailable(iOS 26) {
            safari.preferredControlTintColor = tintColor
            safari.preferredBarTintColor = UIColor.black
        }
        safari.delegate = context.coordinator
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDismiss: (() -> Void)?
        
        init(onDismiss: (() -> Void)?) {
            self.onDismiss = onDismiss
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss?()
        }
    }
}

// MARK: - Browser Sheet Modifier

/// Convenience modifier for presenting the in-app browser as a sheet.
struct InAppBrowserSheet: ViewModifier {
    @Binding var url: URL?
    var onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { url != nil },
                set: { if !$0 { url = nil } }
            )) {
                if let browseURL = url {
                    InAppBrowserView(url: browseURL) {
                        url = nil
                        onDismiss?()
                    }
                    .ignoresSafeArea()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
    }
}

extension View {
    /// Present an in-app browser when the URL binding is non-nil.
    func inAppBrowser(url: Binding<URL?>, onDismiss: (() -> Void)? = nil) -> some View {
        modifier(InAppBrowserSheet(url: url, onDismiss: onDismiss))
    }
}
