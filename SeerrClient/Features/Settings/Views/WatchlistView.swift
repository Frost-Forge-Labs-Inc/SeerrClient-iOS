// WatchlistView.swift
// SeerrClient
//
// Dedicated screen showing the user's watchlist items in a responsive poster grid.

import SwiftUI

// MARK: - WatchlistGridLayout

struct WatchlistGridLayout: Equatable {
    let columnCount: Int
    let cardWidth: CGFloat
    let spacing: CGFloat
    let columns: [GridItem]

    init(
        containerWidth: CGFloat,
        horizontalPadding: CGFloat = 16,
        spacing: CGFloat = 12,
        preferredColumnCount: Int = 3,
        minimumCardWidth: CGFloat = 96
    ) {
        self.spacing = spacing

        let availableWidth = max(containerWidth - (horizontalPadding * 2), minimumCardWidth)
        var resolvedCount = preferredColumnCount

        while resolvedCount > 1 {
            let candidateWidth = floor(
                (availableWidth - (CGFloat(resolvedCount - 1) * spacing)) / CGFloat(resolvedCount)
            )

            if candidateWidth >= minimumCardWidth {
                self.columnCount = resolvedCount
                self.cardWidth = candidateWidth
                self.columns = Array(
                    repeating: GridItem(.fixed(candidateWidth), spacing: spacing, alignment: .top),
                    count: resolvedCount
                )
                return
            }

            resolvedCount -= 1
        }

        self.columnCount = 1
        self.cardWidth = availableWidth
        self.columns = [GridItem(.fixed(availableWidth), spacing: spacing, alignment: .top)]
    }
}

// MARK: - WatchlistView

struct WatchlistView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var viewModel: WatchlistViewModel?

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let renderedWidth = min(
                proxy.size.width,
                UITestLaunchConfiguration.current.watchlistContainerWidth ?? proxy.size.width
            )
            let layout = WatchlistGridLayout(containerWidth: renderedWidth)

            Group {
                if let viewModel {
                    contentForState(viewModel, layout: layout)
                } else {
                    ProgressView()
                }
            }
            .frame(width: renderedWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
    private func contentForState(_ vm: WatchlistViewModel, layout: WatchlistGridLayout) -> some View {
        switch vm.loadState {
        case .idle, .loading:
            loadingContent(vm, layout: layout)

        case .loaded:
            loadedContent(vm, layout: layout)

        case .empty:
            emptyContent(vm)

        case .error(let message):
            errorContent(message: message, vm: vm)
        }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ vm: WatchlistViewModel, layout: WatchlistGridLayout) -> some View {
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
                    LazyVGrid(columns: layout.columns, spacing: layout.spacing) {
                        ForEach(vm.visibleItems) { item in
                            watchlistCard(for: item, vm: vm, layout: layout)
                        }

                        if vm.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .gridCellColumns(layout.columnCount)
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

    private func loadingContent(_ vm: WatchlistViewModel, layout: WatchlistGridLayout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                mediaSegmentControl(vm)

                LazyVGrid(columns: layout.columns, spacing: layout.spacing) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: layout.cardWidth * 1.5)
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
    private func watchlistCard(
        for item: DiscoverMediaItem,
        vm: WatchlistViewModel,
        layout: WatchlistGridLayout
    ) -> some View {
        if item.isMovie {
            NavigationLink(value: MovieNavDestination(id: item.effectiveTmdbId, title: item.displayTitle)) {
                MediaCardView(
                    item: item,
                    size: .custom(layout.cardWidth),
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
                    size: .custom(layout.cardWidth),
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
                size: .custom(layout.cardWidth),
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
