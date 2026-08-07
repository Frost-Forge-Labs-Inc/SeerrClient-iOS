// MacContentView.swift
// SeerrClientMac
//
// macOS root shell: auth branching + 2-column NavigationSplitView sidebar.
// M3c: Discover + Search + Requests + Watchlist + Profile + media detail destinations.

import SwiftUI

// MARK: - Focused Values (menu commands)

/// Routes the View → Toggle Sidebar (⌘0) command into the active scene.
/// Shared with `MacAppCommands` in `SeerrClientMacApp`.
struct MacSidebarVisibilityKey: FocusedValueKey {
    typealias Value = Binding<NavigationSplitViewVisibility>
}

extension FocusedValues {
    var macSidebarVisibility: Binding<NavigationSplitViewVisibility>? {
        get { self[MacSidebarVisibilityKey.self] }
        set { self[MacSidebarVisibilityKey.self] = newValue }
    }
}

// MARK: - MacContentView

/// macOS root view. Branches on the same `AppState` flags as iOS `ContentView`:
/// server setup → login → main split shell → loading.
struct MacContentView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState
    @Environment(ServerStore.self) private var serverStore

    // MARK: - State

    @State private var selectedTab = UITestLaunchConfiguration.current.initialTab
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    /// Same key as ProfileViewModel / MacSettingsView (`seerr.appTheme` Int rawValue).
    /// Applied at root so every window follows the Preferences theme.
    @AppStorage("seerr.appTheme") private var themeRaw: Int = AppTheme.system.rawValue

    private var defaultSessionTab: AppTab {
        UITestLaunchConfiguration.current.initialTab
    }

    private var preferredScheme: ColorScheme? {
        (AppTheme(rawValue: themeRaw) ?? .system).colorScheme
    }

    // MARK: - Body

    var body: some View {
        Group {
            if appState.showServerSetup {
                MacServerListView()
            } else if appState.showLogin, let server = appState.activeServer {
                MacLoginView(
                    server: server,
                    appState: appState,
                    serverStore: serverStore
                )
            } else if appState.showMainInterface {
                mainSplitShell
            } else {
                loadingView
            }
        }
        .frame(
            minWidth: 960, idealWidth: 1240, maxWidth: .infinity,
            minHeight: 640, idealHeight: 820, maxHeight: .infinity
        )
        .preferredColorScheme(preferredScheme)
        .animation(.easeInOut(duration: 0.25), value: appState.showServerSetup)
        .animation(.easeInOut(duration: 0.25), value: appState.showMainInterface)
        .onChange(of: appState.activeServer?.id) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = defaultSessionTab
        }
        .onChange(of: appState.activeServerCapabilities?.supportsWatchlistRead) { _, supported in
            selectedTab = TabSelectionPolicy.resolvedTab(
                current: selectedTab,
                supportsWatchlistRead: supported,
                defaultSessionTab: defaultSessionTab
            )
        }
    }

    // MARK: - Main Split Shell

    @ViewBuilder
    private var mainSplitShell: some View {
        let supportsWatchlistRead = appState.activeServerCapabilities?.supportsWatchlistRead ?? false
        let title = appState.activeServerCapabilities?.applicationTitle ?? "Octopus Explorer"
        let subtitle = appState.activeServer?.displayName ?? ""

        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedTab) {
                Label("Discover", systemImage: "film.stack")
                    .tag(AppTab.discover)
                Label("Search", systemImage: "magnifyingglass")
                    .tag(AppTab.search)
                Label("Requests", systemImage: "tray.full")
                    .tag(AppTab.requests)
                if supportsWatchlistRead {
                    Label("Watchlist", systemImage: "bookmark")
                        .tag(AppTab.watchlist)
                }
                Label("Profile", systemImage: "person.circle")
                    .tag(AppTab.profile)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            NavigationStack {
                detailContent(for: selectedTab)
            }
        }
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .focusedSceneValue(\.macSidebarVisibility, $columnVisibility)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(for tab: AppTab) -> some View {
        switch tab {
        case .discover:
            DiscoverView()
                .navigationDestination(for: MovieNavDestination.self) { dest in
                    MovieDetailView(movieId: dest.id, movieTitle: dest.title)
                }
                .navigationDestination(for: TvNavDestination.self) { dest in
                    TvShowDetailView(tvId: dest.id, showTitle: dest.title)
                }
                .navigationDestination(for: CollectionNavDestination.self) { dest in
                    CollectionDetailView(collectionId: dest.id, collectionName: dest.name)
                }
                .navigationDestination(for: RequestNavDestination.self) { dest in
                    RequestDetailView(requestID: dest.requestID)
                }
        case .search:
            SearchView()
                .navigationDestination(for: MovieNavDestination.self) { dest in
                    MovieDetailView(movieId: dest.id, movieTitle: dest.title)
                }
                .navigationDestination(for: TvNavDestination.self) { dest in
                    TvShowDetailView(tvId: dest.id, showTitle: dest.title)
                }
                .navigationDestination(for: CollectionNavDestination.self) { dest in
                    CollectionDetailView(collectionId: dest.id, collectionName: dest.name)
                }
                .navigationDestination(for: RequestNavDestination.self) { dest in
                    RequestDetailView(requestID: dest.requestID)
                }
        case .requests:
            RequestsView()
        case .watchlist:
            WatchlistView()
                .navigationDestination(for: MovieNavDestination.self) { dest in
                    MovieDetailView(movieId: dest.id, movieTitle: dest.title)
                }
                .navigationDestination(for: TvNavDestination.self) { dest in
                    TvShowDetailView(tvId: dest.id, showTitle: dest.title)
                }
                .navigationDestination(for: CollectionNavDestination.self) { dest in
                    CollectionDetailView(collectionId: dest.id, collectionName: dest.name)
                }
        case .profile:
            MacProfileView()
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading…")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Server Setup") {
    let store = ServerStore()
    let state = AppState(serverStore: store)
    MacContentView()
        .environment(state)
        .environment(store)
}
