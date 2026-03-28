// TMDBImageURL.swift
// SeerrClient
//
// Helpers for constructing full TMDB image URLs from the relative path strings
// returned by the Seerr API (e.g. "/abc123.jpg").
// All image requests go through the TMDB CDN at https://image.tmdb.org/t/p/.

import Foundation
import SwiftUI

// MARK: - TMDBImageSize

/// TMDB poster image size variants.
///
/// Use the smallest size that satisfies your layout to minimise bandwidth.
public enum TMDBPosterSize: String, CaseIterable, Sendable {
    case w92   = "w92"
    case w154  = "w154"
    case w185  = "w185"
    case w342  = "w342"
    case w500  = "w500"
    case w780  = "w780"
    case original = "original"

    /// Recommended size for a standard media card thumbnail (~170 pt wide).
    public static let card: TMDBPosterSize = .w342
    /// Recommended size for detail view hero poster (~300 pt wide).
    public static let detail: TMDBPosterSize = .w500
}

/// TMDB backdrop image size variants.
public enum TMDBBackdropSize: String, CaseIterable, Sendable {
    case w300  = "w300"
    case w780  = "w780"
    case w1280 = "w1280"
    case original = "original"

    /// Recommended size for a card banner.
    public static let card: TMDBBackdropSize = .w780
    /// Recommended size for a full-screen hero backdrop.
    public static let hero: TMDBBackdropSize = .w1280
}

/// TMDB profile (person) image size variants.
public enum TMDBProfileSize: String, CaseIterable, Sendable {
    case w45   = "w45"
    case w185  = "w185"
    case h632  = "h632"
    case original = "original"

    /// Recommended size for a cast member avatar.
    public static let avatar: TMDBProfileSize = .w185
}

// MARK: - TMDBImageURL

/// Builds full TMDB CDN URLs from the relative path strings returned by the API.
///
/// All API responses contain image paths like `"/abc123.jpg"` or `nil`.
/// Pass them to the static helpers on this type to get a usable `URL`.
///
/// Usage:
/// ```swift
/// // Poster for a media card:
/// let url = TMDBImageURL.poster(path: movie.posterPath, size: .card)
///
/// // Backdrop for a detail hero:
/// let url = TMDBImageURL.backdrop(path: movie.backdropPath, size: .hero)
///
/// // In a SwiftUI view:
/// AsyncImage(url: TMDBImageURL.poster(path: movie.posterPath))
/// ```
public enum TMDBImageURL {

    // MARK: - Constants

    /// Base URL for all TMDB CDN images.
    static let baseURL = "https://image.tmdb.org/t/p/"

    // MARK: - Poster

    /// Constructs a poster image URL for the given relative path and size.
    ///
    /// - Parameters:
    ///   - path: Relative image path from the API (e.g. `"/abc123.jpg"`). Returns `nil` if `nil` is passed.
    ///   - size: The desired size variant. Defaults to `.card`.
    /// - Returns: A fully-qualified `URL`, or `nil` if `path` is `nil` or malformed.
    public static func poster(
        path: String?,
        size: TMDBPosterSize = .card
    ) -> URL? {
        build(path: path, sizeSegment: size.rawValue)
    }

    // MARK: - Backdrop

    /// Constructs a backdrop image URL for the given relative path and size.
    ///
    /// - Parameters:
    ///   - path: Relative image path from the API. Returns `nil` if `nil` is passed.
    ///   - size: The desired size variant. Defaults to `.card`.
    /// - Returns: A fully-qualified `URL`, or `nil` if `path` is `nil` or malformed.
    public static func backdrop(
        path: String?,
        size: TMDBBackdropSize = .card
    ) -> URL? {
        build(path: path, sizeSegment: size.rawValue)
    }

    // MARK: - Profile

    /// Constructs a profile (person) image URL for the given relative path and size.
    ///
    /// - Parameters:
    ///   - path: Relative image path from the API. Returns `nil` if `nil` is passed.
    ///   - size: The desired size variant. Defaults to `.avatar`.
    /// - Returns: A fully-qualified `URL`, or `nil` if `path` is `nil` or malformed.
    public static func profile(
        path: String?,
        size: TMDBProfileSize = .avatar
    ) -> URL? {
        build(path: path, sizeSegment: size.rawValue)
    }

    // MARK: - Still (Episode)

    /// Constructs an episode still image URL for the given relative path and size.
    ///
    /// Episode stills use the same CDN path structure as backdrops.
    ///
    /// - Parameters:
    ///   - path: Relative image path from the API (e.g. from `Episode.stillPath`).
    ///   - size: The desired size variant. Defaults to `.w780`.
    /// - Returns: A fully-qualified `URL`, or `nil` if `path` is `nil` or malformed.
    public static func still(
        path: String?,
        size: TMDBBackdropSize = .w780
    ) -> URL? {
        build(path: path, sizeSegment: size.rawValue)
    }

    // MARK: - Generic

    /// Constructs a TMDB image URL with an arbitrary size segment.
    ///
    /// Use the typed overloads (`poster`, `backdrop`, `profile`) when possible.
    ///
    /// - Parameters:
    ///   - path: Relative image path from the API.
    ///   - sizeSegment: Raw size segment string (e.g. `"w342"`, `"original"`).
    /// - Returns: A fully-qualified `URL`, or `nil` if `path` is `nil` or malformed.
    public static func build(path: String?, sizeSegment: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        // Ensure the path starts with "/" for correct URL concatenation.
        let normalised = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: "\(baseURL)\(sizeSegment)\(normalised)")
    }
}

// MARK: - SwiftUI Convenience

public extension TMDBImageURL {

    /// Returns a SwiftUI `AsyncImage` for a poster path.
    ///
    /// - Parameters:
    ///   - path: Relative poster path from the API.
    ///   - size: Desired size variant. Defaults to `.card`.
    ///   - content: Closure receiving the loaded `Image`.
    ///   - placeholder: Placeholder view shown while loading or on failure.
    @ViewBuilder
    static func posterImage<Content: View, Placeholder: View>(
        path: String?,
        size: TMDBPosterSize = .card,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) -> some View {
        AsyncImage(url: poster(path: path, size: size)) { phase in
            switch phase {
            case .success(let image): content(image)
            default:                 placeholder()
            }
        }
    }
}
