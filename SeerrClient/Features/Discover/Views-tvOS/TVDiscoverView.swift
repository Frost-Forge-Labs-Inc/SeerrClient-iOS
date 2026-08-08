// TVDiscoverView.swift
// SeerrClientTV (Octopus Explorer)

import SwiftUI

struct TVDiscoverView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: DiscoverViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                TVLoadingStateView(title: "Discover")
            }
        }
        .accessibilityIdentifier("tvos.discover.screen")
        .task {
            if viewModel == nil, let client = appState.apiClient {
                viewModel = DiscoverViewModel(repository: DiscoverRepository(apiClient: client))
            }
            guard let viewModel else { return }
            if viewModel.loadState == .loading {
                await viewModel.retry()
            } else {
                await viewModel.loadDiscover()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: DiscoverViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            TVLoadingStateView(title: "Discover")
        case .loaded:
            TVScreenScaffold(title: "Discover", subtitle: appState.activeServer?.displayName) {
                VStack(alignment: .leading, spacing: 52) {
                    ForEach(viewModel.sliderRows) { row in
                        TVDiscoverRail(row: row)
                    }
                    Button("Refresh") {
                        Task { await viewModel.refresh() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isRefreshing)
                }
            }
        case .empty:
            TVMessageStateView(
                title: "Discover",
                message: "No discover sliders are enabled on this server.",
                systemImage: "film.stack",
                actionTitle: "Refresh"
            ) {
                Task { await viewModel.refresh() }
            }
        case .error(let message):
            TVMessageStateView(
                title: "Discover",
                message: message,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Try Again"
            ) {
                Task { await viewModel.retry() }
            }
        }
    }
}

private struct TVDiscoverRail: View {
    let row: SliderContent

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(row.displayTitle)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)

            ScrollView(.horizontal) {
                LazyHStack(spacing: TVMetrics.railSpacing) {
                    ForEach(row.items) { item in
                        TVDiscoverNavigationCard(item: item)
                    }
                }
                // Extra vertical room + disabled scroll clipping so the focus lift/
                // scale of `.card` buttons (and the title/year beneath) is never
                // clipped by the ScrollView's bounds.
                .padding(.vertical, 24)
            }
            .scrollClipDisabled()
        }
    }
}

private struct TVDiscoverNavigationCard: View {
    let item: DiscoverMediaItem

    var body: some View {
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

    private var poster: some View {
        TVMediaPosterCard(
            title: item.displayTitle,
            subtitle: item.year,
            posterPath: item.posterPath,
            status: item.mediaInfo?.status
        )
        .accessibilityIdentifier("tvos.discover.card.\(item.effectiveTmdbId)")
    }
}
