// SeerrAPIClient.swift
// SeerrClient
//
// The single HTTP client for all Seerr API calls. Actor-isolated for thread
// safety. Handles URL construction, auth headers, JSON encoding/decoding,
// cookie management, error mapping, and configurable timeouts.
//
// Repositories and ViewModels never build URLs themselves — they call this
// client with paths from APIEndpoints.

import Foundation

// MARK: - SeerrAPIClient

/// Actor-isolated HTTP client for the Seerr REST API.
///
/// Create one instance per active server:
/// ```swift
/// let client = SeerrAPIClient(server: myServerConfig)
/// let user: User = try await client.get(APIEndpoints.v1.authMe)
/// ```
///
/// Authentication is injected automatically:
/// - If the server has an API key stored in Keychain, it is added as
///   `X-Api-Key` on every request.
/// - Session cookies set by `/auth/*` endpoints are maintained in the
///   client's private `HTTPCookieStorage` and sent automatically.
public actor SeerrAPIClient {

    // MARK: - Constants

    /// Default request timeout (seconds).
    static let defaultTimeout: TimeInterval = 30
    /// Extended timeout for media-heavy operations (scan, sync, etc.).
    static let mediaOperationTimeout: TimeInterval = 60

    // MARK: - Properties

    /// Normalised base URL for the active server (no trailing slash).
    private let baseURL: String

    /// The server configuration this client was created for.
    private let serverConfig: ServerConfiguration

    /// Session cookies stored directly on the actor. Private `HTTPCookieStorage()`
    /// instances silently drop cookies, so we manage them manually.
    private var storedCookies: [HTTPCookie] = []

    /// The URLSession used for all requests.
    private let session: URLSession

    /// The trust manager delegate (also the session delegate for cert challenges).
    private let trustManager: TrustManager

    /// JSON decoder: converts `snake_case` keys to `camelCase` Swift property names.
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// JSON encoder: preserves `camelCase` property names as-is.
    /// The Overseerr/Jellyseerr API expects camelCase keys in request bodies.
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    /// Endpoint path registry (v1). Nonisolated because it's an immutable constant.
    public nonisolated let endpoints = APIEndpoints.v1

    // MARK: - Init

    /// Creates an API client for the given server configuration.
    ///
    /// - Parameters:
    ///   - server: The `ServerConfiguration` describing the target server.
    ///   - serverStore: The store used to read/write certificate fingerprints.
    public init(server: ServerConfiguration, serverStore: ServerStore) {
        self.baseURL = server.baseURL
        self.serverConfig = server

        let trustMgr = TrustManager(serverURL: server.baseURL, serverStore: serverStore)
        self.trustManager = trustMgr

        let config = URLSessionConfiguration.default
        // Disable automatic cookie handling — we manage cookies manually
        // via storedCookies because private HTTPCookieStorage instances
        // silently drop cookies.
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = SeerrAPIClient.defaultTimeout
        config.timeoutIntervalForResource = SeerrAPIClient.mediaOperationTimeout

        self.session = URLSession(
            configuration: config,
            delegate: trustMgr,
            delegateQueue: nil
        )
    }

    // MARK: - GET

    /// Performs a `GET` request and decodes the response body as `T`.
    ///
    /// - Parameters:
    ///   - path: An endpoint path from `APIEndpoints` (e.g. `endpoints.search`).
    ///   - queryItems: Optional query parameters appended to the URL.
    ///   - timeout: Override the default request timeout in seconds.
    /// - Returns: A decoded value of type `T`.
    /// - Throws: `SeerrAPIError` on any network, HTTP, or decoding failure.
    public func get<T: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let request = try buildRequest(
            method: "GET",
            path: path,
            queryItems: queryItems,
            body: nil as Data?,
            timeout: timeout
        )
        return try await perform(request)
    }

    // MARK: - POST

    /// Performs a `POST` request with an `Encodable` body and decodes the response.
    ///
    /// - Parameters:
    ///   - path: An endpoint path from `APIEndpoints`.
    ///   - body: An `Encodable` value to JSON-encode as the request body.
    ///   - timeout: Override the default request timeout.
    /// - Returns: A decoded value of type `T`.
    /// - Throws: `SeerrAPIError`.
    public func post<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let bodyData = try encodeBody(body)
        let request = try buildRequest(
            method: "POST",
            path: path,
            queryItems: [],
            body: bodyData,
            timeout: timeout
        )
        return try await perform(request)
    }

    /// Performs a `POST` request with no body and decodes the response.
    public func post<T: Decodable>(
        _ path: String,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let request = try buildRequest(
            method: "POST",
            path: path,
            queryItems: [],
            body: nil as Data?,
            timeout: timeout
        )
        return try await perform(request)
    }

    // MARK: - PUT

    /// Performs a `PUT` request with an `Encodable` body and decodes the response.
    ///
    /// - Parameters:
    ///   - path: An endpoint path from `APIEndpoints`.
    ///   - body: An `Encodable` value to JSON-encode as the request body.
    ///   - timeout: Override the default request timeout.
    /// - Returns: A decoded value of type `T`.
    /// - Throws: `SeerrAPIError`.
    public func put<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let bodyData = try encodeBody(body)
        let request = try buildRequest(
            method: "PUT",
            path: path,
            queryItems: [],
            body: bodyData,
            timeout: timeout
        )
        return try await perform(request)
    }

    // MARK: - PATCH

    /// Performs a `PATCH` request with an `Encodable` body and decodes the response.
    public func patch<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let bodyData = try encodeBody(body)
        let request = try buildRequest(
            method: "PATCH",
            path: path,
            queryItems: [],
            body: bodyData,
            timeout: timeout
        )
        return try await perform(request)
    }

    // MARK: - DELETE

    /// Performs a `DELETE` request and decodes the response.
    ///
    /// - Parameters:
    ///   - path: An endpoint path from `APIEndpoints`.
    ///   - timeout: Override the default request timeout.
    /// - Returns: A decoded value of type `T`.
    /// - Throws: `SeerrAPIError`.
    public func delete<T: Decodable>(
        _ path: String,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let request = try buildRequest(
            method: "DELETE",
            path: path,
            queryItems: [],
            body: nil as Data?,
            timeout: timeout
        )
        return try await perform(request)
    }

    /// Performs a `DELETE` request and discards the response body.
    public func deleteVoid(_ path: String, timeout: TimeInterval? = nil) async throws {
        let request = try buildRequest(
            method: "DELETE",
            path: path,
            queryItems: [],
            body: nil as Data?,
            timeout: timeout
        )
        let (_, response) = try await executeDataTask(for: request)
        try validateHTTPStatus(response, data: Data())
    }

    // MARK: - Cookie Management

    /// Stores a session cookie received outside of a network response
    /// (e.g. injected from a Plex OAuth callback).
    ///
    /// - Parameter cookie: The `HTTPCookie` to store.
    public func storeCookie(_ cookie: HTTPCookie) {
        storedCookies.removeAll { $0.name == cookie.name }
        storedCookies.append(cookie)
    }

    /// Injects a previously persisted cookie (e.g. loaded from Keychain on app launch).
    ///
    /// Used by session restoration to populate the cookie jar before `GET /auth/me`.
    ///
    /// - Parameter cookie: The `HTTPCookie` to inject.
    public func restoreCookie(_ cookie: HTTPCookie) {
        storedCookies.removeAll { $0.name == cookie.name }
        storedCookies.append(cookie)
        AppLogger.debug("SeerrAPIClient: restored cookie '\(cookie.name)' for \(cookie.domain)")
    }

    /// Returns the stored cookie with the given name, or `nil` if not present.
    ///
    /// Use this after a successful login to extract `connect.sid` for Keychain persistence.
    ///
    /// - Parameter name: The cookie name (e.g. `"connect.sid"`).
    /// - Returns: The matching `HTTPCookie`, or `nil`.
    public func cookie(named name: String) -> HTTPCookie? {
        storedCookies.first { $0.name == name }
    }

    /// Removes all cookies for this client.
    public func clearCookies() {
        storedCookies.removeAll()
    }

    // MARK: - Trust Manager Access

    /// Allows the next certificate challenge to succeed unconditionally.
    ///
    /// Call this after the user has explicitly confirmed they want to trust
    /// a self-signed certificate for this server.
    public func allowNextCertificateChallenge() {
        trustManager.allowAllForCurrentChallenge = true
    }

    // MARK: - Private: Request Building

    private func buildRequest<Body: DataConvertible>(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Body?,
        timeout: TimeInterval?
    ) throws -> URLRequest {
        // Construct URL.
        guard var components = URLComponents(string: baseURL + path) else {
            throw SeerrAPIError.invalidURL(baseURL + path)
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw SeerrAPIError.invalidURL(baseURL + path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let timeout {
            request.timeoutInterval = timeout
        }

        // Headers.
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Attach stored session cookies to the request.
        if !storedCookies.isEmpty {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: storedCookies)
            for (header, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: header)
            }
            AppLogger.debug("Attached \(storedCookies.count) cookie(s)")
        }

        // Inject API key if available.
        if let apiKey = KeychainManager.shared.readAPIKey(for: baseURL) {
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        }

        // Body.
        if let bodyData = body?.asData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        AppLogger.debug("[\(method)] \(url.absoluteString)")
        return request
    }

    // MARK: - Private: Execution & Error Mapping

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await executeDataTask(for: request)
        try validateHTTPStatus(response, data: data)
        return try decodeBody(data, as: T.self)
    }

    private func executeDataTask(
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, urlResponse) = try await session.data(for: request)
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw SeerrAPIError.networkError(underlying: URLError(.badServerResponse))
            }
            // Extract and store session cookies from the response.
            if let url = request.url,
               let headerFields = httpResponse.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                for cookie in cookies {
                    storedCookies.removeAll { $0.name == cookie.name }
                    storedCookies.append(cookie)
                }
                if !cookies.isEmpty {
                    AppLogger.debug("Stored \(cookies.count) cookie(s) for \(url.host ?? "")")
                }
            }
            return (data, httpResponse)
        } catch let error as SeerrAPIError {
            throw error
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw SeerrAPIError.networkError(underlying: error)
        }
    }

    private func validateHTTPStatus(_ response: HTTPURLResponse, data: Data) throws {
        let status = response.statusCode
        guard status >= 200 && status < 300 else {
            // Try to extract a detail message from the response body.
            let detail = extractErrorDetail(from: data)
            AppLogger.warning("HTTP \(status) — \(detail ?? "no detail")")
            throw SeerrAPIError.from(statusCode: status, detail: detail)
        }
    }

    private func decodeBody<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            AppLogger.error("Decoding failed: \(error)")
            throw SeerrAPIError.decodingError(underlying: error)
        }
    }

    private func encodeBody<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw SeerrAPIError.networkError(underlying: error)
        }
    }

    private func extractErrorDetail(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        return (try? decoder.decode(APIErrorBody.self, from: data))?.detail
    }

    private func mapURLError(_ error: URLError) -> SeerrAPIError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .cancelled:
            return .cancelled
        case .serverCertificateHasBadDate,
             .serverCertificateUntrusted,
             .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot,
             .clientCertificateRequired,
             .clientCertificateRejected:
            return .sslError(underlying: error)
        default:
            return .networkError(underlying: error)
        }
    }
}

// MARK: - DataConvertible (private helper)

/// Protocol that lets `buildRequest` accept `Data?` and `nil` uniformly.
private protocol DataConvertible {
    var asData: Data? { get }
}

extension Data: DataConvertible {
    var asData: Data? { self.isEmpty ? nil : self }
}

extension Optional: DataConvertible where Wrapped == Data {
    var asData: Data? {
        switch self {
        case .some(let data): return data.isEmpty ? nil : data
        case .none:           return nil
        }
    }
}
