// MediaCardView.swift
// SeerrClient
//
// A reusable media card component that displays a poster image, title, year,
// and optional availability status badge. Used in discover slider rows, search
// results, and anywhere a compact media preview is needed.

import SwiftUI

// MARK: - MediaCardSize

/// Size presets for the media card, controlling the poster width.
/// The height is always derived from the 2:3 poster aspect ratio.
enum MediaCardSize {
    case small   // 100 pt wide — compact lists
    case medium  // 130 pt wide — default discover row
    case large   // 160 pt wide — featured / hero rows
    case custom(CGFloat)

    var width: CGFloat {
        switch self {
        case .small:  return 100
        case .medium: return 130
        case .large:  return 160
        case .custom(let width): return width
        }
    }

    /// Height derived from 2:3 poster aspect ratio.
    var posterHeight: CGFloat { width * 1.5 }
}

// MARK: - MediaCardView

/// Displays a single media item as a poster card with title and optional status badge.
///
/// Usage:
/// ```swift
/// MediaCardView(item: discoverItem, size: .medium) {
///     // navigate to detail
/// }
/// ```
struct MediaCardView: View {

    /// The media item to display.
    let item: DiscoverMediaItem

    /// Size variant. Defaults to `.medium`.
    var size: MediaCardSize = .medium

    /// Overrides `item.posterPath` when the API doesn't include it (e.g. watchlist endpoint).
    var posterPathOverride: String? = nil

    /// Overrides the year derived from `item.year` when the API doesn't include
    /// release/air date fields (e.g. watchlist endpoint). Pass a pre-extracted year
    /// string such as `"1999"` or a range like `"1999–2007"`.
    var yearOverride: String? = nil

    /// Action triggered when the card is tapped.
    var onTap: (() -> Void)?

    var body: some View {
        if let onTap {
            Button {
                onTap()
            } label: {
                cardContent
            }
            .buttonStyle(MediaCardButtonStyle())
        } else {
            // When no tap action is provided the card is expected to be wrapped
            // in a NavigationLink or similar container. Avoid nesting a Button
            // inside another interactive element which causes duplicate taps.
            cardContent
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            posterImage
            titleSection
        }
        .frame(width: size.width)
    }

    // MARK: - Poster

    @ViewBuilder
    private var posterImage: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: TMDBImageURL.poster(path: posterPathOverride ?? item.posterPath, size: .card)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    posterPlaceholder
                case .empty:
                    skeletonPlaceholder
                @unknown default:
                    posterPlaceholder
                }
            }
            .frame(width: size.width, height: size.posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Status badge overlay
            StatusBadgeView(statusCode: item.mediaInfo?.status)
                .padding(6)
        }
    }

    /// Gradient placeholder shown when no poster is available or loading fails.
    @ViewBuilder
    private var posterPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemGray5), Color(.systemGray4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(width: size.width, height: size.posterHeight)
    }

    /// Shimmer placeholder shown during initial image load.
    @ViewBuilder
    private var skeletonPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(width: size.width, height: size.posterHeight)
            .overlay {
                ShimmerView()
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Title

    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.displayTitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let year = yearOverride ?? item.year {
                Text(year)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Button Style

/// Custom button style that scales down slightly on press for tactile feedback.
private struct MediaCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Media Card") {
    let item = DiscoverMediaItem(
        id: 603,
        tmdbId: 603,
        mediaType: "movie",
        title: "The Matrix",
        name: nil,
        posterPath: "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
        backdropPath: nil,
        overview: "Set in the 22nd century...",
        voteAverage: 8.7,
        releaseDate: "1999-03-31",
        firstAirDate: nil,
        genreIds: [28, 878],
        mediaInfo: MediaInfo(
            id: 1,
            tmdbId: 603,
            tvdbId: nil,
            status: 5,
            seasons: nil,
            requests: nil,
            createdAt: nil,
            updatedAt: nil,
            watchlisted: false
        )
    )

    HStack(spacing: 16) {
        MediaCardView(item: item, size: .small)
        MediaCardView(item: item, size: .medium)
        MediaCardView(item: item, size: .large)
    }
    .padding()
}

#Preview("No Poster") {
    let item = DiscoverMediaItem(
        id: 1,
        tmdbId: nil,
        mediaType: "tv",
        title: nil,
        name: "A Very Long TV Show Name That Should Truncate",
        posterPath: nil,
        backdropPath: nil,
        overview: nil,
        voteAverage: nil,
        releaseDate: nil,
        firstAirDate: "2024-01-15",
        genreIds: nil,
        mediaInfo: nil
    )

    MediaCardView(item: item)
        .padding()
}
