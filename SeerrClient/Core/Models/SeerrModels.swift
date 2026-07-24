// SeerrModels.swift
// SeerrClient
//
// API response models auto-generated from the Overseerr OpenAPI specification.
// All types conform to Codable, Sendable, and Hashable for use with
// SwiftUI, async/await, and Set/Dictionary keying.
//
// SOURCE: Shared/models/SeerrModels.swift — copied verbatim; do not hand-edit.
// Regenerate by running the model-gen script when the API spec is updated.

import Foundation

// MARK: - Server & Public Settings

/// Current status of the Overseerr/Jellyseerr server.
public struct ServerStatus: Codable, Sendable, Hashable {
    /// Application version string.
    public let version: String
    /// Short git commit hash.
    public let commitTag: String?
    /// Whether a newer version is available.
    public let updateAvailable: Bool?
    /// Number of commits behind the latest release.
    public let commitsBehind: Int?
    /// Whether the server needs a restart to apply pending changes.
    public let restartRequired: Bool?
}

/// Public settings returned by `/settings/public`. No authentication required.
public struct PublicSettings: Codable, Sendable, Hashable {
    /// Whether the server has been initialized through the setup wizard.
    public let initialized: Bool?
}

/// Full main settings. Requires admin authentication.
public struct MainSettings: Codable, Sendable, Hashable {
    /// The server API key (read-only).
    public let apiKey: String?
    /// Application UI language code (e.g. `"en"`).
    public let appLanguage: String?
    /// Display title shown in the web UI (e.g. `"Overseerr"`).
    public let applicationTitle: String?
    /// Public-facing URL for the application (e.g. `"https://os.example.com"`).
    public let applicationUrl: String?
    /// Whether the server trusts reverse-proxy `X-Forwarded-For` headers.
    public let trustProxy: Bool?
    /// Whether CSRF protection is enabled.
    public let csrfProtection: Bool?
    /// Whether already-available media is hidden from search/discover results.
    public let hideAvailable: Bool?
    /// Whether partial (season-subset) TV requests are allowed.
    public let partialRequestsEnabled: Bool?
    /// Whether local email/password login is enabled.
    public let localLogin: Bool?
    /// Whether new Plex OAuth login flow is enabled.
    public let newPlexLogin: Bool?
    /// Default permission bitmask assigned to new users.
    public let defaultPermissions: Int?
}

/// A Plex library entry.
public struct PlexLibrary: Codable, Sendable, Hashable {
    /// Plex library identifier.
    public let id: String
    /// Human-readable library name (e.g. `"Movies"`).
    public let name: String
    /// Whether this library is enabled for scanning.
    public let enabled: Bool
}

/// Plex server configuration.
public struct PlexSettings: Codable, Sendable, Hashable {
    /// Friendly server name (read-only).
    public let name: String
    /// Plex machine identifier (read-only).
    public let machineId: String
    /// IP address or hostname of the Plex server.
    public let ip: String
    /// Port used to connect to Plex.
    public let port: Int
    /// Whether SSL is used to connect.
    public let useSsl: Bool?
    /// List of known Plex libraries (read-only).
    public let libraries: [PlexLibrary]?
    /// URL to the Plex web app (e.g. `"https://app.plex.tv/desktop"`).
    public let webAppUrl: String?
}

/// Radarr service configuration.
public struct RadarrSettings: Codable, Sendable, Hashable {
    /// Unique identifier assigned by Overseerr (read-only).
    public let id: Int?
    /// Human-readable name for this Radarr instance.
    public let name: String
    /// Hostname or IP of the Radarr server.
    public let hostname: String
    /// Port Radarr is listening on.
    public let port: Int
    /// Radarr API key.
    public let apiKey: String
    /// Whether SSL is used.
    public let useSsl: Bool
    /// Optional URL base path (if Radarr is behind a reverse proxy sub-path).
    public let baseUrl: String?
    /// Active quality profile identifier.
    public let activeProfileId: Int
    /// Active quality profile display name.
    public let activeProfileName: String
    /// Root folder path for downloads.
    public let activeDirectory: String
    /// Whether this instance handles 4K content.
    public let is4k: Bool
    /// Minimum availability setting (e.g. `"In Cinema"`).
    public let minimumAvailability: String
    /// Whether this is the default Radarr instance.
    public let isDefault: Bool
    /// Publicly accessible URL for linking (optional).
    public let externalUrl: String?
    /// Whether automatic library sync is enabled.
    public let syncEnabled: Bool?
    /// Whether automatic search is suppressed when adding media.
    public let preventSearch: Bool?
}

/// Sonarr service configuration.
public struct SonarrSettings: Codable, Sendable, Hashable {
    /// Unique identifier assigned by Overseerr (read-only).
    public let id: Int?
    /// Human-readable name for this Sonarr instance.
    public let name: String
    /// Hostname or IP of the Sonarr server.
    public let hostname: String
    /// Port Sonarr is listening on.
    public let port: Int
    /// Sonarr API key.
    public let apiKey: String
    /// Whether SSL is used.
    public let useSsl: Bool
    /// Optional URL base path.
    public let baseUrl: String?
    /// Active quality profile identifier.
    public let activeProfileId: Int
    /// Active quality profile display name.
    public let activeProfileName: String
    /// Root folder path for TV series downloads.
    public let activeDirectory: String
    /// Active language profile identifier.
    public let activeLanguageProfileId: Int?
    /// Quality profile identifier used for anime.
    public let activeAnimeProfileId: Int?
    /// Language profile identifier used for anime.
    public let activeAnimeLanguageProfileId: Int?
    /// Anime quality profile name.
    public let activeAnimeProfileName: String?
    /// Root folder for anime downloads.
    public let activeAnimeDirectory: String?
    /// Whether this instance handles 4K content.
    public let is4k: Bool
    /// Whether season folders are created automatically. Optional to handle Jellyseerr versions
    /// that omit or null this field in the response.
    public let enableSeasonFolders: Bool?
    /// Whether this is the default Sonarr instance.
    public let isDefault: Bool
    /// Publicly accessible URL for linking.
    public let externalUrl: String?
    /// Whether automatic library sync is enabled.
    public let syncEnabled: Bool?
    /// Whether automatic search is suppressed when adding media.
    public let preventSearch: Bool?
}

/// A tag used in Radarr or Sonarr.
public struct ServarrTag: Codable, Sendable, Hashable {
    public let id: Int?
    public let label: String?
}

// MARK: - Authentication

/// User type discriminator bitmask values as returned by the API.
/// 1 = Plex, 2 = Local, 3 = Jellyfin
public typealias UserType = Int

// MARK: - User

/// A user account registered in Overseerr.
public struct User: Codable, Sendable, Hashable {
    /// Unique user identifier.
    public let id: Int
    /// User email address. Optional — Plex-imported users may not have one.
    public let email: String?
    /// Human-readable display name returned by the Jellyseerr API (e.g. "macmedia").
    /// Present for all user types — prefer this over username/plexUsername for display.
    public let displayName: String?
    /// Optional display username.
    public let username: String?
    /// Plex authentication token (read-only, sensitive).
    public let plexToken: String?
    /// Username as known to Plex (read-only).
    public let plexUsername: String?
    /// User type: 1 = Plex, 2 = Local, 3 = Jellyfin (read-only).
    public let userType: Int?
    /// Bitmask of user permissions.
    public let permissions: Int?
    /// URL path to user avatar image (read-only).
    public let avatar: String?
    /// ISO 8601 timestamp when the account was created (read-only).
    public let createdAt: String?
    /// ISO 8601 timestamp of the last profile update (read-only).
    public let updatedAt: String?
    /// Total number of requests made by this user (read-only).
    public let requestCount: Int?
}

/// Per-user locale and language preferences.
public struct UserSettings: Codable, Sendable, Hashable {
    /// BCP 47 locale code (e.g. `"en"`).
    public let locale: String?
    /// ISO 3166-1 alpha-2 region code (e.g. `"US"`).
    public let region: String?
    /// ISO 639-1 original language filter code.
    public let originalLanguage: String?
}

/// Per-user notification preferences.
public struct UserSettingsNotifications: Codable, Sendable, Hashable {
    /// Per-agent notification type bitmasks.
    public let notificationTypes: NotificationAgentTypes?
    /// Whether email notifications are enabled for this user.
    public let emailEnabled: Bool?
    /// PGP key for encrypted email notifications.
    public let pgpKey: String?
    /// Whether Discord notifications are enabled for this user.
    public let discordEnabled: Bool?
    /// Discord notification type bitmask override.
    public let discordEnabledTypes: Int?
    /// Discord user or channel snowflake ID.
    public let discordId: String?
    /// Pushbullet access token.
    public let pushbulletAccessToken: String?
    /// Pushover application token.
    public let pushoverApplicationToken: String?
    /// Pushover user/group key.
    public let pushoverUserKey: String?
    /// Pushover notification sound name.
    public let pushoverSound: String?
    /// Whether Telegram notifications are enabled for this user.
    public let telegramEnabled: Bool?
    /// Telegram bot username.
    public let telegramBotUsername: String?
    /// Telegram chat identifier.
    public let telegramChatId: String?
    /// Whether Telegram messages are sent silently (no notification sound).
    public let telegramSendSilently: Bool?
}

// MARK: - Media (Movie, TV, Season, Episode)

/// A genre tag from TMDB.
public struct Genre: Codable, Sendable, Hashable {
    /// TMDB genre identifier.
    public let id: Int?
    /// Genre name (e.g. `"Adventure"`).
    public let name: String?
}

/// A production company associated with a movie or TV series.
public struct ProductionCompany: Codable, Sendable, Hashable {
    /// TMDB company identifier.
    public let id: Int?
    /// Relative path to the company logo image on TMDB.
    public let logoPath: String?
    /// ISO 3166-1 alpha-2 country code where the company is based.
    public let originCountry: String?
    /// Company display name.
    public let name: String?
}

/// A broadcast network associated with a TV series.
public struct Network: Codable, Sendable, Hashable {
    /// TMDB network identifier.
    public let id: Int?
    /// Relative path to the network logo image on TMDB.
    public let logoPath: String?
    /// ISO 3166-1 alpha-2 country of origin.
    public let originCountry: String?
    /// Network display name.
    public let name: String?
}

/// A spoken language entry on a TMDB title.
public struct SpokenLanguage: Codable, Sendable, Hashable {
    /// English name of the language.
    public let englishName: String?
    /// ISO 639-1 language code.
    public let iso639_1: String?
    /// Native-script name of the language.
    public let name: String?

    private enum CodingKeys: String, CodingKey {
        case englishName
        case iso639_1 = "iso_639_1"
        case name
    }
}

/// A production country entry on a TMDB title.
public struct ProductionCountry: Codable, Sendable, Hashable {
    /// ISO 3166-1 alpha-2 country code.
    public let iso31661: String?
    /// Country display name.
    public let name: String?

    private enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case name
    }
}

/// A TMDB keyword tag.
public struct Keyword: Codable, Sendable, Hashable {
    /// TMDB keyword identifier.
    public let id: Int?
    /// Keyword text (e.g. `"anime"`).
    public let name: String?
}

/// External identifier links for a TMDB title.
public struct ExternalIds: Codable, Sendable, Hashable {
    public let facebookId: String?
    public let freebaseId: String?
    public let freebaseMid: String?
    public let imdbId: String?
    public let instagramId: String?
    public let tvdbId: Int?
    public let tvrageId: Int?
    public let twitterId: String?
}

/// A related video (trailer, teaser, etc.) linked from YouTube.
public struct RelatedVideo: Codable, Sendable, Hashable {
    /// Full URL to the video (e.g. `"https://www.youtube.com/watch?v=…"`).
    public let url: String?
    /// Video platform key (e.g. YouTube video ID).
    public let key: String?
    /// Human-readable video name.
    public let name: String?
    /// Video resolution in pixels (e.g. `1080`).
    public let size: Int?
    /// Category of the video.
    public let type: RelatedVideoType?
    /// Hosting platform.
    public let site: RelatedVideoSite?
}

/// Type classification for a related video.
public enum RelatedVideoType: String, Codable, Sendable, Hashable {
    case clip = "Clip"
    case teaser = "Teaser"
    case trailer = "Trailer"
    case featurette = "Featurette"
    case openingCredits = "Opening Credits"
    case behindTheScenes = "Behind the Scenes"
    case bloopers = "Bloopers"
}

/// Hosting platform for a related video.
public enum RelatedVideoSite: String, Codable, Sendable, Hashable {
    case youTube = "YouTube"
}

/// A cast member in a movie or TV credit.
public struct Cast: Codable, Sendable, Hashable {
    /// TMDB person identifier.
    public let id: Int?
    /// Cast slot identifier within the production.
    public let castId: Int?
    /// Character name portrayed.
    public let character: String?
    /// Unique credit identifier on TMDB.
    public let creditId: String?
    /// Gender code (0 = unknown, 1 = female, 2 = male, 3 = non-binary).
    public let gender: Int?
    /// Person's full name.
    public let name: String?
    /// Billing order position.
    public let order: Int?
    /// Relative path to profile photo on TMDB.
    public let profilePath: String?
}

/// A crew member in a movie or TV credit.
public struct Crew: Codable, Sendable, Hashable {
    /// TMDB person identifier.
    public let id: Int?
    /// Unique credit identifier on TMDB.
    public let creditId: String?
    /// Gender code.
    public let gender: Int?
    /// Person's full name.
    public let name: String?
    /// Job title (e.g. `"Director"`).
    public let job: String?
    /// Department (e.g. `"Directing"`).
    public let department: String?
    /// Relative path to profile photo on TMDB.
    public let profilePath: String?
}

/// Credits (cast and crew) bundled in a movie or TV detail response.
public struct Credits: Codable, Sendable, Hashable {
    public let cast: [Cast]?
    public let crew: [Crew]?
}

/// A release date / certification entry for a specific country.
public struct ReleaseDateEntry: Codable, Sendable, Hashable {
    /// Content rating certification (e.g. `"PG-13"`).
    public let certification: String?
    /// ISO 639-1 language code.
    public let iso6391: String?
    /// Optional note (e.g. `"Blu ray"`).
    public let note: String?
    /// ISO 8601 release date string.
    public let releaseDate: String?
    /// Release type code.
    public let type: Int?

    private enum CodingKeys: String, CodingKey {
        case certification
        case iso6391 = "iso_639_1"
        case note
        case releaseDate = "release_date"
        case type
    }
}

/// Country-level release information for a movie.
public struct CountryRelease: Codable, Sendable, Hashable {
    /// ISO 3166-1 alpha-2 country code.
    public let iso31661: String?
    /// Optional rating string.
    public let rating: String?
    /// List of release dates and certifications for this country.
    public let releaseDates: [ReleaseDateEntry]?

    private enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case rating
        case releaseDates = "release_dates"
    }
}

/// Releases container (wraps country-level release lists).
public struct ReleasesContainer: Codable, Sendable, Hashable {
    public let results: [CountryRelease]?
}

/// Full detail response for a movie from `/movie/{movieId}`.
public struct MovieDetails: Codable, Sendable, Hashable {
    /// TMDB movie identifier (read-only).
    public let id: Int?
    /// IMDb identifier (e.g. `"tt0123456"`).
    public let imdbId: String?
    /// Whether the movie is rated for adults only.
    public let adult: Bool?
    /// Relative path to the backdrop image on TMDB.
    public let backdropPath: String?
    /// Relative path to the poster image on TMDB.
    public let posterPath: String?
    /// Production budget in USD.
    public let budget: Int?
    /// List of genre tags.
    public let genres: [Genre]?
    /// Movie homepage URL.
    public let homepage: String?
    /// Related trailers and clips.
    public let relatedVideos: [RelatedVideo]?
    /// Original filming language code.
    public let originalLanguage: String?
    /// Original title in the filming language.
    public let originalTitle: String?
    /// Plot summary.
    public let overview: String?
    /// TMDB popularity score.
    public let popularity: Double?
    /// Production companies involved.
    public let productionCompanies: [ProductionCompany]?
    /// Countries where production took place.
    public let productionCountries: [ProductionCountry]?
    /// Theatrical release date string (ISO 8601 date).
    public let releaseDate: String?
    /// Country-level release date and certification data.
    public let releases: ReleasesContainer?
    /// Box office revenue in USD.
    public let revenue: Int?
    /// Runtime in minutes.
    public let runtime: Int?
    /// Languages spoken in the movie.
    public let spokenLanguages: [SpokenLanguage]?
    /// Production status (e.g. `"Released"`).
    public let status: String?
    /// Marketing tagline.
    public let tagline: String?
    /// Localized title.
    public let title: String?
    /// Whether the movie is a video release (direct-to-video).
    public let video: Bool?
    /// Weighted average vote score (0–10).
    public let voteAverage: Double?
    /// Total number of votes.
    public let voteCount: Int?
    /// Cast and crew credits.
    public let credits: Credits?
    /// The TMDB collection this movie belongs to (if any).
    public let collection: MovieCollection?
    /// External IDs (IMDb, TVDB, social media).
    public let externalIds: ExternalIds?
    /// Seerr-specific availability and request info.
    public let mediaInfo: MediaInfo?
    /// Watch provider information grouped by region.
    public let watchProviders: [WatchProviderRegionEntry]?
}

/// Lightweight collection reference embedded in a movie detail response.
public struct MovieCollection: Codable, Sendable, Hashable {
    public let id: Int?
    public let name: String?
    public let posterPath: String?
    public let backdropPath: String?
}

/// A TV show episode.
public struct Episode: Codable, Sendable, Hashable {
    /// TMDB episode identifier.
    public let id: Int?
    /// Episode title.
    public let name: String?
    /// Air date (ISO 8601 date or null if unaired).
    public let airDate: String?
    /// Episode number within the season.
    public let episodeNumber: Int?
    /// Plot summary for this episode.
    public let overview: String?
    /// Production code assigned by the network.
    public let productionCode: String?
    /// Season number this episode belongs to.
    public let seasonNumber: Int?
    /// TMDB series identifier of the parent show.
    public let showId: Int?
    /// Relative path to the episode still image on TMDB.
    public let stillPath: String?
    /// Weighted average vote score (0–10).
    public let voteAverage: Double?
    /// Total number of votes.
    public let voteCount: Int?
}

/// A season of a TV series.
public struct Season: Codable, Sendable, Hashable {
    /// TMDB season identifier.
    public let id: Int?
    /// First air date of the season (ISO 8601 date or null).
    public let airDate: String?
    /// Total episode count for this season.
    public let episodeCount: Int?
    /// Season title (e.g. `"Season 1"` or `"Specials"`).
    public let name: String?
    /// Overview / description of the season.
    public let overview: String?
    /// Relative path to the season poster on TMDB.
    public let posterPath: String?
    /// Ordinal season number (0 = specials).
    public let seasonNumber: Int?
    /// Episodes belonging to this season (populated in detail responses).
    public let episodes: [Episode]?
}

/// Content rating result for a specific country.
public struct ContentRatingResult: Codable, Sendable, Hashable {
    /// ISO 3166-1 alpha-2 country code.
    public let iso31661: String?
    /// Content rating string (e.g. `"TV-14"`).
    public let rating: String?

    private enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case rating
    }
}

/// Content ratings container for a TV show.
public struct ContentRatings: Codable, Sendable, Hashable {
    public let results: [ContentRatingResult]?
}

/// A creator credit on a TV show.
public struct TvCreator: Codable, Sendable, Hashable {
    public let id: Int?
    public let name: String?
    /// Gender code.
    public let gender: Int?
    /// Relative path to profile photo on TMDB.
    public let profilePath: String?
}

/// Full detail response for a TV series from `/tv/{tvId}`.
public struct TvDetails: Codable, Sendable, Hashable {
    /// TMDB series identifier.
    public let id: Int?
    /// Relative path to the backdrop image on TMDB.
    public let backdropPath: String?
    /// Relative path to the poster image on TMDB.
    public let posterPath: String?
    /// Country-level content rating information.
    public let contentRatings: ContentRatings?
    /// People who created the series.
    public let createdBy: [TvCreator]?
    /// Typical episode run times in minutes.
    public let episodeRunTime: [Int]?
    /// First air date (ISO 8601 date).
    public let firstAirDate: String?
    /// List of genre tags.
    public let genres: [Genre]?
    /// Official homepage URL.
    public let homepage: String?
    /// Whether the show is currently in production.
    public let inProduction: Bool?
    /// Languages used in the series (ISO 639-1 codes).
    public let languages: [String]?
    /// Most recent air date (ISO 8601 date).
    public let lastAirDate: String?
    /// The most recently aired episode.
    public let lastEpisodeToAir: Episode?
    /// Localised series name.
    public let name: String?
    /// The next scheduled episode to air.
    public let nextEpisodeToAir: Episode?
    /// Broadcast networks.
    public let networks: [ProductionCompany]?
    /// Total episode count across all seasons.
    public let numberOfEpisodes: Int?
    /// Total season count.
    public let numberOfSeason: Int?
    /// Countries of origin (ISO 3166-1 alpha-2).
    public let originCountry: [String]?
    /// Original filming language code.
    public let originalLanguage: String?
    /// Original title in the filming language.
    public let originalName: String?
    /// Plot summary.
    public let overview: String?
    /// TMDB popularity score.
    public let popularity: Double?
    /// Production companies involved.
    public let productionCompanies: [ProductionCompany]?
    /// Countries where production took place.
    public let productionCountries: [ProductionCountry]?
    /// Languages spoken in the show.
    public let spokenLanguages: [SpokenLanguage]?
    /// Seasons list.
    public let seasons: [Season]?
    /// Production status (e.g. `"Ended"`).
    public let status: String?
    /// Marketing tagline.
    public let tagline: String?
    /// Series type (e.g. `"Scripted"`).
    public let type: String?
    /// Weighted average vote score (0–10).
    public let voteAverage: Double?
    /// Total number of votes.
    public let voteCount: Int?
    /// Cast and crew credits.
    public let credits: Credits?
    /// External IDs (IMDb, TVDB, social media).
    public let externalIds: ExternalIds?
    /// Associated keywords.
    public let keywords: [Keyword]?
    /// Seerr-specific availability and request info.
    public let mediaInfo: MediaInfo?
    /// Watch provider information grouped by region.
    public let watchProviders: [WatchProviderRegionEntry]?
}

// MARK: - Search Results

/// Lightweight movie card returned in search and discover lists.
public struct MovieResult: Codable, Sendable, Hashable {
    /// TMDB movie identifier.
    public let id: Int
    /// Always `"movie"` for this type.
    public let mediaType: String
    /// TMDB popularity score.
    public let popularity: Double?
    /// Relative path to the poster image on TMDB.
    public let posterPath: String?
    /// Relative path to the backdrop image on TMDB.
    public let backdropPath: String?
    /// Total number of votes.
    public let voteCount: Int?
    /// Weighted average vote score (0–10).
    public let voteAverage: Double?
    /// TMDB genre identifiers.
    public let genreIds: [Int]?
    /// Plot summary.
    public let overview: String?
    /// Original filming language code.
    public let originalLanguage: String?
    /// Localised movie title.
    public let title: String
    /// Original title in the filming language.
    public let originalTitle: String?
    /// Theatrical release date (ISO 8601 date).
    public let releaseDate: String?
    /// Whether the movie is rated for adults only.
    public let adult: Bool?
    /// Whether this is a video release.
    public let video: Bool?
    /// Seerr-specific availability and request info.
    public let mediaInfo: MediaInfo?
}

/// Lightweight TV series card returned in search and discover lists.
public struct TvResult: Codable, Sendable, Hashable {
    /// TMDB series identifier.
    public let id: Int?
    /// Always `"tv"` for this type.
    public let mediaType: String?
    /// TMDB popularity score.
    public let popularity: Double?
    /// Relative path to the poster image on TMDB.
    public let posterPath: String?
    /// Relative path to the backdrop image on TMDB.
    public let backdropPath: String?
    /// Total number of votes.
    public let voteCount: Int?
    /// Weighted average vote score (0–10).
    public let voteAverage: Double?
    /// TMDB genre identifiers.
    public let genreIds: [Int]?
    /// Plot summary.
    public let overview: String?
    /// Original filming language code.
    public let originalLanguage: String?
    /// Localised series name.
    public let name: String?
    /// Original series name in the filming language.
    public let originalName: String?
    /// Countries of origin (ISO 3166-1 alpha-2).
    public let originCountry: [String]?
    /// First air date (ISO 8601 date).
    public let firstAirDate: String?
    /// Seerr-specific availability and request info.
    public let mediaInfo: MediaInfo?
}

/// A person result returned in search queries.
public struct PersonResult: Codable, Sendable, Hashable {
    /// TMDB person identifier.
    public let id: Int?
    /// Relative path to the profile photo on TMDB.
    public let profilePath: String?
    /// Whether the person has adult-content credits.
    public let adult: Bool?
    /// Always `"person"` for this type.
    public let mediaType: String?
    /// Sample of movies/shows the person is known for.
    public let knownFor: [KnownForItem]?
}

/// A union type representing either a movie or TV result in a person's known-for list.
/// Decodes `mediaType` first to determine which shape to parse.
public enum KnownForItem: Codable, Sendable, Hashable {
    case movie(MovieResult)
    case tv(TvResult)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Peek at mediaType to decide which shape to decode.
        if let movie = try? container.decode(MovieResult.self), movie.mediaType == "movie" {
            self = .movie(movie)
        } else if let tv = try? container.decode(TvResult.self) {
            self = .tv(tv)
        } else {
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "KnownForItem: unrecognised mediaType")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .movie(let m): try container.encode(m)
        case .tv(let t):    try container.encode(t)
        }
    }
}

// MARK: - Requests

/// Availability status of a media item in Seerr.
/// - 1: UNKNOWN
/// - 2: PENDING
/// - 3: PROCESSING
/// - 4: PARTIALLY_AVAILABLE
/// - 5: AVAILABLE
/// - 6: DELETED
public typealias MediaStatus = Int

/// Seerr-specific metadata attached to a TMDB media item.
public struct MediaInfo: Codable, Sendable, Hashable {
    /// Seerr internal media record identifier (read-only).
    public let id: Int?
    /// TMDB identifier for this media item (read-only).
    public let tmdbId: Int?
    /// TVDB identifier for TV series (read-only, nullable).
    public let tvdbId: Int?
    /// Availability status: 1=UNKNOWN, 2=PENDING, 3=PROCESSING, 4=PARTIALLY_AVAILABLE, 5=AVAILABLE, 6=DELETED.
    public let status: Int?
    /// Per-season availability status (TV only). Each entry tracks a season's availability on the media server.
    public let seasons: [MediaInfoSeason]?
    /// List of active or historical requests for this media item (read-only).
    public let requests: [MediaRequest]?
    /// ISO 8601 timestamp when the record was first created (read-only).
    public let createdAt: String?
    /// ISO 8601 timestamp of the last update (read-only).
    public let updatedAt: String?
    /// Whether the current user has this item on their watchlist.
    /// Present on media detail responses in Seerr 2.x and later.
    public let watchlisted: Bool?
}

/// Per-season availability status within MediaInfo.
public struct MediaInfoSeason: Codable, Sendable, Hashable {
    /// Seerr internal season record identifier.
    public let id: Int?
    /// Season number (1-based, matches TMDB).
    public let seasonNumber: Int
    /// Availability status: 1=UNKNOWN, 2=PENDING, 3=PROCESSING, 4=PARTIALLY_AVAILABLE, 5=AVAILABLE.
    public let status: Int
}

/// A media request submitted by a user.
public struct MediaRequest: Codable, Sendable, Hashable {
    /// Seerr request identifier (read-only).
    public let id: Int
    /// Request status: 1=PENDING, 2=APPROVED, 3=DECLINED (read-only).
    public let status: Int
    /// Media associated with this request.
    public let media: MediaInfo?
    /// ISO 8601 creation timestamp (read-only).
    public let createdAt: String?
    /// ISO 8601 last-update timestamp (read-only).
    public let updatedAt: String?
    /// The user who submitted the request.
    public let requestedBy: User?
    /// The user who last modified the request (admin/auto-approve).
    public let modifiedBy: User?
    /// Whether this request is for 4K quality.
    public let is4k: Bool?
    /// Radarr/Sonarr server identifier to fulfil this request.
    public let serverId: Int?
    /// Quality profile identifier.
    public let profileId: Int?
    /// Root folder path override.
    public let rootFolder: String?
    /// Season requests within this request (TV only).
    public let seasons: [SeasonRequest]?
}

/// A season within a media request, tracking approval status for that season.
public struct SeasonRequest: Codable, Sendable, Hashable {
    /// Seerr internal identifier.
    public let id: Int?
    /// Season number (1-based, matches TMDB).
    public let seasonNumber: Int
    /// Season request status: 1=PENDING, 2=APPROVED, 3=DECLINED.
    public let status: Int
}

/// Request body for creating or updating a media request.
public struct MediaRequestBody: Codable, Sendable, Hashable {
    /// Media type to request.
    public let mediaType: MediaRequestMediaType
    /// TMDB identifier of the media item.
    public let mediaId: Int
    /// TVDB identifier (required for TV requests).
    public let tvdbId: Int?
    /// For TV requests: specific season numbers, or `"all"` (represented as `nil` here; use `seasonsAll` flag).
    public let seasons: [Int]?
    /// If true, requests all seasons (sends `"all"` to the API).
    public let seasonsAll: Bool?
    /// Whether to request 4K quality.
    public let is4k: Bool?
    /// Target Radarr/Sonarr server identifier.
    public let serverId: Int?
    /// Target quality profile identifier.
    public let profileId: Int?
    /// Root folder path override.
    public let rootFolder: String?
    /// Language profile identifier (Sonarr only).
    public let languageProfileId: Int?
    /// Override to create the request on behalf of another user (admin only).
    public let userId: Int?
}

/// Media type discriminator used in requests and search results.
public enum MediaRequestMediaType: String, Codable, Sendable, Hashable {
    case movie
    case tv
}

/// Summarised request counts by status.
public struct RequestCounts: Codable, Sendable, Hashable {
    public let total: Int?
    public let movie: Int?
    public let tv: Int?
    public let pending: Int?
    public let approved: Int?
    public let declined: Int?
    public let processing: Int?
    public let available: Int?
}

// MARK: - Discover

/// A discover slider configuration entry.
public struct DiscoverSlider: Codable, Sendable, Hashable {
    /// Unique identifier.
    public let id: Int?
    /// Slider type code determining what content is shown.
    public let type: Int
    /// Optional custom title for the slider row.
    public let title: String?
    /// Whether this is a built-in (non-deletable) slider.
    public let isBuiltIn: Bool?
    /// Whether the slider is currently visible on the discover page.
    public let enabled: Bool
    /// Optional JSON configuration string for custom sliders.
    public let data: String?
}

/// Paginated response from discover content endpoints (`/discover/*`).
///
/// Unlike `PaginatedResponse` (which uses `pageInfo`), discover endpoints return
/// `page`, `totalPages`, and `totalResults` at the top level alongside `results`.
///
/// Results can be a mix of `MovieResult` and `TvResult` (trending), or homogeneous
/// (movies-only, TV-only). Use `DiscoverMediaItem` to decode the heterogeneous case.
public struct DiscoverResponse<T: Codable & Sendable & Hashable>: Codable, Sendable, Hashable {
    /// Current page number (1-based).
    public let page: Int
    /// Total number of pages available.
    public let totalPages: Int
    /// Total number of results across all pages.
    public let totalResults: Int
    /// The content items for this page.
    public let results: [T]
}

/// A media item from discover/trending that could be a movie or TV show.
///
/// Trending endpoints return a mix of `MovieResult` and `TvResult` in the same array.
/// This unified type decodes both, using `mediaType` to distinguish them.
public struct DiscoverMediaItem: Codable, Sendable, Hashable, Identifiable {
    public let id: Int
    /// The TMDB ID for this item. For Jellyfin watchlist items `id` is an internal
    /// DB row ID, while `tmdbId` holds the actual TMDB identifier needed for API
    /// calls to `/movie/{id}` and `/tv/{id}`. For Plex users the two are equal.
    public let tmdbId: Int?
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

    /// The TMDB ID to use for detail API calls and navigation.
    /// Jellyfin watchlist items carry an internal `id` and a separate `tmdbId`;
    /// when the top-level `tmdbId` is absent, prefer the nested `mediaInfo.tmdbId`
    /// (also a real TMDB id) before falling back to `id` — otherwise detail/poster
    /// enrichment fetches with the internal DB id and silently returns nothing
    /// (missing poster/year on some watchlist items). Plex items have all three equal.
    public var effectiveTmdbId: Int { tmdbId ?? mediaInfo?.tmdbId ?? id }

    /// Display title: movie `title` or TV `name`.
    public var displayTitle: String {
        title ?? name ?? "Unknown"
    }

    /// Release year extracted from `releaseDate` (movie) or `firstAirDate` (TV).
    public var year: String? {
        let dateStr = releaseDate ?? firstAirDate
        guard let dateStr, dateStr.count >= 4 else { return nil }
        return String(dateStr.prefix(4))
    }

    /// Whether this item is a movie.
    public var isMovie: Bool { mediaType == "movie" }

    /// Whether this item is a TV show.
    public var isTv: Bool { mediaType == "tv" }
}

/// Semantic media status codes mapped from the integer values in `MediaInfo.status`.
public enum MediaStatusCode: Int, Sendable {
    case unknown = 1
    case pending = 2
    case processing = 3
    case partiallyAvailable = 4
    case available = 5
    case deleted = 6

    /// Human-readable short label for status badges.
    public var label: String {
        switch self {
        case .unknown: return ""
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .partiallyAvailable: return "Partial"
        case .available: return "Available"
        case .deleted: return ""
        }
    }

    /// Whether a status badge should be shown for this status.
    public var showsBadge: Bool {
        switch self {
        case .pending, .processing, .partiallyAvailable, .available: return true
        case .unknown, .deleted: return false
        }
    }
}

/// Slider type codes used by the Seerr discover configuration.
///
/// Each type maps to a specific content endpoint. The integer values match the
/// `type` field returned by `GET /settings/discover`.
public enum DiscoverSliderType: Int, Sendable, CaseIterable {
    case trendingMovies = 1
    case popularMovies = 2
    case upcomingMovies = 3
    case trendingTv = 4
    case popularTv = 5
    case upcomingTv = 6
    case trending = 7
    case movieGenre = 8
    case tvGenre = 9
    case studioMovies = 10
    case networkTv = 11
    case tmdbMovieKeyword = 12
    case tmdbTvKeyword = 13
    case plexWatchlist = 14

    /// Default display title for this slider type.
    public var defaultTitle: String {
        switch self {
        case .trendingMovies: return "Trending Movies"
        case .popularMovies: return "Popular Movies"
        case .upcomingMovies: return "Upcoming Movies"
        case .trendingTv: return "Trending TV Shows"
        case .popularTv: return "Popular TV Shows"
        case .upcomingTv: return "Upcoming TV Shows"
        case .trending: return "Trending"
        case .movieGenre: return "Movies"
        case .tvGenre: return "TV Shows"
        case .studioMovies: return "Studio Movies"
        case .networkTv: return "Network TV"
        case .tmdbMovieKeyword: return "Movies"
        case .tmdbTvKeyword: return "TV Shows"
        case .plexWatchlist: return "Plex Watchlist"
        }
    }
}

/// Full TMDB collection detail from `/collection/{collectionId}`.
public struct Collection: Codable, Sendable, Hashable {
    /// TMDB collection identifier.
    public let id: Int?
    /// Collection name (e.g. `"The Dark Knight Collection"`).
    public let name: String?
    /// Overview / description of the collection.
    public let overview: String?
    /// Relative path to the collection poster on TMDB.
    public let posterPath: String?
    /// Relative path to the collection backdrop on TMDB.
    public let backdropPath: String?
    /// Movies that belong to this collection.
    public let parts: [MovieResult]?
}

// MARK: - Issues

/// An issue filed against a media item (quality problem, wrong audio, etc.).
public struct Issue: Codable, Sendable, Hashable {
    /// Seerr issue identifier.
    public let id: Int?
    /// Issue type code: 1=VIDEO, 2=AUDIO, 3=SUBTITLE, 4=OTHER.
    public let issueType: Int?
    /// The media item this issue is filed against.
    public let media: MediaInfo?
    /// User who created the issue.
    public let createdBy: User?
    /// Admin who last modified the issue.
    public let modifiedBy: User?
    /// Comment thread on the issue.
    public let comments: [IssueComment]?
}

/// A comment on an issue.
public struct IssueComment: Codable, Sendable, Hashable {
    /// Seerr comment identifier.
    public let id: Int?
    /// User who posted the comment.
    public let user: User?
    /// Comment body text.
    public let message: String?
}

// MARK: - Notifications

/// Per-agent notification type bitmasks for a user.
public struct NotificationAgentTypes: Codable, Sendable, Hashable {
    public let discord: Int?
    public let email: Int?
    public let pushbullet: Int?
    public let pushover: Int?
    public let slack: Int?
    public let telegram: Int?
    public let webhook: Int?
    public let webpush: Int?
}

/// Discord notification agent settings.
public struct DiscordSettings: Codable, Sendable, Hashable {
    public let enabled: Bool?
    /// Bitmask of event types that trigger a notification.
    public let types: Int?
    public let options: DiscordOptions?

    public struct DiscordOptions: Codable, Sendable, Hashable {
        public let botUsername: String?
        public let botAvatarUrl: String?
        public let webhookUrl: String?
        public let enableMentions: Bool?
    }
}

/// Slack notification agent settings.
public struct SlackSettings: Codable, Sendable, Hashable {
    public let enabled: Bool?
    public let types: Int?
    public let options: SlackOptions?

    public struct SlackOptions: Codable, Sendable, Hashable {
        public let webhookUrl: String?
    }
}

/// Web push notification settings.
public struct WebPushSettings: Codable, Sendable, Hashable {
    public let enabled: Bool?
    public let types: Int?
}

/// Generic webhook notification settings.
public struct WebhookSettings: Codable, Sendable, Hashable {
    public let enabled: Bool?
    public let types: Int?
    public let options: WebhookOptions?

    public struct WebhookOptions: Codable, Sendable, Hashable {
        public let webhookUrl: String?
        public let authHeader: String?
        /// JSON payload template string.
        public let jsonPayload: String?
    }
}

/// Telegram notification agent settings.
public struct TelegramSettings: Codable, Sendable, Hashable {
    public let enabled: Bool?
    public let types: Int?
    public let options: TelegramOptions?

    public struct TelegramOptions: Codable, Sendable, Hashable {
        public let botUsername: String?
        public let botAPI: String?
        public let chatId: String?
        /// Whether messages are delivered silently (no sound).
        public let sendSilently: Bool?
    }
}

/// Pushbullet notification agent settings.
public struct PushbulletSettings: Codable, Sendable, Hashable {
    public let enabled: Bool?
    public let types: Int?
    public let options: PushbulletOptions?

    public struct PushbulletOptions: Codable, Sendable, Hashable {
        public let accessToken: String?
        public let channelTag: String?
    }
}

/// Pushover notification agent settings.
public struct PushoverSettings: Codable, Sendable, Hashable {
    public let enabled: Bool?
    public let types: Int?
    public let options: PushoverOptions?

    public struct PushoverOptions: Codable, Sendable, Hashable {
        public let accessToken: String?
        public let userToken: String?
        public let sound: String?
    }
}

/// Gotify notification agent settings.
public struct GotifySettings: Codable, Sendable, Hashable {
    public let enabled: Bool?
    public let types: Int?
    public let options: GotifyOptions?

    public struct GotifyOptions: Codable, Sendable, Hashable {
        public let url: String?
        public let token: String?
    }
}

/// LunaSea notification agent settings.
public struct LunaSeaSettings: Codable, Sendable, Hashable {
    public let enabled: Bool?
    public let types: Int?
    public let options: LunaSeaOptions?

    public struct LunaSeaOptions: Codable, Sendable, Hashable {
        public let webhookUrl: String?
        public let profileName: String?
    }
}

/// Email notification agent settings.
public struct NotificationEmailSettings: Codable, Sendable, Hashable {
    public let enabled: Bool?
    public let types: Int?
    public let options: EmailOptions?

    public struct EmailOptions: Codable, Sendable, Hashable {
        public let emailFrom: String?
        public let senderName: String?
        public let smtpHost: String?
        public let smtpPort: Int?
        public let secure: Bool?
        public let ignoreTls: Bool?
        public let requireTls: Bool?
        public let authUser: String?
        public let authPass: String?
        public let allowSelfSigned: Bool?
    }
}

// MARK: - Pagination

/// Pagination metadata returned alongside list responses.
public struct PageInfo: Codable, Sendable, Hashable {
    /// Current page number (1-based).
    public let page: Int?
    /// Total number of pages available.
    public let pages: Int?
    /// Total number of results across all pages.
    public let results: Int?
}

/// Generic paginated response wrapper.
/// Example: `PaginatedResponse<MediaRequest>` for the `/request` endpoint.
public struct PaginatedResponse<T: Codable & Sendable & Hashable>: Codable, Sendable, Hashable {
    public let pageInfo: PageInfo?
    public let results: [T]?
}

/// Watch provider details for a specific streaming service.
public struct WatchProviderDetails: Codable, Sendable, Hashable {
    /// Sort priority (lower = higher priority).
    public let displayPriority: Int?
    /// Relative path to the provider logo on TMDB.
    public let logoPath: String?
    /// TMDB watch provider identifier.
    public let id: Int?
    /// Provider display name (e.g. `"Netflix"`).
    public let name: String?
}

/// Watch provider availability for a single region.
public struct WatchProviderRegionEntry: Codable, Sendable, Hashable {
    /// ISO 3166-1 alpha-2 region code.
    public let iso31661: String?
    /// JustWatch link for this title in this region.
    public let link: String?
    /// Providers offering the title for purchase.
    public let buy: [WatchProviderDetails]?
    /// Providers offering the title via a flat-rate subscription.
    public let flatrate: [WatchProviderDetails]?

    private enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case link, buy, flatrate
    }
}

/// A region entry from the watch-provider regions list.
public struct WatchProviderRegion: Codable, Sendable, Hashable {
    /// ISO 3166-1 alpha-2 country code.
    public let iso31661: String?
    /// English name of the region.
    public let englishName: String?
    /// Native-script name of the region.
    public let nativeName: String?

    private enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case englishName = "english_name"
        case nativeName = "native_name"
    }
}

/// Full detail for a person from `/person/{personId}`.
public struct PersonDetails: Codable, Sendable, Hashable {
    /// TMDB person identifier.
    public let id: Int?
    /// Full name.
    public let name: String?
    /// Date of death (ISO 8601 date), if applicable.
    public let deathday: String?
    /// Primary department this person is known for.
    public let knownForDepartment: String?
    /// Alternative names or transliterations.
    public let alsoKnownAs: [String]?
    /// Gender description string.
    public let gender: String?
    /// Biographical summary.
    public let biography: String?
    /// Popularity score string (as returned by TMDB).
    public let popularity: String?
    /// Birthplace description.
    public let placeOfBirth: String?
    /// Relative path to profile photo on TMDB.
    public let profilePath: String?
    /// Whether the person has adult-content credits.
    public let adult: Bool?
    /// IMDb identifier.
    public let imdbId: String?
    /// Personal or official homepage URL.
    public let homepage: String?
}

/// A movie or TV credit from a person's filmography (acting role).
public struct CreditCast: Codable, Sendable, Hashable {
    /// TMDB title identifier.
    public let id: Int?
    /// Original filming language code.
    public let originalLanguage: String?
    /// Number of episodes the person appeared in (TV credits).
    public let episodeCount: Int?
    /// Plot summary.
    public let overview: String?
    /// Countries of origin (ISO 3166-1 alpha-2).
    public let originCountry: [String]?
    /// Original series name.
    public let originalName: String?
    /// Total vote count.
    public let voteCount: Int?
    /// Localised title or series name.
    public let name: String?
    /// Media type (`"movie"` or `"tv"`).
    public let mediaType: String?
    /// TMDB popularity score.
    public let popularity: Double?
    /// Unique credit identifier on TMDB.
    public let creditId: String?
    /// Relative path to backdrop image.
    public let backdropPath: String?
    /// First air date (TV) or nil.
    public let firstAirDate: String?
    /// Weighted average vote score.
    public let voteAverage: Double?
    /// TMDB genre identifiers.
    public let genreIds: [Int]?
    /// Relative path to poster image.
    public let posterPath: String?
    /// Original movie title.
    public let originalTitle: String?
    /// Whether the title is a video release.
    public let video: Bool?
    /// Localised movie title.
    public let title: String?
    /// Whether the content is adult-rated.
    public let adult: Bool?
    /// Theatrical release date.
    public let releaseDate: String?
    /// Character name portrayed.
    public let character: String?
    /// Seerr-specific availability and request info.
    public let mediaInfo: MediaInfo?
}

/// A movie or TV credit from a person's filmography (crew role).
public struct CreditCrew: Codable, Sendable, Hashable {
    /// TMDB title identifier.
    public let id: Int?
    /// Original filming language code.
    public let originalLanguage: String?
    /// Number of episodes worked on (TV credits).
    public let episodeCount: Int?
    /// Plot summary.
    public let overview: String?
    /// Countries of origin (ISO 3166-1 alpha-2).
    public let originCountry: [String]?
    /// Original series name.
    public let originalName: String?
    /// Total vote count.
    public let voteCount: Int?
    /// Localised title or series name.
    public let name: String?
    /// Media type (`"movie"` or `"tv"`).
    public let mediaType: String?
    /// TMDB popularity score.
    public let popularity: Double?
    /// Unique credit identifier on TMDB.
    public let creditId: String?
    /// Relative path to backdrop image.
    public let backdropPath: String?
    /// First air date (TV) or nil.
    public let firstAirDate: String?
    /// Weighted average vote score.
    public let voteAverage: Double?
    /// TMDB genre identifiers.
    public let genreIds: [Int]?
    /// Relative path to poster image.
    public let posterPath: String?
    /// Original movie title.
    public let originalTitle: String?
    /// Whether the title is a video release.
    public let video: Bool?
    /// Localised movie title.
    public let title: String?
    /// Whether the content is adult-rated.
    public let adult: Bool?
    /// Theatrical release date.
    public let releaseDate: String?
    /// Production department (e.g. `"Directing"`).
    public let department: String?
    /// Job title (e.g. `"Director"`).
    public let job: String?
    /// Seerr-specific availability and request info.
    public let mediaInfo: MediaInfo?
}

/// Combined cast and crew credits for a person.
public struct PersonCombinedCredits: Codable, Sendable, Hashable {
    public let cast: [CreditCast]?
    public let crew: [CreditCrew]?
}

/// A Sonarr series record.
public struct SonarrSeries: Codable, Sendable, Hashable {
    /// Series title.
    public let title: String?
    /// Sort-friendly title (lowercase, articles removed).
    public let sortTitle: String?
    /// Number of seasons.
    public let seasonCount: Int?
    /// Series status in Sonarr (e.g. `"upcoming"`).
    public let status: String?
    /// Plot summary.
    public let overview: String?
    /// Broadcast network name.
    public let network: String?
    /// Typical air time (HH:mm).
    public let airTime: String?
    /// Cover images (banner, poster, fanart).
    public let images: [SonarrImage]?
    /// Remote poster URL.
    public let remotePoster: String?
    /// Season monitoring status list.
    public let seasons: [SonarrSeasonMonitor]?
    /// First air year.
    public let year: Int?
    /// File system path in Sonarr.
    public let path: String?
    /// Sonarr quality profile identifier.
    public let profileId: Int?
    /// Sonarr language profile identifier.
    public let languageProfileId: Int?
    /// Whether season folders are used.
    public let seasonFolder: Bool?
    /// Whether this series is monitored in Sonarr.
    public let monitored: Bool?
    /// Whether scene numbering is used.
    public let useSceneNumbering: Bool?
    /// Average episode runtime in minutes.
    public let runtime: Int?
    /// TVDB identifier.
    public let tvdbId: Int?
    /// TV Rage identifier.
    public let tvRageId: Int?
    /// TV Maze identifier.
    public let tvMazeId: Int?
    /// First aired date.
    public let firstAired: String?
    /// Last info sync timestamp.
    public let lastInfoSync: String?
    /// Series type in Sonarr (e.g. `"standard"`).
    public let seriesType: String?
    /// Clean (slug-safe) title.
    public let cleanTitle: String?
    /// IMDb identifier.
    public let imdbId: String?
    /// Slug used in Sonarr URLs.
    public let titleSlug: String?
    /// Content certification string.
    public let certification: String?
    /// Genre tags.
    public let genres: [String]?
    /// Sonarr tag labels applied to this series.
    public let tags: [String]?
    /// Date the series was added to Sonarr.
    public let added: String?
    /// Ratings from external sources.
    public let ratings: [SonarrRating]?
    /// Sonarr quality profile identifier (v3+).
    public let qualityProfileId: Int?
    /// Sonarr internal series identifier.
    public let id: Int?
    /// Root folder path override.
    public let rootFolderPath: String?
    /// Options applied when adding the series to Sonarr.
    public let addOptions: [SonarrAddOptions]?
}

/// A cover image entry in a Sonarr series.
public struct SonarrImage: Codable, Sendable, Hashable {
    /// Image type (e.g. `"banner"`, `"poster"`, `"fanart"`).
    public let coverType: String?
    /// Relative URL served by Sonarr's media proxy.
    public let url: String?
}

/// Season monitoring flag for a Sonarr series.
public struct SonarrSeasonMonitor: Codable, Sendable, Hashable {
    public let seasonNumber: Int?
    public let monitored: Bool?
}

/// Rating entry from an external source.
public struct SonarrRating: Codable, Sendable, Hashable {
    public let votes: Int?
    public let value: Double?
}

/// Options set when adding a series to Sonarr.
public struct SonarrAddOptions: Codable, Sendable, Hashable {
    public let ignoreEpisodesWithFiles: Bool?
    public let ignoreEpisodesWithoutFiles: Bool?
    public let searchForMissingEpisodes: Bool?
}

/// A quality or language profile from a Radarr/Sonarr instance.
public struct ServiceProfile: Codable, Sendable, Hashable {
    public let id: Int?
    public let name: String?
}

/// Response from `GET /api/v1/service/sonarr/{sonarrId}` or `GET /api/v1/service/radarr/{radarrId}`.
/// Contains quality profiles and root folders for the named service instance.
public struct ServiceInstanceDetails: Codable, Sendable, Hashable {
    /// Available quality profiles on this service instance.
    public let profiles: [ServiceProfile]
}

/// A scheduled background job in Overseerr.
public struct Job: Codable, Sendable, Hashable {
    /// Machine-readable job identifier.
    public let id: String?
    /// Execution type.
    public let type: JobType?
    /// Scheduling interval category.
    public let interval: JobInterval?
    /// Human-readable job name.
    public let name: String?
    /// ISO 8601 timestamp of the next scheduled execution.
    public let nextExecutionTime: String?
    /// Whether the job is currently running.
    public let running: Bool?
}

/// Job execution type.
public enum JobType: String, Codable, Sendable, Hashable {
    case process
    case command
}

/// Job scheduling interval category.
public enum JobInterval: String, Codable, Sendable, Hashable {
    case short
    case long
    case fixed
}
