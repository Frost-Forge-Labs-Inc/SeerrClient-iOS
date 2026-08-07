// SeerrClientMacApp.swift
// SeerrClientMac
//
// macOS app entry point. Mirrors the iOS SeerrClientApp bootstrap:
// constructs ServerStore + AppState, runs UITest bootstrap when enabled,
// injects both into the environment, and presents MacRootView as the root.

import SwiftUI

// MARK: - App Entry Point

/// The @main entry point for SeerrClient on macOS.
///
/// Responsibilities:
/// - Creates the singleton `AppState` that tracks the active server and auth status.
/// - Creates the singleton `ServerStore` for persisting server configurations.
/// - Injects both into the SwiftUI environment.
/// - Presents `MacRootView` as the root scene (placeholders in M2a).
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
            MacRootView()
                .environment(appState)
                .environment(serverStore)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
    }
}
