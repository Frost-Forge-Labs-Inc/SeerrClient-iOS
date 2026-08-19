// ScreenshotDemoBootstrapper.swift
// SeerrClient
//
// DEBUG-only launch bootstrap for the fictional Screenshot Demo Mode.

import Foundation

#if DEBUG

// MARK: - ScreenshotDemoBootstrapper

/// Seeds isolated demo servers and an authenticated fictional user at launch.
@MainActor
enum ScreenshotDemoBootstrapper {

    /// Configures the app state from the process-lifetime screenshot demo snapshot.
    static func configureIfNeeded(appState: AppState, serverStore: ServerStore) {
        let configuration = ScreenshotDemoConfiguration.current
        guard configuration.isEnabled,
              ServerStore.isUsingScreenshotDemoDefaults,
              let catalog = configuration.catalog else {
            return
        }

        let capabilities = ServerCapabilities(
            backendType: .jellyseerr,
            publicSettings: PublicSettingsNormalized(
                initialized: true,
                applicationTitle: "Octopus Explorer Demo",
                localLoginEnabled: true,
                mediaServerLoginEnabled: true,
                mediaServerKind: .jellyfin
            )
        )
        guard let server = seedServers(
            catalog.servers,
            capabilities: capabilities,
            serverStore: serverStore
        ) else {
            return
        }

        guard configuration.scene != .multiServer else { return }

        appState.selectServer(server, capabilities: capabilities)
        appState.setAuthenticatedUser(User(
            id: 1,
            email: "demo@octopusexplorer.invalid",
            displayName: "Demo Explorer",
            username: "demo",
            plexToken: nil,
            plexUsername: nil,
            userType: 2,
            permissions: 2,
            avatar: nil,
            createdAt: nil,
            updatedAt: nil,
            requestCount: 0
        ))

        let watchlist = catalog.items(featuredIn: "watchlist")
        appState.watchlistedTmdbIds = Set(
            watchlist.0.map { catalog.movieID(for: $0.id) }
                + watchlist.1.map { catalog.tvID(for: $0.id) }
        )
        appState.watchlistNeedsRefresh = false
    }

    // MARK: - Private Helpers

    /// Replaces only isolated demo servers and returns the stored default server instance.
    private static func seedServers(
        _ source: [ScreenshotDemoCatalog.Server],
        capabilities: ServerCapabilities,
        serverStore: ServerStore
    ) -> ServerConfiguration? {
        for server in serverStore.servers where ScreenshotDemoURLProtocol.isDemoServer(server) {
            serverStore.remove(server)
        }

        var defaultServer: ServerConfiguration?
        for (index, item) in source.enumerated() {
            guard let id = UUID(uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                index + 1
            )) else {
                continue
            }

            let backend: BackendType = item.type?.lowercased() == "overseerr"
                ? .overseerr
                : .jellyseerr
            let server = ServerConfiguration(
                id: id,
                displayName: item.name,
                baseURL: ScreenshotDemoURLProtocol.baseURLString(for: index),
                backendType: backend,
                authMethod: .none,
                availableAuthMethods: index == 0 ? capabilities.availableAuthMethods : nil,
                capabilities: index == 0 ? capabilities : nil,
                isDefault: index == 0
            )
            serverStore.add(server)
            if index == 0 {
                defaultServer = server
            }
        }
        return defaultServer
    }
}

#else

@MainActor
enum ScreenshotDemoBootstrapper {
    /// Does nothing outside of DEBUG builds.
    static func configureIfNeeded(appState: AppState, serverStore: ServerStore) {}
}

#endif
