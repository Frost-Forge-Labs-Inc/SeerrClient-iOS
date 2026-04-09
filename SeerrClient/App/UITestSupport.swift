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
    case collectionRequestSelection = "collection_request_selection"
    case aboutNavigation = "about_navigation"
}

// MARK: - UITestLaunchConfiguration

struct UITestLaunchConfiguration {
    static let scenarioKey = "SEERR_UI_TEST_SCENARIO"
    static let disableLaunchAnimationKey = "SEERR_UI_TEST_DISABLE_LAUNCH_ANIMATION"

    let scenario: UITestScenario?
    let disableLaunchAnimation: Bool
    let initialTab: AppTab
    let rootDestination: UITestRootDestination

    static var current: UITestLaunchConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let scenario = environment[scenarioKey].flatMap(UITestScenario.init(rawValue:))
        let disableLaunchAnimation = environment[disableLaunchAnimationKey] == "1"
        let initialTab: AppTab = {
            switch scenario {
            case .watchlistRemoval:
                return .watchlist
            case .collectionRequestSelection:
                return .discover
            case .aboutNavigation:
                return .profile
            case nil:
                return .discover
            }
        }()
        let rootDestination: UITestRootDestination = {
            switch scenario {
            case .collectionRequestSelection:
                return .collectionDetail(id: 1000, name: "Collection UI Test")
            case .watchlistRemoval, .aboutNavigation, nil:
                return .mainTabs
            }
        }()

        return UITestLaunchConfiguration(
            scenario: scenario,
            disableLaunchAnimation: disableLaunchAnimation,
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

    static func configureIfNeeded(appState: AppState) {
        let configuration = UITestLaunchConfiguration.current
        guard let scenario = configuration.scenario else { return }

        UITestURLProtocol.resetState(for: scenario)

        switch scenario {
        case .watchlistRemoval:
            bootstrapWatchlistRemovalScenario(appState: appState)
        case .collectionRequestSelection:
            bootstrapCollectionRequestScenario(appState: appState)
        case .aboutNavigation:
            bootstrapAboutNavigationScenario(appState: appState)
        }
    }

    private static func bootstrapWatchlistRemovalScenario(appState: AppState) {
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
        appState.watchlistedTmdbIds = [550]
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
}

#else

struct UITestLaunchConfiguration {
    let disableLaunchAnimation = false
    let initialTab: AppTab = .discover
    let rootDestination: UITestRootDestination = .mainTabs

    static let current = UITestLaunchConfiguration()

    var isEnabled: Bool {
        false
    }
}

@MainActor
enum UITestAppBootstrapper {
    static func configureIfNeeded(appState: AppState) {}
}

#endif
