// ScreenshotDemoURLProtocol.swift
// SeerrClient
//
// DEBUG-only URLProtocol that serves the fictional screenshot catalog.

import Foundation

#if DEBUG

// MARK: - ScreenshotDemoURLProtocol

/// Intercepts demo-server requests and synthesizes API responses from the cached catalog.
final class ScreenshotDemoURLProtocol: URLProtocol {
    static let baseURLString = "http://jellyseerr.home:5055"
    /// One distinct host per demo server, so the Servers screenshot does not show
    /// the same address twice. Index 0 is the default/active server.
    private static let orderedHosts = [
        "jellyseerr.home",
        "cabin.homelab.local",
        "office.homelab.local"
    ]
    private static let hosts: Set<String> = Set(orderedHosts).union(["media.homelab.local"])
    private static let legacyDemoHosts: Set<String> = ["screenshot-demo.seerr"]

    /// Returns the displayed base URL for a demo server at the given catalog index.
    static func baseURLString(for index: Int) -> String {
        guard index > 0, index < orderedHosts.count else { return baseURLString }
        return "http://\(orderedHosts[index]):5055"
    }

    /// Returns whether a stored server belongs to the isolated demo host set.
    static func isDemoServer(_ server: ServerConfiguration) -> Bool {
        guard let host = URL(string: server.baseURL)?.host else { return false }
        return hosts.contains(host) || legacyDemoHosts.contains(host)
    }

    /// Returns whether this protocol owns a request to one of the demo servers.
    override class func canInit(with request: URLRequest) -> Bool {
        ScreenshotDemoConfiguration.current.isEnabled
            && request.url?.host.map { hosts.contains($0) } == true
    }

    /// Returns the request unchanged because demo URLs need no normalization.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    /// Stops loading; all demo responses are produced synchronously.
    override func stopLoading() {}

    /// Delivers the synthesized JSON response to the URL loading client.
    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let data = try Self.response(for: request, url: url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    // MARK: - Response Routing

    /// Routes Jellyseerr API paths to deterministic payloads from the cached demo catalog.
    private static func response(for request: URLRequest, url: URL) throws -> Data {
        guard let catalog = ScreenshotDemoConfiguration.current.catalog else {
            return try json(emptyDiscoverResponse)
        }

        let method = request.httpMethod ?? "GET"
        let path = url.path
        let discoverMovies = catalog.movies
        let discoverShows = catalog.tvShows
        let trendingMovies = Array(discoverMovies.prefix(4))
        let trendingShows = Array(discoverShows.prefix(2))
        let popularMovies = Array(discoverMovies.dropFirst(4).prefix(5))
        // Disjoint from trending/popular so no poster appears in two Discover rows.
        let upcomingMovies = Array(discoverMovies.dropFirst(9).prefix(5))
        let popularShows = Array(discoverShows.dropFirst(2).prefix(3))
        let watchlist = catalog.items(featuredIn: "watchlist")

        switch (method, path) {
        case ("GET", "/api/v1/auth/me"):
            return try json([
                "id": 1,
                "email": "demo@octopusexplorer.invalid",
                "displayName": "Demo Explorer",
                "username": "demo",
                "userType": 2,
                "permissions": 2,
                "requestCount": 0
            ])
        case ("GET", "/api/v1/status"):
            return try json([
                "version": "2.0.0-demo",
                "commitTag": "demo",
                "updateAvailable": false
            ])
        case ("GET", "/api/v1/settings/discover"):
            return try json([
                ["id": 1, "type": 7, "title": "Trending Now", "enabled": true],
                ["id": 2, "type": 2, "title": "Popular Movies", "enabled": true],
                ["id": 3, "type": 5, "title": "Popular Series", "enabled": true],
                ["id": 4, "type": 3, "title": "Upcoming Movies", "enabled": true]
            ])
        case ("GET", "/api/v1/discover/watchlist"):
            return try json(ScreenshotDemoResponseBuilder.discover(
                catalog,
                movies: watchlist.0,
                shows: watchlist.1
            ))
        case ("GET", "/api/v1/discover/movies"):
            return try json(ScreenshotDemoResponseBuilder.discover(
                catalog,
                movies: popularMovies,
                shows: []
            ))
        case ("GET", "/api/v1/discover/movies/upcoming"):
            return try json(ScreenshotDemoResponseBuilder.discover(
                catalog,
                movies: upcomingMovies,
                shows: []
            ))
        case ("GET", "/api/v1/discover/tv"), ("GET", "/api/v1/discover/tv/upcoming"):
            return try json(ScreenshotDemoResponseBuilder.discover(
                catalog,
                movies: [],
                shows: popularShows
            ))
        case ("GET", "/api/v1/discover/trending"), ("GET", "/api/v1/search"):
            return try json(ScreenshotDemoResponseBuilder.discover(
                catalog,
                movies: trendingMovies,
                shows: trendingShows
            ))
        case ("GET", "/api/v1/request/count"):
            return try json([
                "total": 0,
                "movie": 0,
                "tv": 0,
                "pending": 0,
                "approved": 0,
                "declined": 0,
                "processing": 0,
                "available": 0
            ])
        case ("GET", "/api/v1/request"):
            return try json([
                "pageInfo": ["page": 1, "pages": 1, "results": 0],
                "results": []
            ])
        case ("POST", "/api/v1/request"):
            return try json(["id": 1, "status": 1])
        case ("GET", "/api/v1/settings/radarr"):
            return try json([[
                "id": 1,
                "name": "Home Radarr",
                "hostname": "media-server",
                "port": 7878,
                "apiKey": "demo",
                "useSsl": false,
                "activeProfileId": 1,
                "activeProfileName": "1080p Web-DL",
                "activeDirectory": "/movies",
                "is4k": false,
                "minimumAvailability": "Released",
                "isDefault": true
            ]])
        case ("GET", "/api/v1/settings/radarr/1/profiles"):
            return try json(ScreenshotDemoResponseBuilder.profiles())
        case ("GET", "/api/v1/settings/sonarr"):
            return try json([[
                "id": 1,
                "name": "Home Sonarr",
                "hostname": "media-server",
                "port": 8989,
                "apiKey": "demo",
                "useSsl": false,
                "activeProfileId": 1,
                "activeProfileName": "1080p Web-DL",
                "activeDirectory": "/tv",
                "is4k": false,
                "isDefault": true
            ]])
        case ("GET", "/api/v1/service/sonarr/1"):
            return try json(["profiles": ScreenshotDemoResponseBuilder.profiles()])
        default:
            break
        }

        if let id = number(after: "/api/v1/movie/", in: path), let movie = catalog.movie(id: id) {
            if path.hasSuffix("/recommendations") || path.hasSuffix("/similar") {
                return try json(ScreenshotDemoResponseBuilder.discover(
                    catalog,
                    movies: catalog.movies.filter { $0.id != movie.id }.suffix(5).map { $0 },
                    shows: []
                ))
            }
            return try json(ScreenshotDemoResponseBuilder.movieDetails(movie, catalog: catalog))
        }

        if let id = number(after: "/api/v1/tv/", in: path), let show = catalog.tv(id: id) {
            let components = path.split(separator: "/")
            if let seasonIndex = components.firstIndex(of: "season"),
               components.count > seasonIndex + 1,
               let number = Int(components[seasonIndex + 1]),
               let season = (show.seasons ?? []).first(where: { ($0.seasonNumber ?? 1) == number }) {
                return try json(ScreenshotDemoResponseBuilder.season(season, show: show, catalog: catalog))
            }
            if path.hasSuffix("/recommendations") || path.hasSuffix("/similar") {
                return try json(ScreenshotDemoResponseBuilder.discover(
                    catalog,
                    movies: [],
                    shows: catalog.tvShows.filter { $0.id != show.id }.suffix(4).map { $0 }
                ))
            }
            return try json(ScreenshotDemoResponseBuilder.tvDetails(show, catalog: catalog))
        }

        AppLogger.warning("Screenshot Demo Mode unmatched endpoint: \(method) \(path)")
        return try json(emptyDiscoverResponse)
    }

    // MARK: - Private Helpers

    /// Parses the first numeric component following a verified API path prefix.
    private static func number(after prefix: String, in path: String) -> Int? {
        guard path.hasPrefix(prefix) else { return nil }
        return Int(path.dropFirst(prefix.count).split(separator: "/").first ?? "")
    }

    /// Serializes an API-shaped value as JSON data.
    private static func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    /// Empty discovery response used only if the cached configuration is disabled.
    private static let emptyDiscoverResponse: [String: Any] = [
        "page": 1,
        "totalPages": 1,
        "totalResults": 0,
        "results": []
    ]
}

#endif
