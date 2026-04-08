// MovieDetailView.swift
// SeerrClient
//
// Full detail screen for a movie. Shows hero backdrop+poster, metadata,
// cast carousel, and request button. Loads details on appear via ViewModel.

import SwiftUI

// MARK: - MovieDetailView

/// Full movie detail screen accessible from Discover and Search.
struct MovieDetailView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    /// The TMDB movie ID to load.
    let movieId: Int
    /// The movie title for the navigation bar (known before detail loads).
    let movieTitle: String

    // MARK: - State

    @State private var viewModel: MovieDetailViewModel?

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                contentForState(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(movieTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let vm = viewModel, vm.movie?.mediaInfo?.id != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        vm.toggleWatchlist()
                    } label: {
                        if vm.isTogglingWatchlist {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: vm.isOnWatchlist ? "bookmark.fill" : "bookmark")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                    .accessibilityLabel(vm.isOnWatchlist ? "Remove from Watchlist" : "Add to Watchlist")
                }
            }
        }
        .task {
            if viewModel == nil {
                guard let client = appState.apiClient else { return }
                let repo = MediaDetailRepository(apiClient: client)
                viewModel = MovieDetailViewModel(movieId: movieId, repository: repo)
            }
            await viewModel?.loadDetails()
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private func contentForState(_ vm: MovieDetailViewModel) -> some View {
        switch vm.loadState {
        case .idle, .loading:
            loadingContent

        case .loaded(let movie):
            loadedContent(movie, vm: vm)

        case .error(let message):
            errorContent(message: message, vm: vm)
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Backdrop skeleton
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay { ShimmerView() }

                // Metadata skeleton
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
    private func loadedContent(_ movie: MovieDetails, vm: MovieDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero
                MediaDetailHeroView(
                    backdropPath: movie.backdropPath,
                    posterPath: movie.posterPath,
                    mediaInfo: movie.mediaInfo
                )

                // Metadata
                MediaMetadataView(
                    title: movie.title ?? movieTitle,
                    tagline: movie.tagline,
                    overview: movie.overview,
                    year: movie.releaseDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil },
                    endYear: nil,
                    runtime: movie.runtime.flatMap { "\($0) min" },
                    rating: movie.voteAverage,
                    genres: movie.genres,
                    status: movie.status
                )

                // Cast
                CastCarouselView(credits: movie.credits)

                // Recommendations
                if !vm.recommendations.isEmpty {
                    MediaHorizontalRowView(title: "Recommendations", items: vm.recommendations)
                }

                // Similar Movies
                if !vm.similar.isEmpty {
                    MediaHorizontalRowView(title: "Similar Movies", items: vm.similar)
                }

                // Request Button
                RequestButtonView(
                    mediaInfo: movie.mediaInfo,
                    showRequestSheet: Binding(
                        get: { vm.showRequestSheet },
                        set: { vm.showRequestSheet = $0 }
                    ),
                    activeRequestId: movie.mediaInfo?.requests?.first { $0.status == 1 || $0.status == 2 }?.id
                )

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.showRequestSheet },
            set: { vm.showRequestSheet = $0 }
        )) {
            CreateRequestView(
                mediaType: .movie,
                mediaId: movie.id ?? movieId
            ) {
                Task { await vm.retry() }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Error

    @ViewBuilder
    private func errorContent(message: String, vm: MovieDetailViewModel) -> some View {
        ContentUnavailableView {
            Label("Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await vm.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
