// MediaMetadataView.swift
// SeerrClient
//
// Displays metadata for a movie or TV show: title, year, runtime/episode count,
// rating, genres, and overview text.

import SwiftUI

// MARK: - MediaMetadataView

/// Metadata section showing title, year, runtime, rating, genres, and overview.
struct MediaMetadataView: View {

    let title: String
    let tagline: String?
    let overview: String?
    let year: String?
    let endYear: String?
    let runtime: String?
    let rating: Double?
    let genres: [Genre]?
    let status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            // Tagline
            if let tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // Metadata pills row
            metadataRow

            // Genre chips
            if let genres, !genres.isEmpty {
                genreRow(genres)
            }

            // Overview
            if let overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Metadata Row

    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: 12) {
            // Year
            if let year {
                let yearText = endYear.map { "\(year)–\($0)" } ?? year
                metadataPill(systemImage: "calendar", text: yearText)
            }

            // Runtime
            if let runtime {
                metadataPill(systemImage: "clock", text: runtime)
            }

            // Rating
            if let rating, rating > 0 {
                metadataPill(systemImage: "star.fill", text: String(format: "%.1f", rating))
            }

            // Status
            if let status {
                metadataPill(systemImage: "info.circle", text: status)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func metadataPill(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(text)
        }
    }

    // MARK: - Genre Row

    @ViewBuilder
    private func genreRow(_ genres: [Genre]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(genres.prefix(5), id: \.id) { genre in
                    Text(genre.name ?? "")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
        }
    }
}
