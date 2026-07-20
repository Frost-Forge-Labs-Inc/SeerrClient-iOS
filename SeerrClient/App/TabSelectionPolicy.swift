// TabSelectionPolicy.swift
// SeerrClient
//
// Pure tab-selection policy logic extracted from ContentView so it can be
// unit-tested in isolation.

import Foundation

// MARK: - TabSelectionPolicy

enum TabSelectionPolicy {

    /// Resolves the tab that should be selected after a change in the active
    /// server's watchlist-read capability.
    ///
    /// The Watchlist tab is only rendered when the backend reports
    /// `supportsWatchlistRead == true`. If that capability is lost at runtime
    /// (re-detected as `false`, or the capability snapshot becomes `nil` on a
    /// disconnect) while the Watchlist tab is currently selected, the selection
    /// must move off the now-unrendered tab so the sidebar/tab selection is not
    /// orphaned. In every other situation the current selection is preserved.
    ///
    /// This is a one-way guard: it ONLY ever redirects AWAY from `.watchlist`
    /// when the capability is unavailable. It never force-navigates the user
    /// onto any tab when the capability is regained or when a non-Watchlist tab
    /// is already selected.
    ///
    /// - Example:
    ///   ```swift
    ///   // Watchlist selected, capability lost -> reset to default
    ///   TabSelectionPolicy.resolvedTab(current: .watchlist, supportsWatchlistRead: nil, defaultSessionTab: .discover) // .discover
    ///   // Some other tab selected, capability lost -> unchanged
    ///   TabSelectionPolicy.resolvedTab(current: .search, supportsWatchlistRead: false, defaultSessionTab: .discover) // .search
    ///   ```
    ///
    /// - Parameters:
    ///   - current: The currently selected tab.
    ///   - supportsWatchlistRead: The active server's watchlist-read capability
    ///     (`nil` when no capability snapshot is available).
    ///   - defaultSessionTab: The tab to fall back to when the Watchlist tab must
    ///     be vacated. The caller is trusted to pass a tab that is always
    ///     rendered; passing `.watchlist` here would defeat the guard (the
    ///     function returns it verbatim), so callers must never do so.
    /// - Returns: The tab that should be selected. Equal to `current` when no
    ///   change is required.
    static func resolvedTab(current: AppTab, supportsWatchlistRead: Bool?, defaultSessionTab: AppTab) -> AppTab {
        guard current == .watchlist, supportsWatchlistRead != true else {
            return current
        }
        return defaultSessionTab
    }
}
