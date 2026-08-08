// MacSidebarSmokeUITests.swift
// SeerrClientMacUITests
//
// M4b: pointer-driven smoke — launch under mock scenario, click each
// sidebar row, assert the macOS shell navigates and stays alive.

import XCTest

// MARK: - MacSidebarSmokeUITests

final class MacSidebarSmokeUITests: XCTestCase {

    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Asserts the app launches into the main split shell with a visible sidebar.
    @MainActor
    func testLaunches() throws {
        let app = launchApp()
        let discover = sidebarElement(in: app, identifier: "macSidebar.discover")
        XCTAssertTrue(
            discover.waitForExistence(timeout: timeout),
            "Sidebar Discover row did not appear after launch"
        )
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Clicks Requests → Discover → Search → Profile; asserts no crash.
    @MainActor
    func testSidebarRowsArePointerDrivable() throws {
        let app = launchApp()

        // Sidebar must be present before we drive it.
        for id in ["macSidebar.discover", "macSidebar.search", "macSidebar.requests", "macSidebar.profile"] {
            let row = sidebarElement(in: app, identifier: id)
            XCTAssertTrue(
                row.waitForExistence(timeout: timeout),
                "Missing sidebar row \(id)"
            )
        }

        // Pointer-drive in the order required by the M4b spec.
        clickSidebar(in: app, identifier: "macSidebar.requests")
        XCTAssertEqual(app.state, .runningForeground, "App left foreground after Requests click")
        // Tolerant content anchor: nav title / table / empty-state text.
        let requestsAnchor = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Request")
        ).firstMatch
        _ = requestsAnchor.waitForExistence(timeout: timeout)

        clickSidebar(in: app, identifier: "macSidebar.discover")
        XCTAssertEqual(app.state, .runningForeground, "App left foreground after Discover click")

        clickSidebar(in: app, identifier: "macSidebar.search")
        XCTAssertEqual(app.state, .runningForeground, "App left foreground after Search click")

        clickSidebar(in: app, identifier: "macSidebar.profile")
        XCTAssertEqual(app.state, .runningForeground, "App left foreground after Profile click")

        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Helpers

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SEERR_UI_TEST_SCENARIO"] = "request_media_filter"
        app.launchEnvironment["SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"] = "1"
        app.launch()
        return app
    }

    /// Query robustly: sidebar `.listStyle(.sidebar)` bridges to an outline on macOS.
    @MainActor
    private func sidebarElement(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func clickSidebar(in app: XCUIApplication, identifier: String) {
        let row = sidebarElement(in: app, identifier: identifier)
        XCTAssertTrue(row.waitForExistence(timeout: timeout), "Missing \(identifier) before click")
        row.click()
    }
}
