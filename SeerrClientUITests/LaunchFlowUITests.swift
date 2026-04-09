import XCTest

final class LaunchFlowUITests: XCTestCase {
    private let timeout: TimeInterval = 10
    private let rememberedServerID = "11111111-1111-1111-1111-111111111111"
    private let alternateServerID = "22222222-2222-2222-2222-222222222222"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testColdLaunchAlwaysStartsOnServerListAndRememberedServerRestoresIntoTabs() throws {
        let app = launchApp()

        let serverList = app.descendants(matching: .any)["serverList.screen"]
        let rememberedServer = serverButton(in: app, id: rememberedServerID)

        XCTAssertTrue(serverList.waitForExistence(timeout: timeout))
        XCTAssertTrue(rememberedServer.waitForExistence(timeout: timeout))
        XCTAssertFalse(app.tabBars.firstMatch.exists)

        rememberedServer.tap()

        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
    }

    @MainActor
    func testSelectingServerWithoutRememberedAuthShowsLoginScreen() throws {
        let app = launchApp()
        let alternateServer = serverButton(in: app, id: alternateServerID)

        XCTAssertTrue(alternateServer.waitForExistence(timeout: timeout))
        alternateServer.tap()

        XCTAssertTrue(app.scrollViews["login.screen"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["Back to Servers"].exists)
    }

    @MainActor
    func testSwitchServerButtonReturnsToServerListAndForgetSignInKeepsSameServerOnLogin() throws {
        let app = launchApp()
        let rememberedServer = serverButton(in: app, id: rememberedServerID)

        XCTAssertTrue(rememberedServer.waitForExistence(timeout: timeout))
        rememberedServer.tap()
        XCTAssertTrue(app.tabBars.buttons["Profile"].waitForExistence(timeout: timeout))

        app.tabBars.buttons["Profile"].tap()

        let switchButton = app.descendants(matching: .any)["profile.switchServer"]
        XCTAssertTrue(switchButton.waitForExistence(timeout: timeout))
        switchButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["serverList.screen"].waitForExistence(timeout: timeout))

        let rememberedServerAfterReturn = serverButton(in: app, id: rememberedServerID)
        rememberedServerAfterReturn.swipeLeft()

        let forgetButton = app.buttons["Forget Sign-In"]
        XCTAssertTrue(forgetButton.waitForExistence(timeout: timeout))
        forgetButton.tap()

        let refreshedRememberedServer = serverButton(in: app, id: rememberedServerID)
        XCTAssertTrue(refreshedRememberedServer.waitForExistence(timeout: timeout))
        refreshedRememberedServer.tap()

        let backToServersButton = app.buttons["Back to Servers"]
        if !backToServersButton.waitForExistence(timeout: 2) {
            refreshedRememberedServer.tap()
        }

        XCTAssertTrue(backToServersButton.waitForExistence(timeout: timeout))
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SEERR_UI_TEST_SCENARIO"] = "launch_flow_server_selection"
        app.launchEnvironment["SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"] = "1"
        app.launch()
        return app
    }

    private func serverButton(in app: XCUIApplication, id: String) -> XCUIElement {
        app.buttons["serverList.select.\(id)"]
    }
}
