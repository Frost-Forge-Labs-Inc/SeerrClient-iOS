// DiscoverRepository.swift
// SeerrClient
//
// Data layer for the Discover feature. Fetches slider configuration and
// content for each slider from the Seerr API. Maps slider types to the
// correct API endpoints and handles pagination.

import Foundation

// MARK: - SliderContent

/// The resolved content for a single discover slider row.
///
/// Combines the slider configuration with the fetched media items, ready for
/// display in `DiscoverSliderView`.
public struct SliderContent: Identifiable, Sendable {
    /// Unique identifier (matches the slider's ID or a hash for built-ins).
    public let id: Int
    /// The original slider configuration.
    public let slider: DiscoverSlider
    /// The display title: custom title > default title for the slider type.
    public let displayTitle: String
    /// The media items to show in this row.
    public let items: [DiscoverMediaItem]
    /// Current page (1-based).
    public let page: Int
    /// Total number of pages available for this slider.
    public let totalPages: Int
}

// MARK: - DiscoverRepository

/// Fetches and assembles discover page data from the Seerr API.
///
/// Usage:
/// ```swift
/// let repo = DiscoverRepository(apiClient: client)
/// let sliders = try await repo.fetchEnabledSliders()
/// let content = try await repo.fetchAllContent(for: sliders)
/// ```
public final class DiscoverRepository: @unchecked Sendable {

    // MARK: - Dependencies

    private let apiClient: SeerrAPIClient

    // MARK: - Init

    /// Creates a repository backed by the given API client.
    ///
    /// - Parameter apiClient: The authenticated `SeerrAPIClient` for the active server.
    public init(apiClient: SeerrAPIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Slider Configuration

    /// Fetches the server's discover slider configuration and returns only enabled sliders.
    ///
    /// - Returns: An array of `DiscoverSlider` where `enabled == true`.
    /// - Throws: `SeerrAPIError` on network or decoding failure.
    public func fetchEnabledSliders() async throws -> [DiscoverSlider] {
        let endpoints = apiClient.endpoints
        let allSliders: [DiscoverSlider] = try await apiClient.get(endpoints.settingsDiscover)
        return allSliders.filter { $0.enabled }
    }

    // MARK: - Content Fetching

    /// Fetches first-page content for a single slider.
    ///
    /// Maps the slider's `type` to the correct API endpoint, parses any embedded
    /// data (genre ID, studio ID, etc.), and returns the resolved content.
    ///
    /// - Parameters:
    ///   - slider: The slider configuration to fetch content for.
    ///   - page: The page to fetch (1-based). Defaults to 1.
    /// - Returns: A `SliderContent` with the fetched media items.
    /// - Throws: `SeerrAPIError` on failure.
    public func fetchContent(for slider: DiscoverSlider, page: Int = 1) async throws -> SliderContent {
        let endpoints = apiClient.endpoints
        let sliderType = DiscoverSliderType(rawValue: slider.type)
        let path = contentPath(for: sliderType, slider: slider, endpoints: endpoints)
        let queryItems = [URLQueryItem(name: "page", value: "\(page)")]

        let displayTitle = slider.title.flatMap { $0.isEmpty ? nil : $0 }
            ?? sliderType?.defaultTitle
            ?? "Discover"

        // Most slider types return MovieResult or TvResult; trending returns mixed.
        // We decode as DiscoverMediaItem which handles both shapes.
        let response: DiscoverResponse<DiscoverMediaItem> = try await apiClient.get(
            path,
            queryItems: queryItems
        )

        return SliderContent(
            id: slider.id ?? (slider.type * 1000 + abs(slider.data?.hashValue ?? 0) % 1000),
            slider: slider,
            displayTitle: displayTitle,
            items: response.results,
            page: response.page,
            totalPages: response.totalPages
        )
    }

    /// Fetches first-page content for all sliders concurrently.
    ///
    /// Sliders that fail to load are silently skipped (logged as warnings).
    /// The returned array preserves the original slider order.
    ///
    /// - Parameter sliders: The enabled sliders to fetch content for.
    /// - Returns: An array of `SliderContent`, one per successfully loaded slider.
    // MARK: - Watchlist

    /// Fetches the user's Plex watchlist from `GET /discover/watchlist`.
    ///
    /// - Parameter page: 1-based page number.
    /// - Returns: A `DiscoverResponse` containing the watchlist items and pagination info.
    public func fetchWatchlist(page: Int = 1) async throws -> DiscoverResponse<DiscoverMediaItem> {
        let endpoints = apiClient.endpoints
        let queryItems = [URLQueryItem(name: "page", value: "\(page)")]
        return try await apiClient.get(endpoints.discoverWatchlist, queryItems: queryItems)
    }

    public func fetchAllContent(for sliders: [DiscoverSlider]) async -> [SliderContent] {
        await withTaskGroup(of: (Int, SliderContent?).self) { group in
            for (index, slider) in sliders.enumerated() {
                group.addTask { [self] in
                    do {
                        let content = try await self.fetchContent(for: slider)
                        return (index, content)
                    } catch {
                        AppLogger.warning("DiscoverRepository: failed to load slider '\(slider.title ?? "unknown")': \(error)")
                        return (index, nil)
                    }
                }
            }

            var results = [(Int, SliderContent)]()
            for await (index, content) in group {
                if let content {
                    results.append((index, content))
                }
            }

            // Preserve original slider ordering.
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    // MARK: - Private: Endpoint Mapping

    /// Maps a slider type to its API endpoint path.
    private func contentPath(
        for sliderType: DiscoverSliderType?,
        slider: DiscoverSlider,
        endpoints: APIEndpoints
    ) -> String {
        guard let sliderType else {
            AppLogger.warning("DiscoverRepository: unknown slider type \(slider.type), falling back to trending")
            return endpoints.discoverTrending
        }

        switch sliderType {
        case .trendingMovies, .popularMovies:
            return endpoints.discoverMovies
        case .upcomingMovies:
            return endpoints.discoverMoviesUpcoming
        case .trendingTv, .popularTv:
            return endpoints.discoverTv
        case .upcomingTv:
            return endpoints.discoverTvUpcoming
        case .trending:
            return endpoints.discoverTrending
        case .movieGenre:
            let genreId = extractDataId(from: slider.data, key: "genreId") ?? 28
            return endpoints.discoverMoviesByGenre(id: genreId)
        case .tvGenre:
            let genreId = extractDataId(from: slider.data, key: "genreId") ?? 10759
            return endpoints.discoverTvByGenre(id: genreId)
        case .studioMovies:
            let studioId = extractDataId(from: slider.data, key: "studioId") ?? 1
            return endpoints.discoverMoviesByStudio(id: studioId)
        case .networkTv:
            let networkId = extractDataId(from: slider.data, key: "networkId") ?? 1
            return endpoints.discoverTvByNetwork(id: networkId)
        case .tmdbMovieKeyword:
            let keywordId = extractDataId(from: slider.data, key: "keywordId") ?? 1
            return endpoints.discoverMoviesByKeyword(id: keywordId)
        case .tmdbTvKeyword:
            // TV keyword filtering uses the general TV endpoint (keyword passed via query in future).
            return endpoints.discoverTv
        case .plexWatchlist:
            return endpoints.discoverWatchlist
        }
    }

    /// Parses a JSON data string from a slider configuration to extract an integer ID.
    ///
    /// Slider data looks like `{"genreId": 28}` or `{"studioId": 420}`.
    ///
    /// - Parameters:
    ///   - jsonString: The raw JSON string from `DiscoverSlider.data`.
    ///   - key: The JSON key to extract (e.g. `"genreId"`).
    /// - Returns: The integer value, or `nil` if parsing fails.
    private func extractDataId(from jsonString: String?, key: String) -> Int? {
        guard let jsonString, !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = dict[key] as? Int else {
            return nil
        }
        return value
    }
}
