// ContentView.swift
// SeerrClient
//
// Root view that reads AppState from the environment and switches between the
// server-setup onboarding flow, the login screen, and the main tab interface.
// No business logic lives here — it is purely a navigation branch point.

import SwiftUI

// MARK: - ContentView

/// Root view for SeerrClient.
///
/// Reads `AppState` from the environment and presents the correct top-level
/// experience:
/// - **Server Setup** — no server configured yet → `ServerListView`
/// - **Login** — server selected but user not yet authenticated → `LoginView`
/// - **Main Interface** — fully authenticated; shows the primary tab bar.
struct ContentView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState
    @Environment(ServerStore.self) private var serverStore

    // MARK: - Launch Phase

    /// True for the first 2.5 s of the app's life — drives the launch animation overlay.
    /// Lives here (not in LoginView) so task-cancellation from auth state transitions
    /// cannot shorten the minimum display time.
    @State private var isInLaunchPhase = !UITestLaunchConfiguration.current.disableLaunchAnimation
    @State private var selectedTab = UITestLaunchConfiguration.current.initialTab

    private var defaultSessionTab: AppTab {
        UITestLaunchConfiguration.current.initialTab
    }

    // MARK: - Body

    var body: some View {
        Group {
            if appState.showServerSetup {
                ServerListView()
            } else if appState.showLogin, let server = appState.activeServer {
                LoginView(
                    server: server,
                    appState: appState,
                    serverStore: serverStore
                )
            } else if appState.showMainInterface {
                mainInterfacePlaceholder
            } else {
                // Transitional state: server selected, loading auth — show spinner.
                loadingView
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.showServerSetup)
        .animation(.easeInOut(duration: 0.25), value: appState.showMainInterface)
        // Launch animation — overlaid at this level so it survives auth state transitions.
        .overlay {
            if isInLaunchPhase {
                LaunchAnimationView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: isInLaunchPhase)
        .task {
            guard isInLaunchPhase else { return }
            // Hold the launch animation for exactly 2.5 s then fade out.
            try? await Task.sleep(for: .seconds(2.5))
            isInLaunchPhase = false
        }
        .onChange(of: appState.activeServer?.id) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = defaultSessionTab
        }
    }

    // MARK: - Main Interface

    /// Main tab interface with Discover, Search, Requests, Watchlist, and Profile tabs.
    @ViewBuilder
    private var mainInterfacePlaceholder: some View {
#if DEBUG
        switch UITestLaunchConfiguration.current.rootDestination {
        case .collectionDetail(let collectionId, let collectionName):
            NavigationStack {
                CollectionDetailView(collectionId: collectionId, collectionName: collectionName)
                    .navigationDestination(for: MovieNavDestination.self) { dest in
                        MovieDetailView(movieId: dest.id, movieTitle: dest.title)
                    }
                    .navigationDestination(for: RequestNavDestination.self) { dest in
                        RequestDetailView(requestID: dest.requestID)
                    }
            }
        case .mainTabs:
            standardMainInterface
        }
#else
        standardMainInterface
#endif
    }

    @ViewBuilder
    private var standardMainInterface: some View {
        let supportsWatchlistRead = appState.activeServerCapabilities?.supportsWatchlistRead ?? false

        TabView(selection: $selectedTab) {
            NavigationStack {
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
            }
            .tabItem { Label("Discover", systemImage: "film.stack") }
            .tag(AppTab.discover)

            NavigationStack {
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
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppTab.search)

            NavigationStack {
                RequestListView()
                    .navigationDestination(for: MovieNavDestination.self) { dest in
                        MovieDetailView(movieId: dest.id, movieTitle: dest.title)
                    }
                    .navigationDestination(for: TvNavDestination.self) { dest in
                        TvShowDetailView(tvId: dest.id, showTitle: dest.title)
                    }
                    .navigationDestination(for: CollectionNavDestination.self) { dest in
                        CollectionDetailView(collectionId: dest.id, collectionName: dest.name)
                    }
            }
            .tabItem { Label("Requests", systemImage: "tray.full") }
            .tag(AppTab.requests)

            if supportsWatchlistRead {
                NavigationStack {
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
                }
                .tabItem { Label("Watchlist", systemImage: "bookmark") }
                .tag(AppTab.watchlist)
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.circle") }
            .tag(AppTab.profile)
        }
    }

    /// Animated splash shown while session restoration is in progress.
    @ViewBuilder
    private var loadingView: some View {
        LaunchAnimationView()
    }
}

// MARK: - Preview

#Preview("No Server") {
    let store = ServerStore()
    let state = AppState(serverStore: store)
    ContentView()
        .environment(state)
        .environment(store)
}

#Preview("Authenticated") {
    let store = ServerStore()
    let state = AppState(serverStore: store)
    let server = ServerConfiguration(
        displayName: "Home Seerr",
        baseURL: "http://192.168.1.50:5055",
        backendType: .jellyseerr
    )
    let mockUser = User(
        id: 1,
        email: "admin@example.com",
        displayName: nil,
        username: "admin",
        plexToken: nil,
        plexUsername: nil,
        userType: 2,
        permissions: 2,
        avatar: nil,
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z",
        requestCount: 0
    )
    ContentView()
        .environment(state)
        .environment(store)
        .onAppear {
            state.selectServer(server)
            state.setAuthenticatedUser(mockUser)
        }
}
