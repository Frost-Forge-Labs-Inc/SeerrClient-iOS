// APIError.swift
// SeerrClient
//
// Typed error domain for all failures originating in the networking layer.
// Every throwing function in SeerrAPIClient surfaces one of these cases so
// callers can give precise, localised feedback to the user.

import Foundation

// MARK: - SeerrAPIError

/// All possible failures from `SeerrAPIClient` and related networking code.
///
/// Usage in a ViewModel:
/// ```swift
/// do {
///     let user = try await apiClient.get(endpoints.authMe, as: User.self)
/// } catch let error as SeerrAPIError {
///     switch error {
///     case .unauthorized: appState.signOut()
///     default: showError(error.userMessage)
///     }
/// }
/// ```
public enum SeerrAPIError: Error, LocalizedError, Sendable {

    // MARK: - Cases

    /// The URL could not be constructed (e.g. base URL is malformed).
    case invalidURL(String)

    /// A transport-level failure (no connectivity, DNS, etc.).
    case networkError(underlying: Error)

    /// The server responded with an HTTP error status.
    /// - Parameters:
    ///   - statusCode: The HTTP status code (e.g. 404, 500).
    ///   - message: The `detail` field from the JSON body, if present.
    case httpError(statusCode: Int, message: String?)

    /// The response body could not be decoded into the expected type.
    case decodingError(underlying: Error)

    /// 401 Unauthorized — session expired or API key invalid.
    case unauthorized

    /// 403 Forbidden — user lacks permission.
    case forbidden

    /// 404 Not Found — the requested resource does not exist.
    case notFound

    /// 409 Conflict — a duplicate resource or conflicting state (e.g. request already exists).
    case conflict(message: String?)

    /// 429 Too Many Requests — server-side rate limiting.
    case rateLimited

    /// 5xx Server Error.
    case serverError(statusCode: Int, message: String?)

    /// The request timed out.
    case timeout

    /// SSL/TLS error (e.g. untrusted certificate, handshake failure).
    case sslError(underlying: Error)

    /// A request was cancelled (e.g. task was cancelled via Swift Concurrency).
    case cancelled

    // MARK: - LocalizedError

    /// A user-facing message suitable for display in an alert or inline error view.
    public var userMessage: String {
        switch self {
        case .invalidURL(let url):
            return "Invalid server URL: \(url)"
        case .networkError:
            return "Cannot connect to the server. Check your network and server address."
        case .httpError(let code, let msg):
            if let msg, !msg.isEmpty {
                return "Server error (\(code)): \(msg)"
            }
            return "Server returned an error (HTTP \(code))."
        case .decodingError:
            return "The server returned an unexpected response. Please check your server version."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .notFound:
            return "The requested content was not found."
        case .conflict(let msg):
            return msg ?? "A conflict occurred (the request may already exist)."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(let code, let msg):
            if let msg, !msg.isEmpty {
                return "Server error (\(code)): \(msg)"
            }
            return "The server encountered an error. Please try again later."
        case .timeout:
            return "The connection timed out. Check your network or server address."
        case .sslError:
            return "A secure connection could not be established. The server may use a self-signed certificate."
        case .cancelled:
            return "The request was cancelled."
        }
    }

    public var errorDescription: String? { userMessage }

    // MARK: - Factory

    /// Maps an HTTP status code and optional JSON body to a `SeerrAPIError`.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP response status code.
    ///   - detail: Optional `detail` string parsed from the JSON error body.
    /// - Returns: The most specific `SeerrAPIError` for this status code.
    static func from(statusCode: Int, detail: String?) -> SeerrAPIError {
        switch statusCode {
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 409: return .conflict(message: detail)
        case 429: return .rateLimited
        case 500...599: return .serverError(statusCode: statusCode, message: detail)
        default:  return .httpError(statusCode: statusCode, message: detail)
        }
    }
}

// MARK: - API Error Body

/// Minimal JSON structure for error responses from Seerr.
///
/// Example: `{ "message": "...", "errors": [...] }`
struct APIErrorBody: Decodable {
    let message: String?
    let errors: [String]?

    /// The most useful human-readable detail string from this error body.
    var detail: String? {
        if let message, !message.isEmpty { return message }
        if let first = errors?.first, !first.isEmpty { return first }
        return nil
    }
}
