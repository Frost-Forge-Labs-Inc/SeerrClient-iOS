// SeerrClientApp.swift
// SeerrClient
//
// App entry point. Bootstraps the shared AppState and injects it into the
// SwiftUI environment so every view in the hierarchy can reach it.

import SwiftUI

// MARK: - App Entry Point

/// The @main entry point for SeerrClient.
///
/// Responsibilities:
/// - Creates the singleton `AppState` that tracks the active server and auth status.
/// - Creates the singleton `ServerStore` for persisting server configurations.
/// - Injects both into the SwiftUI environment.
/// - Presents `ContentView` as the root scene.
@main
struct SeerrClientApp: App {

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
            ContentView()
                .environment(appState)
                .environment(serverStore)
        }
    }
}
