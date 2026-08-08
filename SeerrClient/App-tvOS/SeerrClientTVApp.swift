// SeerrClientTVApp.swift
// SeerrClientTV (Octopus Explorer — tvOS)
//
// Milestone 2: nav shell. @main entry that bootstraps the SHARED AppState and
// ServerStore (identical wiring to the iOS SeerrClientApp) and presents the
// tvOS root view TVRootView. Real feature screens remain Milestone 3.

import SwiftUI

@main
struct SeerrClientTVApp: App {

    /// Persistent store for server configurations (shared type, dual target membership).
    @State private var serverStore: ServerStore

    /// Global observable app state (shared type, dual target membership).
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

    var body: some Scene {
        WindowGroup {
            TVRootView()
                .environment(appState)
                .environment(serverStore)
        }
    }
}
