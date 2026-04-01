// RequestButtonView.swift
// SeerrClient
//
// Status-aware request button for media detail screens. Changes label, icon,
// and color based on the current media availability status. The actual request
// form is deferred to Week 6 — this button triggers the sheet binding.

import SwiftUI

// MARK: - RequestButtonView

/// A button whose appearance adapts to the media's current request/availability status.
///
/// For TV shows, Pending and Processing states remain actionable so users can
/// request additional unrequested seasons — matching the Jellyseerr web UI.
struct RequestButtonView: View {

    /// The media info containing status. Nil means not yet loaded.
    let mediaInfo: MediaInfo?
    /// Whether this is a TV show (enables "request more seasons" for Pending/Processing states).
    var isTvShow: Bool = false
    /// Binding to trigger the request sheet.
    @Binding var showRequestSheet: Bool

    var body: some View {
        let config = buttonConfig(for: mediaInfo?.status)

        Button {
            if config.isActionable {
                showRequestSheet = true
            }
        } label: {
            Label(config.label, systemImage: config.icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(config.tint)
        .disabled(!config.isActionable)
        .padding(.horizontal)
        .accessibilityLabel(config.accessibilityLabel)
    }

    // MARK: - Button Configuration

    private struct ButtonConfig {
        let label: String
        let icon: String
        let tint: Color
        let isActionable: Bool
        let accessibilityLabel: String
    }

    private func buttonConfig(for status: Int?) -> ButtonConfig {
        guard let status else {
            return ButtonConfig(
                label: "Request",
                icon: "plus.circle.fill",
                tint: .blue,
                isActionable: true,
                accessibilityLabel: "Request this media"
            )
        }

        switch status {
        case 5: // Available
            return ButtonConfig(
                label: "Available",
                icon: "checkmark.circle.fill",
                tint: .green,
                isActionable: false,
                accessibilityLabel: "Already available"
            )
        case 2: // Pending
            if isTvShow {
                return ButtonConfig(
                    label: "Request More",
                    icon: "plus.circle.fill",
                    tint: .blue,
                    isActionable: true,
                    accessibilityLabel: "Some seasons pending. Tap to request more."
                )
            }
            return ButtonConfig(
                label: "Pending",
                icon: "clock.fill",
                tint: .orange,
                isActionable: false,
                accessibilityLabel: "Request is pending approval"
            )
        case 3: // Processing
            if isTvShow {
                return ButtonConfig(
                    label: "Request More",
                    icon: "plus.circle.fill",
                    tint: .blue,
                    isActionable: true,
                    accessibilityLabel: "Some seasons requested. Tap to request more."
                )
            }
            return ButtonConfig(
                label: "Requested",
                icon: "arrow.triangle.2.circlepath",
                tint: .purple,
                isActionable: false,
                accessibilityLabel: "Request is being processed"
            )
        case 4: // Partially Available
            return ButtonConfig(
                label: "Request More",
                icon: "plus.circle.fill",
                tint: .blue,
                isActionable: true,
                accessibilityLabel: "Partially available. Tap to request remaining."
            )
        default: // Unknown or 1 (no status)
            return ButtonConfig(
                label: "Request",
                icon: "plus.circle.fill",
                tint: .blue,
                isActionable: true,
                accessibilityLabel: "Request this media"
            )
        }
    }
}
