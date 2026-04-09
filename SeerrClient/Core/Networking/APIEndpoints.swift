// APIEndpoints.swift
// SeerrClient
//
// Single source of truth for every API endpoint path used in the app.
// Repositories and ViewModels NEVER hardcode path strings — they always call
// into this struct. This makes version upgrades and auditing trivial.

import Foundation

// MARK: - APIVersion

/// The API version prefix injected into every endpoint path.
///
/// Add `case v2 = "/api/v2"` here when Seerr ships a v2 API; then flip the
/// default on `APIEndpoints.init(version:)`.
public enum APIVersion: String, Sendable {
    case v1 = "/api/v1"
    // case v2 = "/api/v2"  // future
}

// MARK: - APIEndpoints

/// Computed path strings for every Seerr API endpoint.
///
/// Instantiate once per server (or share a global one since all servers use the
/// same path structure):
/// ```swift
/// let endpoints = APIEndpoints()
/// let path = endpoints.authMe           // "/api/v1/auth/me"
/// let path2 = endpoints.movie(id: 603)  // "/api/v1/movie/603"
/// ```
///
/// The `SeerrAPIClient` appends these paths to `baseURL`:
/// `"http://192.168.1.50:5055" + "/api/v1/search"  →  full URL`
public struct APIEndpoints: Sendable {

    // MARK: - Properties

    /// The API version prefix. Defaults to `.v1`.
    public let version: APIVersion

    // MARK: - Init

    /// Creates an `APIEndpoints` instance for the given API version.
    ///
    /// - Parameter version: The target API version. Defaults to `.v1`.
    public init(version: APIVersion = .v1) {
        self.version = version
    }

    // MARK: - Base

    private var base: String { version.rawValue }

    // MARK: - Public (no auth required)

    /// `GET /api/v1/status` — Server version, update info.
    public var status: String { "\(base)/status" }

    /// `GET /api/v1/status/appdata` — App data directory path.
    public var statusAppdata: String { "\(base)/status/appdata" }

    /// `GET /api/v1/settings/public` — Public settings (app name, login methods available).
    public var settingsPublic: String { "\(base)/settings/public" }

    // MARK: - Authentication

    /// `GET /api/v1/auth/me` — Fetch current authenticated user.
    public var authMe: String { "\(base)/auth/me" }

    /// `POST /api/v1/auth/local` — Local email/password sign-in.
    public var authLocal: String { "\(base)/auth/local" }

    /// `POST /api/v1/auth/plex` — Plex OAuth sign-in.
    public var authPlex: String { "\(base)/auth/plex" }

    /// `POST /api/v1/auth/jellyfin` — Jellyfin/Emby sign-in.
    public var authJellyfin: String { "\(base)/auth/jellyfin" }

    /// `POST /api/v1/auth/logout` — Destroy the current session.
    public var authLogout: String { "\(base)/auth/logout" }

    /// `POST /api/v1/auth/reset-password` — Initiate a password reset email.
    public var authResetPassword: String { "\(base)/auth/reset-password" }

    /// `POST /api/v1/auth/reset-password/{guid}` — Complete a password reset.
    ///
    /// - Parameter guid: The reset token from the password-reset email.
    public func authResetPasswordComplete(guid: String) -> String {
        "\(base)/auth/reset-password/\(guid)"
    }

    // MARK: - Search

    /// `GET /api/v1/search` — Multi-search (movies, TV, people).
    /// Supports prefixes `tmdb:`, `imdb:`, `tvdb:` in the `query` param.
    public var search: String { "\(base)/search" }

    /// `GET /api/v1/search/movie` — Search movies only.
    public var searchMovie: String { "\(base)/search/movie" }

    /// `GET /api/v1/search/tv` — Search TV shows only.
    public var searchTv: String { "\(base)/search/tv" }

    /// `GET /api/v1/search/person` — Search people only.
    public var searchPerson: String { "\(base)/search/person" }

    // MARK: - Requests

    /// `GET /api/v1/request` — List all media requests.
    /// `POST /api/v1/request` — Create a new media request.
    public var request: String { "\(base)/request" }

    /// `GET /api/v1/request/count` — Request counts by status.
    public var requestCount: String { "\(base)/request/count" }

    /// `GET/PUT/DELETE /api/v1/request/{id}` — Get, update, or delete a specific request.
    ///
    /// - Parameter id: The Seerr request identifier.
    public func request(id: Int) -> String { "\(base)/request/\(id)" }

    /// `POST /api/v1/request/{id}/approve` — Approve a request.
    ///
    /// - Parameter id: The Seerr request identifier.
    public func requestApprove(id: Int) -> String { "\(base)/request/\(id)/approve" }

    /// `POST /api/v1/request/{id}/decline` — Decline a request.
    ///
    /// - Parameter id: The Seerr request identifier.
    public func requestDecline(id: Int) -> String { "\(base)/request/\(id)/decline" }

    /// Generic request action endpoint builder.
    ///
    /// - Parameters:
    ///   - id: The Seerr request identifier.
    ///   - action: The action string (e.g. `"approve"`, `"decline"`).
    public func requestAction(id: Int, action: String) -> String {
        "\(base)/request/\(id)/\(action)"
    }

    // MARK: - Media

    /// `GET /api/v1/media` — List all media items.
    public var media: String { "\(base)/media" }

    /// `GET/PUT/DELETE /api/v1/media/{id}` — Get, update, or delete a media item.
    ///
    /// - Parameter id: The Seerr media record identifier.
    public func media(id: Int) -> String { "\(base)/media/\(id)" }

    // MARK: - Watchlist

    /// `POST /api/v1/watchlist` — Add an item to the current user's watchlist.
    ///
    /// Expects a JSON body with `mediaType` ("movie" or "tv") and `tmdbId`.
    /// Returns 201 on success, 409 if the item is already on the watchlist.
    public var watchlist: String { "\(base)/watchlist" }

    /// `DELETE /api/v1/watchlist/{tmdbId}` — Remove an item from the current user's watchlist.
    ///
    /// Pass `mediaType` as a query parameter ("movie" or "tv").
    /// Returns 204 on success, 404 if the item was not on the watchlist.
    ///
    /// - Parameter tmdbId: The TMDB ID of the item to remove.
    public func watchlistItem(tmdbId: Int) -> String { "\(base)/watchlist/\(tmdbId)" }

    // MARK: - Movies

    /// `GET /api/v1/movie/{movieId}` — Movie details (from TMDB via Seerr proxy).
    ///
    /// - Parameter id: The TMDB movie identifier.
    public func movie(id: Int) -> String { "\(base)/movie/\(id)" }

    /// `GET /api/v1/movie/{movieId}/recommendations` — Movie recommendations.
    ///
    /// - Parameter id: The TMDB movie identifier.
    public func movieRecommendations(id: Int) -> String { "\(base)/movie/\(id)/recommendations" }

    /// `GET /api/v1/movie/{movieId}/similar` — Similar movies.
    ///
    /// - Parameter id: The TMDB movie identifier.
    public func movieSimilar(id: Int) -> String { "\(base)/movie/\(id)/similar" }

    // MARK: - TV Shows

    /// `GET /api/v1/tv/{tvId}` — TV show details.
    ///
    /// - Parameter id: The TMDB series identifier.
    public func tv(id: Int) -> String { "\(base)/tv/\(id)" }

    /// `GET /api/v1/tv/{tvId}/season/{seasonNumber}` — Season details.
    ///
    /// - Parameters:
    ///   - tvId: The TMDB series identifier.
    ///   - season: The season number (0 = specials).
    public func season(tvId: Int, season: Int) -> String {
        "\(base)/tv/\(tvId)/season/\(season)"
    }

    /// `GET /api/v1/tv/{tvId}/recommendations` — TV recommendations.
    ///
    /// - Parameter id: The TMDB series identifier.
    public func tvRecommendations(id: Int) -> String { "\(base)/tv/\(id)/recommendations" }

    /// `GET /api/v1/tv/{tvId}/similar` — Similar TV shows.
    ///
    /// - Parameter id: The TMDB series identifier.
    public func tvSimilar(id: Int) -> String { "\(base)/tv/\(id)/similar" }

    // MARK: - Discover

    /// `GET /api/v1/settings/discover` — Get discover sliders configuration.
    /// `POST /api/v1/settings/discover` — Create a discover slider.
    public var settingsDiscover: String { "\(base)/settings/discover" }

    /// `POST /api/v1/settings/discover/add` — Add a slider.
    public var settingsDiscoverAdd: String { "\(base)/settings/discover/add" }

    /// `PUT/DELETE /api/v1/settings/discover/{sliderId}` — Update or delete a slider.
    ///
    /// - Parameter id: The discover slider identifier.
    public func settingsDiscoverSlider(id: Int) -> String {
        "\(base)/settings/discover/\(id)"
    }

    /// `GET /api/v1/settings/discover/reset` — Reset discover sliders to defaults.
    public var settingsDiscoverReset: String { "\(base)/settings/discover/reset" }

    // MARK: - Discover Content

    /// `GET /api/v1/discover/trending` — Trending movies and TV shows.
    public var discoverTrending: String { "\(base)/discover/trending" }

    /// `GET /api/v1/discover/movies` — Discover movies with filters.
    public var discoverMovies: String { "\(base)/discover/movies" }

    /// `GET /api/v1/discover/movies/upcoming` — Upcoming movies.
    public var discoverMoviesUpcoming: String { "\(base)/discover/movies/upcoming" }

    /// `GET /api/v1/discover/movies/genre/{genreId}` — Movies by genre.
    public func discoverMoviesByGenre(id: Int) -> String { "\(base)/discover/movies/genre/\(id)" }

    /// `GET /api/v1/discover/movies/language/{lang}` — Movies by language.
    public func discoverMoviesByLanguage(_ lang: String) -> String { "\(base)/discover/movies/language/\(lang)" }

    /// `GET /api/v1/discover/movies/studio/{studioId}` — Movies by studio.
    public func discoverMoviesByStudio(id: Int) -> String { "\(base)/discover/movies/studio/\(id)" }

    /// `GET /api/v1/discover/tv` — Discover TV shows with filters.
    public var discoverTv: String { "\(base)/discover/tv" }

    /// `GET /api/v1/discover/tv/upcoming` — Upcoming TV shows.
    public var discoverTvUpcoming: String { "\(base)/discover/tv/upcoming" }

    /// `GET /api/v1/discover/tv/genre/{genreId}` — TV shows by genre.
    public func discoverTvByGenre(id: Int) -> String { "\(base)/discover/tv/genre/\(id)" }

    /// `GET /api/v1/discover/tv/language/{lang}` — TV shows by language.
    public func discoverTvByLanguage(_ lang: String) -> String { "\(base)/discover/tv/language/\(lang)" }

    /// `GET /api/v1/discover/tv/network/{networkId}` — TV shows by network.
    public func discoverTvByNetwork(id: Int) -> String { "\(base)/discover/tv/network/\(id)" }

    /// `GET /api/v1/discover/keyword/{keywordId}/movies` — Movies by keyword.
    public func discoverMoviesByKeyword(id: Int) -> String { "\(base)/discover/keyword/\(id)/movies" }

    /// `GET /api/v1/discover/keyword/{keywordId}/tv` — TV shows by keyword.
    public func discoverTvByKeyword(id: Int) -> String { "\(base)/discover/keyword/\(id)/tv" }

    /// `GET /api/v1/discover/genreslider/movie` — Genre slider data for movies.
    public var discoverGenreSliderMovie: String { "\(base)/discover/genreslider/movie" }

    /// `GET /api/v1/discover/genreslider/tv` — Genre slider data for TV.
    public var discoverGenreSliderTv: String { "\(base)/discover/genreslider/tv" }

    /// `GET /api/v1/discover/watchlist` — Plex watchlist.
    public var discoverWatchlist: String { "\(base)/discover/watchlist" }

    // MARK: - Users

    /// `GET /api/v1/user` — List all users.
    /// `POST /api/v1/user` — Create a user.
    /// `PUT /api/v1/user` — Update current user.
    public var user: String { "\(base)/user" }

    /// `GET/PUT/DELETE /api/v1/user/{userId}` — Get, update, or delete a user by ID.
    ///
    /// - Parameter id: The Seerr user identifier.
    public func user(id: Int) -> String { "\(base)/user/\(id)" }

    /// `GET /api/v1/user/{userId}/requests` — Requests made by a specific user.
    ///
    /// - Parameter id: The Seerr user identifier.
    public func userRequests(id: Int) -> String { "\(base)/user/\(id)/requests" }

    /// `POST /api/v1/user/import-from-plex` — Bulk import Plex users.
    public var userImportFromPlex: String { "\(base)/user/import-from-plex" }

    /// `POST /api/v1/user/registerPushSubscription` — Register a web push subscription.
    public var userRegisterPushSubscription: String {
        "\(base)/user/registerPushSubscription"
    }

    /// `GET /api/v1/user/{userId}/pushSubscriptions` — Get push subscriptions for a user.
    ///
    /// - Parameter id: The Seerr user identifier.
    public func userPushSubscriptions(id: Int) -> String {
        "\(base)/user/\(id)/pushSubscriptions"
    }

    /// `DELETE /api/v1/user/{userId}/pushSubscription/{endpoint}` — Remove a push subscription.
    ///
    /// - Parameters:
    ///   - userId: The Seerr user identifier.
    ///   - endpoint: The push endpoint URL-encoded string.
    public func userPushSubscription(userId: Int, endpoint: String) -> String {
        "\(base)/user/\(userId)/pushSubscription/\(endpoint)"
    }

    // MARK: - Person

    /// `GET /api/v1/person/{personId}` — Person details.
    ///
    /// - Parameter id: The TMDB person identifier.
    public func person(id: Int) -> String { "\(base)/person/\(id)" }

    /// `GET /api/v1/person/{personId}/credits` — Person's combined movie/TV credits.
    ///
    /// - Parameter id: The TMDB person identifier.
    public func personCredits(id: Int) -> String { "\(base)/person/\(id)/credits" }

    // MARK: - Collection

    /// `GET /api/v1/collection/{collectionId}` — TMDB collection details.
    ///
    /// - Parameter id: The TMDB collection identifier.
    public func collection(id: Int) -> String { "\(base)/collection/\(id)" }

    // MARK: - Issues

    /// `GET /api/v1/issues` — List all issues.
    /// `POST /api/v1/issues` — Create an issue.
    public var issues: String { "\(base)/issues" }

    /// `GET/PUT/DELETE /api/v1/issues/{issueId}` — Get, update, or delete an issue.
    ///
    /// - Parameter id: The Seerr issue identifier.
    public func issue(id: Int) -> String { "\(base)/issues/\(id)" }

    /// `POST /api/v1/issues/{issueId}/comments` — Add a comment to an issue.
    ///
    /// - Parameter id: The Seerr issue identifier.
    public func issueComments(id: Int) -> String { "\(base)/issues/\(id)/comments" }

    // MARK: - Services

    /// `GET /api/v1/service` — Service details.
    public var service: String { "\(base)/service" }

    /// `GET /api/v1/service/radarr` — Radarr instances visible to the current user.
    public var serviceRadarr: String { "\(base)/service/radarr" }

    /// `GET /api/v1/service/radarr/{radarrId}` — Quality profiles and root folders for a Radarr instance.
    ///
    /// - Parameter id: The Radarr instance identifier.
    public func serviceRadarr(id: Int) -> String { "\(base)/service/radarr/\(id)" }

    /// `GET /api/v1/service/sonarr` — Sonarr instances visible to the current user.
    public var serviceSonarr: String { "\(base)/service/sonarr" }

    /// `GET /api/v1/service/sonarr/{sonarrId}` — Quality profiles and root folders for a Sonarr instance.
    ///
    /// - Parameter id: The Sonarr instance identifier.
    public func serviceSonarr(id: Int) -> String { "\(base)/service/sonarr/\(id)" }

    // MARK: - Reference Data

    /// `GET /api/v1/watch-providers/regions` — Watch provider regions.
    public var watchProviderRegions: String { "\(base)/watch-providers/regions" }

    /// `GET /api/v1/watch-providers` — Available watch providers.
    public var watchProviders: String { "\(base)/watch-providers" }

    /// `GET /api/v1/languages` — Available languages.
    public var languages: String { "\(base)/languages" }

    /// `GET /api/v1/genres` — Available genres.
    public var genres: String { "\(base)/genres" }

    /// `GET /api/v1/keywords` — Keywords.
    public var keywords: String { "\(base)/keywords" }

    // MARK: - Settings (Admin)

    /// `GET/POST /api/v1/settings/main` — Main application settings.
    public var settingsMain: String { "\(base)/settings/main" }

    /// `POST /api/v1/settings/main/regenerate` — Regenerate the server API key.
    public var settingsMainRegenerate: String { "\(base)/settings/main/regenerate" }

    /// `GET/POST /api/v1/settings/plex` — Plex integration configuration.
    public var settingsPlex: String { "\(base)/settings/plex" }

    /// `GET /api/v1/settings/plex/library` — Plex libraries.
    public var settingsPlexLibrary: String { "\(base)/settings/plex/library" }

    /// `GET/POST /api/v1/settings/plex/sync` — Plex library sync.
    public var settingsPlexSync: String { "\(base)/settings/plex/sync" }

    /// `GET /api/v1/settings/plex/devices/servers` — Available Plex media servers.
    public var settingsPlexDevicesServers: String {
        "\(base)/settings/plex/devices/servers"
    }

    /// `GET /api/v1/settings/plex/users` — Plex users.
    public var settingsPlexUsers: String { "\(base)/settings/plex/users" }

    /// `GET/POST /api/v1/settings/tautulli` — Tautulli integration.
    public var settingsTautulli: String { "\(base)/settings/tautulli" }

    /// `GET/POST /api/v1/settings/radarr` — Radarr servers list.
    public var settingsRadarr: String { "\(base)/settings/radarr" }

    /// `POST /api/v1/settings/radarr/test` — Test a Radarr connection.
    public var settingsRadarrTest: String { "\(base)/settings/radarr/test" }

    /// `PUT/DELETE /api/v1/settings/radarr/{id}` — Manage a Radarr instance.
    ///
    /// - Parameter id: The Radarr instance identifier.
    public func settingsRadarr(id: Int) -> String { "\(base)/settings/radarr/\(id)" }

    /// `GET /api/v1/settings/radarr/{id}/profiles` — Quality profiles for a Radarr instance.
    ///
    /// - Parameter id: The Radarr instance identifier.
    public func settingsRadarrProfiles(id: Int) -> String {
        "\(base)/settings/radarr/\(id)/profiles"
    }

    /// `GET /api/v1/settings/sonarr/{id}/profiles` — Quality profiles for a Sonarr instance.
    ///
    /// - Parameter id: The Sonarr instance identifier.
    public func settingsSonarrProfiles(id: Int) -> String {
        "\(base)/settings/sonarr/\(id)/profiles"
    }

    /// `GET/POST /api/v1/settings/sonarr` — Sonarr servers list.
    public var settingsSonarr: String { "\(base)/settings/sonarr" }

    /// `POST /api/v1/settings/sonarr/test` — Test a Sonarr connection.
    public var settingsSonarrTest: String { "\(base)/settings/sonarr/test" }

    /// `PUT/DELETE /api/v1/settings/sonarr/{id}` — Manage a Sonarr instance.
    ///
    /// - Parameter id: The Sonarr instance identifier.
    public func settingsSonarr(id: Int) -> String { "\(base)/settings/sonarr/\(id)" }

    /// `POST /api/v1/settings/initialize` — First-time setup wizard completion.
    public var settingsInitialize: String { "\(base)/settings/initialize" }

    /// `GET /api/v1/settings/jobs` — Background job list.
    public var settingsJobs: String { "\(base)/settings/jobs" }

    /// `POST /api/v1/settings/jobs/{jobId}/run` — Immediately run a background job.
    ///
    /// - Parameter jobId: The machine-readable job identifier.
    public func settingsJobRun(jobId: String) -> String {
        "\(base)/settings/jobs/\(jobId)/run"
    }

    /// `POST /api/v1/settings/jobs/{jobId}/cancel` — Cancel a running job.
    ///
    /// - Parameter jobId: The machine-readable job identifier.
    public func settingsJobCancel(jobId: String) -> String {
        "\(base)/settings/jobs/\(jobId)/cancel"
    }

    /// `POST /api/v1/settings/jobs/{jobId}/schedule` — Update a job's schedule.
    ///
    /// - Parameter jobId: The machine-readable job identifier.
    public func settingsJobSchedule(jobId: String) -> String {
        "\(base)/settings/jobs/\(jobId)/schedule"
    }

    /// `GET /api/v1/settings/cache` — Cache usage info.
    public var settingsCache: String { "\(base)/settings/cache" }

    /// `POST /api/v1/settings/cache/{cacheId}/flush` — Flush a named cache.
    ///
    /// - Parameter cacheId: The cache identifier (e.g. `"tmdb"`, `"overseerr"`).
    public func settingsCacheFlush(cacheId: String) -> String {
        "\(base)/settings/cache/\(cacheId)/flush"
    }

    /// `GET /api/v1/settings/logs` — Application log entries.
    public var settingsLogs: String { "\(base)/settings/logs" }

    /// `GET /api/v1/settings/about` — About / version info.
    public var settingsAbout: String { "\(base)/settings/about" }

    // MARK: - Notification Settings (Admin)

    /// `GET/POST /api/v1/settings/notifications/email`
    public var notificationsEmail: String {
        "\(base)/settings/notifications/email"
    }

    /// `POST /api/v1/settings/notifications/email/test`
    public var notificationsEmailTest: String {
        "\(base)/settings/notifications/email/test"
    }

    /// `GET/POST /api/v1/settings/notifications/discord`
    public var notificationsDiscord: String {
        "\(base)/settings/notifications/discord"
    }

    /// `POST /api/v1/settings/notifications/discord/test`
    public var notificationsDiscordTest: String {
        "\(base)/settings/notifications/discord/test"
    }

    /// `GET/POST /api/v1/settings/notifications/lunasea`
    public var notificationsLunaSea: String {
        "\(base)/settings/notifications/lunasea"
    }

    /// `POST /api/v1/settings/notifications/lunasea/test`
    public var notificationsLunaSeaTest: String {
        "\(base)/settings/notifications/lunasea/test"
    }

    /// `GET/POST /api/v1/settings/notifications/pushbullet`
    public var notificationsPushbullet: String {
        "\(base)/settings/notifications/pushbullet"
    }

    /// `POST /api/v1/settings/notifications/pushbullet/test`
    public var notificationsPushbulletTest: String {
        "\(base)/settings/notifications/pushbullet/test"
    }

    /// `GET/POST /api/v1/settings/notifications/pushover`
    public var notificationsPushover: String {
        "\(base)/settings/notifications/pushover"
    }

    /// `POST /api/v1/settings/notifications/pushover/test`
    public var notificationsPushoverTest: String {
        "\(base)/settings/notifications/pushover/test"
    }

    /// `GET /api/v1/settings/notifications/pushover/sounds`
    public var notificationsPushoverSounds: String {
        "\(base)/settings/notifications/pushover/sounds"
    }

    /// `GET/POST /api/v1/settings/notifications/gotify`
    public var notificationsGotify: String {
        "\(base)/settings/notifications/gotify"
    }

    /// `POST /api/v1/settings/notifications/gotify/test`
    public var notificationsGotifyTest: String {
        "\(base)/settings/notifications/gotify/test"
    }

    /// `GET/POST /api/v1/settings/notifications/slack`
    public var notificationsSlack: String {
        "\(base)/settings/notifications/slack"
    }

    /// `POST /api/v1/settings/notifications/slack/test`
    public var notificationsSlackTest: String {
        "\(base)/settings/notifications/slack/test"
    }

    /// `GET/POST /api/v1/settings/notifications/telegram`
    public var notificationsTelegram: String {
        "\(base)/settings/notifications/telegram"
    }

    /// `POST /api/v1/settings/notifications/telegram/test`
    public var notificationsTelegramTest: String {
        "\(base)/settings/notifications/telegram/test"
    }

    /// `GET/POST /api/v1/settings/notifications/webpush`
    public var notificationsWebPush: String {
        "\(base)/settings/notifications/webpush"
    }

    /// `POST /api/v1/settings/notifications/webpush/test`
    public var notificationsWebPushTest: String {
        "\(base)/settings/notifications/webpush/test"
    }

    /// `GET/POST /api/v1/settings/notifications/webhook`
    public var notificationsWebhook: String {
        "\(base)/settings/notifications/webhook"
    }

    /// `POST /api/v1/settings/notifications/webhook/test`
    public var notificationsWebhookTest: String {
        "\(base)/settings/notifications/webhook/test"
    }
}

// MARK: - Shared Default Instance

/// A shared default `APIEndpoints` instance for v1, usable as a convenience
/// when you don't need to configure the version dynamically.
///
/// ```swift
/// let path = APIEndpoints.v1.search
/// ```
public extension APIEndpoints {
    static let v1 = APIEndpoints(version: .v1)
}
