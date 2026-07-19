@testable import SeerrClient
import XCTest

/// Exhaustively covers the tab-reset decision matrix for watchlist capability changes.
final class TabSelectionPolicyTests: XCTestCase {

    func test_watchlistSelectedAndCapabilityFalseResetsToDefaultSessionTab() {
        XCTAssertEqual(
            TabSelectionPolicy.resolvedTab(
                current: .watchlist,
                supportsWatchlistRead: false,
                defaultSessionTab: .discover
            ),
            .discover
        )
    }

    func test_watchlistSelectedAndCapabilityNilResetsToDefaultSessionTab() {
        XCTAssertEqual(
            TabSelectionPolicy.resolvedTab(
                current: .watchlist,
                supportsWatchlistRead: nil,
                defaultSessionTab: .discover
            ),
            .discover
        )
    }

    func test_watchlistSelectedAndCapabilityTruePreservesWatchlist() {
        XCTAssertEqual(
            TabSelectionPolicy.resolvedTab(
                current: .watchlist,
                supportsWatchlistRead: true,
                defaultSessionTab: .discover
            ),
            .watchlist
        )
    }

    func test_searchSelectedAndCapabilityFalsePreservesSearch() {
        XCTAssertEqual(
            TabSelectionPolicy.resolvedTab(
                current: .search,
                supportsWatchlistRead: false,
                defaultSessionTab: .discover
            ),
            .search
        )
    }

    func test_searchSelectedAndCapabilityNilPreservesSearch() {
        XCTAssertEqual(
            TabSelectionPolicy.resolvedTab(
                current: .search,
                supportsWatchlistRead: nil,
                defaultSessionTab: .discover
            ),
            .search
        )
    }

    func test_searchSelectedAndCapabilityTruePreservesSearch() {
        XCTAssertEqual(
            TabSelectionPolicy.resolvedTab(
                current: .search,
                supportsWatchlistRead: true,
                defaultSessionTab: .discover
            ),
            .search
        )
    }

    func test_capabilityRegainedWhileProfileSelectedDoesNotForceNavigate() {
        XCTAssertEqual(
            TabSelectionPolicy.resolvedTab(
                current: .profile,
                supportsWatchlistRead: true,
                defaultSessionTab: .discover
            ),
            .profile
        )
    }

    func test_defaultSessionTabIsHonoredWhenWatchlistMustBeVacated() {
        XCTAssertEqual(
            TabSelectionPolicy.resolvedTab(
                current: .watchlist,
                supportsWatchlistRead: false,
                defaultSessionTab: .requests
            ),
            .requests
        )
    }

    /// Locks in the trusted-caller contract boundary: `resolvedTab` does not
    /// validate `defaultSessionTab`, so if a caller ever passes `.watchlist`
    /// as the default while the Watchlist tab must be vacated, the function
    /// returns `.watchlist` verbatim. This documents the assumption so a future
    /// caller change (e.g. persisting a "last active tab" as the default) that
    /// reintroduces the orphaned-tab bug is caught here rather than in production.
    func test_defaultSessionTabWatchlistIsReturnedVerbatim_callerContractBoundary() {
        XCTAssertEqual(
            TabSelectionPolicy.resolvedTab(
                current: .watchlist,
                supportsWatchlistRead: false,
                defaultSessionTab: .watchlist
            ),
            .watchlist
        )
    }
}
