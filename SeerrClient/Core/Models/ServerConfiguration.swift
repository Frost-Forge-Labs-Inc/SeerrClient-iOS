// ServerConfiguration.swift
// SeerrClient
//
// Local model representing a saved Seerr server entry. Stored in UserDefaults
// (non-sensitive fields) and Keychain (credentials). This type is the iOS-side
// source of truth for everything the app knows about a configured server.

import Foundation

// MARK: - BackendType

/// The detected backend type of a Seerr-compatible server.
///
/// Auto-detected by calling `GET /api/v1/status` and inspecting the response.
/// The `unknown` case is used before detection has completed or when the
/// version string cannot be matched to a known variant.
public enum BackendType: String, Codable, Sendable, CaseIterable {
    /// Overseerr — the original (Plex-focused).
    case overseerr
    /// Jellyseerr — the Jellyfin/Emby fork.
    case jellyseerr
    /// Seerr — another fork; may add Emby-native auth.
    case seerr
    /// Could not be determined from the `/status` response.
    case unknown

    /// A user-friendly display name.
    public var displayName: String {
        switch self {
        case .overseerr:   return "Overseerr"
        case .jellyseerr:  return "Jellyseerr"
        case .seerr:       return "Seerr"
        case .unknown:     return "Unknown"
        }
    }

    /// The SF Symbol name that best represents this backend.
    public var symbolName: String {
        switch self {
        case .overseerr:   return "play.rectangle.fill"
        case .jellyseerr:  return "server.rack"
        case .seerr:       return "film.stack"
        case .unknown:     return "questionmark.circle"
        }
    }
}

// MARK: - MediaServerKind

/// The media-server family configured behind a Seerr-compatible backend.
///
/// This is derived primarily from `GET /api/v1/settings/public` using
/// `mediaServerType`, then normalised into a stable client-side model used for
/// auth gating and feature compatibility decisions.
public enum MediaServerKind: String, Codable, Sendable, CaseIterable {
    case plex
    case jellyfin
    case emby
    case unknown

    /// A user-friendly display name.
    public var displayName: String {
        switch self {
        case .plex:     return "Plex"
        case .jellyfin: return "Jellyfin"
        case .emby:     return "Emby"
        case .unknown:  return "Unknown"
        }
    }
}

// MARK: - PublicSettingsNormalized

/// Normalised subset of `GET /api/v1/settings/public`.
///
/// The live public-settings payload is richer than the current generated model
/// in `SeerrModels.swift`, so the app stores a normalised snapshot here. All
/// backend-specific fields remain optional.
public struct PublicSettingsNormalized: Codable, Sendable, Hashable {
    public var initialized: Bool
    public var applicationTitle: String?
    public var localLoginEnabled: Bool?
    public var newPlexLoginEnabled: Bool?
    public var mediaServerLoginEnabled: Bool?
    public var mediaServerKind: MediaServerKind
    public var hideAvailable: Bool?
    public var hideBlacklisted: Bool?
    public var partialRequestsEnabled: Bool?
    public var discoverRegion: String?
    public var streamingRegion: String?
    public var region: String?
    public var originalLanguage: String?
    public var locale: String?
    public var jellyfinExternalHost: String?
    public var jellyfinForgotPasswordURL: String?
    public var userEmailRequired: Bool?
    public var youtubeURL: String?

    public init(
        initialized: Bool = true,
        applicationTitle: String? = nil,
        localLoginEnabled: Bool? = nil,
        newPlexLoginEnabled: Bool? = nil,
        mediaServerLoginEnabled: Bool? = nil,
        mediaServerKind: MediaServerKind = .unknown,
        hideAvailable: Bool? = nil,
        hideBlacklisted: Bool? = nil,
        partialRequestsEnabled: Bool? = nil,
        discoverRegion: String? = nil,
        streamingRegion: String? = nil,
        region: String? = nil,
        originalLanguage: String? = nil,
        locale: String? = nil,
        jellyfinExternalHost: String? = nil,
        jellyfinForgotPasswordURL: String? = nil,
        userEmailRequired: Bool? = nil,
        youtubeURL: String? = nil
    ) {
        self.initialized = initialized
        self.applicationTitle = applicationTitle
        self.localLoginEnabled = localLoginEnabled
        self.newPlexLoginEnabled = newPlexLoginEnabled
        self.mediaServerLoginEnabled = mediaServerLoginEnabled
        self.mediaServerKind = mediaServerKind
        self.hideAvailable = hideAvailable
        self.hideBlacklisted = hideBlacklisted
        self.partialRequestsEnabled = partialRequestsEnabled
        self.discoverRegion = discoverRegion
        self.streamingRegion = streamingRegion
        self.region = region
        self.originalLanguage = originalLanguage
        self.locale = locale
        self.jellyfinExternalHost = jellyfinExternalHost
        self.jellyfinForgotPasswordURL = jellyfinForgotPasswordURL
        self.userEmailRequired = userEmailRequired
        self.youtubeURL = youtubeURL
    }
}

// MARK: - ServerCapabilities

/// Cached runtime compatibility snapshot for a server.
///
/// This is the client-side source of truth for:
/// - login UI selection
/// - backend-specific feature enable/disable
/// - platform-level compatibility decisions
///
/// It is derived during server detection and persisted with
/// `ServerConfiguration` so the app does not need to re-probe the backend on
/// every launch or screen transition.
public struct ServerCapabilities: Codable, Sendable, Hashable {
    public var backendType: BackendType
    public var publicSettings: PublicSettingsNormalized

    public init(
        backendType: BackendType,
        publicSettings: PublicSettingsNormalized
    ) {
        self.backendType = backendType
        self.publicSettings = publicSettings
    }

    /// User-facing app title reported by the backend, falling back to the
    /// backend family name when not explicitly configured.
    public var applicationTitle: String {
        let trimmedTitle = publicSettings.applicationTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedTitle, !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        return backendType.displayName
    }

    /// Whether the server has completed its first-run setup wizard.
    public var isInitialized: Bool {
        publicSettings.initialized
    }

    /// Normalised media-server family used for login and compatibility gating.
    public var mediaServerKind: MediaServerKind {
        publicSettings.mediaServerKind
    }

    /// Whether local username/email + password login is available.
    public var supportsLocalLogin: Bool {
        publicSettings.localLoginEnabled ?? true
    }

    /// Whether Plex OAuth login should be shown.
    ///
    /// `newPlexLogin` is deliberately ignored for Jellyfin/Emby families to
    /// avoid the broken "show Plex login on Jellyseerr" path documented in the
    /// compatibility guide.
    public var supportsPlexLogin: Bool {
        guard mediaServerKind == .plex else { return false }
        return (publicSettings.mediaServerLoginEnabled ?? true)
            || (publicSettings.newPlexLoginEnabled ?? false)
    }

    /// Whether Jellyfin/Emby credential login should be shown.
    public var supportsJellyfinLogin: Bool {
        switch mediaServerKind {
        case .jellyfin, .emby:
            return publicSettings.mediaServerLoginEnabled ?? true
        case .plex, .unknown:
            return false
        }
    }

    /// `GET /discover/watchlist` and `GET /user/{id}/watchlist` are shared.
    public var supportsWatchlistRead: Bool { true }

    /// `POST/DELETE /watchlist` are Jellyseerr-family only.
    public var supportsWatchlistWrite: Bool { backendType != .overseerr }

    public var supportsBlacklist: Bool { backendType != .overseerr }
    public var supportsLinkedAccounts: Bool { backendType != .overseerr }
    public var supportsJellyfinAdmin: Bool { backendType != .overseerr }
    public var supportsNtfy: Bool { backendType != .overseerr }
    public var supportsLunaSea: Bool { backendType == .overseerr }
    public var supportsMediaFileDelete: Bool { backendType != .overseerr }
    public var supportsNetworkSettings: Bool { backendType != .overseerr }

    /// Login methods derived from the normalised capability model.
    public var availableAuthMethods: [AuthMethod] {
        var methods: [AuthMethod] = []
        if supportsLocalLogin { methods.append(.local) }
        if supportsPlexLogin { methods.append(.plex) }
        if supportsJellyfinLogin { methods.append(.jellyfin) }
        return methods
    }

    /// Best-effort compatibility snapshot for server entries saved before the
    /// capability model existed.
    public static func legacyDefault(
        backendType: BackendType,
        availableAuthMethods: [AuthMethod]?,
        applicationTitle: String? = nil,
        isInitialized: Bool = true
    ) -> ServerCapabilities {
        let methods = availableAuthMethods ?? {
            switch backendType {
            case .overseerr:
                return [.local, .plex]
            case .jellyseerr, .seerr:
                return [.local, .jellyfin]
            case .unknown:
                return [.local]
            }
        }()

        let mediaServerKind: MediaServerKind = {
            if methods.contains(.jellyfin) { return .jellyfin }
            if methods.contains(.plex) { return .plex }
            switch backendType {
            case .overseerr:
                return .plex
            case .jellyseerr, .seerr:
                return .jellyfin
            case .unknown:
                return .unknown
            }
        }()

        let publicSettings = PublicSettingsNormalized(
            initialized: isInitialized,
            applicationTitle: applicationTitle,
            localLoginEnabled: methods.contains(.local),
            newPlexLoginEnabled: methods.contains(.plex),
            mediaServerLoginEnabled: methods.contains(.plex) || methods.contains(.jellyfin),
            mediaServerKind: mediaServerKind
        )
        return ServerCapabilities(backendType: backendType, publicSettings: publicSettings)
    }
}

// MARK: - AuthMethod

/// The authentication method configured for a server entry.
public enum AuthMethod: String, Codable, Sendable, CaseIterable {
    /// Local email/password (`POST /auth/local`).
    case local
    /// Plex OAuth (`POST /auth/plex`).
    case plex
    /// Jellyfin credential login (`POST /auth/jellyfin`).
    case jellyfin
    /// API key only — no user session. Used when the user manages API keys
    /// directly rather than logging in through the web flow.
    case apiKeyOnly
    /// Not yet determined (before the first connection).
    case none
}

// MARK: - APIVersion (server-side)

/// The API version advertised by the server.
///
/// Distinct from `APIEndpoints.APIVersion` which is the client-side version we
/// target. They typically match but can differ during upgrades.
public enum ServerAPIVersion: String, Codable, Sendable {
    case v1 = "v1"
    // case v2 = "v2"  // future
}

// MARK: - ServerConfiguration

/// A fully-specified server entry saved on the device.
///
/// Non-sensitive fields are stored in `UserDefaults` via `ServerStore`.
/// Credentials (API key, session token) are stored in the Keychain, keyed by
/// `baseURL`.
///
/// Usage:
/// ```swift
/// let server = ServerConfiguration(
///     displayName: "Home Jellyseerr",
///     baseURL: "http://192.168.1.50:5055",
///     backendType: .jellyseerr
/// )
/// ```
public struct ServerConfiguration: Identifiable, Codable, Sendable, Hashable {

    // MARK: - Stored Properties

    /// Client-generated unique identifier. Never changes after creation.
    public let id: UUID

    /// User-assigned friendly name (e.g. "Home Server", "Work Seerr").
    public var displayName: String

    /// Normalised base URL (no trailing slash, no path component).
    /// Example: `"http://192.168.1.50:5055"`
    public var baseURL: String

    /// Auto-detected backend flavour. `unknown` until first successful `/status` call.
    public var backendType: BackendType

    /// Server-reported API version string.
    public var apiVersion: ServerAPIVersion

    /// The auth method the user last authenticated with.
    public var authMethod: AuthMethod

    /// All auth methods available on this server, as detected during setup.
    /// `nil` for servers saved before this field was added.
    public var availableAuthMethods: [AuthMethod]?

    /// Cached runtime capability snapshot derived from `/status` and
    /// `/settings/public`.
    /// `nil` for servers saved before the capability model was introduced.
    public var capabilities: ServerCapabilities?

    /// Whether this is the user's default / primary server.
    public var isDefault: Bool

    /// The ISO 8601 timestamp of the last successful connection.
    public var lastConnected: Date?

    /// SHA-256 fingerprint of the server's TLS certificate, stored for TOFU
    /// (Trust On First Use) validation. `nil` for CA-signed or HTTP servers.
    public var certFingerprint: String?

    // MARK: - Init

    /// Creates a new `ServerConfiguration` with sensible defaults.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new `UUID`.
    ///   - displayName: The user-facing label for this server.
    ///   - baseURL: Normalised base URL (use `URLNormalizer.normalize(_:)` first).
    ///   - backendType: Detected backend flavour. Defaults to `.unknown`.
    ///   - apiVersion: API version. Defaults to `.v1`.
    ///   - authMethod: Most recent auth method. Defaults to `.none`.
    ///   - availableAuthMethods: All auth methods available on this server. Defaults to `nil`.
    ///   - capabilities: Cached runtime compatibility snapshot. Defaults to `nil`.
    ///   - isDefault: Whether this is the primary server. Defaults to `false`.
    ///   - lastConnected: Last successful connection date. Defaults to `nil`.
    ///   - certFingerprint: TOFU certificate fingerprint. Defaults to `nil`.
    public init(
        id: UUID = UUID(),
        displayName: String,
        baseURL: String,
        backendType: BackendType = .unknown,
        apiVersion: ServerAPIVersion = .v1,
        authMethod: AuthMethod = .none,
        availableAuthMethods: [AuthMethod]? = nil,
        capabilities: ServerCapabilities? = nil,
        isDefault: Bool = false,
        lastConnected: Date? = nil,
        certFingerprint: String? = nil
    ) {
        let resolvedCapabilities = capabilities
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.backendType = resolvedCapabilities?.backendType ?? backendType
        self.apiVersion = apiVersion
        self.authMethod = authMethod
        self.availableAuthMethods = availableAuthMethods ?? resolvedCapabilities?.availableAuthMethods
        self.capabilities = resolvedCapabilities
        self.isDefault = isDefault
        self.lastConnected = lastConnected
        self.certFingerprint = certFingerprint
    }

    // MARK: - Computed

    /// A short display string combining backend type and host for list subtitles.
    /// Example: `"Jellyseerr · 192.168.1.50:5055"`
    public var subtitle: String {
        let host = URLNormalizer.displayHost(from: baseURL)
        return "\(backendType.displayName) · \(host)"
    }

    /// Whether this server uses HTTPS.
    public var usesHTTPS: Bool {
        baseURL.lowercased().hasPrefix("https://")
    }

    /// Whether this server has a stored certificate fingerprint for TOFU validation.
    public var hasCertFingerprint: Bool {
        certFingerprint != nil
    }

    /// Runtime capability snapshot, falling back to a best-effort model for
    /// server entries persisted before capabilities were cached explicitly.
    public var resolvedCapabilities: ServerCapabilities {
        capabilities ?? ServerCapabilities.legacyDefault(
            backendType: backendType,
            availableAuthMethods: availableAuthMethods,
            applicationTitle: displayName
        )
    }

    /// Backward-compatible auth-method resolver used by older call sites during
    /// the capability-model rollout.
    public var resolvedAuthMethods: [AuthMethod] {
        if let methods = capabilities?.availableAuthMethods {
            return methods
        }
        if let methods = availableAuthMethods {
            return methods
        }
        return resolvedCapabilities.availableAuthMethods
    }
}

// MARK: - AuthMethod Display Helpers

extension AuthMethod: Identifiable {
    public var id: String { rawValue }

    /// A user-friendly display name for the auth method.
    public var displayName: String {
        switch self {
        case .local:      return "Local"
        case .plex:       return "Plex"
        case .jellyfin:   return "Jellyfin"
        case .apiKeyOnly: return "API Key"
        case .none:       return "None"
        }
    }

    /// The SF Symbol name that best represents this auth method.
    public var symbolName: String {
        switch self {
        case .local:      return "person.fill"
        case .plex:       return "play.rectangle.fill"
        case .jellyfin:   return "server.rack"
        case .apiKeyOnly: return "key.fill"
        case .none:       return "questionmark"
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
public extension ServerConfiguration {
    /// A mock server useful in SwiftUI previews and unit tests.
    static let preview = ServerConfiguration(
        displayName: "Local Jellyseerr",
        baseURL: "http://192.168.1.50:5055",
        backendType: .jellyseerr,
        apiVersion: .v1,
        authMethod: .local,
        isDefault: true,
        lastConnected: Date()
    )
}
#endif
