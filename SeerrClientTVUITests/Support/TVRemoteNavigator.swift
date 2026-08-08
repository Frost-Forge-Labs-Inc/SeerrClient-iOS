// TVRemoteNavigator.swift
// SeerrClientTVUITests
//
// XCUIRemote helpers for focus-driven tvOS UI tests.

import XCTest

// MARK: - TVRemoteNavigator

/// Small bounded focus navigator for Siri Remote-driven UI tests.
struct TVRemoteNavigator {
    let app: XCUIApplication
    let remote: XCUIRemote
    let timeout: TimeInterval

    init(app: XCUIApplication, remote: XCUIRemote = .shared, timeout: TimeInterval = 10) {
        self.app = app
        self.remote = remote
        self.timeout = timeout
    }

    @MainActor
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Resolves a root tab-bar item. Prefer `.button` so the query only matches
    /// the focusable tab control, never a content pane that might share an id.
    @MainActor
    func tabElement(_ identifier: String) -> XCUIElement {
        app.buttons[identifier].firstMatch
    }

    @MainActor
    func waitForElement(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing \(identifier)", file: file, line: line)
    }

    @MainActor
    func waitForTab(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = tabElement(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing tab \(identifier)", file: file, line: line)
    }

    @MainActor
    func focusTab(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        waitForTab(identifier, file: file, line: line)

        for _ in 0..<8 where focusedTabIdentifier == nil {
            remote.press(.up)
            waitBriefly()
        }

        if isFocused(tabElement(identifier)) { return }

        for _ in 0..<8 {
            remote.press(.right)
            waitBriefly()
            if isFocused(tabElement(identifier)) { return }
        }

        for _ in 0..<8 {
            remote.press(.left)
            waitBriefly()
            if isFocused(tabElement(identifier)) { return }
        }

        XCTFail("Could not focus \(identifier)", file: file, line: line)
    }

    @MainActor
    func focusElement(
        _ identifier: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        waitForElement(identifier, file: file, line: line)

        if isFocused(element(identifier)) { return }

        let scan: [XCUIRemote.Button] = [
            .down, .down, .down, .down, .down, .down,
            .right, .right, .right, .right,
            .left, .left, .left, .left,
            .up, .up, .up, .up,
            .right, .right, .down, .down
        ]

        for direction in scan {
            remote.press(direction)
            waitBriefly()
            if isFocused(element(identifier)) { return }
        }

        XCTFail("Could not focus \(identifier)", file: file, line: line)
    }

    @MainActor
    func pressSelect() {
        remote.press(.select)
        waitBriefly()
    }

    /// `hasFocus` raises if the element does not exist; guard with `.exists` first
    /// so capability-gated tabs (e.g. Watchlist) do not fail the query.
    @MainActor
    private func isFocused(_ element: XCUIElement) -> Bool {
        element.exists && element.hasFocus
    }

    @MainActor
    private var focusedTabIdentifier: String? {
        TVTab.allCases.map(\.identifier).first { isFocused(tabElement($0)) }
    }

    @MainActor
    private func waitBriefly() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
}

// MARK: - TVTab

enum TVTab: CaseIterable {
    case discover
    case search
    case requests
    case watchlist
    case profile

    var identifier: String {
        switch self {
        case .discover:
            "tab.discover"
        case .search:
            "tab.search"
        case .requests:
            "tab.requests"
        case .watchlist:
            "tab.watchlist"
        case .profile:
            "tab.profile"
        }
    }

    var screenIdentifier: String {
        switch self {
        case .discover:
            "tvos.discover.screen"
        case .search:
            "tvos.search.screen"
        case .requests:
            "tvos.requests.screen"
        case .watchlist:
            "tvos.watchlist.screen"
        case .profile:
            "tvos.profile.screen"
        }
    }
}
