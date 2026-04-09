// MediaDetailRepository.swift
// SeerrClient
//
// Data layer for the Media Detail feature. Fetches full movie, TV show, and
// season details from the Seerr API.

import Foundation

// MARK: - MediaDetailRepository

/// Fetches movie, TV, and season details from the Seerr API.
///
/// Usage:
/// ```swift
/// let repo = MediaDetailRepository(apiClient: client)
/// let movie = try await repo.fetchMovieDetails(movieId: 603)
/// ```
public final class MediaDetailRepository: Sendable {

    // MARK: - Dependencies

    private let apiClient: SeerrAPIClient

    // MARK: - Init

    public init(apiClient: SeerrAPIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Movie

    /// Fetches full details for a movie by TMDB ID.
    ///
    /// - Parameter movieId: The TMDB movie identifier.
    /// - Returns: A `MovieDetails` with credits, media info, and metadata.
    /// - Throws: `SeerrAPIError` on network or decoding failure.
    public func fetchMovieDetails(movieId: Int) async throws -> MovieDetails {
        let path = apiClient.endpoints.movie(id: movieId)
        return try await apiClient.get(path)
    }

    // MARK: - TV Show

    /// Fetches full details for a TV show by TMDB ID.
    ///
    /// - Parameter tvId: The TMDB series identifier.
    /// - Returns: A `TvDetails` with seasons, credits, and media info.
    /// - Throws: `SeerrAPIError` on network or decoding failure.
    public func fetchTvDetails(tvId: Int) async throws -> TvDetails {
        let path = apiClient.endpoints.tv(id: tvId)
        return try await apiClient.get(path)
    }

    // MARK: - Recommendations & Similar

    /// Fetches movie recommendations based on a given movie.
    public func fetchMovieRecommendations(movieId: Int) async throws -> [DiscoverMediaItem] {
        let path = apiClient.endpoints.movieRecommendations(id: movieId)
        let response: DiscoverResponse<DiscoverMediaItem> = try await apiClient.get(path)
        return response.results
    }

    /// Fetches movies similar to a given movie.
    public func fetchSimilarMovies(movieId: Int) async throws -> [DiscoverMediaItem] {
        let path = apiClient.endpoints.movieSimilar(id: movieId)
        let response: DiscoverResponse<DiscoverMediaItem> = try await apiClient.get(path)
        return response.results
    }

    /// Fetches TV show recommendations based on a given show.
    public func fetchTvRecommendations(tvId: Int) async throws -> [DiscoverMediaItem] {
        let path = apiClient.endpoints.tvRecommendations(id: tvId)
        let response: DiscoverResponse<DiscoverMediaItem> = try await apiClient.get(path)
        return response.results
    }

    /// Fetches TV shows similar to a given show.
    public func fetchSimilarTvShows(tvId: Int) async throws -> [DiscoverMediaItem] {
        let path = apiClient.endpoints.tvSimilar(id: tvId)
        let response: DiscoverResponse<DiscoverMediaItem> = try await apiClient.get(path)
        return response.results
    }

    // MARK: - Season

    /// Fetches details for a specific season of a TV show.
    ///
    /// - Parameters:
    ///   - tvId: The TMDB series identifier.
    ///   - seasonNumber: The season number (0 = specials).
    /// - Returns: A `Season` with episode list.
    /// - Throws: `SeerrAPIError` on network or decoding failure.
    public func fetchSeasonDetails(tvId: Int, seasonNumber: Int) async throws -> Season {
        let path = apiClient.endpoints.season(tvId: tvId, season: seasonNumber)
        return try await apiClient.get(path)
    }

    // MARK: - Collection

    /// Fetches full details for a TMDB collection by collection ID.
    ///
    /// - Parameter collectionId: The TMDB collection identifier (from `MovieCollection.id`).
    /// - Returns: A `Collection` with name, overview, and member movie list.
    /// - Throws: `SeerrAPIError` on network or decoding failure.
    public func fetchCollection(collectionId: Int) async throws -> Collection {
        let path = apiClient.endpoints.collection(id: collectionId)
        return try await apiClient.get(path)
    }

    // MARK: - Watchlist

    /// Adds an item to the current user's watchlist.
    ///
    /// Calls `POST /api/v1/watchlist` with a JSON body containing `mediaType` and `tmdbId`.
    /// The TMDB ID is used (not the Seerr internal media record ID).
    /// Returns normally on 201 Created. A 409 Conflict (already on watchlist) is silently
    /// treated as success — the item is on the watchlist either way.
    ///
    /// Example:
    /// ```swift
    /// try await repo.addToWatchlist(tmdbId: 603, mediaType: "movie")
    /// ```
    ///
    /// - Parameters:
    ///   - tmdbId: The TMDB identifier for the movie or TV show.
    ///   - mediaType: `"movie"` or `"tv"` (lowercase).
    /// - Throws: `SeerrAPIError` on network or server failure (except 409, which is ignored).
    public func addToWatchlist(tmdbId: Int, mediaType: String) async throws {
        let path = apiClient.endpoints.watchlist
        let body = WatchlistAddBody(mediaType: mediaType, tmdbId: tmdbId)
        do {
            let _: WatchlistResponse = try await apiClient.post(path, body: body)
        } catch SeerrAPIError.conflict {
            // 409 means the item is already on the watchlist — treat as success.
            AppLogger.info("MediaDetailRepository: item tmdbId=\(tmdbId) already on watchlist (409 ignored)")
        }
    }

    /// Removes an item from the current user's watchlist.
    ///
    /// Calls `DELETE /api/v1/watchlist/{tmdbId}`.
    /// The TMDB ID is used (not the Seerr internal media record ID).
    /// Returns normally on 204 No Content. A 404 Not Found (not on watchlist) is silently
    /// treated as success — the item is off the watchlist either way.
    ///
    /// Example:
    /// ```swift
    /// try await repo.removeFromWatchlist(tmdbId: 603)
    /// ```
    ///
    /// - Parameter tmdbId: The TMDB identifier for the movie or TV show.
    /// - Throws: `SeerrAPIError` on network or server failure (except 404, which is ignored).
    public func removeFromWatchlist(tmdbId: Int) async throws {
        let path = apiClient.endpoints.watchlistItem(tmdbId: tmdbId)
        do {
            try await apiClient.deleteVoid(path)
        } catch SeerrAPIError.notFound {
            // 404 means the item was not on the watchlist — treat as success.
            AppLogger.info("MediaDetailRepository: item tmdbId=\(tmdbId) not on watchlist (404 ignored)")
        }
    }
}

// MARK: - WatchlistAddBody

/// Request body for `POST /api/v1/watchlist`.
private struct WatchlistAddBody: Encodable {
    /// The media type. Must be `"movie"` or `"tv"` (lowercase).
    let mediaType: String
    /// The TMDB identifier of the item to add.
    let tmdbId: Int
}

// MARK: - WatchlistResponse

/// Minimal response type for the watchlist POST endpoint.
private struct WatchlistResponse: Decodable {}
