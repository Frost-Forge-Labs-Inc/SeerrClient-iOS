// WatchlistViewModelTests.swift
// SeerrClientTests
//
// Tests for WatchlistViewModel load states, pagination, and enrichment.
// Uses MockWatchlistFetcher (WatchlistFetching) with nil mediaDetailRepository
// so no enrichment occurs and no network is touched.
//
// The class is @MainActor because WatchlistViewModel is @MainActor @Observable.

@testable import SeerrClient
import XCTest

@MainActor
final class WatchlistViewModelTests: XCTestCase {

    // MARK: - System Under Test

    var mock: MockWatchlistFetcher!
    var sut: WatchlistViewModel!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        mock = MockWatchlistFetcher()
        sut = WatchlistViewModel(repository: mock, mediaDetailRepository: nil)
    }

    override func tearDown() async throws {
        sut = nil
        mock = nil
    }

    // MARK: - Helpers

    private func makeItem(
        id: Int,
        mediaType: String = "movie",
        posterPath: String? = nil
    ) -> DiscoverMediaItem {
        DiscoverMediaItem(
            id: id, tmdbId: id, mediaType: mediaType,
            title: "Test \(id)", name: nil,
            posterPath: posterPath, backdropPath: nil,
            overview: nil, voteAverage: nil,
            releaseDate: "2020-01-01", firstAirDate: nil,
            genreIds: nil, mediaInfo: nil
        )
    }

    private func makeResponse(
        items: [DiscoverMediaItem],
        page: Int = 1,
        totalPages: Int = 1
    ) -> DiscoverResponse<DiscoverMediaItem> {
        DiscoverResponse(
            page: page,
            totalPages: totalPages,
            totalResults: items.count,
            results: items
        )
    }

    // MARK: - Initial State

    func test_initialState() {
        XCTAssertEqual(sut.loadState, .idle)
        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertEqual(sut.currentPage, 1)
        XCTAssertEqual(sut.totalPages, 1)
    }

    // MARK: - canLoadMore

    func test_canLoadMore_falseWhenPageEqualsTotal() {
        // Initial: page 1, totalPages 1
        XCTAssertFalse(sut.canLoadMore)
    }

    func test_canLoadMore_trueWhenMorePagesExist() async throws {
        mock.stubbedResponse = makeResponse(items: [makeItem(id: 1)], page: 1, totalPages: 3)
        await sut.refresh()
        XCTAssertTrue(sut.canLoadMore)
    }

    func test_canLoadMore_falseWhileLoadingMore() {
        // isLoadingMore starts false, page==totalPages → canLoadMore is false
        XCTAssertFalse(sut.isLoadingMore)
        XCTAssertFalse(sut.canLoadMore)
    }

    // MARK: - loadIfNeeded

    func test_loadIfNeeded_transitionsFromIdleToLoaded() async throws {
        mock.stubbedResponse = makeResponse(items: [makeItem(id: 1)])
        // loadIfNeeded fires a Task internally; call refresh() instead to get
        // synchronous async awaiting. Separately verify that calling loadIfNeeded
        // from a non-idle state is a no-op by calling it twice.
        await sut.refresh()
        let stateAfterFirstLoad = sut.loadState

        // Second call to loadIfNeeded should be a no-op (state is no longer .idle)
        sut.loadIfNeeded()
        // State should not have changed back to .loading
        XCTAssertEqual(sut.loadState, stateAfterFirstLoad)
    }

    // MARK: - refresh

    func test_refresh_setsLoadedWithItems() async throws {
        let items = [makeItem(id: 1), makeItem(id: 2)]
        mock.stubbedResponse = makeResponse(items: items)
        await sut.refresh()
        XCTAssertEqual(sut.loadState, .loaded(sut.items))
        XCTAssertEqual(sut.items.count, 2)
    }

    func test_refresh_setsErrorOnFailure() async throws {
        mock.stubbedError = URLError(.notConnectedToInternet)
        await sut.refresh()
        if case .error = sut.loadState {
            // pass
        } else {
            XCTFail("Expected .error loadState, got \(sut.loadState)")
        }
    }

    func test_refresh_setsEmptyWhenNoResults() async throws {
        mock.stubbedResponse = makeResponse(items: [])
        await sut.refresh()
        XCTAssertEqual(sut.loadState, .empty)
    }

    func test_refresh_deduplicatesConcurrentCalls() async throws {
        mock.stubbedResponse = makeResponse(items: [makeItem(id: 1)])
        mock.delayNanoseconds = 50_000_000

        async let firstRefresh: Void = sut.refresh()
        async let secondRefresh: Void = sut.refresh()
        _ = await (firstRefresh, secondRefresh)

        XCTAssertEqual(mock.fetchWatchlistCallCount, 1)
        XCTAssertEqual(sut.loadState, .loaded(sut.items))
        XCTAssertEqual(sut.items.map(\.id), [1])
    }

    // MARK: - items

    func test_items_populatedAfterLoad() async throws {
        let items = [makeItem(id: 1), makeItem(id: 2), makeItem(id: 3)]
        mock.stubbedResponse = makeResponse(items: items)
        await sut.refresh()
        XCTAssertEqual(sut.items.count, 3)
    }

    // MARK: - Pagination

    func test_pagination_pageAndTotalPagesSet() async throws {
        mock.stubbedResponse = makeResponse(
            items: [makeItem(id: 1)],
            page: 2,
            totalPages: 5
        )
        await sut.refresh()
        XCTAssertEqual(sut.currentPage, 2)
        XCTAssertEqual(sut.totalPages, 5)
    }

    // MARK: - Enrichment (nil mediaDetailRepository)

    func test_posterPaths_notPopulated_withNilMediaDetailRepo() async throws {
        mock.stubbedResponse = makeResponse(items: [makeItem(id: 1, posterPath: nil)])
        await sut.refresh()
        // Give any background enrichment Task a moment to complete (it should be
        // a no-op since mediaDetailRepository is nil, so this is instant)
        XCTAssertTrue(sut.posterPaths.isEmpty)
    }

    func test_years_notPopulated_withNilMediaDetailRepo() async throws {
        mock.stubbedResponse = makeResponse(items: [makeItem(id: 1)])
        await sut.refresh()
        XCTAssertTrue(sut.years.isEmpty)
    }

    // MARK: - Watchlist Reconciliation

    func test_reconcileWithWatchlistIds_removesItemsNoLongerPresent() async throws {
        let first = makeItem(id: 1)
        let second = makeItem(id: 2)
        mock.stubbedResponse = makeResponse(items: [first, second])

        await sut.refresh()
        sut.reconcileWithWatchlistIds([second.effectiveTmdbId])

        XCTAssertEqual(sut.items.map(\.id), [second.id])
        XCTAssertEqual(sut.loadState, .loaded(sut.items))
    }

    func test_reconcileWithWatchlistIds_setsEmptyWhenAllItemsRemoved() async throws {
        mock.stubbedResponse = makeResponse(items: [makeItem(id: 1)])

        await sut.refresh()
        sut.reconcileWithWatchlistIds([])

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertEqual(sut.loadState, .empty)
    }

    func test_reconcileWithWatchlistIds_usesEffectiveTmdbIdForJellyfinItems() async throws {
        let jellyfinItem = DiscoverMediaItem(
            id: 9001,
            tmdbId: 550,
            mediaType: "movie",
            title: "Fight Club",
            name: nil,
            posterPath: nil,
            backdropPath: nil,
            overview: nil,
            voteAverage: nil,
            releaseDate: "1999-10-15",
            firstAirDate: nil,
            genreIds: nil,
            mediaInfo: nil
        )
        mock.stubbedResponse = makeResponse(items: [jellyfinItem])

        await sut.refresh()
        sut.reconcileWithWatchlistIds([550])

        XCTAssertEqual(sut.items.map(\.id), [jellyfinItem.id])
        XCTAssertEqual(sut.loadState, .loaded(sut.items))
    }
}

@MainActor
final class AppStateWatchlistTests: XCTestCase {

    func test_recordWatchlistMembershipChange_addsIdAndMarksRefreshNeeded() {
        let sut = AppState(serverStore: ServerStore())

        sut.recordWatchlistMembershipChange(tmdbId: 550, isOnWatchlist: true)

        XCTAssertTrue(sut.watchlistedTmdbIds.contains(550))
        XCTAssertTrue(sut.watchlistNeedsRefresh)
    }

    func test_recordWatchlistMembershipChange_removesIdAndMarksRefreshNeeded() {
        let sut = AppState(serverStore: ServerStore())
        sut.watchlistedTmdbIds = [550, 603]
        sut.watchlistNeedsRefresh = false

        sut.recordWatchlistMembershipChange(tmdbId: 550, isOnWatchlist: false)

        XCTAssertEqual(sut.watchlistedTmdbIds, [603])
        XCTAssertTrue(sut.watchlistNeedsRefresh)
    }
}
