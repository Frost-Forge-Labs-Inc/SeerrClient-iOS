// TVTabNavigationUITests.swift
// SeerrClientTVUITests
//
// UI tests for root tvOS tab navigation using the Siri Remote focus engine.

import XCTest

// MARK: - TVTabNavigationUITests

/// Verifies the authenticated tvOS tab bar can be traversed and activated with XCUIRemote.
final class TVTabNavigationUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_remoteNavigatesAcrossAuthenticatedTabs() throws {
        // `search` scenario bootstraps jellyseerr capabilities where
        // `supportsWatchlistRead == true`, so all 5 tabs (including Watchlist)
        // are present. Combined with TVRemoteNavigator's exists-before-hasFocus
        // guard, a future capability-gated omission of Watchlist stays safe.
        let app = launchApp(scenario: "search")
        let navigator = TVRemoteNavigator(app: app, timeout: timeout)

        for tab in TVTab.allCases {
            navigator.waitForTab(tab.identifier)
        }

        for tab in TVTab.allCases {
            navigator.focusTab(tab.identifier)
            navigator.pressSelect()
            XCTAssertTrue(
                navigator.element(tab.screenIdentifier).waitForExistence(timeout: timeout),
                "Missing screen after selecting \(tab.identifier)"
            )
        }
    }

    @MainActor
    private func launchApp(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SEERR_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"] = "1"
        app.launch()
        return app
    }
}
