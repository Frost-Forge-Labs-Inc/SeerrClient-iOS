// EpisodeListView.swift
// SeerrClient
//
// A 2-column grid of episodes for a given season. Used within TvShowDetailView
// to display episodes for the selected season.

import SwiftUI

// MARK: - EpisodeListView

/// 2-column grid of episodes for a season.
struct EpisodeListView: View {

    /// The season containing episodes to display.
    let season: Season
    /// Current loading state for the season.
    let loadState: SeasonLoadState

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            contentForState
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var sectionHeader: some View {
        HStack {
            Text("Episodes")
                .font(.title3.bold())

            if let count = season.episodes?.count {
                Text("(\(count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentForState: some View {
        switch loadState {
        case .loading:
            ProgressView("Loading episodes...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)

        case .loaded:
            if let episodes = season.episodes, !episodes.isEmpty {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(episodes, id: \.id) { episode in
                        EpisodeCardView(episode: episode)
                    }
                }
                .padding(.horizontal)
            } else {
                Text("No episodes available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }

        case .error(let message):
            VStack(spacing: 8) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()

        case .idle:
            EmptyView()
        }
    }
}
