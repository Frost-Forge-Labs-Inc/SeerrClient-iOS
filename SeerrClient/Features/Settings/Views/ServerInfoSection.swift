// ServerInfoSection.swift
// SeerrClient
//
// Read-only server details shown on the profile screen.

import SwiftUI

// MARK: - ServerInfoSection

struct ServerInfoSection: View {
    let server: ServerConfiguration
    let serverStatus: ServerStatus?

    var body: some View {
        Section("Server") {
            infoRow(title: "Name", value: server.displayName)
            infoRow(title: "URL", value: server.baseURL, monospaced: true)
            infoRow(title: "Backend", value: server.backendType.displayName)
            infoRow(title: "Version", value: serverStatus?.version ?? "—")
        }
    }

    private func infoRow(title: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)

            Spacer(minLength: 8)

            Text(value)
                .font(monospaced ? .system(.footnote, design: .monospaced) : .body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(monospaced ? .middle : .tail)
                .multilineTextAlignment(.trailing)
        }
    }
}
