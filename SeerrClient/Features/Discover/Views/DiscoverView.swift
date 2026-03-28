// DiscoverView.swift
// SeerrClient
//
// The main Discover tab screen. Displays a vertical list of horizontal slider
// rows, each containing media cards from the server's discover configuration.
// Supports pull-to-refresh, loading skeletons, empty state, and error + retry.

import SwiftUI

// MARK: - DiscoverView

/// The primary Discover screen showing server-configured content sliders.
///
/// Reads `AppState` from the environment to obtain the API client, then
/// creates a `DiscoverViewModel` to manage loading state.
struct DiscoverView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var viewModel: DiscoverViewModel?

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                contentForState(viewModel)
            } else {
                loadingContent
            }
        }
        .navigationTitle("Discover")
        .task {
            // Create the VM on first appear; re-use on subsequent appearances.
            if viewModel == nil {
                guard let client = appState.apiClient else { return }
                let repo = DiscoverRepository(apiClient: client)
                viewModel = DiscoverViewModel(repository: repo)
            }
            guard let vm = viewModel else { return }
            // If a previous task was cancelled mid-load, retry.
            if vm.loadState == .loading {
                await vm.retry()
            } else {
                await vm.loadDiscover()
            }
        }
    }

    // MARK: - State-Driven Content

    @ViewBuilder
    private func contentForState(_ vm: DiscoverViewModel) -> some View {
        switch vm.loadState {
        case .idle, .loading:
            loadingContent

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
    private func loadedContent(_ vm: DiscoverViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(vm.sliderRows) { row in
                    DiscoverSliderView(content: row)
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await vm.refresh()
        }
    }

    // MARK: - Loading (Skeleton)

    @ViewBuilder
    private var loadingContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonSliderView()
                }
            }
            .padding(.vertical)
        }
        .scrollDisabled(true)
    }

    // MARK: - Empty

    @ViewBuilder
    private func emptyContent(_ vm: DiscoverViewModel) -> some View {
        ContentUnavailableView {
            Label("No Discover Content", systemImage: "film.stack")
        } description: {
            Text("No discover sliders are enabled on your server. Ask an admin to configure them in the Seerr web UI.")
        } actions: {
            Button("Refresh") {
                Task { await vm.refresh() }
            }
            .buttonStyle(.bordered)
            .disabled(vm.isRefreshing)
        }
    }

    // MARK: - Error

    @ViewBuilder
    private func errorContent(message: String, vm: DiscoverViewModel) -> some View {
        ContentUnavailableView {
            Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
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

// MARK: - Previews

#Preview("Loading") {
    let store = ServerStore()
    let state = AppState(serverStore: store)
    DiscoverView()
        .environment(state)
        .environment(store)
}
