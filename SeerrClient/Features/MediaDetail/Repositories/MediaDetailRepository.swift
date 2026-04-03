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
}
