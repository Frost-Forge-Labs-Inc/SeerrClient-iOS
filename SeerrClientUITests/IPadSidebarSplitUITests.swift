// IPadSidebarSplitUITests.swift
// SeerrClientUITests
//
// UI tests for the iPad sidebar and split-view request detail presentation.

import UIKit
import XCTest

// MARK: - IPadSidebarSplitUITests

final class IPadSidebarSplitUITests: XCTestCase {
    private let timeout: TimeInterval = 5
    private let detailTimeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSidebarRendersAllTabs() throws {
        // Assumes full-screen iPad; Slide Over / compact-width multitasking reverts to a bottom tab bar and tabBars.count == 0 would not hold.
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("iPad only")
        }

        let app = launchApp()

        // Tab switching on iPad is proven by TabNavigationUITests; this test only asserts the sidebar renders all tabs.
        for tab in SeerrClientTab.allCases {
            let element = app.tabElement(tab)
            XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing \(tab.label) tab")
            XCTAssertTrue(element.isHittable, "\(tab.label) tab is not hittable")
        }

        XCTAssertEqual(app.tabBars.count, 0, "Expected .sidebarAdaptable (no bottom tab bar) at iPad regular width")
    }

    @MainActor
    func testSelectingRequestPopulatesDetailColumn() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("iPad only")
        }

        let app = launchApp()

        let placeholder = app.descendants(matching: .any)["requests.detail.placeholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: timeout))

        let requestCard = app.descendants(matching: .any)["requests.card.1001"]
        XCTAssertTrue(requestCard.waitForExistence(timeout: timeout))
        requestCard.tap()

        let detailContent = app.descendants(matching: .any)["requests.detail.content"]
        XCTAssertTrue(detailContent.waitForExistence(timeout: detailTimeout))
        XCTAssertFalse(placeholder.exists)
        XCTAssertTrue(detailContent.staticTexts["Request Filter Movie"].waitForExistence(timeout: detailTimeout))
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
