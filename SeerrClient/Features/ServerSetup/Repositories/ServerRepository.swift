// ServerRepository.swift
// SeerrClient
//
// Repository responsible for detecting a Seerr-compatible server at a given
// URL. Calls GET /status to detect the backend type and version, then calls
// GET /settings/public to obtain available authentication methods and the
// application title. All network calls are routed through SeerrAPIClient —
// URLs are never constructed inside this file.

import Foundation

// MARK: - ServerDetectionResult

/// The result of a successful server detection sequence.
///
/// Produced by `ServerRepository.detectServer()` after both
/// `GET /status` and `GET /settings/public` succeed.
///
/// Usage:
/// ```swift
/// let repo = ServerRepository(baseURL: normalizedURL, serverStore: store)
/// let result = try await repo.detectServer()
/// print(result.backendType.displayName)   // "Jellyseerr"
/// print(result.availableAuthMethods)      // [.local, .plex]
/// ```
public struct ServerDetectionResult: Sendable {

    /// The normalised base URL that was successfully contacted.
    public let baseURL: String

    /// The server's version string (e.g. `"1.33.2"`).
    public let version: String

    /// The auto-detected backend flavour.
    public let backendType: BackendType

    /// Whether local email/password login is available.
    public let localLoginEnabled: Bool

    /// Whether Plex OAuth login is available.
    public let plexLoginEnabled: Bool

    /// Whether Jellyfin credential login is available.
    public let jellyfinLoginEnabled: Bool

    /// The application title configured on the server (e.g. `"My Media Server"`).
    /// Falls back to the backend type's display name when the server does not
    /// provide one.
    public let applicationTitle: String

    /// Whether the server has completed its first-time setup wizard.
    public let isInitialized: Bool

    /// The auth methods that are currently enabled on the server, in display order.
    ///
    /// Only methods that are explicitly enabled are included. ViewModels use this
    /// to show only the relevant login tabs in `LoginView`.
    public var availableAuthMethods: [AuthMethod] {
        var methods: [AuthMethod] = []
        if localLoginEnabled    { methods.append(.local) }
        if plexLoginEnabled     { methods.append(.plex) }
        if jellyfinLoginEnabled { methods.append(.jellyfin) }
        return methods
    }
}

// MARK: - ServerDetectionPublicSettings (private decoding model)

/// Extended public settings response that includes login-method flags.
///
/// `SeerrModels.PublicSettings` only models `initialized`. Different backends
/// (Overseerr, Jellyseerr) expose additional fields. We decode them all here
/// with optional values and fall back gracefully when fields are absent.
private struct ServerDetectionPublicSettings: Decodable {
    let initialized: Bool?
    let localLogin: Bool?
    let newPlexLogin: Bool?
    /// Whether any media-server (Jellyfin/Plex) login is enabled.
    /// Field name confirmed from Jellyseerr source: `mediaServerLogin`.
    let mediaServerLogin: Bool?
    /// Which media server is configured: 1 = Plex, 2 = Jellyfin, 3 = Emby.
    let mediaServerType: Int?
    /// Some backends expose the application display title in public settings.
    let applicationTitle: String?
}

// MARK: - ServerRepository

/// Repository that coordinates the two-step server detection handshake.
///
/// Detection sequence:
/// 1. `GET /api/v1/status`          — extract version, derive backend type
/// 2. `GET /api/v1/settings/public` — extract available auth methods, app title
///
/// Repositories never construct URLs. Paths are taken from `APIEndpoints` and
/// passed to `SeerrAPIClient`, which handles all URL construction.
///
/// Usage:
/// ```swift
/// let repo = ServerRepository(baseURL: "http://192.168.1.50:5055", serverStore: store)
/// let result = try await repo.detectServer()
/// ```
public struct ServerRepository {

    // MARK: - Properties

    /// The normalised base URL of the target server.
    private let baseURL: String

    /// The shared server store used to persist TOFU certificate fingerprints.
    private let serverStore: ServerStore

    // MARK: - Init

    /// Creates a `ServerRepository` for the given server address.
    ///
    /// - Parameters:
    ///   - baseURL: The normalised base URL (use `URLNormalizer.normalize(_:)` first).
    ///   - serverStore: The store where cert fingerprints are persisted.
    public init(baseURL: String, serverStore: ServerStore) {
        self.baseURL = baseURL
        self.serverStore = serverStore
    }

    // MARK: - Detection

    /// Runs the full server detection sequence against `baseURL`.
    ///
    /// Calls `GET /status` then `GET /settings/public` using a short-lived
    /// `SeerrAPIClient` constructed from the provided base URL. Both calls
    /// must succeed for a result to be returned.
    ///
    /// - Returns: A populated `ServerDetectionResult`.
    /// - Throws: `SeerrAPIError` on network failure, SSL error, timeout, or
    ///   HTTP error status.
    public func detectServer() async throws -> ServerDetectionResult {
        let client = makeDetectionClient()
        return try await runDetection(client: client)
    }

    // MARK: - Self-Signed Certificate Trust

    /// Retries server detection after the user has agreed to trust a self-signed
    /// certificate at `baseURL`.
    ///
    /// Sets `allowAllForCurrentChallenge` on the client's trust manager before
    /// issuing the first request, allowing the TOFU fingerprint to be recorded.
    ///
    /// - Returns: A populated `ServerDetectionResult`.
    /// - Throws: `SeerrAPIError` if the connection still fails after trust is granted.
    public func detectServerTrustingCertificate() async throws -> ServerDetectionResult {
        let client = makeDetectionClient()
        // Allow the next cert challenge to succeed unconditionally (TOFU).
        await client.allowNextCertificateChallenge()
        return try await runDetection(client: client)
    }

    // MARK: - Private Helpers

    /// Creates a minimal, unauthenticated `SeerrAPIClient` for detection.
    private func makeDetectionClient() -> SeerrAPIClient {
        let tempConfig = ServerConfiguration(
            displayName: "Detection",
            baseURL: baseURL
        )
        return SeerrAPIClient(server: tempConfig, serverStore: serverStore)
    }

    /// Shared detection sequence: query /status then /settings/public.
    private func runDetection(client: SeerrAPIClient) async throws -> ServerDetectionResult {
        let endpoints = client.endpoints

        // Step 1: Query /status — version and implicit backend type.
        let status: ServerStatus = try await client.get(
            endpoints.status,
            timeout: SeerrAPIClient.defaultTimeout
        )
        var backendType = detectBackendType(from: status)

        // Step 2: Query /settings/public — auth methods and application title.
        let publicSettings: ServerDetectionPublicSettings = try await client.get(
            endpoints.settingsPublic
        )

        // Refine backend type using mediaServerType from public settings.
        // Jellyseerr version strings are plain semver (e.g. "1.9.2") so the
        // string-based detection above may fall back to .overseerr. Use the
        // mediaServerType field to correct this: only Jellyseerr/Emby forks
        // expose mediaServerType 2 (Jellyfin) or 3 (Emby); Overseerr always
        // uses Plex (1) and predates this field.
        if backendType == .overseerr {
            let mst = publicSettings.mediaServerType
            if mst == 2 || mst == 3 {
                backendType = .jellyseerr
            }
        }

        // Determine the application title: server-provided > backend display name.
        let appTitle = publicSettings.applicationTitle.flatMap { $0.isEmpty ? nil : $0 }
            ?? backendType.displayName

        // Auth method availability:
        // - localLogin: default true (all backends support it unless explicitly disabled)
        // - mediaServerLogin: controls whether Plex/Jellyfin media-server login is enabled
        // - mediaServerType: 1=Plex, 2=Jellyfin, 3=Emby — inferred from backend when absent
        // - newPlexLogin: Plex OAuth specifically (Overseerr path)
        let localEnabled = publicSettings.localLogin ?? true

        let mediaServerEnabled = publicSettings.mediaServerLogin ?? true
        // Infer mediaServerType from backend when the field is absent.
        let mediaServerType = publicSettings.mediaServerType
            ?? (backendType == .jellyseerr || backendType == .seerr ? 2 : 1)

        let jellyfinEnabled = mediaServerEnabled && (mediaServerType == 2 || mediaServerType == 3)
        let plexEnabled     = (publicSettings.newPlexLogin ?? false)
            || (mediaServerEnabled && mediaServerType == 1)

        return ServerDetectionResult(
            baseURL: baseURL,
            version: status.version,
            backendType: backendType,
            localLoginEnabled: localEnabled,
            plexLoginEnabled: plexEnabled,
            jellyfinLoginEnabled: jellyfinEnabled,
            applicationTitle: appTitle,
            isInitialized: publicSettings.initialized ?? true
        )
    }

    /// Infers the backend type from the server status response.
    ///
    /// Jellyseerr self-identifies by including `"jellyseerr"` in its version
    /// string or commit tag. Seerr (the fork) does the same with `"seerr"`.
    /// Anything else is treated as Overseerr.
    ///
    /// - Parameter status: The decoded `ServerStatus`.
    /// - Returns: The best matching `BackendType`.
    private func detectBackendType(from status: ServerStatus) -> BackendType {
        let version  = status.version.lowercased()
        let tag      = (status.commitTag ?? "").lowercased()
        let combined = version + " " + tag

        if combined.contains("jellyseerr") {
            return .jellyseerr
        } else if combined.contains("seerr") && !combined.contains("over") {
            // "seerr" substring but NOT "overseerr"
            return .seerr
        } else {
            return .overseerr
        }
    }
}
