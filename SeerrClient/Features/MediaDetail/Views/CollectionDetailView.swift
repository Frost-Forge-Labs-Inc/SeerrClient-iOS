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
/// Each movie shows its availability state and request-selection affordance.
/// Users can request all requestable movies or a selected subset.
struct CollectionDetailView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    /// The TMDB collection identifier.
    let collectionId: Int
    /// The collection name for the navigation bar (known from the parent detail).
    let collectionName: String

    // MARK: - State

    @State private var viewModel: CollectionDetailViewModel?

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
        .accessibilityIdentifier("collection.screen")
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
                        requestControls(vm: vm, requestableCount: requestable.count)
                    } else {
                        Text("All movies in this collection are already available or have active requests.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
        .sheet(isPresented: Binding(
            get: { vm.showRequestSheet },
            set: { if !$0 { vm.dismissRequestSheet() } }
        )) {
            requestQueueSheet(vm: vm)
        }
    }

    // MARK: - Collection Movie Row

    @ViewBuilder
    private func collectionMovieRow(_ movie: MovieResult, vm: CollectionDetailViewModel) -> some View {
        HStack(spacing: 12) {
            requestSelectionButton(for: movie, vm: vm)

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
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                statusChip(for: movie)

                NavigationLink(value: MovieNavDestination(id: movie.id, title: movie.title)) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("collection.row.\(movie.id)")
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
                    .accessibilityIdentifier("collection.status.\(movie.id).available")
            case 2:
                Label("Pending", systemImage: "clock.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("collection.status.\(movie.id).pending")
            case 3:
                Label("Requested", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.purple)
                    .accessibilityIdentifier("collection.status.\(movie.id).requested")
            case 4:
                Label("Partial", systemImage: "circle.lefthalf.filled")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
                    .accessibilityIdentifier("collection.status.\(movie.id).partial")
            default:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Request Controls

    @ViewBuilder
    private func requestControls(vm: CollectionDetailViewModel, requestableCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(requestableCount) movie\(requestableCount == 1 ? "" : "s") can be requested from this collection.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(vm.allRequestableMoviesSelected ? "Clear Selection" : "Select All") {
                    if vm.allRequestableMoviesSelected {
                        vm.clearSelection()
                    } else {
                        vm.selectAll()
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(
                    vm.allRequestableMoviesSelected ? "collection.clearSelection" : "collection.selectAll"
                )

                Text(vm.hasSelection ? "\(vm.selectedRequestMovieIDs.count) selected" : "No movies selected")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(vm.hasSelection ? .primary : .secondary)
                    .accessibilityIdentifier("collection.selectionSummary")

                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    vm.requestSelected()
                } label: {
                    Label(
                        vm.hasSelection ? "Request Selected (\(vm.selectedRequestMovieIDs.count))" : "Request Selected",
                        systemImage: "checkmark.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(!vm.hasSelection)
                .accessibilityIdentifier("collection.requestSelected")

                Button {
                    vm.requestAll()
                } label: {
                    Label("Request All", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("collection.requestAll")
            }
        }
    }

    @ViewBuilder
    private func requestSelectionButton(for movie: MovieResult, vm: CollectionDetailViewModel) -> some View {
        if vm.isUnavailable(movie) {
            Image(systemName: "slash.circle")
                .font(.title3)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        } else {
            Button {
                vm.toggleSelection(movieId: movie.id)
            } label: {
                Image(systemName: vm.isSelected(movieId: movie.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(vm.isSelected(movieId: movie.id) ? Color.accentColor : Color.secondary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(vm.isSelected(movieId: movie.id) ? "Deselect \(movie.title)" : "Select \(movie.title)")
            .accessibilityValue(vm.isSelected(movieId: movie.id) ? "Selected" : "Not selected")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("collection.select.\(movie.id)")
        }
    }

    @ViewBuilder
    private func requestQueueSheet(vm: CollectionDetailViewModel) -> some View {
        if let movie = vm.activeRequestMovie {
            CreateRequestView(
                mediaType: .movie,
                mediaId: movie.id,
                mediaInfo: movie.mediaInfo,
                dismissOnSuccess: vm.queuedRequestMovieIDs.count <= 1
            ) {
                vm.handleRequestSuccess()
            }
            .presentationDetents([.medium, .large])
            .id(movie.id)
        } else {
            ProgressView()
                .presentationDetents([.medium])
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
