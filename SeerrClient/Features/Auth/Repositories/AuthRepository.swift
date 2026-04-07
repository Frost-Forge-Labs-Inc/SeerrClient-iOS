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
    /// Credentials are NOT saved here — call `storeLocalCredentials` afterwards
    /// if the user has enabled "Remember Me".
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
        AppLogger.info("AuthRepository: local login success — user id=\(user.id)")
        return user
    }

    /// Persists local login credentials in the Keychain for session restoration.
    /// Call after a successful `loginLocal` only when the user has enabled "Remember Me".
    public func storeLocalCredentials(email: String, password: String) {
        let km = KeychainManager.shared
        try? km.save(email,   for: .username,   server: server.baseURL)
        try? km.save(password, for: .password,  server: server.baseURL)
        try? km.save("local", for: .authMethod, server: server.baseURL)
    }

    // MARK: - POST /auth/plex

    /// Signs in using a Plex auth token obtained via the Plex pin OAuth flow.
    ///
    /// For Plex, no reusable credentials exist — only the session cookie is persisted.
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

    /// Records the Plex auth method in the Keychain so session cookie restore is
    /// attempted on the next launch. Call only when the user has enabled "Remember Me".
    public func storePlexAuthMethod() {
        try? KeychainManager.shared.save("plex", for: .authMethod, server: server.baseURL)
    }

    // MARK: - POST /auth/jellyfin

    /// Signs in with Jellyfin credentials.
    ///
    /// On success stores credentials and session cookie in the Keychain for
    /// silent session restoration on next app launch.
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
        AppLogger.info("AuthRepository: Jellyfin login success — user id=\(user.id)")
        return user
    }

    /// Persists Jellyfin credentials in the Keychain for session restoration.
    /// Call after a successful `loginJellyfin` only when the user has enabled "Remember Me".
    public func storeJellyfinCredentials(username: String, password: String, hostname: String?) {
        let km = KeychainManager.shared
        try? km.save(username,       for: .username,         server: server.baseURL)
        try? km.save(password,       for: .password,         server: server.baseURL)
        try? km.save("jellyfin",     for: .authMethod,       server: server.baseURL)
        try? km.save(hostname ?? "", for: .jellyfinHostname, server: server.baseURL)
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
        // Clear in-memory cookies FIRST — unconditionally — so that even if the
        // server call fails the old cookie cannot be used by the next session restore.
        await apiClient.clearCookies()
        let endpoints = await apiClient.endpoints
        let _: EmptyResponse = try await apiClient.post(endpoints.authLogout)
        AppLogger.info("AuthRepository: logout success for \(server.baseURL)")
    }

    // MARK: - Session Persistence

    /// Extracts the `connect.sid` cookie from the API client and saves its value
    /// to the Keychain so it can be restored on the next app launch.
    ///
    /// Call this immediately after any successful login.
    public func persistSessionCookie() async {
        guard let cookie = await apiClient.cookie(named: "connect.sid") else {
            AppLogger.debug("AuthRepository: no connect.sid cookie to persist")
            return
        }
        try? KeychainManager.shared.save(cookie.value, for: .sessionToken, server: server.baseURL)
        AppLogger.info("AuthRepository: session cookie persisted for \(server.baseURL)")
    }

    /// Reads the persisted `connect.sid` cookie value from the Keychain and
    /// injects a reconstructed `HTTPCookie` into the API client.
    ///
    /// Call this before `fetchCurrentUser()` on app launch so the session
    /// cookie is available to the `GET /auth/me` request.
    public func restorePersistedSession() async {
        guard let savedValue = KeychainManager.shared.read(.sessionToken, server: server.baseURL),
              !savedValue.isEmpty,
              let url = URL(string: server.baseURL),
              let host = url.host else {
            return
        }
        let properties: [HTTPCookiePropertyKey: Any] = [
            .name:   "connect.sid",
            .value:  savedValue,
            .domain: host,
            .path:   "/"
        ]
        guard let cookie = HTTPCookie(properties: properties) else { return }
        await apiClient.restoreCookie(cookie)
        AppLogger.info("AuthRepository: restored persisted session cookie for \(host)")
    }

    /// Silently re-authenticates using credentials stored in the Keychain.
    ///
    /// Used when the persisted session cookie has expired. Supports local and
    /// Jellyfin auth. Plex users must re-authenticate interactively (OAuth).
    ///
    /// - Returns: The re-authenticated `User`, or `nil` if no stored credentials exist.
    /// - Throws: `SeerrAPIError` if credentials exist but are rejected by the server.
    public func reAuthenticateWithStoredCredentials() async throws -> User? {
        let km = KeychainManager.shared
        guard let method = km.read(.authMethod, server: server.baseURL) else {
            return nil
        }

        switch method {
        case "local":
            guard let email    = km.read(.username, server: server.baseURL),
                  let password = km.read(.password, server: server.baseURL),
                  !email.isEmpty, !password.isEmpty else {
                return nil
            }
            AppLogger.info("AuthRepository: attempting silent local re-auth for \(server.baseURL)")
            return try await loginLocal(email: email, password: password)

        case "jellyfin":
            guard let username = km.read(.username, server: server.baseURL),
                  let password = km.read(.password, server: server.baseURL),
                  !username.isEmpty, !password.isEmpty else {
                return nil
            }
            let hostname = km.read(.jellyfinHostname, server: server.baseURL)
            let effectiveHostname = (hostname?.isEmpty == false) ? hostname : nil
            AppLogger.info("AuthRepository: attempting silent Jellyfin re-auth for \(server.baseURL)")
            return try await loginJellyfin(username: username, password: password, hostname: effectiveHostname)

        default:
            // "plex" or unknown — no reusable credentials; interactive login required.
            return nil
        }
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

    /// Clears all credentials (API key, session token, username, password, auth method)
    /// from the Keychain. Call on explicit user logout.
    public func clearStoredCredentials() {
        KeychainManager.shared.deleteAll(server: server.baseURL)
    }
}

// MARK: - EmptyResponse

/// Dummy `Decodable` type used when the server returns an empty body on success.
private struct EmptyResponse: Decodable {}
