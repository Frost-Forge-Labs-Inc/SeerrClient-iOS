import XCTest

final class CollectionRequestSelectionUITests: XCTestCase {
    private let timeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// One-tap Request Selected on a multi-movie selection marks every chosen
    /// movie Pending without presenting a per-movie CreateRequest sheet.
    @MainActor
    func testSelectingMultipleMoviesRequestsAllChosenInOneTap() throws {
        let app = launchApp()

        let collectionScreen = app.scrollViews["collection.screen"]
        XCTAssertTrue(collectionScreen.waitForExistence(timeout: timeout))

        let firstRow = app.descendants(matching: .any)["collection.row.1001"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: timeout))
        let secondRow = app.descendants(matching: .any)["collection.row.1002"]
        XCTAssertTrue(secondRow.waitForExistence(timeout: timeout))

        let selectFirst = app.buttons["collection.select.1001"]
        XCTAssertTrue(selectFirst.waitForExistence(timeout: timeout))
        XCTAssertTrue(selectFirst.isHittable)
        selectFirst.tap()

        let selectSecond = app.buttons["collection.select.1002"]
        XCTAssertTrue(selectSecond.waitForExistence(timeout: timeout))
        XCTAssertTrue(selectSecond.isHittable)
        selectSecond.tap()

        let requestSelectedButton = app.buttons["collection.requestSelected"]
        XCTAssertTrue(requestSelectedButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(requestSelectedButton.isHittable)
        requestSelectedButton.tap()

        // Batch path: no per-movie Submit Request sheet.
        XCTAssertFalse(app.buttons["Submit Request"].waitForExistence(timeout: 1))

        let pendingFirst = app.descendants(matching: .any)["collection.status.1001.pending"]
        XCTAssertTrue(pendingFirst.waitForExistence(timeout: timeout))
        let pendingSecond = app.descendants(matching: .any)["collection.status.1002.pending"]
        XCTAssertTrue(pendingSecond.waitForExistence(timeout: timeout))

        // Both requestable movies are now pending; selection chips are gone.
        XCTAssertFalse(app.buttons["collection.select.1001"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["collection.select.1002"].exists)
        // Movies 1003/1004 were already pending/available and never had select controls.
        XCTAssertFalse(app.buttons["collection.requestSelected"].exists)
        XCTAssertFalse(app.buttons["collection.requestAll"].exists)
    }

    /// Request All requests every requestable movie in one tap.
    @MainActor
    func testRequestAllMarksMultipleMoviesPendingInOneTap() throws {
        let app = launchApp()

        let collectionScreen = app.scrollViews["collection.screen"]
        XCTAssertTrue(collectionScreen.waitForExistence(timeout: timeout))

        XCTAssertTrue(app.descendants(matching: .any)["collection.row.1001"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.descendants(matching: .any)["collection.row.1002"].waitForExistence(timeout: timeout))

        let requestAllButton = app.buttons["collection.requestAll"]
        XCTAssertTrue(requestAllButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(requestAllButton.isHittable)
        requestAllButton.tap()

        XCTAssertFalse(app.buttons["Submit Request"].waitForExistence(timeout: 1))

        let pendingFirst = app.descendants(matching: .any)["collection.status.1001.pending"]
        XCTAssertTrue(pendingFirst.waitForExistence(timeout: timeout))
        let pendingSecond = app.descendants(matching: .any)["collection.status.1002.pending"]
        XCTAssertTrue(pendingSecond.waitForExistence(timeout: timeout))

        XCTAssertFalse(app.buttons["collection.select.1001"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["collection.select.1002"].exists)
        XCTAssertFalse(app.buttons["collection.requestAll"].exists)
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SEERR_UI_TEST_SCENARIO"] = "collection_request_selection"
        app.launchEnvironment["SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"] = "1"
        app.launch()
        return app
    }
}
