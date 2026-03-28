// URLNormalizer.swift
// SeerrClient
//
// Converts user-entered server addresses into well-formed base URLs.
// Handles every format a home-server user might type:
//   192.168.1.50          → http://192.168.1.50:5055
//   192.168.1.50:8096     → http://192.168.1.50:8096
//   seerr.local           → http://seerr.local:5055
//   http://seerr.local    → http://seerr.local:5055
//   https://seerr.home    → https://seerr.home   (standard HTTPS port — no append)
//   https://media.example.com:8443  → https://media.example.com:8443

import Foundation

// MARK: - URLNormalizer

/// Normalises raw user input into a fully-qualified base URL string.
///
/// Rules:
/// - If no scheme is present, `http://` is prepended (most home setups use HTTP).
/// - If no explicit port is present AND the scheme is not using its standard port
///   (80 for HTTP, 443 for HTTPS), port **5055** (Seerr default) is appended.
/// - Any trailing slash is stripped.
/// - The result never includes a path component — repositories append endpoint
///   paths from `APIEndpoints` themselves.
///
/// Usage:
/// ```swift
/// let normalized = try URLNormalizer.normalize("192.168.1.50:5055")
/// // → "http://192.168.1.50:5055"
///
/// let secure = try URLNormalizer.normalize("https://media.example.com")
/// // → "https://media.example.com"  (standard port omitted)
/// ```
public enum URLNormalizer {

    // MARK: - Constants

    /// Default scheme used when the user does not specify one.
    static let defaultScheme = "http"

    /// Default port appended when no port is given and the scheme is not at its
    /// standard port.
    static let defaultPort = 5055

    // MARK: - Public API

    /// Normalises a raw user-entered string to a base URL string.
    ///
    /// - Parameter rawInput: The string as typed by the user.
    /// - Returns: A normalised base URL string (no trailing slash, no path).
    /// - Throws: `SeerrAPIError.invalidURL` if the result is not a valid URL.
    public static func normalize(_ rawInput: String) throws -> String {
        var input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            throw SeerrAPIError.invalidURL("Empty input")
        }

        // Step 1: Inject a scheme if none is present.
        // A bare IP or hostname has no "://" so we add "http://".
        if !input.contains("://") {
            input = "\(defaultScheme)://\(input)"
        }

        // Step 2: Parse with URLComponents for structured access.
        guard var components = URLComponents(string: input) else {
            throw SeerrAPIError.invalidURL(rawInput)
        }

        // Step 3: Ensure we have a non-empty host.
        guard let host = components.host, !host.isEmpty else {
            throw SeerrAPIError.invalidURL(rawInput)
        }

        // Step 4: Add default port when needed.
        let scheme = components.scheme ?? defaultScheme
        if components.port == nil {
            if scheme == "http" {
                // Home Seerr instances run on 5055, not 80 — always add the default port.
                components.port = defaultPort
            }
            // For HTTPS without an explicit port, 443 is implied — leave it as-is.
        }

        // Step 5: Strip any path (we don't want /some/path in the base URL).
        components.path = ""
        components.query = nil
        components.fragment = nil

        guard let result = components.url?.absoluteString else {
            throw SeerrAPIError.invalidURL(rawInput)
        }

        // Strip trailing slash.
        return result.hasSuffix("/") ? String(result.dropLast()) : result
    }

    /// Returns `true` when `rawInput` appears to be a valid, reachable URL format.
    ///
    /// This is a lightweight syntactic check — it does not make a network call.
    ///
    /// - Parameter rawInput: The string to validate.
    public static func isLikelyValid(_ rawInput: String) -> Bool {
        (try? normalize(rawInput)) != nil
    }

    /// Extracts just the display-friendly host[:port] from a normalised base URL.
    ///
    /// - Parameter baseURL: A normalised base URL string.
    /// - Returns: A string like `"192.168.1.50:5055"` or `"seerr.local"`.
    public static func displayHost(from baseURL: String) -> String {
        guard let components = URLComponents(string: baseURL),
              let host = components.host else {
            return baseURL
        }
        if let port = components.port {
            return "\(host):\(port)"
        }
        return host
    }
}
