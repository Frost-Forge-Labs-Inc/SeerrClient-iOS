// WatchlistView.swift
// SeerrClient
//
// Dedicated screen showing the user's Plex watchlist items in a two-column grid.
// Matches the JellySeerr web UI watchlist page behaviour: paginated grid with
// poster cards, pull-to-refresh, and navigation to media detail.

import SwiftUI

// MARK: - WatchlistView

struct WatchlistView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var viewModel: WatchlistViewModel?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                contentForState(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Watchlist")
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard let viewModel = makeViewModelIfNeeded() else { return }

            if appState.watchlistNeedsRefresh {
                await refreshWatchlist(viewModel)
            } else {
                viewModel.loadIfNeeded()
            }
        }
        .onChange(of: appState.watchlistedTmdbIds) { _, newIds in
            viewModel?.reconcileWithWatchlistIds(newIds)
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private func contentForState(_ vm: WatchlistViewModel) -> some View {
        switch vm.loadState {
        case .idle, .loading:
            loadingContent

        case .loaded(let items):
            loadedContent(items, vm: vm)

        case .empty:
            emptyContent(vm)

        case .error(let message):
            errorContent(message: message, vm: vm)
        }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ items: [DiscoverMediaItem], vm: WatchlistViewModel) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(items) { item in
                    if item.isMovie {
                        NavigationLink(value: MovieNavDestination(id: item.effectiveTmdbId, title: item.displayTitle)) {
                            MediaCardView(
                                item: item,
                                size: .medium,
                                posterPathOverride: vm.posterPaths[item.id],
                                yearOverride: vm.years[item.id]
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("watchlist.card.\(item.effectiveTmdbId)")
                        .onAppear { vm.onItemAppear(item) }
                    } else if item.isTv {
                        NavigationLink(value: TvNavDestination(id: item.effectiveTmdbId, title: item.displayTitle)) {
                            MediaCardView(
                                item: item,
                                size: .medium,
                                posterPathOverride: vm.posterPaths[item.id],
                                yearOverride: vm.years[item.id]
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("watchlist.card.\(item.effectiveTmdbId)")
                        .onAppear { vm.onItemAppear(item) }
                    } else {
                        MediaCardView(
                            item: item,
                            size: .medium,
                            posterPathOverride: vm.posterPaths[item.id],
                            yearOverride: vm.years[item.id]
                        )
                        .accessibilityIdentifier("watchlist.card.\(item.effectiveTmdbId)")
                        .onAppear { vm.onItemAppear(item) }
                    }
                }

                if vm.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .gridCellColumns(2)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("watchlist.screen")
        .refreshable {
            await refreshWatchlist(vm)
        }
    }

    // MARK: - Loading

    private var loadingContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<8, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .aspectRatio(2/3, contentMode: .fit)
                        .overlay { ShimmerView() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("watchlist.screen")
        .scrollDisabled(true)
    }

    // MARK: - Empty

    private func emptyContent(_ vm: WatchlistViewModel) -> some View {
        ScrollView {
            ContentUnavailableView {
                Label("No Watchlist Items", systemImage: "bookmark.slash")
            } description: {
                Text("Your Plex watchlist is empty. Add titles in Plex and they'll appear here.")
            }
            .accessibilityIdentifier("watchlist.empty-state")
            .padding(.top, 60)
        }
        .accessibilityIdentifier("watchlist.screen")
        .refreshable {
            await refreshWatchlist(vm)
        }
    }

    // MARK: - Error

    private func errorContent(message: String, vm: WatchlistViewModel) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load Watchlist", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                vm.retry()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func makeViewModelIfNeeded() -> WatchlistViewModel? {
        if let viewModel {
            return viewModel
        }

        guard let client = appState.apiClient else { return nil }
        let repo = DiscoverRepository(apiClient: client)
        let mediaRepo = MediaDetailRepository(apiClient: client)
        let vm = WatchlistViewModel(repository: repo, mediaDetailRepository: mediaRepo)
        viewModel = vm
        return vm
    }

    @MainActor
    private func refreshWatchlist(_ viewModel: WatchlistViewModel) async {
        viewModel.reconcileWithWatchlistIds(appState.watchlistedTmdbIds)
        await appState.loadWatchlistCache()
        await viewModel.refresh()
    }

}
