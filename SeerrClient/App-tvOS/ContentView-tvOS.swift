// ContentView-tvOS.swift
// SeerrClientTV (Octopus Explorer — tvOS)
//
// tvOS root view. Mirrors the iOS ContentView's SHARED 3-way AppState decision
// (server-setup / login / main interface) driven by the same shared AppState
// flags, but renders tvOS-native chrome.
//
// Milestone 2 scope:
//  - The main-interface TAB CHROME is REAL: 4 content tabs (Discover, Search,
//    Requests, Watchlist) using the default tvOS TabView (no .sidebarAdaptable),
//    plus Profile as a trailing ICON-ONLY tab (the tvOS-native realization of the
//    "top-bar icon, not a 5th content tab" design decision — mirrors how Apple's
//    own tvOS TV/Photos apps place Search/settings as icon tab items).
//  - Watchlist is capability-gated exactly like iOS via the shared
//    TabSelectionPolicy (server capability, not a platform trait).
//  - Milestone 3 replaces placeholders with real tvOS-native screens that reuse
//    shared repositories/view models. Search and interactive Plex auth are still
//    open M3 follow-ups.

import SwiftUI

// MARK: - TVRootView

struct TVRootView: View {

    @Environment(AppState.self) private var appState
    @Environment(ServerStore.self) private var serverStore

    @State private var selectedTab = UITestLaunchConfiguration.current.initialTab

    private var defaultSessionTab: AppTab {
        UITestLaunchConfiguration.current.initialTab
    }

    var body: some View {
        Group {
            if appState.showServerSetup {
                TVServerSetupView()
            } else if appState.showLogin {
                TVLoginView()
            } else if appState.showMainInterface {
                mainInterface
            } else {
                ProgressView()
                    .scaleEffect(2.0)
            }
        }
        // NOTE: No implicit `.animation(_:value:)` on this Group. On tvOS, animating
        // the wholesale replacement of a focusable subtree (server-setup <-> login <->
        // main) can leave the focus engine unseeded after the transition, making the
        // Siri Remote appear dead. Animate at the state-mutation site with
        // `withAnimation` if a transition is ever needed here.
        .onChange(of: appState.activeServer?.id) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = defaultSessionTab
        }
        .onChange(of: appState.activeServerCapabilities?.supportsWatchlistRead) { _, supported in
            // Never leave selection orphaned on a Watchlist tab that is no longer rendered.
            selectedTab = TabSelectionPolicy.resolvedTab(
                current: selectedTab,
                supportsWatchlistRead: supported,
                defaultSessionTab: defaultSessionTab
            )
        }
    }

    // MARK: Main Interface (tab chrome — REAL for Milestone 2)

    @ViewBuilder
    private var mainInterface: some View {
        let supportsWatchlistRead = appState.activeServerCapabilities?.supportsWatchlistRead ?? false

        TabView(selection: $selectedTab) {
            NavigationStack {
                TVDiscoverView()
                    .navigationDestination(for: MovieNavDestination.self) { dest in
                        TVMovieDetailView(movieId: dest.id, movieTitle: dest.title)
                    }
                    .navigationDestination(for: TvNavDestination.self) { dest in
                        TVShowDetailView(tvId: dest.id, showTitle: dest.title)
                    }
                    .navigationDestination(for: RequestNavDestination.self) { dest in
                        TVRequestDetailView(requestID: dest.requestID)
                    }
            }
                .tabItem { Label("Discover", systemImage: "film.stack") }
                .accessibilityIdentifier("tab.discover")
                .tag(AppTab.discover)

            TVTabPlaceholder(feature: "Search")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .accessibilityIdentifier("tab.search")
                .tag(AppTab.search)

            NavigationStack {
                TVRequestsView()
                    .navigationDestination(for: RequestNavDestination.self) { dest in
                        TVRequestDetailView(requestID: dest.requestID)
                    }
            }
                .tabItem { Label("Requests", systemImage: "tray.full") }
                .accessibilityIdentifier("tab.requests")
                .tag(AppTab.requests)

            if supportsWatchlistRead {
                NavigationStack {
                    TVWatchlistView()
                        .navigationDestination(for: MovieNavDestination.self) { dest in
                            TVMovieDetailView(movieId: dest.id, movieTitle: dest.title)
                        }
                        .navigationDestination(for: TvNavDestination.self) { dest in
                            TVShowDetailView(tvId: dest.id, showTitle: dest.title)
                        }
                }
                    .tabItem { Label("Watchlist", systemImage: "bookmark") }
                    .accessibilityIdentifier("tab.watchlist")
                    .tag(AppTab.watchlist)
            }

            // Profile = trailing ICON-ONLY tab. Image-only tabItem (no text) is the
            // tvOS-native "top-bar icon" affordance; inherits standard remote/Menu focus.
            // accessibilityLabel restores the "Profile" VoiceOver reading that an
            // icon-only tab would otherwise lose vs a text Label.
            TVProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                        .accessibilityLabel("Profile")
                }
                .accessibilityIdentifier("tab.profile")
                .tag(AppTab.profile)
        }
    }
}

// MARK: - Placeholder Views (Milestone 2 — chrome only, content is Milestone 3)

/// Placeholder body for each of the 4 content tabs. Reads the SHARED AppState so
/// the demo proves real state wiring (not just static chrome).
private struct TVTabPlaceholder: View {
    @Environment(AppState.self) private var appState
    let feature: String

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.067, blue: 0.11).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(feature)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
                Text("Milestone 3")
                    .font(.system(size: 29, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                if let user = appState.currentUser {
                    Text("Signed in as \(user.displayName ?? user.username ?? "user")")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("tvOS Main Interface") {
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
    return TVRootView()
        .environment(state)
        .environment(store)
        .onAppear {
            state.selectServer(server)
            state.setAuthenticatedUser(mockUser)
        }
}
