//
//  DraftService.swift
//  Nudge
//
//  Background AI draft generation for actionable tasks.
//  Pre-fetches drafts when a card becomes active, caches on NudgeItem.
//  Pro-only feature.
//

import Foundation
import SwiftData
import os

/// Manages AI-generated message drafts for actionable tasks.
/// Runs draft generation in the background when items become the active "One-Thing."
@MainActor @Observable
final class DraftService {
    
    static let shared = DraftService()
    
    // MARK: - State
    
    private(set) var isGenerating = false
    private(set) var lastError: String?
    
    /// Currently generating draft for this item ID (prevents duplicate calls)
    private var inFlightItemID: UUID?
    
    // MARK: - Generate Draft
    
    /// Generate an AI draft for the given item if eligible.
    /// - Returns silently if: AI unavailable, non-actionable, draft already cached, or already in-flight.
    /// Note: Drafts use on-device Apple Foundation Models (free) — no Pro gate needed.
    func generateDraftIfNeeded(
        for item: NudgeItem,
        isPro: Bool = true,
        repository: NudgeRepository,
        senderName: String? = nil
    ) async {
        
        // Only for text/email actions (calling doesn't need a draft)
        guard let actionType = item.actionType,
              actionType == .text || actionType == .email else { return }
        
        // Don't regenerate if draft exists and is less than 24 hours old
        if item.hasDraft,
           let generatedAt = item.draftGeneratedAt,
           Date().timeIntervalSince(generatedAt) < 86400 {
            return
        }
        
        // Prevent duplicate in-flight requests
        guard inFlightItemID != item.id else { return }
        
        // Check if NudgyEngine AI is available (OpenAI or on-device)
        guard NudgyEngine.shared.isAvailable || AIService.shared.isAvailable else {
            lastError = String(localized: "AI is not available")
            return
        }
        
        inFlightItemID = item.id
        isGenerating = true
        lastError = nil
        
        do {
            // Try NudgyEngine first (OpenAI-powered), fall back to on-device AIService
            let categoryHint = item.resolvedCategory != .general ? item.resolvedCategory.label : nil
            
            if NudgyEngine.shared.isAvailable {
                if let result = await NudgyEngine.shared.generateDraft(
                    taskContent: item.content,
                    actionType: actionType.rawValue,
                    contactName: item.contactName,
                    senderName: senderName,
                    categoryLabel: categoryHint
                ) {
                    if !result.draft.isEmpty {
                        repository.updateDraft(item, draft: result.draft, subject: result.subject.isEmpty ? nil : result.subject)
                    }
                }
            } else {
                let response = try await AIService.shared.generateDraft(
                    taskContent: item.content,
                    actionType: actionType,
                    contactName: item.contactName,
                    senderName: senderName
                )
                
                if !response.draft.isEmpty {
                    repository.updateDraft(item, draft: response.draft, subject: response.subject.isEmpty ? nil : response.subject)
                }
            }
        } catch {
            // Silently fail — user can still compose manually
            lastError = error.localizedDescription
            Log.services.warning("Draft generation failed: \(error, privacy: .public)")
        }
        
        isGenerating = false
        inFlightItemID = nil
    }
    
    /// Clear a draft from an item (user wants to regenerate)
    func clearDraft(for item: NudgeItem, repository: NudgeRepository) {
        repository.updateDraft(item, draft: "", subject: nil)
    }
    
    /// Force regenerate a draft (user tapped refresh)
    func regenerateDraft(
        for item: NudgeItem,
        isPro: Bool = true,
        repository: NudgeRepository,
        senderName: String? = nil
    ) async {
        // Clear existing draft first
        clearDraft(for: item, repository: repository)
        // Then generate fresh
        await generateDraftIfNeeded(for: item, isPro: isPro, repository: repository, senderName: senderName)
    }
}
