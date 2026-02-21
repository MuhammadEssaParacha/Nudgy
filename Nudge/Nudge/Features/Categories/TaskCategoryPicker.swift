//
//  TaskCategoryPicker.swift
//  Nudge
//
//  Compact task category picker — shows all 20 categories in a grid.
//  Used alongside the existing CategoryPickerView (color/icon/energy picker).
//  Tapping a category sets it; tapping again deselects (auto-classify).
//

import SwiftUI

// MARK: - Task Category Picker

/// Compact grid showing all 20 task categories for manual selection.
struct TaskCategoryPicker: View {
    
    @Binding var selectedCategory: TaskCategory?
    var columns: Int = 4
    var compact: Bool = false
    
    private let categories = TaskCategory.allCases
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            if !compact {
                HStack(spacing: DesignTokens.spacingXS) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(String(localized: "Task Type"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignTokens.textSecondary)
                    
                    Spacer()
                    
                    if selectedCategory != nil {
                        Button {
                            HapticService.shared.cardAppear()
                            selectedCategory = nil
                        } label: {
                            Text(String(localized: "Auto"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
                ForEach(categories, id: \.self) { cat in
                    categoryCell(cat)
                }
            }
        }
    }
    
    private func categoryCell(_ cat: TaskCategory) -> some View {
        let isSelected = selectedCategory == cat
        let tint = cat.primaryColor
        
        return Button {
            HapticService.shared.cardAppear()
            withAnimation(AnimationConstants.springSmooth) {
                selectedCategory = isSelected ? nil : cat
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: cat.icon)
                    .font(.system(size: compact ? 16 : 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : tint)
                
                if !compact {
                    Text(cat.label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isSelected ? .white : DesignTokens.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 6 : 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? tint : tint.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? tint.opacity(0.5) : tint.opacity(0.10), lineWidth: isSelected ? 1.5 : 0.5)
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: cat.label,
            hint: isSelected ? String(localized: "Selected. Tap to deselect.") : String(localized: "Tap to select \(cat.label) category"),
            traits: isSelected ? [.isButton, .isSelected] : .isButton
        )
    }
}

// MARK: - Inline Category Chip

/// Compact single-line category chip for card headers.
struct CategoryChip: View {
    let category: TaskCategory
    var small: Bool = false
    
    var body: some View {
        let tint = category.primaryColor
        
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.system(size: small ? 9 : 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(category.label)
                .font(.system(size: small ? 9 : 11, weight: .medium))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, small ? 6 : 8)
        .padding(.vertical, small ? 2 : 4)
        .background(
            Capsule()
                .fill(tint.opacity(0.08))
                .overlay(
                    Capsule()
                        .strokeBorder(tint.opacity(0.12), lineWidth: 0.5)
                )
        )
    }
}
