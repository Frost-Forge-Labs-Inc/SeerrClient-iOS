// SearchRepository.swift
// SeerrClient
//
// Data layer for the Search feature. Executes search queries against the Seerr
// API with type filtering and pagination support. Maps search type selection
// to the correct endpoint (multi-search, movie-only, TV-only, or person-only).

import Foundation

// MARK: - SearchType

/// The type filter for search queries.
public enum SearchType: String, Sendable, CaseIterable, Hashable {
    case all
    case movie
    case tv
    case person

    /// Human-readable label for filter chips.
    public var displayName: String {
        switch self {
        case .all:    return "All"
        case .movie:  return "Movies"
        case .tv:     return "TV Shows"
        case .person: return "People"
        }
    }
}

// MARK: - SearchResultItem

/// A single search result that may be a movie, TV show, or person.
///
/// Search endpoints return a mix of media types in the `results` array.
/// Use `mediaType` to distinguish rendering (poster card vs. person card).
public struct SearchResultItem: Codable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let mediaType: String?
    public let title: String?
    public let name: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let overview: String?
    public let voteAverage: Double?
    public let releaseDate: String?
    public let firstAirDate: String?
    public let genreIds: [Int]?
    public let mediaInfo: MediaInfo?

    // Person-specific fields
    public let profilePath: String?
    public let knownForDepartment: String?

    /// Display title: movie `title`, TV `name`, or person `name`.
    public var displayTitle: String {
        title ?? name ?? "Unknown"
    }

    /// Release year extracted from `releaseDate` (movie) or `firstAirDate` (TV).
    public var year: String? {
        let dateStr = releaseDate ?? firstAirDate
        guard let dateStr, dateStr.count >= 4 else { return nil }
        return String(dateStr.prefix(4))
    }

    /// Whether this result is a person.
    public var isPerson: Bool { mediaType == "person" }

    /// Whether this result is a movie.
    public var isMovie: Bool { mediaType == "movie" }

    /// Whether this result is a TV show.
    public var isTv: Bool { mediaType == "tv" }
}

// MARK: - SearchRepository

/// Fetches search results from the Seerr API with type filtering and pagination.
///
/// Usage:
/// ```swift
/// let repo = SearchRepository(apiClient: client)
/// let page = try await repo.search(query: "batman", type: .all, page: 1)
/// ```
public final class SearchRepository: Sendable {

    // MARK: - Dependencies

    private let apiClient: SeerrAPIClient

    // MARK: - Init

    /// Creates a repository backed by the given API client.
    ///
    /// - Parameter apiClient: The authenticated `SeerrAPIClient` for the active server.
    public init(apiClient: SeerrAPIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Search

    /// Executes a search query with optional type filter and pagination.
    ///
    /// - Parameters:
    ///   - query: The search string (must not be empty).
    ///   - type: Filter by media type. Use `.all` for multi-search.
    ///   - page: The page number to fetch (1-based). Defaults to 1.
    /// - Returns: A `DiscoverResponse<SearchResultItem>` with paginated results.
    /// - Throws: `SeerrAPIError` on network or decoding failure.
    public func search(
        query: String,
        type: SearchType = .all,
        page: Int = 1
    ) async throws -> DiscoverResponse<SearchResultItem> {
        let endpoints = apiClient.endpoints
        let path = endpoint(for: type, endpoints: endpoints)

        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: "\(page)")
        ]

        // Language param (optional, API defaults to "en")
        queryItems.append(URLQueryItem(name: "language", value: "en"))

        let response: DiscoverResponse<SearchResultItem> = try await apiClient.get(
            path,
            queryItems: queryItems
        )

        return response
    }

    // MARK: - Private

    /// Maps a search type to the correct API endpoint path.
    private func endpoint(for type: SearchType, endpoints: APIEndpoints) -> String {
        switch type {
        case .all:    return endpoints.search
        case .movie:  return endpoints.searchMovie
        case .tv:     return endpoints.searchTv
        case .person: return endpoints.searchPerson
        }
    }
}
