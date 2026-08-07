// MacRootView.swift
// SeerrClientMac
//
// Root view for the macOS target. Mirrors the iOS ContentView branch structure
// (server setup / login / main / loading) but renders placeholders only.
// Real login + sidebar UI lands in M2b.

import SwiftUI

// MARK: - MacRootView

/// macOS root view that reads `AppState` + `ServerStore` from the environment
/// and branches on the same flags as the iOS `ContentView`.
///
/// Each branch is a simple SF Symbol + label placeholder for M2a —
/// proving shared state wiring compiles and runs on macOS.
struct MacRootView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState
    @Environment(ServerStore.self) private var serverStore

    // MARK: - Body

    var body: some View {
        Group {
            if appState.showServerSetup {
                placeholder(
                    systemImage: "server.rack",
                    title: "Server Setup",
                    subtitle: "Placeholder — real UI in M2b"
                )
            } else if appState.showLogin, let server = appState.activeServer {
                placeholder(
                    systemImage: "person.badge.key",
                    title: "Login",
                    subtitle: server.displayName
                )
            } else if appState.showMainInterface {
                placeholder(
                    systemImage: "sidebar.left",
                    title: "Main Interface — sidebar shell coming in M2b",
                    subtitle: "Authenticated"
                )
            } else {
                placeholder(
                    systemImage: "progress.indicator",
                    title: "Loading…",
                    subtitle: "Restoring session"
                )
            }
        }
        .frame(minWidth: 900, idealWidth: 1200, maxWidth: .infinity,
               minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: appState.showServerSetup)
        .animation(.easeInOut(duration: 0.25), value: appState.showMainInterface)
    }

    // MARK: - Placeholder

    @ViewBuilder
    private func placeholder(systemImage: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text(title)
                .font(.largeTitle.weight(.semibold))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Server Setup") {
    let store = ServerStore()
    let state = AppState(serverStore: store)
    MacRootView()
        .environment(state)
        .environment(store)
}
