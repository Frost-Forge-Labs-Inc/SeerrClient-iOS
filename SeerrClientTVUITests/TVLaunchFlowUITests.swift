// TVLaunchFlowUITests.swift
// SeerrClientTVUITests
//
// UI tests for pre-authentication tvOS launch chrome.
// Mirrors SeerrClientUITests/LaunchFlowUITests for both alternate-server→login
// and remembered-server restore paths.

import XCTest

// MARK: - TVLaunchFlowUITests

/// Verifies server selection, login, and remembered-session restore in the
/// deterministic `launch_flow_server_selection` scenario.
final class TVLaunchFlowUITests: XCTestCase {
    private let timeout: TimeInterval = 10
    /// Seeded default server with keychain credentials (see UITestAppBootstrapper).
    private let rememberedServerID = "11111111-1111-1111-1111-111111111111"
    private let alternateServerID = "22222222-2222-2222-2222-222222222222"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Alternate server has no saved sign-in → selecting it lands on login chrome.
    @MainActor
    func test_launchFlowRendersServerSetupAndLoginChrome() throws {
        let app = launchApp()
        let navigator = TVRemoteNavigator(app: app, timeout: timeout)
        let alternateServerIdentifier = "tvos.serversetup.select.\(alternateServerID.uppercased())"

        XCTAssertTrue(navigator.element("tvos.serversetup.screen").waitForExistence(timeout: timeout))
        XCTAssertTrue(navigator.element(alternateServerIdentifier).waitForExistence(timeout: timeout))

        navigator.focusElement(alternateServerIdentifier)
        navigator.pressSelect()

        XCTAssertTrue(navigator.element("tvos.login.screen").waitForExistence(timeout: timeout))
    }

    /// Cold launch always starts on the server list. Selecting the remembered
    /// default server (keychain session + /auth/me stub) should restore into the
    /// main tab chrome the same way iOS LaunchFlowUITests asserts.
    ///
    /// Asserts the actual tvOS product path: server list → select remembered
    /// server → silent restore via TVLoginView.restoreSessionIfPossible → main tabs.
    /// If that restore ever regresses, this test fails rather than being relaxed.
    @MainActor
    func test_rememberedServerRestoresIntoMainTabs() throws {
        let app = launchApp()
        let navigator = TVRemoteNavigator(app: app, timeout: timeout)
        let rememberedServerIdentifier = "tvos.serversetup.select.\(rememberedServerID.uppercased())"

        // Cold launch: always the server list (no auto-pick of the default).
        XCTAssertTrue(navigator.element("tvos.serversetup.screen").waitForExistence(timeout: timeout))
        XCTAssertTrue(navigator.element(rememberedServerIdentifier).waitForExistence(timeout: timeout))
        // On tvOS, tab.* identifiers do not attach to focusable tab-bar buttons;
        // assert the content-pane identifier instead (reliable in the UI tree).
        XCTAssertFalse(
            navigator.element("tvos.discover.screen").exists,
            "Main interface must not appear before a server is selected"
        )

        navigator.focusElement(rememberedServerIdentifier)
        navigator.pressSelect()

        // After select, TVLoginView probes keychain + GET /auth/me and, on success,
        // AppState.showMainInterface becomes true. Assert Discover content pane —
        // sufficient proof of silent restore (Profile pane only exists when selected).
        XCTAssertTrue(
            navigator.element("tvos.discover.screen").waitForExistence(timeout: timeout),
            "Selecting the remembered server should silently restore the session into the main interface (Discover screen). If this fails, tvOS is missing iOS's silent session-restore path — product gap, not a flaky test."
        )
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SEERR_UI_TEST_SCENARIO"] = "launch_flow_server_selection"
        app.launchEnvironment["SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"] = "1"
        app.launch()
        return app
    }
}
