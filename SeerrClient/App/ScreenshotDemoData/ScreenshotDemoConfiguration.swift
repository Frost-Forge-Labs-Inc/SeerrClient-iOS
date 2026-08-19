// ScreenshotDemoConfiguration.swift
// SeerrClient
//
// DEBUG-only launch configuration for the wholly fictional screenshot catalog.

import Foundation

// MARK: - ScreenshotDemoRootDestination

/// The root content selected by Screenshot Demo Mode.
enum ScreenshotDemoRootDestination: Equatable {
    case mainTabs
    case movieDetail(id: Int, title: String)
    case tvDetail(id: Int, title: String)
}

#if DEBUG

// MARK: - ScreenshotDemoScene

/// The launch destinations supported by Screenshot Demo Mode.
enum ScreenshotDemoScene: String, Sendable {
    case discover
    case mediaDetail
    case tvEpisodes
    case requestFlow
    case watchlist
    case multiServer
}

// MARK: - ScreenshotDemoScrollAnchor

/// The in-app destinations available for screenshot demo scrolling.
enum ScreenshotDemoScrollAnchor: String, Sendable {
    /// The season picker and episode list in a TV show detail screen.
    case episodes
}

// MARK: - ScreenshotDemoConfiguration

/// Reads and validates Screenshot Demo Mode launch environment variables once per process.
struct ScreenshotDemoConfiguration: Sendable {
    static let modeKey = "SCREENSHOT_DEMO_MODE"
    static let catalogPathKey = "SCREENSHOT_DEMO_CATALOG_PATH"
    static let sceneKey = "SCREENSHOT_DEMO_SCENE"
    /// The launch environment variable selecting an in-app scroll destination.
    static let scrollToKey = "SCREENSHOT_DEMO_SCROLL_TO"

    let catalogRoot: String?
    let scene: ScreenshotDemoScene
    /// The optional in-app destination to scroll to after its content loads.
    let scrollAnchor: ScreenshotDemoScrollAnchor?
    let isEnabled: Bool
    let catalog: ScreenshotDemoCatalog?

    /// The immutable launch configuration shared by every demo-mode caller.
    static let current: ScreenshotDemoConfiguration = {
        let environment = ProcessInfo.processInfo.environment
        let scene = environment[sceneKey]
            .flatMap(ScreenshotDemoScene.init(rawValue:)) ?? .discover
        let scrollAnchor = environment[scrollToKey]
            .flatMap(ScreenshotDemoScrollAnchor.init(rawValue:))

        guard environment[modeKey] == "1",
              let root = environment[catalogPathKey],
              FileManager.default.isReadableFile(atPath: root + "/catalog.json"),
              let catalog = ScreenshotDemoCatalog.load(from: root) else {
            return ScreenshotDemoConfiguration(
                catalogRoot: nil,
                scene: scene,
                scrollAnchor: scrollAnchor,
                isEnabled: false,
                catalog: nil
            )
        }

        return ScreenshotDemoConfiguration(
            catalogRoot: root,
            scene: scene,
            scrollAnchor: scrollAnchor,
            isEnabled: true,
            catalog: catalog
        )
    }()

    /// The tab shown when the demo scene starts in the main interface.
    var initialTab: AppTab {
        scene == .watchlist ? .watchlist : .discover
    }

    /// The first destination for the selected demo scene.
    var rootDestination: ScreenshotDemoRootDestination {
        guard let catalog else { return .mainTabs }

        switch scene {
        case .mediaDetail, .requestFlow, .tvEpisodes:
            switch catalog.featuredItem(forScene: scene) {
            case .movie(let movie):
                return .movieDetail(id: catalog.movieID(for: movie.id), title: movie.title)
            case .tvShow(let show):
                return .tvDetail(id: catalog.tvID(for: show.id), title: show.title)
            case nil:
                return .mainTabs
            }
        case .discover, .watchlist, .multiServer:
            return .mainTabs
        }
    }
}

#else

/// The single release-mode scene placeholder.
enum ScreenshotDemoScene {
    case discover
}

/// The inert release-mode screenshot demo scroll destination placeholder.
enum ScreenshotDemoScrollAnchor {}

/// Inert release-mode screenshot demo configuration.
struct ScreenshotDemoConfiguration {
    let catalogRoot: String? = nil
    let scene: ScreenshotDemoScene = .discover
    /// The inert release-mode screenshot demo scroll destination.
    let scrollAnchor: ScreenshotDemoScrollAnchor? = nil
    let isEnabled = false
    let initialTab: AppTab = .discover
    let rootDestination: ScreenshotDemoRootDestination = .mainTabs
    static let current = ScreenshotDemoConfiguration()
}

#endif
