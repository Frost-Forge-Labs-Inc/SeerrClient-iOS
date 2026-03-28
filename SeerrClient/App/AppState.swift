// AppState.swift
// SeerrClient
//
// Global observable application state. Holds references to the currently active
// server, the authenticated user, and top-level navigation flags. Injected into
// the SwiftUI environment so all views share a single source of truth.

import Foundation
import Observation

// MARK: - AppState

/// Global app state that drives the root navigation decision in `ContentView`.
///
/// Inject via `.environment(appState)` and access with:
/// ```swift
/// @Environment(AppState.self) private var appState
/// ```
@Observable
@MainActor
final class AppState {

    // MARK: - Current Server

    /// The currently active server configuration. `nil` means no server is selected.
    var activeServer: ServerConfiguration?

    /// The API client configured for `activeServer`. Rebuilt whenever `activeServer` changes.
    private(set) var apiClient: SeerrAPIClient?

    // MARK: - Authentication

    /// The currently authenticated user for the active server. `nil` when not authenticated.
    var currentUser: User?

    /// Whether authentication is in progress (e.g. login network call running).
    var isAuthenticating: Bool = false

    /// A user-facing error message from the most recent auth attempt. `nil` when no error.
    var authError: String?

    /// The auth methods available on the active server, as detected during server setup.
    /// Used by `LoginView` to show only the relevant login tabs.
    var availableAuthMethods: [AuthMethod] = []

    // MARK: - Navigation Flags

    /// Whether the app should show the server-setup onboarding flow.
    /// Driven by whether `activeServer` is non-nil AND the user is authenticated.
    var showServerSetup: Bool {
        activeServer == nil
    }

    /// Whether the main tab interface should be visible.
    var showMainInterface: Bool {
        activeServer != nil && currentUser != nil
    }

    /// Whether the login screen should be presented (server selected but not yet authenticated).
    var showLogin: Bool {
        activeServer != nil && currentUser == nil && !isAuthenticating
    }

    // MARK: - Dependencies

    /// Reference to the shared server store, needed for TOFU cert persistence.
    private let serverStore: ServerStore

    // MARK: - Init

    init(serverStore: ServerStore) {
        self.serverStore = serverStore
    }

    // MARK: - Actions

    /// Sets a new active server and instantiates a matching `SeerrAPIClient`.
    ///
    /// Call this after the user picks or adds a server from the server list.
    /// - Parameters:
    ///   - server: The `ServerConfiguration` to make active.
    ///   - authMethods: The auth methods available on this server, from detection.
    ///     Defaults to `[.local]` when not provided (e.g. reconnecting a saved server).
    func selectServer(_ server: ServerConfiguration, authMethods: [AuthMethod] = [.local]) {
        activeServer = server
        currentUser = nil
        authError = nil
        availableAuthMethods = authMethods.isEmpty ? [.local] : authMethods
        apiClient = SeerrAPIClient(server: server, serverStore: serverStore)
        AppLogger.info("AppState: active server set to '\(server.displayName)' (\(server.baseURL))")
    }

    /// Stores the authenticated user and clears any auth error.
    ///
    /// - Parameter user: The `User` returned by `GET /auth/me`.
    func setAuthenticatedUser(_ user: User) {
        currentUser = user
        authError = nil
        isAuthenticating = false
        AppLogger.info("AppState: authenticated as user id=\(user.id)")
    }

    /// Clears authentication state, keeping the server selection intact.
    ///
    /// Triggers the login flow to be presented again.
    func signOut() {
        currentUser = nil
        authError = nil
        isAuthenticating = false
        AppLogger.info("AppState: signed out from '\(activeServer?.displayName ?? "unknown")'")
    }

    /// Removes both the active server and the authenticated user, returning the app
    /// to the server-setup onboarding flow.
    func disconnectFromServer() {
        activeServer = nil
        currentUser = nil
        apiClient = nil
        authError = nil
        availableAuthMethods = []
        isAuthenticating = false
        AppLogger.info("AppState: disconnected from server")
    }

    /// Records a user-facing auth error message.
    ///
    /// - Parameter message: Localised message to display.
    func setAuthError(_ message: String) {
        authError = message
        isAuthenticating = false
    }
}
