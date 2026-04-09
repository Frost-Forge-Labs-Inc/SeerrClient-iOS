// WatchlistView.swift
// SeerrClient
//
// Dedicated screen showing the user's watchlist items in a two-column grid.

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
            loadingContent(vm)

        case .loaded:
            loadedContent(vm)

        case .empty:
            emptyContent(vm)

        case .error(let message):
            errorContent(message: message, vm: vm)
        }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ vm: WatchlistViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                mediaSegmentControl(vm)

                if vm.visibleItems.isEmpty {
                    if vm.isLoadingMore {
                        filteredLoadingContent(vm)
                    } else {
                        filteredEmptyContent(vm)
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(vm.visibleItems) { item in
                            watchlistCard(for: item, vm: vm)
                        }

                        if vm.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .gridCellColumns(2)
                                .padding(.vertical, 8)
                        }
                    }
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

    private func loadingContent(_ vm: WatchlistViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                mediaSegmentControl(vm)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray5))
                            .aspectRatio(2/3, contentMode: .fit)
                            .overlay { ShimmerView() }
                    }
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
            VStack(alignment: .leading, spacing: 12) {
                mediaSegmentControl(vm)

                ContentUnavailableView {
                    Label("No Watchlist Items", systemImage: "bookmark.slash")
                } description: {
                    Text("Your watchlist is empty. Add titles on your server and they'll appear here.")
                }
                .accessibilityIdentifier("watchlist.empty-state")
                .padding(.top, 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("watchlist.screen")
        .refreshable {
            await refreshWatchlist(vm)
        }
    }

    // MARK: - Error

    private func errorContent(message: String, vm: WatchlistViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                mediaSegmentControl(vm)

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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("watchlist.screen")
    }

    // MARK: - Helpers

    @ViewBuilder
    private func watchlistCard(for item: DiscoverMediaItem, vm: WatchlistViewModel) -> some View {
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

    private func mediaSegmentControl(_ vm: WatchlistViewModel) -> some View {
        Picker(
            "Media Type",
            selection: Binding(
                get: { vm.selectedMediaSegment },
                set: vm.selectMediaSegment
            )
        ) {
            ForEach(WatchlistMediaSegment.allCases, id: \.self) { segment in
                Text(segment.title)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("watchlist.mediaSegment")
    }

    private func filteredEmptyContent(_ vm: WatchlistViewModel) -> some View {
        ContentUnavailableView {
            Label(vm.selectedMediaSegment.emptyTitle, systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text(vm.selectedMediaSegment.emptyMessage)
        }
        .accessibilityIdentifier("watchlist.filtered-empty")
        .padding(.top, 60)
    }

    private func filteredLoadingContent(_ vm: WatchlistViewModel) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading \(vm.selectedMediaSegment.title)...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .accessibilityIdentifier("watchlist.filtered-loading")
    }

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
