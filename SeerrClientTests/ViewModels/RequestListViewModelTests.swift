// RequestListViewModelTests.swift
// SeerrClientTests
//
// Tests for Requests-tab media segmentation, filtered pagination, and loading.

@testable import SeerrClient
import XCTest

@MainActor
final class RequestListViewModelTests: XCTestCase {

    var mock: MockRequestListFetcher!
    var sut: RequestListViewModel!

    override func setUp() async throws {
        mock = MockRequestListFetcher()
        sut = RequestListViewModel(
            repository: mock,
            mediaDetailRepository: nil,
            userPermissions: 2
        )
    }

    override func tearDown() async throws {
        sut = nil
        mock = nil
    }

    private func makeRequest(
        id: Int,
        tmdbId: Int,
        tvdbId: Int? = nil,
        status: Int = 1,
        requestSeasons: [SeasonRequest]? = nil,
        mediaSeasons: [MediaInfoSeason]? = nil
    ) -> MediaRequest {
        MediaRequest(
            id: id,
            status: status,
            media: MediaInfo(
                id: id,
                tmdbId: tmdbId,
                tvdbId: tvdbId,
                status: status,
                seasons: mediaSeasons,
                requests: nil,
                createdAt: nil,
                updatedAt: nil,
                watchlisted: nil
            ),
            createdAt: "2026-04-09T00:00:00.000Z",
            updatedAt: nil,
            requestedBy: nil,
            modifiedBy: nil,
            is4k: nil,
            serverId: nil,
            profileId: nil,
            rootFolder: nil,
            seasons: requestSeasons
        )
    }

    private func makeResponse(
        requests: [MediaRequest],
        page: Int,
        pages: Int
    ) -> PaginatedResponse<MediaRequest> {
        PaginatedResponse(
            pageInfo: PageInfo(page: page, pages: pages, results: requests.count),
            results: requests
        )
    }

    func test_visibleRequests_defaultToMovies() async {
        mock.stubbedResponse = makeResponse(
            requests: [
                makeRequest(id: 1, tmdbId: 550),
                makeRequest(id: 2, tmdbId: 1399, tvdbId: 121361)
            ],
            page: 1,
            pages: 1
        )

        await sut.refresh()

        XCTAssertEqual(sut.selectedMediaSegment, .movies)
        XCTAssertEqual(sut.visibleRequests.map(\.id), [1])
    }

    func test_selectMediaSegment_updatesVisibleRequestsToTvShows() async {
        mock.stubbedResponse = makeResponse(
            requests: [
                makeRequest(id: 1, tmdbId: 550),
                makeRequest(
                    id: 2,
                    tmdbId: 1399,
                    requestSeasons: [SeasonRequest(id: 1, seasonNumber: 1, status: 1)]
                ),
                makeRequest(id: 3, tmdbId: 1402, tvdbId: 81189)
            ],
            page: 1,
            pages: 1
        )

        await sut.refresh()
        sut.selectMediaSegment(.tvShows)
        await waitUntil {
            self.sut.selectedMediaSegment == .tvShows && self.sut.visibleRequests.map(\.id) == [2, 3]
        }

        XCTAssertEqual(sut.visibleRequests.map(\.id), [2, 3])
    }

    func test_onRequestAppear_usesVisibleRequestsForPaginationThreshold() async {
        mock.stubbedResponsesByKey = [
            "all:0:20": makeResponse(
                requests: [
                    makeRequest(id: 1, tmdbId: 550),
                    makeRequest(id: 2, tmdbId: 551),
                    makeRequest(id: 3, tmdbId: 1399, tvdbId: 121361),
                    makeRequest(id: 4, tmdbId: 1402, tvdbId: 81189),
                    makeRequest(id: 5, tmdbId: 1403, tvdbId: 295640),
                    makeRequest(id: 6, tmdbId: 1404, tvdbId: 71663)
                ],
                page: 1,
                pages: 2
            ),
            "all:6:20": makeResponse(
                requests: [makeRequest(id: 7, tmdbId: 552)],
                page: 2,
                pages: 2
            )
        ]

        await sut.refresh()
        sut.onRequestAppear(makeRequest(id: 2, tmdbId: 551))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mock.fetchRequestsCallCount, 2)
    }

    func test_selectMediaSegment_loadsAdditionalPagesUntilMatchingRequestsFound() async {
        mock.stubbedResponsesByKey = [
            "all:0:20": makeResponse(
                requests: [
                    makeRequest(id: 1, tmdbId: 550),
                    makeRequest(id: 2, tmdbId: 551)
                ],
                page: 1,
                pages: 2
            ),
            "all:2:20": makeResponse(
                requests: [
                    makeRequest(id: 3, tmdbId: 1399, tvdbId: 121361)
                ],
                page: 2,
                pages: 2
            )
        ]

        await sut.refresh()
        sut.selectMediaSegment(.tvShows)
        await waitUntil {
            self.mock.fetchRequestsCallCount == 2 && self.sut.visibleRequests.map(\.id) == [3]
        }

        XCTAssertEqual(mock.fetchRequestsCallCount, 2)
        XCTAssertEqual(sut.visibleRequests.map(\.id), [3])
    }

    func test_selectMediaSegment_stopsBackfillAfterAppendFailure() async {
        mock.stubbedResponsesByKey = [
            "all:0:20": makeResponse(
                requests: [
                    makeRequest(id: 1, tmdbId: 550),
                    makeRequest(id: 2, tmdbId: 551)
                ],
                page: 1,
                pages: 2
            )
        ]
        mock.stubbedErrorsByKey = [
            "all:2:20": URLError(.notConnectedToInternet)
        ]

        await sut.refresh()
        sut.selectMediaSegment(.tvShows)
        await waitUntil {
            self.mock.fetchRequestsCallCount == 2 && !self.sut.isLoadingMore
        }

        XCTAssertEqual(mock.fetchRequestsCallCount, 2)
        XCTAssertTrue(sut.visibleRequests.isEmpty)
        XCTAssertFalse(sut.isLoadingMore)
    }

    func test_selectMediaSegment_cancelsInFlightPaginationWithoutDuplicatingRequests() async {
        mock.delayNanoseconds = 50_000_000
        mock.stubbedResponsesByKey = [
            "all:0:20": makeResponse(
                requests: [makeRequest(id: 1, tmdbId: 550)],
                page: 1,
                pages: 2
            ),
            "all:1:20": makeResponse(
                requests: [makeRequest(id: 2, tmdbId: 1399, tvdbId: 121361)],
                page: 2,
                pages: 2
            )
        ]

        await sut.refresh()
        sut.onRequestAppear(sut.visibleRequests[0])
        sut.selectMediaSegment(.tvShows)
        await waitUntil {
            self.sut.visibleRequests.map(\.id) == [2] && self.sut.requests.map(\.id) == [1, 2]
        }

        XCTAssertEqual(sut.requests.map(\.id), [1, 2])
        XCTAssertEqual(sut.visibleRequests.map(\.id), [2])
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 300_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while !condition() && DispatchTime.now().uptimeNanoseconds < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
