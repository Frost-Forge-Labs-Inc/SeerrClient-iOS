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
    /// `nil` for servers saved before this field was added (treated as `[.local]`).
    public var availableAuthMethods: [AuthMethod]?

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
        isDefault: Bool = false,
        lastConnected: Date? = nil,
        certFingerprint: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.backendType = backendType
        self.apiVersion = apiVersion
        self.authMethod = authMethod
        self.availableAuthMethods = availableAuthMethods
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
