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

    /// Cached runtime compatibility snapshot for the active server.
    ///
    /// This becomes the single source of truth for login gating and
    /// backend-specific UI enable/disable decisions at runtime.
    var activeServerCapabilities: ServerCapabilities?

    /// The auth methods available on the active server.
    var availableAuthMethods: [AuthMethod] {
        activeServerCapabilities?.availableAuthMethods
            ?? activeServer?.resolvedAuthMethods
            ?? [.local]
    }

    // MARK: - Watchlist Cache

    /// In-memory set of TMDB IDs currently on the user's watchlist.
    ///
    /// Populated after authentication completes; updated optimistically whenever
    /// `MovieDetailViewModel` or `TvShowDetailViewModel` successfully toggles
    /// watchlist membership. Detail views seed their `isOnWatchlist` flag from
    /// this cache so the bookmark icon is correct immediately on open, without
    /// requiring a separate network call.
    var watchlistedTmdbIds: Set<Int> = []

    /// Set after a local watchlist toggle succeeds so the Watchlist tab knows it
    /// should perform a targeted re-sync the next time it becomes visible.
    var watchlistNeedsRefresh: Bool = false

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
    ///   - capabilities: Optional detected capabilities. If omitted, a
    ///     best-effort snapshot is resolved from the saved server entry.
    func selectServer(_ server: ServerConfiguration, capabilities: ServerCapabilities? = nil) {
        let resolvedCapabilities = capabilities ?? server.resolvedCapabilities

        var selectedServer = server
        if selectedServer.capabilities != resolvedCapabilities
            || selectedServer.availableAuthMethods != resolvedCapabilities.availableAuthMethods {
            selectedServer.capabilities = resolvedCapabilities
            selectedServer.availableAuthMethods = resolvedCapabilities.availableAuthMethods
            if serverStore.servers.contains(where: { $0.id == selectedServer.id }) {
                serverStore.update(selectedServer)
            }
        }

        activeServer = selectedServer
        activeServerCapabilities = resolvedCapabilities
        currentUser = nil
        authError = nil
        watchlistedTmdbIds = []
        watchlistNeedsRefresh = false
        apiClient = SeerrAPIClient(server: selectedServer, serverStore: serverStore)
        AppLogger.info(
            "AppState: active server set to '\(selectedServer.displayName)' (\(selectedServer.baseURL))"
        )
    }

    /// Stores the authenticated user and clears any auth error.
    ///
    /// Immediately kicks off a background task to populate `watchlistedTmdbIds`
    /// using the active API client's watchlist endpoint, so detail screens that
    /// open shortly after login see the correct bookmark state.
    ///
    /// - Parameter user: The `User` returned by `GET /auth/me`.
    func setAuthenticatedUser(_ user: User) {
        currentUser = user
        authError = nil
        isAuthenticating = false
        AppLogger.info("AppState: authenticated as user id=\(user.id)")
        Task { await loadWatchlistCache() }
    }

    /// Fetches all pages of the user's watchlist and stores the TMDB IDs in
    /// `watchlistedTmdbIds`. Called automatically after authentication; safe to
    /// call again to force a refresh (e.g. after returning to the Watchlist tab).
    ///
    /// Failures are non-fatal: the cache simply stays empty and the bookmark icon
    /// starts as unfilled until the user explicitly toggles it.
    func loadWatchlistCache() async {
        guard activeServerCapabilities?.supportsWatchlistRead ?? false else {
            watchlistedTmdbIds = []
            watchlistNeedsRefresh = false
            AppLogger.info("AppState: skipping watchlist cache — backend does not expose watchlist read")
            return
        }
        guard let client = apiClient else { return }
        let repo = DiscoverRepository(apiClient: client)
        do {
            let ids = try await repo.fetchAllWatchlistTmdbIds()
            watchlistedTmdbIds = ids
            watchlistNeedsRefresh = false
            AppLogger.info("AppState: watchlist cache loaded — \(ids.count) item(s)")
        } catch {
            AppLogger.warning("AppState: failed to load watchlist cache — \(error)")
        }
    }

    /// Records a successful watchlist mutation from a detail screen.
    ///
    /// This keeps the bookmark cache accurate immediately and signals the
    /// Watchlist tab to reconcile/refresh its paginated content.
    func recordWatchlistMembershipChange(tmdbId: Int, isOnWatchlist: Bool) {
        if isOnWatchlist {
            watchlistedTmdbIds.insert(tmdbId)
        } else {
            watchlistedTmdbIds.remove(tmdbId)
        }
        watchlistNeedsRefresh = true
    }

    /// Clears authentication state, keeping the server selection intact.
    ///
    /// Triggers the login flow to be presented again.
    func signOut() {
        currentUser = nil
        authError = nil
        isAuthenticating = false
        watchlistedTmdbIds = []
        watchlistNeedsRefresh = false
        AppLogger.info("AppState: signed out from '\(activeServer?.displayName ?? "unknown")'")
    }

    /// Removes both the active server and the authenticated user, returning the app
    /// to the server-setup onboarding flow.
    func disconnectFromServer() {
        activeServer = nil
        activeServerCapabilities = nil
        currentUser = nil
        apiClient = nil
        authError = nil
        isAuthenticating = false
        watchlistedTmdbIds = []
        watchlistNeedsRefresh = false
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
