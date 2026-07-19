// TabNavigator.swift
// SeerrClientUITests
//
// Container-agnostic helpers for finding root tabs in UI tests.

import XCTest

// MARK: - SeerrClientTab

/// Primary tabs shown by the root `TabView`.
enum SeerrClientTab: CaseIterable {
    case discover
    case search
    case requests
    case watchlist
    case profile

    var label: String {
        switch self {
        case .discover:
            "Discover"
        case .search:
            "Search"
        case .requests:
            "Requests"
        case .watchlist:
            "Watchlist"
        case .profile:
            "Profile"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .discover:
            "tab.discover"
        case .search:
            "tab.search"
        case .requests:
            "tab.requests"
        case .watchlist:
            "tab.watchlist"
        case .profile:
            "tab.profile"
        }
    }
}

// MARK: - XCUIApplication+TabNavigator

extension XCUIApplication {

    /// Resolves a root tab as a label-keyed button in either root presentation.
    ///
    /// SwiftUI exposes the root tabs as buttons keyed by their visible label in
    /// both the iPhone bottom tab bar and the iPad `.sidebarAdaptable` top
    /// button bar. The regular-width iPad hierarchy has no `tabBars` container
    /// and renders each tab as nested duplicate buttons with the same label, so
    /// `.firstMatch` intentionally disambiguates those duplicates. The polling
    /// loop re-evaluates the queries until timeout because a one-shot snapshot
    /// can bind to a query that never becomes true in the iPad presentation.
    @MainActor
    func tabElement(_ tab: SeerrClientTab, timeout: TimeInterval = 5) -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if tabBars.buttons[tab.label].firstMatch.exists { return tabBars.buttons[tab.label].firstMatch }
            if buttons[tab.label].firstMatch.exists { return buttons[tab.label].firstMatch }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return buttons[tab.label].firstMatch
    }
}
