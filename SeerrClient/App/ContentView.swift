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

    // MARK: - Body

    var body: some View {
        Group {
            if appState.showServerSetup {
                ServerListView()
            } else if appState.showLogin, let server = appState.activeServer {
                LoginView(
                    server: server,
                    availableAuthMethods: appState.availableAuthMethods,
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
    }

    // MARK: - Main Interface

    /// Main tab interface with Discover, Search, Requests, and Profile tabs.
    @ViewBuilder
    private var mainInterfacePlaceholder: some View {
        TabView {
            NavigationStack {
                DiscoverView()
                    .navigationDestination(for: MovieNavDestination.self) { dest in
                        MovieDetailView(movieId: dest.id, movieTitle: dest.title)
                    }
                    .navigationDestination(for: TvNavDestination.self) { dest in
                        TvShowDetailView(tvId: dest.id, showTitle: dest.title)
                    }
            }
            .tabItem { Label("Discover", systemImage: "film.stack") }

            NavigationStack {
                SearchView()
                    .navigationDestination(for: MovieNavDestination.self) { dest in
                        MovieDetailView(movieId: dest.id, movieTitle: dest.title)
                    }
                    .navigationDestination(for: TvNavDestination.self) { dest in
                        TvShowDetailView(tvId: dest.id, showTitle: dest.title)
                    }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                RequestListView()
                    .navigationDestination(for: MovieNavDestination.self) { dest in
                        MovieDetailView(movieId: dest.id, movieTitle: dest.title)
                    }
                    .navigationDestination(for: TvNavDestination.self) { dest in
                        TvShowDetailView(tvId: dest.id, showTitle: dest.title)
                    }
            }
            .tabItem { Label("Requests", systemImage: "tray.full") }

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.circle") }
        }
    }

    /// Spinner shown while auth state is being resolved.
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Connecting…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("No Server") {
    let store = ServerStore()
    let state = AppState(serverStore: store)
    return ContentView()
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
    state.selectServer(server)
    let mockUser = User(
        id: 1,
        email: "admin@example.com",
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
    state.setAuthenticatedUser(mockUser)
    return ContentView()
        .environment(state)
        .environment(store)
}
