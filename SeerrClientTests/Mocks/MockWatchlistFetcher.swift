// MockWatchlistFetcher.swift
// SeerrClientTests
//
// A test double for WatchlistFetching. Allows tests to stub responses and
// errors without any network activity.

@testable import SeerrClient
import Foundation

final class MockWatchlistFetcher: WatchlistFetching, @unchecked Sendable {

    // MARK: - Stubs

    /// Set this to control what `fetchWatchlist` returns.
    var stubbedResponse: DiscoverResponse<DiscoverMediaItem>?

    /// Set this to make `fetchWatchlist` throw.
    var stubbedError: Error?

    /// Artificial delay for concurrency tests.
    var delayNanoseconds: UInt64 = 0

    /// Number of repository fetches observed by the view model.
    private(set) var fetchWatchlistCallCount = 0

    // MARK: - WatchlistFetching

    func fetchWatchlist(page: Int) async throws -> DiscoverResponse<DiscoverMediaItem> {
        fetchWatchlistCallCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let error = stubbedError { throw error }
        return stubbedResponse ?? DiscoverResponse(
            page: 1,
            totalPages: 1,
            totalResults: 0,
            results: []
        )
    }
}
