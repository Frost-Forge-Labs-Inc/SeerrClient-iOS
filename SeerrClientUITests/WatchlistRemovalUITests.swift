import XCTest

final class WatchlistRemovalUITests: XCTestCase {
    private let timeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRemovingMovieFromWatchlistRemovesItAfterNavigatingBack() throws {
        let app = launchApp(scenario: "watchlist_removal")
        let watchlistScreen = app.scrollViews["watchlist.screen"]
        let movieCard = watchlistCard(tmdbId: 550, in: app)

        XCTAssertTrue(watchlistScreen.waitForExistence(timeout: timeout))
        XCTAssertTrue(movieCard.waitForExistence(timeout: timeout))

        movieCard.tap()

        let watchlistButton = app.buttons["movieDetail.watchlistButton"]
        XCTAssertTrue(watchlistButton.waitForExistence(timeout: timeout))
        XCTAssertEqual(watchlistButton.label, "Remove from Watchlist")
        watchlistButton.tap()
        XCTAssertEqual(watchlistButton.label, "Add to Watchlist")

        let backButton = app.navigationBars.buttons["Watchlist"]
        XCTAssertTrue(backButton.waitForExistence(timeout: timeout))
        backButton.tap()

        waitForDisappearance(of: movieCard)
        XCTAssertTrue(app.staticTexts["No Watchlist Items"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.descendants(matching: .any)["watchlist.empty-state"].waitForExistence(timeout: timeout))
    }

    @MainActor
    func testSegmentedControlFiltersMoviesAndTvShows() throws {
        let app = launchApp(scenario: "watchlist_media_filter")
        let segmentedControl = app.segmentedControls["watchlist.mediaSegment"]
        let moviesButton = segmentedControl.buttons["Movies"]
        let tvShowsButton = segmentedControl.buttons["TV Shows"]
        let movieCard = watchlistCard(tmdbId: 550, in: app)
        let tvCard = watchlistCard(tmdbId: 1399, in: app)

        XCTAssertTrue(segmentedControl.waitForExistence(timeout: timeout))
        XCTAssertTrue(moviesButton.exists)
        XCTAssertTrue(tvShowsButton.exists)
        XCTAssertTrue(movieCard.waitForExistence(timeout: timeout))
        XCTAssertFalse(tvCard.exists)

        tvShowsButton.tap()

        XCTAssertTrue(tvCard.waitForExistence(timeout: timeout))
        XCTAssertFalse(movieCard.exists)
    }

    @MainActor
    private func launchApp(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SEERR_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"] = "1"
        app.launch()
        return app
    }

    private func watchlistCard(tmdbId: Int, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["watchlist.card.\(tmdbId)"]
    }

    private func waitForDisappearance(
        of element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, file: file, line: line)
    }
}
