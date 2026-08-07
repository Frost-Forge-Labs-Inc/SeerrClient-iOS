// SeerrClientMacApp.swift
// SeerrClientMac
//
// macOS app entry point. Mirrors the iOS SeerrClientApp bootstrap:
// constructs ServerStore + AppState, runs UITest bootstrap when enabled,
// injects both into the environment, and presents MacContentView as the root.

import SwiftUI

// MARK: - App Entry Point

/// The @main entry point for SeerrClient on macOS.
///
/// Responsibilities:
/// - Creates the singleton `AppState` that tracks the active server and auth status.
/// - Creates the singleton `ServerStore` for persisting server configurations.
/// - Injects both into the SwiftUI environment.
/// - Presents `MacContentView` as the root scene (shell + login + server setup in M2b).
@main
struct SeerrClientMacApp: App {

    // MARK: - Shared State

    /// Persistent store for server configurations.
    @State private var serverStore: ServerStore

    /// Global observable app state (current server, auth, navigation).
    /// Receives the shared `serverStore` so the API client can persist TOFU fingerprints.
    @State private var appState: AppState

    init() {
        let store = ServerStore()
        _serverStore = State(initialValue: store)
        let state = AppState(serverStore: store)
        let uiTestConfiguration = UITestLaunchConfiguration.current

        if uiTestConfiguration.isEnabled {
            UITestAppBootstrapper.configureIfNeeded(appState: state, serverStore: store)
        }
        _appState = State(initialValue: state)
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            MacContentView()
                .environment(appState)
                .environment(serverStore)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1240, height: 820)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            MacAppCommands(appState: appState)
        }
    }
}

// MARK: - Menu Commands (M2b minimal set)

/// Minimal menu bar commands for M2b: Toggle Sidebar (⌘0) and Switch Server (⌘⇧K).
/// Refresh / Find / poster density / Settings{} deferred to M3.
private struct MacAppCommands: Commands {

    let appState: AppState

    @FocusedValue(\.macSidebarVisibility) private var sidebarVisibility

    var body: some Commands {
        // View → Toggle Sidebar (⌘0). Replaces the default sidebar group so we own the shortcut.
        CommandGroup(replacing: .sidebar) {
            Button("Toggle Sidebar") {
                guard let sidebarVisibility else { return }
                sidebarVisibility.wrappedValue =
                    sidebarVisibility.wrappedValue == .detailOnly ? .all : .detailOnly
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(sidebarVisibility == nil)
        }

        CommandMenu("Server") {
            Button("Switch Server / Account…") {
                appState.returnToServerList()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .disabled(appState.showServerSetup)
        }
    }
}
