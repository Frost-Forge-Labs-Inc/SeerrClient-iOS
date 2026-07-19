// TabNavigationUITests.swift
// SeerrClientUITests
//
// UI tests for root tab navigation across compact and regular presentations.

import XCTest

// MARK: - TabNavigationUITests

final class TabNavigationUITests: XCTestCase {
    private let timeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAllTabsResolveAndNavigateAcrossContainers() throws {
        let app = launchApp()

        for tab in SeerrClientTab.allCases {
            let element = app.tabElement(tab)
            XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing \(tab.label) tab")
            XCTAssertTrue(element.isHittable, "\(tab.label) tab is not hittable")
            element.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)[tab.accessibilityIdentifier].waitForExistence(timeout: timeout),
                "Missing selected content pane for \(tab.label) tab"
            )

            if tab == .requests {
                XCTAssertTrue(app.scrollViews["requests.screen"].waitForExistence(timeout: timeout))
            } else if tab == .profile {
                XCTAssertTrue(app.descendants(matching: .any)["profile.screen"].waitForExistence(timeout: timeout))
            }
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SEERR_UI_TEST_SCENARIO"] = "request_media_filter"
        app.launchEnvironment["SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"] = "1"
        app.launch()
        return app
    }
}
