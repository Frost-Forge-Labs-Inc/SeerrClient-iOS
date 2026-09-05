import XCTest

final class AboutNavigationUITests: XCTestCase {
    private let timeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testProfileHasNoSupportSectionAndShowsJellyseerrAcknowledgement() throws {
        let app = launchApp()

        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: timeout))
        profileTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["profile.screen"].waitForExistence(timeout: timeout))

        // Scroll into the Acknowledgements section, which sits below where the removed Support Development section used to render.
        let jellyseerrAcknowledgement = scrollToElement(in: app, identifier: "about.ack.jellyseerr")
        XCTAssertTrue(jellyseerrAcknowledgement.waitForExistence(timeout: timeout))

        // Guideline 3.1.1 (rejection 2026-08-28): no support / funding / sponsorship
        // surface may exist anywhere in the Apple app.
        XCTAssertFalse(app.staticTexts["Support Development"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["Support Development"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["about.support.moreWaysToSupport"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["about.support.buyMeACoffee"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["about.support.kofi"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["about.support.githubSponsors"].exists)

        XCTAssertFalse(app.descendants(matching: .any)["about.funding.entry"].exists)
        XCTAssertFalse(app.navigationBars["Funding Strategy"].exists)
        XCTAssertFalse(app.staticTexts["Funding Strategy"].exists)
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SEERR_UI_TEST_SCENARIO"] = "about_navigation"
        app.launchEnvironment["SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"] = "1"
        app.launch()
        return app
    }

    @MainActor
    private func scrollToElement(
        in app: XCUIApplication,
        identifier: String,
        maxSwipes: Int = 6
    ) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        let scrollContainer = scrollContainer(in: app)

        for _ in 0..<maxSwipes where !element.exists || !element.isHittable {
            scrollContainer.swipeUp()
        }

        return element
    }

    @MainActor
    private func scrollContainer(in app: XCUIApplication) -> XCUIElement {
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            return collectionView
        }

        let table = app.tables.firstMatch
        if table.exists {
            return table
        }

        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            return scrollView
        }

        return app
    }
}
