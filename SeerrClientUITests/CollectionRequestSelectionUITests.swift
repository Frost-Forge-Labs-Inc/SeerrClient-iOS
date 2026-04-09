import XCTest

final class CollectionRequestSelectionUITests: XCTestCase {
    private let timeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSelectingSubsetRequestsChosenMovieAndUpdatesStatusInCollection() throws {
        let app = launchApp()

        let collectionScreen = app.scrollViews["collection.screen"]
        XCTAssertTrue(collectionScreen.waitForExistence(timeout: timeout))

        let firstRow = app.descendants(matching: .any)["collection.row.1001"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: timeout))

        let selectionButton = app.buttons["collection.select.1001"]
        XCTAssertTrue(selectionButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(selectionButton.isHittable)
        selectionButton.tap()

        let requestSelectedButton = app.buttons["collection.requestSelected"]
        XCTAssertTrue(requestSelectedButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(requestSelectedButton.isHittable)
        requestSelectedButton.tap()

        let submitButton = app.buttons["Submit Request"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(submitButton.isHittable)
        submitButton.tap()

        let pendingStatus = app.descendants(matching: .any)["collection.status.1001.pending"]
        XCTAssertTrue(pendingStatus.waitForExistence(timeout: timeout))

        let selectionSummary = app.staticTexts["collection.selectionSummary"]
        XCTAssertTrue(selectionSummary.waitForExistence(timeout: timeout))
        XCTAssertEqual(selectionSummary.label, "No movies selected")

        XCTAssertFalse(app.buttons["collection.select.1001"].exists)
        XCTAssertTrue(app.buttons["collection.select.1002"].exists)
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
