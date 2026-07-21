// TVWatchlistView.swift
// SeerrClientTV (Octopus Explorer)

import SwiftUI

struct TVWatchlistView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: WatchlistViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                TVLoadingStateView(title: "Watchlist")
            }
        }
        .accessibilityIdentifier("tvos.watchlist.screen")
        .task {
            guard let viewModel = makeViewModelIfNeeded() else { return }
            if appState.watchlistNeedsRefresh {
                await refresh(viewModel)
            } else {
                viewModel.loadIfNeeded()
            }
        }
        .onChange(of: appState.watchlistedTmdbIds) { _, ids in
            viewModel?.reconcileWithWatchlistIds(ids)
        }
    }

    @ViewBuilder
    private func content(for viewModel: WatchlistViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            TVLoadingStateView(title: "Watchlist")
        case .loaded:
            TVScreenScaffold(title: "Watchlist", subtitle: appState.activeServer?.displayName) {
                VStack(alignment: .leading, spacing: 28) {
                    segmentRow(viewModel)
                    if viewModel.visibleItems.isEmpty {
                        Text(viewModel.selectedMediaSegment.emptyTitle)
                            .font(.system(size: 29, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(maxWidth: .infinity, minHeight: 260)
                    } else {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(TVMetrics.compactPosterWidth), spacing: 34), count: 5),
                            alignment: .leading,
                            spacing: 46
                        ) {
                            ForEach(viewModel.visibleItems) { item in
                                card(for: item, viewModel: viewModel)
                                    .onAppear { viewModel.onItemAppear(item) }
                            }
                            if viewModel.isLoadingMore {
                                ProgressView()
                            }
                        }
                    }
                    Button("Refresh") {
                        Task { await refresh(viewModel) }
                    }
                    .buttonStyle(.bordered)
                }
            }
        case .empty:
            TVMessageStateView(
                title: "Watchlist",
                message: "Your watchlist is empty.",
                systemImage: "bookmark.slash",
                actionTitle: "Refresh"
            ) {
                Task { await refresh(viewModel) }
            }
        case .error(let message):
            TVMessageStateView(
                title: "Watchlist",
                message: message,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Try Again"
            ) {
                viewModel.retry()
            }
        }
    }

    private func segmentRow(_ viewModel: WatchlistViewModel) -> some View {
        HStack(spacing: 16) {
            ForEach(WatchlistMediaSegment.allCases, id: \.self) { segment in
                Button(segment.title) {
                    viewModel.selectMediaSegment(segment)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.selectedMediaSegment == segment ? .accentColor : .white.opacity(0.25))
            }
        }
    }

    @ViewBuilder
    private func card(for item: DiscoverMediaItem, viewModel: WatchlistViewModel) -> some View {
        let poster = TVMediaPosterCard(
            title: item.displayTitle,
            subtitle: viewModel.years[item.id] ?? item.year,
            posterPath: viewModel.posterPaths[item.id] ?? item.posterPath,
            status: item.mediaInfo?.status,
            width: TVMetrics.compactPosterWidth
        )
        .accessibilityIdentifier("tvos.watchlist.card.\(item.effectiveTmdbId)")

        if item.isMovie {
            NavigationLink(value: MovieNavDestination(id: item.effectiveTmdbId, title: item.displayTitle)) {
                poster
            }
            .buttonStyle(.card)
        } else if item.isTv {
            NavigationLink(value: TvNavDestination(id: item.effectiveTmdbId, title: item.displayTitle)) {
                poster
            }
            .buttonStyle(.card)
        } else {
            poster
        }
    }

    private func makeViewModelIfNeeded() -> WatchlistViewModel? {
        if let viewModel { return viewModel }
        guard let client = appState.apiClient else { return nil }
        let discoverRepository = DiscoverRepository(apiClient: client)
        let mediaDetailRepository = MediaDetailRepository(apiClient: client)
        let viewModel = WatchlistViewModel(
            repository: discoverRepository,
            mediaDetailRepository: mediaDetailRepository
        )
        self.viewModel = viewModel
        return viewModel
    }

    private func refresh(_ viewModel: WatchlistViewModel) async {
        appState.watchlistNeedsRefresh = false
        viewModel.reconcileWithWatchlistIds(appState.watchlistedTmdbIds)
        await appState.loadWatchlistCache()
        await viewModel.refresh()
    }
}
