// CollectionDetailView.swift
// SeerrClient
//
// Displays a TMDB movie collection with its member films, their availability
// status, and buttons to request all or selected movies.

import SwiftUI

// MARK: - CollectionDetailView

/// Full collection detail screen accessible from MovieDetailView when a movie
/// belongs to a TMDB collection.
///
/// Shows the collection name, backdrop, overview, and a list of member movies.
/// Each movie shows its availability chip and a per-item request button.
/// A "Request All" toolbar button triggers the bulk request flow.
struct CollectionDetailView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    /// The TMDB collection identifier.
    let collectionId: Int
    /// The collection name for the navigation bar (known from the parent detail).
    let collectionName: String

    // MARK: - State

    @State private var viewModel: CollectionDetailViewModel?
    /// Index into `requestableMovies` for the currently presenting request sheet.
    @State private var requestSheetMovieIndex: Int = 0

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                contentForState(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(collectionName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                guard let client = appState.apiClient else { return }
                let repo = MediaDetailRepository(apiClient: client)
                viewModel = CollectionDetailViewModel(collectionId: collectionId, repository: repo)
            }
            await viewModel?.loadCollection()
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private func contentForState(_ vm: CollectionDetailViewModel) -> some View {
        switch vm.loadState {
        case .idle, .loading:
            loadingContent

        case .loaded(let collection):
            loadedContent(collection, vm: vm)

        case .error(let message):
            errorContent(message: message, vm: vm)
        }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ collection: Collection, vm: CollectionDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Collection backdrop
                if let backdropPath = collection.backdropPath {
                    AsyncImage(url: tmdbImageURL(backdropPath, size: "w780")) { image in
                        image
                            .resizable()
                            .aspectRatio(16.0 / 9.0, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                            .overlay { ShimmerView() }
                    }
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 16) {

                    // Collection name + overview
                    if let overview = collection.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Action row: Request All
                    let requestable = vm.requestableMovies
                    if !requestable.isEmpty {
                        Button {
                            vm.requestAll()
                        } label: {
                            Label("Request All", systemImage: "arrow.down.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        // Request-all sheet: iterates through requestable movies one at a time.
                        .sheet(isPresented: Binding(
                            get: { vm.showRequestSheet && vm.requestingMovieId == nil },
                            set: { if !$0 { vm.dismissRequestSheet() } }
                        )) {
                            requestAllSheet(vm: vm)
                        }
                    }

                    // Movie list
                    Divider()

                    Text("\(collection.parts?.count ?? 0) Movies")
                        .font(.headline)

                    LazyVStack(spacing: 12) {
                        ForEach(collection.parts ?? [], id: \.id) { movie in
                            collectionMovieRow(movie, vm: vm)
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Collection Movie Row

    @ViewBuilder
    private func collectionMovieRow(_ movie: MovieResult, vm: CollectionDetailViewModel) -> some View {
        HStack(spacing: 12) {
            // Poster
            AsyncImage(url: movie.posterPath.flatMap { tmdbImageURL($0, size: "w92") }) { image in
                image
                    .resizable()
                    .aspectRatio(2.0 / 3.0, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
            .frame(width: 54, height: 81)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                if let year = movie.releaseDate.flatMap({ $0.count >= 4 ? String($0.prefix(4)) : nil }) {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Status chip
                statusChip(for: movie)
            }

            Spacer()

            // Navigation to movie detail
            NavigationLink(value: MovieNavDestination(id: movie.id, title: movie.title)) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status Chip

    @ViewBuilder
    private func statusChip(for movie: MovieResult) -> some View {
        if let status = movie.mediaInfo?.status {
            switch status {
            case 5:
                Label("Available", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            case 2, 3:
                Label("Requested", systemImage: "clock.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            case 4:
                Label("Partial", systemImage: "circle.lefthalf.filled")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
            default:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Request All Sheet

    /// Iterates through the requestable movies in a single sheet session.
    /// Uses a simple index counter — each dismiss increments to the next movie.
    @ViewBuilder
    private func requestAllSheet(vm: CollectionDetailViewModel) -> some View {
        let movies = vm.requestableMovies
        if requestSheetMovieIndex < movies.count {
            let movie = movies[requestSheetMovieIndex]
            CreateRequestView(
                mediaType: .movie,
                mediaId: movie.id
            ) {
                // Advance to next movie or close the sheet
                if requestSheetMovieIndex + 1 < movies.count {
                    requestSheetMovieIndex += 1
                } else {
                    vm.dismissRequestSheet()
                    requestSheetMovieIndex = 0
                }
            }
            .presentationDetents([.medium, .large])
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
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 81)
                            .overlay { ShimmerView() }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private func errorContent(message: String, vm: CollectionDetailViewModel) -> some View {
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

    // MARK: - Helpers

    /// Builds a TMDB image URL for the given path and size.
    private func tmdbImageURL(_ path: String, size: String) -> URL? {
        URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
