// ScreenshotDemoResponseBuilder.swift
// SeerrClient
//
// Jellyseerr-shaped JSON payload builders for Screenshot Demo Mode.

import Foundation

#if DEBUG

// MARK: - ScreenshotDemoResponseBuilder

/// Builds wire-format responses from the fictional screenshot catalog.
enum ScreenshotDemoResponseBuilder {

    // MARK: - Discovery

    /// Builds a paged discovery payload from movie and television cards.
    static func discover(
        _ catalog: ScreenshotDemoCatalog,
        movies: [ScreenshotDemoCatalog.Movie],
        shows: [ScreenshotDemoCatalog.TVShow]
    ) -> [String: Any] {
        [
            "page": 1,
            "totalPages": 1,
            "totalResults": movies.count + shows.count,
            "results": movies.map { card($0, catalog: catalog) }
                + shows.map { card($0, catalog: catalog) }
        ]
    }

    /// Builds a discovery card payload for a movie.
    static func card(
        _ movie: ScreenshotDemoCatalog.Movie,
        catalog: ScreenshotDemoCatalog
    ) -> [String: Any] {
        [
            "id": catalog.movieID(for: movie.id),
            "tmdbId": catalog.movieID(for: movie.id),
            "mediaType": "movie",
            "title": movie.title,
            "posterPath": path(movie.posterFile),
            "backdropPath": path(movie.backdropFile),
            "overview": movie.overview ?? "",
            "voteAverage": movie.rating ?? 0,
            "releaseDate": "\(movie.releaseYear ?? 2026)-01-01",
            "genreIds": genreIDs(movie.genres),
            "mediaInfo": mediaInfo(
                id: catalog.movieID(for: movie.id),
                status: catalog.status(for: movie.watchStatus)
            )
        ]
    }

    /// Builds a discovery card payload for a television show.
    static func card(
        _ show: ScreenshotDemoCatalog.TVShow,
        catalog: ScreenshotDemoCatalog
    ) -> [String: Any] {
        [
            "id": catalog.tvID(for: show.id),
            "tmdbId": catalog.tvID(for: show.id),
            "mediaType": "tv",
            "name": show.title,
            "posterPath": path(show.posterFile),
            "backdropPath": path(show.backdropFile),
            "overview": show.overview ?? "",
            "voteAverage": show.rating ?? 0,
            "firstAirDate": "\(show.firstAirYear ?? 2025)-01-01",
            "genreIds": genreIDs(show.genres),
            "mediaInfo": mediaInfo(
                id: catalog.tvID(for: show.id),
                status: catalog.status(for: show.watchStatus),
                tv: true
            )
        ]
    }

    // MARK: - Detail Payloads

    /// Builds a complete movie detail payload.
    static func movieDetails(
        _ movie: ScreenshotDemoCatalog.Movie,
        catalog: ScreenshotDemoCatalog
    ) -> [String: Any] {
        [
            "id": catalog.movieID(for: movie.id),
            "title": movie.title,
            "tagline": movie.tagline ?? "",
            "overview": movie.overview ?? "",
            "posterPath": path(movie.posterFile),
            "backdropPath": path(movie.backdropFile),
            "releaseDate": "\(movie.releaseYear ?? 2026)-01-01",
            "runtime": movie.runtimeMinutes ?? 100,
            "voteAverage": movie.rating ?? 0,
            "genres": genres(movie.genres),
            "credits": credits(movie.cast, fallbackIDs: movie.castIds, title: movie.title, catalog: catalog),
            "mediaInfo": mediaInfo(
                id: catalog.movieID(for: movie.id),
                status: catalog.status(for: movie.watchStatus)
            )
        ]
    }

    /// Builds a complete television show detail payload.
    static func tvDetails(
        _ show: ScreenshotDemoCatalog.TVShow,
        catalog: ScreenshotDemoCatalog
    ) -> [String: Any] {
        let seasons = show.seasons ?? []

        return [
            "id": catalog.tvID(for: show.id),
            "name": show.title,
            "tagline": show.tagline ?? "",
            "overview": show.overview ?? "",
            "posterPath": path(show.posterFile),
            "backdropPath": path(show.backdropFile),
            "firstAirDate": "\(show.firstAirYear ?? 2025)-01-01",
            "voteAverage": show.rating ?? 0,
            "genres": genres(show.genres),
            "numberOfSeason": seasons.count,
            "numberOfEpisodes": seasons.reduce(0) { $0 + ($1.episodes?.count ?? 0) },
            "seasons": seasons.map {
                season($0, show: show, catalog: catalog, includeEpisodes: false)
            },
            "credits": credits(show.cast, fallbackIDs: show.castIds, title: show.title, catalog: catalog),
            // The request sheet requires a tvdbId to enable submission, so the
            // series payload carries the same synthetic id as its mediaInfo.
            "externalIds": [
                "tvdbId": catalog.tvID(for: show.id) + 100_000
            ],
            "mediaInfo": mediaInfo(
                id: catalog.tvID(for: show.id),
                status: catalog.status(for: show.watchStatus),
                tv: true
            )
        ]
    }

    /// Builds a season payload, optionally including its episodes.
    static func season(
        _ season: ScreenshotDemoCatalog.Season,
        show: ScreenshotDemoCatalog.TVShow,
        catalog: ScreenshotDemoCatalog,
        includeEpisodes: Bool = true
    ) -> [String: Any] {
        [
            "id": catalog.tvID(for: show.id) + (season.seasonNumber ?? 1),
            "seasonNumber": season.seasonNumber ?? 1,
            "name": season.name ?? "Season \(season.seasonNumber ?? 1)",
            "overview": season.overview ?? "",
            "episodeCount": season.episodes?.count ?? 0,
            "episodes": includeEpisodes
                ? (season.episodes ?? []).map { episode($0, show: show, season: season, catalog: catalog) }
                : []
        ]
    }

    /// Builds the named quality profiles shown in the request sheet.
    static func profiles() -> [[String: Any]] {
        [
            ["id": 1, "name": "1080p Web-DL"],
            ["id": 2, "name": "4K HDR"]
        ]
    }

    // MARK: - Private Builders

    /// Builds an episode payload with a stable, varied rating.
    private static func episode(
        _ episode: ScreenshotDemoCatalog.Episode,
        show: ScreenshotDemoCatalog.TVShow,
        season: ScreenshotDemoCatalog.Season,
        catalog: ScreenshotDemoCatalog
    ) -> [String: Any] {
        let episodeNumber = episode.episodeNumber ?? 1

        return [
            "id": catalog.tvID(for: show.id) + episodeNumber,
            "showId": catalog.tvID(for: show.id),
            "seasonNumber": season.seasonNumber ?? 1,
            "episodeNumber": episodeNumber,
            "name": episode.name ?? "Untitled Episode",
            "overview": episode.overview ?? "",
            "stillPath": path(episode.stillFile),
            "voteAverage": 7.2 + (Double(episodeNumber % 7) * 0.2)
        ]
    }

    /// Builds the compact media availability object expected by the app.
    private static func mediaInfo(id: Int, status: Int, tv: Bool = false) -> [String: Any] {
        var result: [String: Any] = [
            "id": id,
            "tmdbId": id,
            "status": status
        ]
        if tv {
            result["tvdbId"] = id + 100_000
        }
        return result
    }

    /// Builds cast credits, preferring per-title credits and retaining tolerant legacy fallbacks.
    private static func credits(
        _ cast: [ScreenshotDemoCatalog.CastCredit]?,
        fallbackIDs: [String]?,
        title: String,
        catalog: ScreenshotDemoCatalog
    ) -> [String: Any] {
        let fallbackCharacters = [
            "Mara Venn",
            "Elias Rowe",
            "Captain Sato",
            "Nina Vale",
            "Orin Hale",
            "Dr. Imani Cross",
            "Tomas Bell",
            "June Calder"
        ]

        let entries: [(id: String, character: String?)] = cast?.map {
            (id: $0.castId, character: $0.character)
        } ?? (fallbackIDs ?? []).map { (id: $0, character: nil) }

        return ["cast": entries.enumerated().compactMap { index, entry -> [String: Any]? in
            guard let member = catalog.cast(id: entry.id) else { return nil }
            let fallbackIndex = stableCharacterIndex(title: title, castID: member.id, count: fallbackCharacters.count)
            return [
                "id": catalog.castID(for: member.id),
                "castId": index + 1,
                "name": member.name,
                "character": entry.character ?? member.character ?? fallbackCharacters[fallbackIndex],
                "order": index,
                "profilePath": path(member.photoFile)
            ]
        }]
    }

    /// Produces a process-stable fallback character choice for a title and performer pair.
    private static func stableCharacterIndex(title: String, castID: String, count: Int) -> Int {
        let value = (title + "|" + castID).unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31) &+ Int(scalar.value)
        }
        return abs(value) % count
    }

    /// Builds genre objects from catalog genre names.
    private static func genres(_ values: [String]?) -> [[String: Any]] {
        (values ?? []).enumerated().map { ["id": $0.offset + 1, "name": $0.element] }
    }

    /// Builds genre identifiers without inventing an ID for an empty list.
    private static func genreIDs(_ values: [String]?) -> [Int] {
        guard let values, !values.isEmpty else { return [] }
        return Array(1...values.count)
    }

    /// Converts a catalog-relative asset path to an API image path.
    private static func path(_ value: String?) -> Any {
        value.map { "/\($0)" } ?? ""
    }
}

#endif
