// AuthRepository.swift
// SeerrClient
//
// Repository that handles all authentication operations: local login, Plex OAuth
// login, Jellyfin login, session validation (/auth/me), and logout. Credentials
// are stored in and read from the Keychain via KeychainManager. All network
// calls go through SeerrAPIClient — this file never constructs URLs.

import Foundation

// MARK: - Auth Request Bodies

/// Request body for `POST /api/v1/auth/local`.
private struct LocalAuthRequest: Encodable {
    let email: String
    let password: String
}

/// Request body for `POST /api/v1/auth/plex`.
private struct PlexAuthRequest: Encodable {
    /// The auth token obtained from the Plex pin-based OAuth flow.
    let authToken: String
}

/// Request body for `POST /api/v1/auth/jellyfin`.
private struct JellyfinAuthRequest: Encodable {
    let username: String
    let password: String
    /// The Jellyfin server hostname. Required by Jellyseerr/Overseerr to route
    /// the credential check. Often the same host as the Seerr server.
    let hostname: String?
}

// MARK: - AuthRepository

/// Repository for all authentication-related API operations.
///
/// Coordinates:
/// - Credential submission (local, Plex, Jellyfin)
/// - Session validation via `GET /auth/me`
/// - Session destruction via `POST /auth/logout`
/// - Keychain reads/writes for stored API keys and session tokens
///
/// Usage:
/// ```swift
/// let repo = AuthRepository(apiClient: appState.apiClient!, server: appState.activeServer!)
/// let user = try await repo.loginLocal(email: "me@example.com", password: "secret")
/// ```
public struct AuthRepository {

    // MARK: - Properties

    /// The API client configured for the active server.
    private let apiClient: SeerrAPIClient

    /// The server configuration whose keychain namespace is used for storage.
    private let server: ServerConfiguration

    // MARK: - Init

    /// Creates an `AuthRepository` bound to a specific server and API client.
    ///
    /// - Parameters:
    ///   - apiClient: An authenticated (or pre-auth) `SeerrAPIClient`.
    ///   - server: The `ServerConfiguration` to use as the keychain scope.
    public init(apiClient: SeerrAPIClient, server: ServerConfiguration) {
        self.apiClient = apiClient
        self.server = server
    }

    // MARK: - GET /auth/me

    /// Validates an existing session and returns the current user.
    ///
    /// Call this on app launch to attempt session restoration. A `401 Unauthorized`
    /// response means the stored session is expired or invalid.
    ///
    /// - Returns: The authenticated `User`.
    /// - Throws: `SeerrAPIError.unauthorized` if the session is invalid;
    ///   other `SeerrAPIError` cases on network or server failures.
    public func fetchCurrentUser() async throws -> User {
        let endpoints = await apiClient.endpoints
        let user: User = try await apiClient.get(endpoints.authMe)
        AppLogger.info("AuthRepository: fetchCurrentUser — id=\(user.id)")
        return user
    }

    // MARK: - POST /auth/local

    /// Signs in with a local email and password.
    ///
    /// On success stores the session token in the Keychain and returns the user.
    ///
    /// - Parameters:
    ///   - email: The user's local account email address.
    ///   - password: The user's plaintext password (transmitted over HTTPS).
    /// - Returns: The authenticated `User`.
    /// - Throws: `SeerrAPIError.unauthorized` on bad credentials;
    ///   other `SeerrAPIError` cases on network or server failures.
    public func loginLocal(email: String, password: String) async throws -> User {
        let endpoints = await apiClient.endpoints
        let body = LocalAuthRequest(email: email, password: password)
        let user: User = try await apiClient.post(endpoints.authLocal, body: body)

        // Persist credentials for session restoration.
        try? KeychainManager.shared.save(email, for: .username, server: server.baseURL)
        AppLogger.info("AuthRepository: local login success — user id=\(user.id)")
        return user
    }

    // MARK: - POST /auth/plex

    /// Signs in using a Plex auth token obtained via the Plex pin OAuth flow.
    ///
    /// - Parameter authToken: The `authToken` returned from `GET plex.tv/api/v2/pins/{id}`
    ///   after the user authenticates in the Plex web view.
    /// - Returns: The authenticated `User`.
    /// - Throws: `SeerrAPIError.unauthorized` if the token is rejected;
    ///   other `SeerrAPIError` cases on network failures.
    public func loginPlex(authToken: String) async throws -> User {
        let endpoints = await apiClient.endpoints
        let body = PlexAuthRequest(authToken: authToken)
        let user: User = try await apiClient.post(endpoints.authPlex, body: body)
        AppLogger.info("AuthRepository: Plex login success — user id=\(user.id)")
        return user
    }

    // MARK: - POST /auth/jellyfin

    /// Signs in with Jellyfin credentials.
    ///
    /// - Parameters:
    ///   - username: The Jellyfin username.
    ///   - password: The Jellyfin password.
    ///   - hostname: Optional Jellyfin server hostname. When `nil`, Seerr uses
    ///     the hostname it is already configured to talk to.
    /// - Returns: The authenticated `User`.
    /// - Throws: `SeerrAPIError.unauthorized` on bad credentials;
    ///   other `SeerrAPIError` on network or server failures.
    public func loginJellyfin(
        username: String,
        password: String,
        hostname: String? = nil
    ) async throws -> User {
        let endpoints = await apiClient.endpoints
        let body = JellyfinAuthRequest(
            username: username,
            password: password,
            hostname: hostname
        )
        let user: User = try await apiClient.post(endpoints.authJellyfin, body: body)

        // Store username for session restoration hints.
        try? KeychainManager.shared.save(username, for: .username, server: server.baseURL)
        AppLogger.info("AuthRepository: Jellyfin login success — user id=\(user.id)")
        return user
    }

    // MARK: - POST /auth/logout

    /// Destroys the active session on the server.
    ///
    /// After this call, the stored session cookie is cleared from the API client.
    /// Call `KeychainManager.shared.deleteAll(server:)` afterwards to remove
    /// all local credentials for this server.
    ///
    /// - Throws: `SeerrAPIError` if the logout request itself fails.
    ///   (Callers should clear local credentials even on failure.)
    public func logout() async throws {
        let endpoints = await apiClient.endpoints
        // Logout typically returns an empty 200 body; decode to `EmptyResponse`.
        let _: EmptyResponse = try await apiClient.post(endpoints.authLogout)
        await apiClient.clearCookies()
        AppLogger.info("AuthRepository: logout success for \(server.baseURL)")
    }

    // MARK: - Keychain Helpers

    /// Returns the API key stored in the Keychain for this server, if any.
    public func storedAPIKey() -> String? {
        KeychainManager.shared.readAPIKey(for: server.baseURL)
    }

    /// Stores an API key in the Keychain for this server.
    ///
    /// - Parameter apiKey: The API key string to persist.
    public func storeAPIKey(_ apiKey: String) {
        try? KeychainManager.shared.save(apiKey, for: .apiKey, server: server.baseURL)
    }

    /// Clears all credentials (API key, session token, username) from the Keychain.
    public func clearStoredCredentials() {
        KeychainManager.shared.deleteAll(server: server.baseURL)
    }
}

// MARK: - EmptyResponse

/// Dummy `Decodable` type used when the server returns an empty body on success.
private struct EmptyResponse: Decodable {}
