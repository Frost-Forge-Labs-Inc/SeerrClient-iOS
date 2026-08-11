// TVRequestsFlowUITests.swift
// SeerrClientTVUITests
//
// UI tests for tvOS request list and detail navigation.

import XCTest

// MARK: - TVRequestsFlowUITests

/// Verifies seeded request rows can be opened with XCUIRemote from the Requests tab.
final class TVRequestsFlowUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_remoteOpensSeededRequestDetail() throws {
        let app = launchApp(scenario: "request_media_filter")
        let navigator = TVRemoteNavigator(app: app, timeout: timeout)
        let requestCardIdentifier = "tvos.requests.card.1001"

        XCTAssertTrue(navigator.element("tvos.requests.screen").waitForExistence(timeout: timeout))
        XCTAssertTrue(navigator.element(requestCardIdentifier).waitForExistence(timeout: timeout))

        navigator.focusElement(requestCardIdentifier)
        navigator.pressSelect()

        XCTAssertTrue(navigator.element("tvos.request.detail.content").waitForExistence(timeout: timeout))
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
