// MediaDetailHeroView.swift
// SeerrClient
//
// Hero section for media detail screens. Displays a 16:9 backdrop image
// with a gradient overlay, an overlaid 2:3 poster offset downward, and
// a status badge in the top-trailing corner.

import SwiftUI

// MARK: - MediaDetailHeroView

/// Backdrop + poster overlay hero section for movie and TV detail screens.
struct MediaDetailHeroView: View {

    /// Relative path to the backdrop image (from TMDB).
    let backdropPath: String?
    /// Relative path to the poster image (from TMDB).
    let posterPath: String?
    /// Optional media info for the status badge.
    let mediaInfo: MediaInfo?

    private let posterWidth: CGFloat = 120
    private let posterOverlap: CGFloat = 60

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdropImage
            posterOverlay
        }
        .overlay(alignment: .topTrailing) {
            StatusBadgeView(statusCode: mediaInfo?.status)
                .padding(12)
        }
        // Add bottom padding to account for the poster overlap into content below
        .padding(.bottom, posterOverlap)
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdropImage: some View {
        GeometryReader { geo in
            AsyncImage(url: TMDBImageURL.backdrop(path: backdropPath, size: .w780)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width * 9 / 16)
                        .clipped()
                case .failure:
                    backdropPlaceholder(width: geo.size.width)
                case .empty:
                    backdropPlaceholder(width: geo.size.width)
                        .overlay { ShimmerView() }
                @unknown default:
                    backdropPlaceholder(width: geo.size.width)
                }
            }
            .frame(width: geo.size.width, height: geo.size.width * 9 / 16)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .overlay(alignment: .bottom) {
            // Gradient fade at the bottom of the backdrop
            LinearGradient(
                colors: [.clear, Color(.systemBackground).opacity(0.8), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
        }
    }

    @ViewBuilder
    private func backdropPlaceholder(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: width, height: width * 9 / 16)
    }

    // MARK: - Poster Overlay

    @ViewBuilder
    private var posterOverlay: some View {
        AsyncImage(url: TMDBImageURL.poster(path: posterPath, size: .w342)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
            case .failure:
                posterPlaceholder
            case .empty:
                posterPlaceholder
                    .overlay { ShimmerView() }
            @unknown default:
                posterPlaceholder
            }
        }
        .frame(width: posterWidth)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .padding(.leading, 16)
        .offset(y: posterOverlap)
    }

    @ViewBuilder
    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(.systemGray5))
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                Image(systemName: "film")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
    }
}
