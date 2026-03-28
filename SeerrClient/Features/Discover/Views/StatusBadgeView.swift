// StatusBadgeView.swift
// SeerrClient
//
// A small pill-shaped badge indicating the media availability status.
// Shows on the top-trailing corner of media cards when the item has a
// known status (pending, processing, partial, available).

import SwiftUI

// MARK: - StatusBadgeView

/// Displays a coloured pill badge for a media item's availability status.
///
/// Returns `EmptyView` when the status code doesn't warrant a visible badge
/// (unknown, deleted, or nil).
///
/// Usage:
/// ```swift
/// StatusBadgeView(statusCode: mediaInfo?.status)
/// ```
struct StatusBadgeView: View {

    /// The raw status integer from `MediaInfo.status`.
    let statusCode: Int?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let code = statusCode,
           let status = MediaStatusCode(rawValue: code),
           status.showsBadge {
            HStack(spacing: 4) {
                Circle()
                    .fill(dotColor(for: status))
                    .frame(width: 6, height: 6)
                Text(status.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(labelColor(for: status))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor(for: status), in: Capsule())
        }
    }

    // MARK: - Colors

    private func dotColor(for status: MediaStatusCode) -> Color {
        switch status {
        case .pending:              return Color(red: 0.96, green: 0.62, blue: 0.05) // amber
        case .processing:           return Color(red: 0.55, green: 0.23, blue: 0.98) // purple
        case .partiallyAvailable:   return Color(red: 0.55, green: 0.23, blue: 0.98)
        case .available:            return Color(red: 0.13, green: 0.77, blue: 0.34) // green
        default:                    return .clear
        }
    }

    private func labelColor(for status: MediaStatusCode) -> Color {
        let isDark = colorScheme == .dark
        switch status {
        case .pending:
            return isDark ? Color(red: 1.0, green: 0.85, blue: 0.45) : Color(red: 0.60, green: 0.38, blue: 0.0)
        case .processing, .partiallyAvailable:
            return isDark ? Color(red: 0.75, green: 0.60, blue: 1.0) : Color(red: 0.40, green: 0.15, blue: 0.75)
        case .available:
            return isDark ? Color(red: 0.30, green: 0.87, blue: 0.50) : Color(red: 0.05, green: 0.50, blue: 0.18)
        default:
            return .primary
        }
    }

    private func backgroundColor(for status: MediaStatusCode) -> Color {
        let isDark = colorScheme == .dark
        switch status {
        case .pending:
            return isDark ? Color(red: 0.35, green: 0.25, blue: 0.0) : Color(red: 1.0, green: 0.95, blue: 0.82)
        case .processing, .partiallyAvailable:
            return isDark ? Color(red: 0.25, green: 0.15, blue: 0.40) : Color(red: 0.93, green: 0.88, blue: 1.0)
        case .available:
            return isDark ? Color(red: 0.08, green: 0.28, blue: 0.12) : Color(red: 0.85, green: 0.97, blue: 0.88)
        default:
            return .clear
        }
    }
}

// MARK: - Previews

#Preview("All Statuses") {
    VStack(spacing: 12) {
        StatusBadgeView(statusCode: 2) // pending
        StatusBadgeView(statusCode: 3) // processing
        StatusBadgeView(statusCode: 4) // partial
        StatusBadgeView(statusCode: 5) // available
        StatusBadgeView(statusCode: 1) // unknown — should be empty
        StatusBadgeView(statusCode: nil) // nil — should be empty
    }
    .padding()
}
