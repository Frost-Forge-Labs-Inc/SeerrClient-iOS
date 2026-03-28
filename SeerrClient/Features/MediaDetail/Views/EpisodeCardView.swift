// EpisodeCardView.swift
// SeerrClient
//
// A card for a single TV episode. Shows a 16:9 still thumbnail, episode
// number, title, air date, and rating.

import SwiftUI

// MARK: - EpisodeCardView

/// Displays a single episode with still image, number, title, and metadata.
struct EpisodeCardView: View {

    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            stillImage
            episodeInfo
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Still Image

    @ViewBuilder
    private var stillImage: some View {
        AsyncImage(url: TMDBImageURL.still(path: episode.stillPath)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(16.0 / 9.0, contentMode: .fill)
            case .failure:
                stillPlaceholder
            case .empty:
                stillPlaceholder
                    .overlay { ShimmerView() }
            @unknown default:
                stillPlaceholder
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottomLeading) {
            if let num = episode.episodeNumber {
                Text("E\(num)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(6)
            }
        }
    }

    @ViewBuilder
    private var stillPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                Image(systemName: "tv")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Episode Info

    @ViewBuilder
    private var episodeInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(episode.name ?? "Episode \(episode.episodeNumber ?? 0)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 8) {
                if let airDate = episode.airDate, !airDate.isEmpty {
                    Text(SeerrDateFormatter.displayDate(airDate))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let rating = episode.voteAverage, rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text(String(format: "%.1f", rating))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var desc = "Episode \(episode.episodeNumber ?? 0)"
        if let name = episode.name {
            desc += ": \(name)"
        }
        if let airDate = episode.airDate {
            desc += ", aired \(SeerrDateFormatter.displayDate(airDate))"
        }
        return desc
    }
}
