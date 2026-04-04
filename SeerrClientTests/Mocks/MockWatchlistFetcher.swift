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

    // MARK: - WatchlistFetching

    func fetchWatchlist(page: Int) async throws -> DiscoverResponse<DiscoverMediaItem> {
        if let error = stubbedError { throw error }
        return stubbedResponse ?? DiscoverResponse(
            page: 1,
            totalPages: 1,
            totalResults: 0,
            results: []
        )
    }
}
