// DiscoverViewModel.swift
// SeerrClient
//
// Presentation logic for the Discover screen. Manages the load state machine,
// pulls slider content from DiscoverRepository, and exposes observable state
// for DiscoverView to render.

import Foundation

// MARK: - DiscoverLoadState

/// The loading state of the discover page.
public enum DiscoverLoadState: Equatable {
    /// Initial state — no load attempted yet.
    case idle
    /// First load in progress — show skeleton placeholders.
    case loading
    /// Content loaded successfully.
    case loaded
    /// Content loaded but no enabled sliders or all sliders returned empty.
    case empty
    /// Load failed with an error message.
    case error(String)
}

// MARK: - DiscoverViewModel

/// @Observable ViewModel for the Discover tab.
///
/// Manages fetching and refreshing discover slider content. The view reads
/// `loadState` and `sliderRows` to decide what to render.
///
/// Usage:
/// ```swift
/// @State private var viewModel = DiscoverViewModel(repository: repo)
/// // In .task: await viewModel.loadDiscover()
/// // In .refreshable: await viewModel.refresh()
/// ```
@MainActor
@Observable
public final class DiscoverViewModel {

    // MARK: - Published State

    /// Current loading state — drives the view's top-level branch.
    public private(set) var loadState: DiscoverLoadState = .idle

    /// The slider rows to display, each containing a title and media items.
    public private(set) var sliderRows: [SliderContent] = []

    /// Whether a pull-to-refresh is in progress (keeps existing content visible).
    public private(set) var isRefreshing: Bool = false

    // MARK: - Dependencies

    private let repository: DiscoverRepository

    // MARK: - Init

    /// Creates a ViewModel backed by the given repository.
    ///
    /// - Parameter repository: The `DiscoverRepository` to fetch content from.
    public init(repository: DiscoverRepository) {
        self.repository = repository
    }

    // MARK: - Actions

    /// Performs the initial load of discover content.
    ///
    /// Only runs when `loadState` is `.idle` — subsequent calls are no-ops.
    /// Sets state to `.loading` → fetches sliders → fetches content → `.loaded` / `.empty` / `.error`.
    public func loadDiscover() async {
        guard loadState == .idle else { return }
        loadState = .loading
        await performLoad()
    }

    /// Pull-to-refresh: re-fetches all content while keeping existing rows visible.
    ///
    /// On success, replaces `sliderRows` and stays in `.loaded`. On failure, retains
    /// the old content and stays in `.loaded` (the user still sees the previous data).
    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let sliders = try await repository.fetchEnabledSliders()
            let content = await repository.fetchAllContent(for: sliders)

            if content.isEmpty {
                // Don't wipe visible content if refresh yields nothing.
                if sliderRows.isEmpty {
                    loadState = .empty
                }
            } else {
                sliderRows = content
                loadState = .loaded
            }
        } catch {
            // Refresh failure: keep existing content, don't transition to error.
            AppLogger.warning("DiscoverViewModel: refresh failed — \(error)")
        }
    }

    /// Retry after an error — resets to idle and re-triggers initial load.
    public func retry() async {
        loadState = .idle
        await loadDiscover()
    }

    // MARK: - Private

    private func performLoad() async {
        do {
            let sliders = try await repository.fetchEnabledSliders()

            if sliders.isEmpty {
                loadState = .empty
                return
            }

            let content = await repository.fetchAllContent(for: sliders)

            if content.isEmpty {
                loadState = .empty
            } else {
                sliderRows = content
                loadState = .loaded
            }
        } catch {
            loadState = .error(userFacingMessage(for: error))
        }
    }

    /// Converts an API error to a user-friendly message.
    private func userFacingMessage(for error: Error) -> String {
        if let apiError = error as? SeerrAPIError {
            switch apiError {
            case .timeout:
                return "The server took too long to respond. Check your connection and try again."
            case .unauthorized:
                return "Your session has expired. Please sign in again."
            case .networkError:
                return "Unable to reach the server. Check your network connection."
            case .sslError:
                return "A secure connection could not be established."
            default:
                return "Something went wrong loading discover content. Please try again."
            }
        }
        return "An unexpected error occurred. Please try again."
    }
}
