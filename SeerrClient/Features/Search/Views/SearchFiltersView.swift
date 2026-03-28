// SearchFiltersView.swift
// SeerrClient
//
// Reusable filter chip row for the Search screen. Displays a horizontal
// scrolling set of capsule-shaped type filter buttons (All, Movies, TV, People).

import SwiftUI

// MARK: - SearchFilterChip

/// A single capsule-shaped filter chip button.
struct SearchFilterChip: View {

    /// The label text displayed on the chip.
    let label: String
    /// Whether this chip is currently selected.
    let isSelected: Bool
    /// Action triggered when the chip is tapped.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                // Note: .white works with default blue accent; for custom accent colors,
                // consider colorScheme-aware label color for WCAG AA contrast.
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - SearchFiltersRow

/// A horizontal scrolling row of search type filter chips.
struct SearchFiltersRow: View {

    /// The currently selected search type.
    let selectedType: SearchType
    /// Callback when a filter chip is tapped.
    let onSelect: (SearchType) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    SearchFilterChip(
                        label: type.displayName,
                        isSelected: selectedType == type
                    ) {
                        onSelect(type)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Previews

#Preview("Filter Chips") {
    VStack(spacing: 20) {
        SearchFiltersRow(selectedType: .all) { _ in }
        SearchFiltersRow(selectedType: .movie) { _ in }
        SearchFiltersRow(selectedType: .person) { _ in }
    }
    .padding()
}
