// TvShowDetailView.swift
// SeerrClient
//
// Full detail screen for a TV show. Shows hero backdrop+poster, metadata,
// cast carousel, season picker, episode list, and request button.
// Uses dual state machines: one for show details, one for season episodes.

import SwiftUI

// MARK: - TvShowDetailView

/// Full TV show detail screen accessible from Discover and Search.
struct TvShowDetailView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    /// The TMDB TV show ID to load.
    let tvId: Int
    /// The show title for the navigation bar (known before detail loads).
    let showTitle: String

    // MARK: - State

    @State private var viewModel: TvShowDetailViewModel?

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                contentForState(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(showTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                guard let client = appState.apiClient else { return }
                let repo = MediaDetailRepository(apiClient: client)
                viewModel = TvShowDetailViewModel(tvId: tvId, repository: repo)
            }
            await viewModel?.loadDetails()
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private func contentForState(_ vm: TvShowDetailViewModel) -> some View {
        switch vm.detailState {
        case .idle, .loading:
            loadingContent

        case .loaded(let tvShow):
            loadedContent(tvShow, vm: vm)

        case .error(let message):
            errorContent(message: message, vm: vm)
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay { ShimmerView() }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 14)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ tvShow: TvDetails, vm: TvShowDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero
                MediaDetailHeroView(
                    backdropPath: tvShow.backdropPath,
                    posterPath: tvShow.posterPath,
                    mediaInfo: tvShow.mediaInfo
                )

                // Metadata
                let firstYear = tvShow.firstAirDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
                let endYear: String? = {
                    guard let status = tvShow.status, status == "Ended" else { return nil }
                    return tvShow.lastAirDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
                }()
                let runtime: String? = {
                    if let eps = tvShow.numberOfEpisodes, let seasons = tvShow.numberOfSeason {
                        return "\(seasons) seasons, \(eps) episodes"
                    }
                    return nil
                }()

                MediaMetadataView(
                    title: tvShow.name ?? showTitle,
                    tagline: tvShow.tagline,
                    overview: tvShow.overview,
                    year: firstYear,
                    endYear: endYear,
                    runtime: runtime,
                    rating: tvShow.voteAverage,
                    genres: tvShow.genres,
                    status: tvShow.status
                )

                // Cast
                CastCarouselView(credits: tvShow.credits)

                // Season Picker + Episodes
                if let seasons = tvShow.seasons, !seasons.isEmpty {
                    seasonSection(seasons: seasons, vm: vm)
                }

                // Request Button
                RequestButtonView(
                    mediaInfo: tvShow.mediaInfo,
                    showRequestSheet: Binding(
                        get: { vm.showRequestSheet },
                        set: { vm.showRequestSheet = $0 }
                    )
                )

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.showRequestSheet },
            set: { vm.showRequestSheet = $0 }
        )) {
            // Week 6: Replace with actual RequestFormSheet
            Text("Request form coming in Week 6")
                .presentationDetents([.medium])
        }
    }

    // MARK: - Season Section

    @ViewBuilder
    private func seasonSection(seasons: [Season], vm: TvShowDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Season Picker
            HStack {
                Text("Season")
                    .font(.title3.bold())

                Spacer()

                Picker("Season", selection: Binding(
                    get: { vm.selectedSeasonNumber },
                    set: { vm.selectedSeasonNumber = $0 }
                )) {
                    ForEach(seasons, id: \.seasonNumber) { season in
                        Text(season.name ?? "Season \(season.seasonNumber ?? 0)")
                            .tag(season.seasonNumber ?? 0)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)

            // Episode List
            if let loadedSeason = vm.season {
                EpisodeListView(season: loadedSeason, loadState: vm.seasonState)
            } else {
                switch vm.seasonState {
                case .loading:
                    ProgressView("Loading episodes...")
                        .frame(maxWidth: .infinity)
                        .padding()
                case .error(let message):
                    VStack(spacing: 8) {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await vm.retrySeason() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private func errorContent(message: String, vm: TvShowDetailViewModel) -> some View {
        ContentUnavailableView {
            Label("Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await vm.retryDetails() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
