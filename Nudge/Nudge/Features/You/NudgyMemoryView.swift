//
//  NudgyMemoryView.swift
//  Nudge
//
//  Shows what Nudgy remembers about you — facts learned from conversations,
//  organized by category. Users can delete facts they don't want Nudgy to know.
//
//  Part of the "Nudgy Remembers" feature that surfaces contextual memories
//  during conversations and task suggestions.
//

import SwiftUI

struct NudgyMemoryView: View {
    
    @State private var memory = NudgyMemory.shared
    @State private var searchText: String = ""
    
    private var groupedFacts: [(category: NudgyMemoryFact.FactCategory, facts: [NudgyMemoryFact])] {
        let facts = memory.store.facts
        let filtered: [NudgyMemoryFact]
        
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filtered = facts
        } else {
            let query = searchText.lowercased()
            filtered = facts.filter { $0.fact.lowercased().contains(query) }
        }
        
        let grouped = Dictionary(grouping: filtered, by: \.category)
        return grouped
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { (category: $0.key, facts: $0.value.sorted { $0.learnedAt > $1.learnedAt }) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingLG) {
                // Search
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.textTertiary)
                    
                    TextField(String(localized: "Search memories..."), text: $searchText)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .submitLabel(.search)
                }
                .padding(DesignTokens.spacingMD)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
                
                if memory.store.facts.isEmpty {
                    emptyState
                } else {
                    // Fact count
                    HStack {
                        Text(String(localized: "\(memory.store.facts.count) things Nudgy remembers"))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                        Spacer()
                    }
                    
                    // Grouped facts
                    ForEach(groupedFacts, id: \.category) { group in
                        factSection(category: group.category, facts: group.facts)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingSM)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(String(localized: "Nudgy's Memory"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.accentActive.opacity(0.5))
            
            Text(String(localized: "Nudgy hasn't learned anything yet"))
                .font(AppTheme.title3)
                .foregroundStyle(DesignTokens.textPrimary)
            
            Text(String(localized: "As you chat with Nudgy, it'll remember things about you to personalize your experience."))
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignTokens.spacingXXXL)
    }
    
    // MARK: - Fact Section
    
    private func factSection(category: NudgyMemoryFact.FactCategory, facts: [NudgyMemoryFact]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: categoryIcon(category))
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.accentActive)
                
                Text(categoryLabel(category))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text("\(facts.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            
            ForEach(facts) { fact in
                factRow(fact)
            }
        }
    }
    
    private func factRow(_ fact: NudgyMemoryFact) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            Text(fact.fact)
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(3)
            
            Spacer()
            
            Button {
                memory.forget(fact.id)
                HapticService.shared.actionButtonTap()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.spacingSM)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
    }
    
    // MARK: - Category Helpers
    
    private func categoryLabel(_ cat: NudgyMemoryFact.FactCategory) -> String {
        switch cat {
        case .preference: return String(localized: "Preferences")
        case .personal: return String(localized: "Personal")
        case .emotional: return String(localized: "Emotional")
        case .behavioral: return String(localized: "Habits")
        case .contextual: return String(localized: "Context")
        }
    }
    
    private func categoryIcon(_ cat: NudgyMemoryFact.FactCategory) -> String {
        switch cat {
        case .preference: return "slider.horizontal.3"
        case .personal: return "person.fill"
        case .emotional: return "heart.fill"
        case .behavioral: return "arrow.trianglehead.2.counterclockwise"
        case .contextual: return "globe"
        }
    }
}
