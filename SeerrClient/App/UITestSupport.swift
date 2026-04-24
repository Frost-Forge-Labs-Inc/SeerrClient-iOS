// UITestSupport.swift
// SeerrClient
//
// Shared launch-time configuration used by XCUITest runs. This lets the app
// boot into deterministic scenarios without depending on a live Seerr server.

import Foundation

// MARK: - AppTab

enum AppTab: Hashable {
    case discover
    case search
    case requests
    case watchlist
    case profile
}

// MARK: - UITestRootDestination

enum UITestRootDestination: Equatable {
    case mainTabs
    case collectionDetail(id: Int, name: String)
}

#if DEBUG

// MARK: - UITestScenario

enum UITestScenario: String {
    case watchlistRemoval = "watchlist_removal"
    case watchlistMediaFilter = "watchlist_media_filter"
    case requestMediaFilter = "request_media_filter"
    case collectionRequestSelection = "collection_request_selection"
    case aboutNavigation = "about_navigation"
    case launchFlowServerSelection = "launch_flow_server_selection"
}

// MARK: - UITestLaunchConfiguration

struct UITestLaunchConfiguration {
    static let scenarioKey = "SEERR_UI_TEST_SCENARIO"
    static let disableLaunchAnimationKey = "SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"
    static let watchlistContainerWidthKey = "SEERR_UI_TEST_WATCHLIST_CONTAINER_WIDTH"

    let scenario: UITestScenario?
    let disableLaunchAnimation: Bool
    let watchlistContainerWidth: CGFloat?
    let initialTab: AppTab
    let rootDestination: UITestRootDestination

    static var current: UITestLaunchConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let scenario = environment[scenarioKey].flatMap(UITestScenario.init(rawValue:))
        let disableLaunchAnimation = environment[disableLaunchAnimationKey] == "1"
        let watchlistContainerWidth = environment[watchlistContainerWidthKey]
            .flatMap(Double.init)
            .map { CGFloat($0) }
        let initialTab: AppTab = {
            switch scenario {
            case .watchlistRemoval:
                return .watchlist
            case .watchlistMediaFilter:
                return .watchlist
            case .requestMediaFilter:
                return .requests
            case .collectionRequestSelection:
                return .discover
            case .aboutNavigation:
                return .profile
            case .launchFlowServerSelection:
                return .discover
            case nil:
                return .discover
            }
        }()
        let rootDestination: UITestRootDestination = {
            switch scenario {
            case .collectionRequestSelection:
                return .collectionDetail(id: 1000, name: "Collection UI Test")
            case .watchlistRemoval, .watchlistMediaFilter, .requestMediaFilter, .aboutNavigation, .launchFlowServerSelection, nil:
                return .mainTabs
            }
        }()

        return UITestLaunchConfiguration(
            scenario: scenario,
            disableLaunchAnimation: disableLaunchAnimation,
            watchlistContainerWidth: watchlistContainerWidth,
            initialTab: initialTab,
            rootDestination: rootDestination
        )
    }

    var isEnabled: Bool {
        scenario != nil
    }
}

// MARK: - UITestAppBootstrapper

@MainActor
enum UITestAppBootstrapper {

    static func configureIfNeeded(appState: AppState, serverStore: ServerStore) {
        let configuration = UITestLaunchConfiguration.current
        guard let scenario = configuration.scenario else { return }

        UITestURLProtocol.resetState(for: scenario)

        switch scenario {
        case .watchlistRemoval:
            bootstrapWatchlistRemovalScenario(appState: appState)
        case .watchlistMediaFilter:
            bootstrapWatchlistMediaFilterScenario(appState: appState)
        case .requestMediaFilter:
            bootstrapRequestMediaFilterScenario(appState: appState)
        case .collectionRequestSelection:
            bootstrapCollectionRequestScenario(appState: appState)
        case .aboutNavigation:
            bootstrapAboutNavigationScenario(appState: appState)
        case .launchFlowServerSelection:
            bootstrapLaunchFlowServerSelectionScenario(serverStore: serverStore)
        }
    }

    private static func bootstrapWatchlistRemovalScenario(appState: AppState) {
        bootstrapAuthenticatedMainTabsScenario(appState: appState, watchlistedTmdbIds: [550])
    }

    private static func bootstrapWatchlistMediaFilterScenario(appState: AppState) {
        bootstrapAuthenticatedMainTabsScenario(
            appState: appState,
            watchlistedTmdbIds: [550, 551, 552, 553, 1399]
        )
    }

    private static func bootstrapRequestMediaFilterScenario(appState: AppState) {
        bootstrapAuthenticatedMainTabsScenario(appState: appState, watchlistedTmdbIds: [])
    }

    private static func bootstrapAuthenticatedMainTabsScenario(
        appState: AppState,
        watchlistedTmdbIds: Set<Int>
    ) {
        let publicSettings = PublicSettingsNormalized(
            initialized: true,
            applicationTitle: "UI Test Jellyseerr",
            localLoginEnabled: true,
            mediaServerLoginEnabled: true,
            mediaServerKind: .jellyfin
        )
        let capabilities = ServerCapabilities(
            backendType: .jellyseerr,
            publicSettings: publicSettings
        )
        let server = ServerConfiguration(
            displayName: "UI Test Jellyseerr",
            baseURL: UITestURLProtocol.baseURLString,
            backendType: .jellyseerr,
            authMethod: .local,
            availableAuthMethods: capabilities.availableAuthMethods,
            capabilities: capabilities
        )
        let user = User(
            id: 1,
            email: "uitest@example.com",
            displayName: "UI Tester",
            username: "uitester",
            plexToken: nil,
            plexUsername: nil,
            userType: 2,
            permissions: 2,
            avatar: nil,
            createdAt: "2026-04-08T00:00:00.000Z",
            updatedAt: "2026-04-08T00:00:00.000Z",
            requestCount: 0
        )

        appState.selectServer(server, capabilities: capabilities)
        appState.setAuthenticatedUser(user)
        appState.watchlistedTmdbIds = watchlistedTmdbIds
        appState.watchlistNeedsRefresh = false
    }

    private static func bootstrapCollectionRequestScenario(appState: AppState) {
        let publicSettings = PublicSettingsNormalized(
            initialized: true,
            applicationTitle: "UI Test Jellyseerr",
            localLoginEnabled: true,
            mediaServerLoginEnabled: true,
            mediaServerKind: .jellyfin
        )
        let capabilities = ServerCapabilities(
            backendType: .jellyseerr,
            publicSettings: publicSettings
        )
        let server = ServerConfiguration(
            displayName: "UI Test Jellyseerr",
            baseURL: UITestURLProtocol.baseURLString,
            backendType: .jellyseerr,
            authMethod: .local,
            availableAuthMethods: capabilities.availableAuthMethods,
            capabilities: capabilities
        )
        let user = User(
            id: 1,
            email: "uitest@example.com",
            displayName: "UI Tester",
            username: "uitester",
            plexToken: nil,
            plexUsername: nil,
            userType: 2,
            permissions: 2,
            avatar: nil,
            createdAt: "2026-04-08T00:00:00.000Z",
            updatedAt: "2026-04-08T00:00:00.000Z",
            requestCount: 0
        )

        appState.selectServer(server, capabilities: capabilities)
        appState.setAuthenticatedUser(user)
        appState.watchlistedTmdbIds = []
        appState.watchlistNeedsRefresh = false
    }

    private static func bootstrapAboutNavigationScenario(appState: AppState) {
        let publicSettings = PublicSettingsNormalized(
            initialized: true,
            applicationTitle: "UI Test Jellyseerr",
            localLoginEnabled: true,
            mediaServerLoginEnabled: true,
            mediaServerKind: .jellyfin
        )
        let capabilities = ServerCapabilities(
            backendType: .jellyseerr,
            publicSettings: publicSettings
        )
        let server = ServerConfiguration(
            displayName: "UI Test Jellyseerr",
            baseURL: UITestURLProtocol.baseURLString,
            backendType: .jellyseerr,
            authMethod: .local,
            availableAuthMethods: capabilities.availableAuthMethods,
            capabilities: capabilities
        )
        let user = User(
            id: 1,
            email: "uitest@example.com",
            displayName: "UI Tester",
            username: "uitester",
            plexToken: nil,
            plexUsername: nil,
            userType: 2,
            permissions: 2,
            avatar: nil,
            createdAt: "2026-04-08T00:00:00.000Z",
            updatedAt: "2026-04-08T00:00:00.000Z",
            requestCount: 0
        )

        appState.selectServer(server, capabilities: capabilities)
        // Keep the About-flow scenario deterministic and quiet at launch.
        // Other UI scenarios exercise the post-auth watchlist/bootstrap path.
        appState.currentUser = user
        appState.authError = nil
        appState.isAuthenticating = false
        appState.watchlistedTmdbIds = []
        appState.watchlistNeedsRefresh = false
    }

    private static func bootstrapLaunchFlowServerSelectionScenario(serverStore: ServerStore) {
        for server in serverStore.servers {
            serverStore.remove(server)
        }

        let rememberedServerID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let alternateServerID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let rememberedBaseURL = UITestURLProtocol.baseURLString
        let alternateBaseURL = "http://ui-test-alt.seerr:5055"

        KeychainManager.shared.deleteAll(server: rememberedBaseURL)
        KeychainManager.shared.deleteAll(server: alternateBaseURL)

        let publicSettings = PublicSettingsNormalized(
            initialized: true,
            applicationTitle: "UI Test Jellyseerr",
            localLoginEnabled: true,
            mediaServerLoginEnabled: true,
            mediaServerKind: .jellyfin
        )
        let capabilities = ServerCapabilities(
            backendType: .jellyseerr,
            publicSettings: publicSettings
        )

        serverStore.add(ServerConfiguration(
            id: rememberedServerID,
            displayName: "Remembered Server",
            baseURL: rememberedBaseURL,
            backendType: .jellyseerr,
            authMethod: .local,
            availableAuthMethods: capabilities.availableAuthMethods,
            capabilities: capabilities,
            isDefault: true,
            lastConnected: Date()
        ))
        serverStore.add(ServerConfiguration(
            id: alternateServerID,
            displayName: "Needs Login Server",
            baseURL: alternateBaseURL,
            backendType: .jellyseerr,
            authMethod: .none,
            availableAuthMethods: capabilities.availableAuthMethods,
            capabilities: capabilities,
            isDefault: false,
            lastConnected: nil
        ))
        serverStore.setDefault(id: rememberedServerID)

        try? KeychainManager.shared.save("local", for: .authMethod, server: rememberedBaseURL)
        try? KeychainManager.shared.save("uitest@example.com", for: .username, server: rememberedBaseURL)
        try? KeychainManager.shared.save("secret", for: .password, server: rememberedBaseURL)
        try? KeychainManager.shared.save("session-token", for: .sessionToken, server: rememberedBaseURL)
    }
}

#else

struct UITestLaunchConfiguration {
    let disableLaunchAnimation = false
    let watchlistContainerWidth: CGFloat? = nil
    let initialTab: AppTab = .discover
    let rootDestination: UITestRootDestination = .mainTabs

    static let current = UITestLaunchConfiguration()

    var isEnabled: Bool {
        false
    }
}

@MainActor
enum UITestAppBootstrapper {
    static func configureIfNeeded(appState: AppState, serverStore: ServerStore) {}
}

#endif
