// SearchView.swift
// SeerrClient
//
// The main Search tab screen. Provides a searchable interface with type filter
// chips, a results grid with infinite scroll, and state-based rendering for
// idle, loading, loaded, empty, and error states.

import SwiftUI

// MARK: - SearchView

/// The primary Search screen with type filter chips and paginated results grid.
///
/// Reads `AppState` from the environment to obtain the API client, then
/// creates a `SearchViewModel` to manage search state and pagination.
struct SearchView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var viewModel: SearchViewModel?
    /// Buffers keystrokes that arrive before the ViewModel is initialised.
    @State private var pendingQuery: String = ""

    // MARK: - Layout

    private let gridColumns = [
        GridItem(.adaptive(minimum: 130), spacing: 12)
    ]

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                contentForState(viewModel)
            } else {
                idleContent
            }
        }
        .navigationTitle("Search")
        .searchable(
            text: Binding(
                get: { viewModel?.searchQuery ?? pendingQuery },
                set: {
                    if viewModel != nil {
                        viewModel?.searchQuery = $0
                    } else {
                        pendingQuery = $0
                    }
                }
            ),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Movies, TV shows, people..."
        )
        .task {
            if viewModel == nil {
                guard let client = appState.apiClient else { return }
                let repo = SearchRepository(apiClient: client)
                let vm = SearchViewModel(repository: repo)
                if !pendingQuery.isEmpty {
                    vm.searchQuery = pendingQuery
                    pendingQuery = ""
                }
                viewModel = vm
            }
        }
    }

    // MARK: - State-Driven Content

    @ViewBuilder
    private func contentForState(_ vm: SearchViewModel) -> some View {
        switch vm.loadState {
        case .idle:
            idleContent

        case .loading:
            VStack(spacing: 0) {
                filterChips(vm)
                loadingContent
            }

        case .loaded:
            loadedContent(vm)

        case .empty:
            VStack(spacing: 0) {
                filterChips(vm)
                emptyContent(vm)
            }

        case .error(let message):
            VStack(spacing: 0) {
                filterChips(vm)
                errorContent(message: message, vm: vm)
            }
        }
    }

    // MARK: - Filter Chips

    @ViewBuilder
    private func filterChips(_ vm: SearchViewModel) -> some View {
        SearchFiltersRow(selectedType: vm.selectedType) { type in
            vm.selectType(type)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Idle

    @ViewBuilder
    private var idleContent: some View {
        ContentUnavailableView {
            Label("Search Seerr", systemImage: "magnifyingglass")
        } description: {
            Text("Search for movies, TV shows, and people to request.")
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingContent: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                        .overlay { ShimmerView() }
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray6))
                        .frame(width: 60, height: 10)
                }
            }
        }
        .padding()
        Spacer()
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ vm: SearchViewModel) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                filterChips(vm)

                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(vm.results) { item in
                        if item.isPerson {
                            PersonSearchCardView(person: item) {
                                AppLogger.debug("SearchView: tapped person result (id: \(item.id))")
                            }
                            .onAppear { vm.onItemAppear(item) }
                        } else if item.isMovie {
                            NavigationLink(value: MovieNavDestination(id: item.id, title: item.displayTitle)) {
                                mediaCard(for: item)
                            }
                            .buttonStyle(MediaCardNavigationStyle())
                            .onAppear { vm.onItemAppear(item) }
                        } else if item.isTv {
                            NavigationLink(value: TvNavDestination(id: item.id, title: item.displayTitle)) {
                                mediaCard(for: item)
                            }
                            .buttonStyle(MediaCardNavigationStyle())
                            .onAppear { vm.onItemAppear(item) }
                        } else {
                            mediaCard(for: item)
                                .onAppear { vm.onItemAppear(item) }
                        }
                    }
                }
                .padding(.horizontal)

                // Loading more indicator
                if vm.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 20)
                }
            }
        }
        .refreshable {
            await vm.refresh()
        }
    }

    // MARK: - Media Card (Movie/TV)

    @ViewBuilder
    private func mediaCard(for item: SearchResultItem) -> some View {
        // Bridge SearchResultItem to DiscoverMediaItem for MediaCardView reuse
        let discoverItem = DiscoverMediaItem(
            id: item.id,
            mediaType: item.mediaType,
            title: item.title,
            name: item.name,
            posterPath: item.posterPath,
            backdropPath: item.backdropPath,
            overview: item.overview,
            voteAverage: item.voteAverage,
            releaseDate: item.releaseDate,
            firstAirDate: item.firstAirDate,
            genreIds: item.genreIds,
            mediaInfo: item.mediaInfo
        )
        // No onTap closure — navigation is handled by the wrapping NavigationLink.
        // Passing onTap here would nest a Button inside the NavigationLink, causing
        // duplicate tap events.
        MediaCardView(item: discoverItem, size: .medium)
    }

    // MARK: - Empty

    @ViewBuilder
    private func emptyContent(_ vm: SearchViewModel) -> some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No results found for \"\(vm.searchQuery)\". Try a different search or filter.")
        }
    }

    // MARK: - Error

    @ViewBuilder
    private func errorContent(message: String, vm: SearchViewModel) -> some View {
        ContentUnavailableView {
            Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await vm.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Previews

#Preview("Idle") {
    let store = ServerStore()
    let state = AppState(serverStore: store)
    NavigationStack {
        SearchView()
    }
    .environment(state)
    .environment(store)
}
