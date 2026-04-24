// UITestURLProtocol.swift
// SeerrClient
//
// Test-only HTTP stub layer used by XCUITest scenarios. Requests are intercepted
// only when the app is launched with a recognised UI-test scenario.

import Foundation

#if DEBUG

// MARK: - UITestURLProtocol

final class UITestURLProtocol: URLProtocol {
    static let baseURLString = "http://ui-test.seerr:5055"

    private static let host = "ui-test.seerr"
    private static let state = UITestScenarioState()

    override class func canInit(with request: URLRequest) -> Bool {
        guard UITestLaunchConfiguration.current.isEnabled,
              request.url?.host == host else {
            return false
        }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let stub = try Self.stubbedResponse(for: request, url: url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: nil,
                headerFields: stub.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let body = stub.body {
                client?.urlProtocol(self, didLoad: body)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func resetState(for scenario: UITestScenario) {
        state.reset(for: scenario)
    }

    private static func stubbedResponse(for request: URLRequest, url: URL) throws -> StubbedResponse {
        let method = request.httpMethod ?? "GET"
        let path = url.path

        switch (method, path) {
        case ("GET", "/api/v1/auth/me"):
            if UITestLaunchConfiguration.current.scenario == .launchFlowServerSelection {
                let hasSavedSignIn =
                    KeychainManager.shared.read(.authMethod, server: Self.baseURLString) != nil
                    || KeychainManager.shared.read(.sessionToken, server: Self.baseURLString) != nil

                if !hasSavedSignIn {
                    return try jsonResponse(
                        statusCode: 401,
                        object: ["message": "No remembered sign-in"]
                    )
                }
            }

            return try jsonResponse(
                statusCode: 200,
                object: [
                    "id": 1,
                    "email": "uitest@example.com",
                    "displayName": "UI Tester",
                    "username": "uitester",
                    "userType": 2,
                    "permissions": 2,
                    "requestCount": 0
                ]
            )

        case ("GET", "/api/v1/status"):
            return try jsonResponse(
                statusCode: 200,
                object: [
                    "version": "2.0.0-uitest",
                    "commitTag": "uitest",
                    "updateAvailable": false,
                    "commitsBehind": 0,
                    "restartRequired": false
                ]
            )

        case ("GET", "/api/v1/request/count"):
            return try jsonResponse(
                statusCode: 200,
                object: [
                    "total": 0,
                    "movie": 0,
                    "tv": 0,
                    "pending": 0,
                    "approved": 0,
                    "declined": 0,
                    "processing": 0,
                    "available": 0
                ]
            )

        case ("GET", "/api/v1/request"):
            return try jsonResponse(
                statusCode: 200,
                object: state.requestListPayload(for: url)
            )

        case ("GET", "/api/v1/settings/discover"):
            return try jsonResponse(statusCode: 200, object: [])

        case ("GET", "/api/v1/settings/radarr"):
            return try jsonResponse(statusCode: 200, object: [])

        case ("GET", "/api/v1/discover/watchlist"):
            return try jsonResponse(
                statusCode: 200,
                object: state.watchlistPayload()
            )

        case ("GET", "/api/v1/collection/1000"):
            return try jsonResponse(
                statusCode: 200,
                object: state.collectionPayload()
            )

        case ("GET", "/api/v1/movie/550"):
            return try jsonResponse(
                statusCode: 200,
                object: state.movieDetailsPayload()
            )

        case ("GET", "/api/v1/movie/1001"):
            return try jsonResponse(
                statusCode: 200,
                object: [
                    "id": 1001,
                    "title": "Request Filter Movie",
                    "posterPath": nil,
                    "mediaInfo": [
                        "id": 1001,
                        "tmdbId": 1001,
                        "status": 2
                    ]
                ]
            )

        case ("GET", "/api/v1/tv/1002"):
            return try jsonResponse(
                statusCode: 200,
                object: [
                    "id": 1002,
                    "name": "Request Filter TV",
                    "posterPath": nil,
                    "firstAirDate": "2024-01-01",
                    "mediaInfo": [
                        "id": 1002,
                        "tmdbId": 1002,
                        "tvdbId": 2002,
                        "status": 1
                    ]
                ]
            )

        case ("GET", "/api/v1/movie/550/recommendations"),
             ("GET", "/api/v1/movie/550/similar"):
            return try jsonResponse(
                statusCode: 200,
                object: [
                    "page": 1,
                    "totalPages": 1,
                    "totalResults": 0,
                    "results": []
                ]
            )

        case ("DELETE", "/api/v1/watchlist/550"):
            state.removeWatchlistMovie()
            return StubbedResponse(statusCode: 204, headers: [:], body: nil)

        case ("POST", "/api/v1/request"):
            state.recordCollectionRequest(from: request)
            return try jsonResponse(
                statusCode: 201,
                object: [
                    "id": state.nextRequestID(),
                    "status": 1
                ]
            )

        default:
            return try jsonResponse(
                statusCode: 404,
                object: [
                    "message": "No UI test stub registered for \(method) \(path)"
                ]
            )
        }
    }

    private static func jsonResponse(statusCode: Int, object: Any) throws -> StubbedResponse {
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        return StubbedResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            body: data
        )
    }
}

// MARK: - StubbedResponse

private struct StubbedResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data?
}

// MARK: - UITestScenarioState

private final class UITestScenarioState: @unchecked Sendable {
    private let lock = NSLock()
    private var activeScenario: UITestScenario = .watchlistRemoval
    private var watchlistContainsMovie = true
    private var watchlistContainsTvShow = false
    private var requestedCollectionMovieIDs: Set<Int> = []
    private var nextRequestIdentifier = 7000

    func reset(for scenario: UITestScenario) {
        lock.withLock {
            activeScenario = scenario
            switch scenario {
            case .watchlistRemoval:
                watchlistContainsMovie = true
                watchlistContainsTvShow = false
                requestedCollectionMovieIDs = []
                nextRequestIdentifier = 7000
            case .watchlistMediaFilter:
                watchlistContainsMovie = true
                watchlistContainsTvShow = true
                requestedCollectionMovieIDs = []
                nextRequestIdentifier = 7000
            case .requestMediaFilter:
                watchlistContainsMovie = true
                watchlistContainsTvShow = false
                requestedCollectionMovieIDs = []
                nextRequestIdentifier = 7000
            case .collectionRequestSelection:
                watchlistContainsMovie = true
                watchlistContainsTvShow = false
                requestedCollectionMovieIDs = []
                nextRequestIdentifier = 7000
            case .aboutNavigation:
                watchlistContainsMovie = true
                watchlistContainsTvShow = false
                requestedCollectionMovieIDs = []
                nextRequestIdentifier = 7000
            case .launchFlowServerSelection:
                watchlistContainsMovie = true
                watchlistContainsTvShow = false
                requestedCollectionMovieIDs = []
                nextRequestIdentifier = 7000
            }
        }
    }

    func removeWatchlistMovie() {
        lock.withLock {
            watchlistContainsMovie = false
        }
    }

    func watchlistPayload() -> [String: Any] {
        lock.withLock {
            var results: [[String: Any]] = []

            switch activeScenario {
            case .watchlistMediaFilter:
                if watchlistContainsMovie {
                    results.append(contentsOf: [
                        watchlistItemPayload(
                            id: 9001,
                            tmdbId: 550,
                            mediaType: "movie",
                            title: "Forbidden Daughters",
                            year: "1927-01-01",
                            overview: "A UI test movie used to validate 3-up watchlist layout."
                        ),
                        watchlistItemPayload(
                            id: 9002,
                            tmdbId: 551,
                            mediaType: "movie",
                            title: "King Kong vs. Godzilla",
                            year: "1962-01-01",
                            overview: "A second movie in the same watchlist test row."
                        ),
                        watchlistItemPayload(
                            id: 9003,
                            tmdbId: 552,
                            mediaType: "movie",
                            title: "RoboCop 2",
                            year: "1990-01-01",
                            overview: "A third movie in the same watchlist test row."
                        ),
                        watchlistItemPayload(
                            id: 9004,
                            tmdbId: 553,
                            mediaType: "movie",
                            title: "RoboCop 3",
                            year: "1993-01-01",
                            overview: "A fourth movie to validate row wrapping."
                        )
                    ])
                }

                if watchlistContainsTvShow {
                    results.append(
                        watchlistItemPayload(
                            id: 9101,
                            tmdbId: 1399,
                            mediaType: "tv",
                            title: "Segmented TV Test",
                            year: "2011-04-17",
                            overview: "A UI test show used to validate watchlist filtering."
                        )
                    )
                }

            default:
                if watchlistContainsMovie {
                    results.append(
                        watchlistItemPayload(
                            id: 9001,
                            tmdbId: 550,
                            mediaType: "movie",
                            title: "Fight Club",
                            year: "1999-10-15",
                            overview: "A UI test movie used to validate watchlist removal."
                        )
                    )
                }

                if watchlistContainsTvShow {
                    results.append(
                        watchlistItemPayload(
                            id: 9101,
                            tmdbId: 1399,
                            mediaType: "tv",
                            title: "Game of Thrones",
                            year: "2011-04-17",
                            overview: "A UI test show used to validate watchlist filtering."
                        )
                    )
                }
            }

            return [
                "page": 1,
                "totalPages": 1,
                "totalResults": results.count,
                "results": results
            ]
        }
    }

    func movieDetailsPayload() -> [String: Any] {
        lock.withLock {
            [
                "id": 550,
                "title": "Fight Club",
                "overview": "A UI test movie used to validate watchlist removal.",
                "releaseDate": "1999-10-15",
                "credits": [
                    "cast": [],
                    "crew": []
                ],
                "mediaInfo": [
                    "id": 1,
                    "tmdbId": 550,
                    "status": 1,
                    "watchlisted": watchlistContainsMovie
                ]
            ]
        }
    }

    func collectionPayload() -> [String: Any] {
        lock.withLock {
            [
                "id": 1000,
                "name": "Collection UI Test",
                "overview": "A deterministic collection used to validate selection-based movie requests.",
                "parts": [
                    collectionMoviePayload(
                        id: 1001,
                        title: "Selectable Movie",
                        status: requestedCollectionMovieIDs.contains(1001) ? 2 : 1
                    ),
                    collectionMoviePayload(
                        id: 1002,
                        title: "Partial Movie",
                        status: requestedCollectionMovieIDs.contains(1002) ? 2 : 4
                    ),
                    collectionMoviePayload(
                        id: 1003,
                        title: "Pending Movie",
                        status: 2
                    ),
                    collectionMoviePayload(
                        id: 1004,
                        title: "Available Movie",
                        status: 5
                    )
                ]
            ]
        }
    }

    func requestListPayload(for url: URL) -> [String: Any] {
        lock.withLock {
            let page = 1
            let pages = 1
            let results: [[String: Any]]

            switch activeScenario {
            case .requestMediaFilter:
                results = [
                    requestPayload(
                        id: 1001,
                        status: 1,
                        tmdbId: 1001,
                        tvdbId: nil,
                        requesterName: "MovieRequester"
                    ),
                    requestPayload(
                        id: 1002,
                        status: 2,
                        tmdbId: 1002,
                        tvdbId: 2002,
                        requesterName: "TvRequester"
                    )
                ]
            default:
                results = []
            }

            return [
                "pageInfo": [
                    "page": page,
                    "pages": pages,
                    "results": results.count
                ],
                "results": results
            ]
        }
    }

    func recordCollectionRequest(from request: URLRequest) {
        guard let body = request.httpBody,
              let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let mediaId = jsonObject["mediaId"] as? Int else {
            return
        }

        _ = lock.withLock {
            requestedCollectionMovieIDs.insert(mediaId)
        }
    }

    func nextRequestID() -> Int {
        lock.withLock {
            nextRequestIdentifier += 1
            return nextRequestIdentifier
        }
    }

    private func collectionMoviePayload(id: Int, title: String, status: Int) -> [String: Any] {
        [
            "id": id,
            "mediaType": "movie",
            "title": title,
            "overview": "\(title) overview",
            "releaseDate": "2024-01-01",
            "mediaInfo": [
                "id": id,
                "tmdbId": id,
                "status": status
            ]
        ]
    }

    private func watchlistItemPayload(
        id: Int,
        tmdbId: Int,
        mediaType: String,
        title: String,
        year: String,
        overview: String
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "id": id,
            "tmdbId": tmdbId,
            "mediaType": mediaType,
            "overview": overview,
            "mediaInfo": [
                "id": id,
                "tmdbId": tmdbId,
                "status": 1,
                "watchlisted": true
            ]
        ]

        if mediaType == "movie" {
            payload["title"] = title
            payload["releaseDate"] = year
        } else {
            payload["name"] = title
            payload["firstAirDate"] = year
        }

        return payload
    }

    private func requestPayload(
        id: Int,
        status: Int,
        tmdbId: Int,
        tvdbId: Int?,
        requesterName: String
    ) -> [String: Any] {
        [
            "id": id,
            "status": status,
            "media": [
                "id": id,
                "tmdbId": tmdbId,
                "tvdbId": tvdbId,
                "status": status
            ],
            "createdAt": "2026-04-09T00:00:00.000Z",
            "requestedBy": [
                "id": id,
                "username": requesterName
            ]
        ]
    }
}

// MARK: - NSLock Helper

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

#endif
