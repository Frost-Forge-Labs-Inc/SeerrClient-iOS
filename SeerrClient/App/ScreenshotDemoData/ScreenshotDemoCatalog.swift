// ScreenshotDemoCatalog.swift
// SeerrClient
//
// Tolerant decoder and lookup helpers for the host-only screenshot demo catalog.

import Foundation

#if DEBUG

// MARK: - ScreenshotDemoCatalog

/// A wholly fictional catalog used only by Screenshot Demo Mode.
struct ScreenshotDemoCatalog: Decodable, Sendable {
    let servers: [Server]
    let castPool: [CastMember]
    let movies: [Movie]
    let tvShows: [TVShow]

    /// A server visible in the demo server switcher.
    struct Server: Decodable, Sendable {
        let name: String
        let type: String?
    }

    /// A fictional cast member used by detail payloads.
    struct CastMember: Decodable, Sendable {
        let id: String
        let name: String
        let photoFile: String?
        let character: String?
    }

    /// A fictional movie in the demo catalog.
    struct Movie: Decodable, Sendable {
        let id: String
        let title: String
        let tagline: String?
        let overview: String?
        let genres: [String]?
        let releaseYear: Int?
        let runtimeMinutes: Int?
        let rating: Double?
        let posterFile: String?
        let backdropFile: String?
        let castIds: [String]?
        let cast: [CastCredit]?
        let watchStatus: String?
        let featuredIn: [String]?

        /// The explicitly assigned screenshot scenes, defaulting to none.
        var featuredInValues: [String] {
            featuredIn ?? []
        }
    }

    /// A fictional television show in the demo catalog.
    struct TVShow: Decodable, Sendable {
        let id: String
        let title: String
        let tagline: String?
        let overview: String?
        let genres: [String]?
        let firstAirYear: Int?
        let rating: Double?
        let posterFile: String?
        let backdropFile: String?
        let castIds: [String]?
        let cast: [CastCredit]?
        let seasons: [Season]?
        let watchStatus: String?
        let featuredIn: [String]?

        /// The explicitly assigned screenshot scenes, defaulting to none.
        var featuredInValues: [String] {
            featuredIn ?? []
        }
    }

    /// A per-title cast credit, allowing a performer to have a different character in each title.
    struct CastCredit: Decodable, Sendable {
        let castId: String
        let character: String?
    }

    /// A catalog item selected for a screenshot scene, retaining its media kind.
    enum FeaturedItem: Sendable {
        case movie(Movie)
        case tvShow(TVShow)
    }

    /// A season within a fictional television show.
    struct Season: Decodable, Sendable {
        let seasonNumber: Int?
        let name: String?
        let overview: String?
        let episodes: [Episode]?
    }

    /// A fictional episode within a demo season.
    struct Episode: Decodable, Sendable {
        let episodeNumber: Int?
        let name: String?
        let overview: String?
        let stillFile: String?
    }

    private enum CodingKeys: String, CodingKey {
        case servers
        case castPool
        case movies
        case tvShows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        servers = (try? container.decode([Server].self, forKey: .servers)) ?? []
        castPool = (try? container.decode([CastMember].self, forKey: .castPool)) ?? []
        movies = (try? container.decode([Movie].self, forKey: .movies)) ?? []
        tvShows = (try? container.decode([TVShow].self, forKey: .tvShows)) ?? []
    }

    // MARK: - Loading

    /// Loads the catalog from a host filesystem directory, logging and returning nil on failure.
    static func load(from root: String?) -> ScreenshotDemoCatalog? {
        guard let root else { return nil }

        let url = URL(fileURLWithPath: root).appendingPathComponent("catalog.json")
        do {
            return try JSONDecoder().decode(ScreenshotDemoCatalog.self, from: Data(contentsOf: url))
        } catch {
            AppLogger.warning("Screenshot Demo Mode disabled: could not load catalog: \(error)")
            return nil
        }
    }

    // MARK: - Identifiers

    /// Returns the stable TMDB-shaped identifier for a movie catalog ID.
    func movieID(for stringID: String) -> Int {
        9_000_000 + trailingNumber(in: stringID)
    }

    /// Returns the stable TMDB-shaped identifier for a television catalog ID.
    func tvID(for stringID: String) -> Int {
        9_100_000 + trailingNumber(in: stringID)
    }

    /// Returns the stable TMDB-shaped identifier for a cast catalog ID.
    func castID(for stringID: String) -> Int {
        9_200_000 + trailingNumber(in: stringID)
    }

    // MARK: - Lookup

    /// Finds a movie by its stable synthetic identifier.
    func movie(id: Int) -> Movie? {
        movies.first { movieID(for: $0.id) == id }
    }

    /// Finds a TV show by its stable synthetic identifier.
    func tv(id: Int) -> TVShow? {
        tvShows.first { tvID(for: $0.id) == id }
    }

    /// Finds a cast member by its catalog identifier.
    func cast(id: String) -> CastMember? {
        castPool.first { $0.id == id }
    }

    /// Returns catalog items explicitly assigned to a screenshot scene.
    func items(featuredIn scene: String) -> ([Movie], [TVShow]) {
        (
            movies.filter { $0.featuredInValues.contains(scene) },
            tvShows.filter { $0.featuredInValues.contains(scene) }
        )
    }

    /// Resolves a scene's explicitly tagged title across movies and TV shows.
    /// If the tag is absent, logs the omission and uses that scene's expected media kind.
    func featuredItem(forScene scene: ScreenshotDemoScene) -> FeaturedItem? {
        let tag = scene.rawValue
        if let movie = movies.first(where: { $0.featuredInValues.contains(tag) }) {
            return .movie(movie)
        }
        if let show = tvShows.first(where: { $0.featuredInValues.contains(tag) }) {
            return .tvShow(show)
        }

        AppLogger.warning("Screenshot Demo Mode missing featuredIn tag: \(tag)")
        switch scene {
        case .mediaDetail:
            return movies.first.map(FeaturedItem.movie)
        case .requestFlow, .tvEpisodes:
            return tvShows.first.map(FeaturedItem.tvShow)
        case .discover, .watchlist, .multiServer:
            return nil
        }
    }

    /// Maps a tolerant catalog watch status to the app's media status code.
    func status(for value: String?) -> Int {
        switch value?.lowercased() {
        case "available":
            return MediaStatusCode.available.rawValue
        case "requested", "pending":
            return MediaStatusCode.pending.rawValue
        case "processing":
            return MediaStatusCode.processing.rawValue
        case "partial", "partiallyavailable", "partially_available":
            return MediaStatusCode.partiallyAvailable.rawValue
        default:
            return MediaStatusCode.unknown.rawValue
        }
    }

    // MARK: - Private Helpers

    /// Extracts the numeric suffix used to create stable synthetic identifiers.
    private func trailingNumber(in value: String) -> Int {
        Int(value.split(separator: "-").last ?? "0") ?? 0
    }
}

#endif
