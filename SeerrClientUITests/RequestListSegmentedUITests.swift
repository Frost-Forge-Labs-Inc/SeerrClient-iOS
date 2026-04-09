import XCTest

final class RequestListSegmentedUITests: XCTestCase {
    private let timeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSegmentedControlFiltersMovieAndTvRequests() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SEERR_UI_TEST_SCENARIO"] = "request_media_filter"
        app.launchEnvironment["SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"] = "1"
        app.launch()

        let requestsTab = app.tabBars.buttons["Requests"]
        let requestsScreen = app.scrollViews["requests.screen"]
        let segmentedControl = app.segmentedControls["requests.mediaSegment"]
        let moviesButton = segmentedControl.buttons["Movies"]
        let tvShowsButton = segmentedControl.buttons["TV Shows"]
        let movieRequest = requestCard(id: 1001, in: app)
        let tvRequest = requestCard(id: 1002, in: app)

        XCTAssertTrue(requestsTab.waitForExistence(timeout: timeout))
        requestsTab.tap()
        XCTAssertTrue(requestsScreen.waitForExistence(timeout: timeout))
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: timeout))
        XCTAssertTrue(moviesButton.exists)
        XCTAssertTrue(tvShowsButton.exists)
        XCTAssertTrue(movieRequest.waitForExistence(timeout: timeout))
        XCTAssertFalse(tvRequest.exists)

        tvShowsButton.tap()

        XCTAssertTrue(tvRequest.waitForExistence(timeout: timeout))
        XCTAssertFalse(movieRequest.exists)
    }

    private func requestCard(id: Int, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["requests.card.\(id)"]
    }
}
