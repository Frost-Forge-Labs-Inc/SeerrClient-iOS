// DateFormatting.swift
// SeerrClient
//
// Shared date formatters for parsing ISO 8601 API responses and formatting
// dates for display in the UI. All formatters are created once and reused —
// DateFormatter is expensive to instantiate.

import Foundation

// MARK: - SeerrDateFormatter

/// A namespace for shared date formatters used throughout the app.
///
/// Usage:
/// ```swift
/// // Parse an API date string:
/// let date = SeerrDateFormatter.iso8601.date(from: "2024-03-15T10:30:00.000Z")
///
/// // Format for display:
/// let display = SeerrDateFormatter.mediumDate.string(from: date!)
/// // → "Mar 15, 2024"
///
/// // Year only:
/// let year = SeerrDateFormatter.year.string(from: date!)
/// // → "2024"
/// ```
public enum SeerrDateFormatter {

    // MARK: - ISO 8601 Parsers

    /// Full ISO 8601 parser with fractional seconds and timezone (e.g. `"2024-03-15T10:30:00.000Z"`).
    /// Used for `createdAt`, `updatedAt` fields returned by the API.
    public static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// ISO 8601 parser without fractional seconds (e.g. `"2024-03-15T10:30:00Z"`).
    /// Some API fields omit the fractional seconds component.
    public static let iso8601NoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Date-only Parser

    /// Parses simple `YYYY-MM-DD` date strings returned for `releaseDate`,
    /// `firstAirDate`, `airDate`, etc.
    public static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    // MARK: - Display Formatters

    /// Abbreviated date: `"Mar 15, 2024"`.
    public static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// Long date: `"March 15, 2024"`.
    public static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    /// Short date: `"3/15/24"`.
    public static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    /// Year only: `"2024"`.
    public static let year: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy"
        return f
    }()

    /// Relative time (e.g. `"2 hours ago"`, `"Yesterday"`).
    /// Backed by `RelativeDateTimeFormatter`.
    public static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

// MARK: - Parsing Helpers

public extension SeerrDateFormatter {

    /// Parses any ISO 8601 string returned by the Seerr API.
    ///
    /// Tries full ISO 8601 with fractional seconds first, then falls back to
    /// the version without fractional seconds, then the date-only format.
    ///
    /// - Parameter string: An ISO 8601 or `YYYY-MM-DD` string from the API.
    /// - Returns: A `Date`, or `nil` if none of the formats matched.
    static func parseAPIDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let date = iso8601.date(from: string)         { return date }
        if let date = iso8601NoFractional.date(from: string) { return date }
        if let date = dateOnly.date(from: string)        { return date }
        return nil
    }

    /// Formats a raw API date string for display using `mediumDate`.
    ///
    /// - Parameter string: An ISO 8601 or `YYYY-MM-DD` string from the API.
    /// - Returns: A formatted display string, or `"Unknown"` if parsing fails.
    static func displayDate(_ string: String?) -> String {
        guard let date = parseAPIDate(string) else { return "Unknown" }
        return mediumDate.string(from: date)
    }

    /// Extracts the year from a raw API date string.
    ///
    /// - Parameter string: An ISO 8601 or `YYYY-MM-DD` string from the API.
    /// - Returns: A 4-digit year string (e.g. `"2024"`), or `nil` on failure.
    static func yearString(from string: String?) -> String? {
        guard let date = parseAPIDate(string) else { return nil }
        return year.string(from: date)
    }

    /// Returns a relative time string for a raw API date (e.g. `"2 hr. ago"`).
    ///
    /// - Parameter string: An ISO 8601 or `YYYY-MM-DD` string from the API.
    /// - Returns: A relative time string, or `nil` on failure.
    static func relativeString(from string: String?) -> String? {
        guard let date = parseAPIDate(string) else { return nil }
        return relative.localizedString(for: date, relativeTo: Date())
    }
}
