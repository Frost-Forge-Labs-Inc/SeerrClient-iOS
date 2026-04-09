// WatchlistViewModel.swift
// SeerrClient
//
// Manages loading, segmentation, and pagination for the user's watchlist.

import Foundation

// MARK: - WatchlistLoadState

public enum WatchlistLoadState: Equatable {
    case idle
    case loading
    case loaded([DiscoverMediaItem])
    case empty
    case error(String)
}

// MARK: - WatchlistMediaSegment

public enum WatchlistMediaSegment: String, CaseIterable, Sendable, Hashable {
    case movies
    case tvShows

    public var title: String {
        switch self {
        case .movies:
            return "Movies"
        case .tvShows:
            return "TV Shows"
        }
    }

    public var emptyTitle: String {
        switch self {
        case .movies:
            return "No Movies in Watchlist"
        case .tvShows:
            return "No TV Shows in Watchlist"
        }
    }

    public var emptyMessage: String {
        switch self {
        case .movies:
            return "Switch to TV Shows or add movies to your watchlist."
        case .tvShows:
            return "Switch to Movies or add TV shows to your watchlist."
        }
    }

    public func matches(_ item: DiscoverMediaItem) -> Bool {
        switch self {
        case .movies:
            return item.isMovie
        case .tvShows:
            return item.isTv
        }
    }
}

// MARK: - WatchlistViewModel

@MainActor
@Observable
public final class WatchlistViewModel {

    // MARK: - Public State

    public private(set) var loadState: WatchlistLoadState = .idle
    public private(set) var selectedMediaSegment: WatchlistMediaSegment = .movies
    public private(set) var items: [DiscoverMediaItem] = []
    public private(set) var isLoadingMore = false
    public private(set) var currentPage = 1
    public private(set) var totalPages = 1
    /// Poster paths fetched from detail API to supplement the watchlist response,
    /// which does not include `posterPath`. Keyed by watchlist item ID.
    public private(set) var posterPaths: [Int: String] = [:]

    /// Release/air years fetched from detail API to supplement the watchlist response,
    /// which does not include `releaseDate` or `firstAirDate`. Keyed by watchlist item ID.
    public private(set) var years: [Int: String] = [:]

    public var visibleItems: [DiscoverMediaItem] {
        items.filter(selectedMediaSegment.matches)
    }

    public var canLoadMore: Bool {
        hasMorePages && !isLoadingMore
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let repository: any WatchlistFetching
    @ObservationIgnored
    private let mediaDetailRepository: MediaDetailRepository?
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?
    @ObservationIgnored
    private var mediaSegmentSelectionTask: Task<Void, Never>?

    // MARK: - Init

    public init(repository: any WatchlistFetching, mediaDetailRepository: MediaDetailRepository? = nil) {
        self.repository = repository
        self.mediaDetailRepository = mediaDetailRepository
    }

    // MARK: - Actions

    public func loadIfNeeded() {
        guard case .idle = loadState else { return }
        Task { await refresh() }
    }

    public func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.refreshTask = nil }
            await self.load(page: 1, reset: true)
            await self.loadAdditionalPagesIfNeeded(previousVisibleCount: 0)
        }

        refreshTask = task
        await task.value
    }

    public func retry() {
        Task { await refresh() }
    }

    public func selectMediaSegment(_ mediaSegment: WatchlistMediaSegment) {
        mediaSegmentSelectionTask?.cancel()
        mediaSegmentSelectionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.mediaSegmentSelectionTask = nil }
            await self.applySelectedMediaSegment(mediaSegment)
        }
    }

    /// Reconciles the currently visible watchlist items against the app-level
    /// TMDB ID cache after a detail screen adds/removes watchlist membership.
    ///
    /// This keeps the Watchlist tab in sync when the user navigates back from a
    /// detail screen without forcing a full network refresh.
    func reconcileWithWatchlistIds(_ watchlistedTmdbIds: Set<Int>) {
        guard !items.isEmpty else { return }

        let filteredItems = items.filter { watchlistedTmdbIds.contains($0.effectiveTmdbId) }
        guard filteredItems.count != items.count else { return }

        let removedItemIds = Set(items.map(\.id)).subtracting(filteredItems.map(\.id))
        items = filteredItems

        if !removedItemIds.isEmpty {
            posterPaths = posterPaths.filter { !removedItemIds.contains($0.key) }
            years = years.filter { !removedItemIds.contains($0.key) }
        }

        loadState = items.isEmpty ? .empty : .loaded(items)
    }

    public func onItemAppear(_ item: DiscoverMediaItem) {
        guard canLoadMore else { return }
        let visibleItems = visibleItems
        guard let index = visibleItems.firstIndex(where: { $0.id == item.id }) else { return }

        let thresholdIndex = max(visibleItems.count - 4, 0)
        if index >= thresholdIndex {
            Task { await loadMore() }
        }
    }

    // MARK: - Private

    private var hasMorePages: Bool {
        currentPage < totalPages
    }

    private func load(page: Int, reset: Bool) async {
        if reset {
            items = []
            currentPage = 1
            totalPages = 1
            loadState = .loading
        }

        do {
            let response = try await repository.fetchWatchlist(page: page)
            let fetched = response.results

            if reset {
                items = fetched
            } else {
                items.append(contentsOf: fetched)
            }

            currentPage = response.page
            totalPages = response.totalPages
            loadState = items.isEmpty ? .empty : .loaded(items)

            // Watchlist endpoint doesn't include posterPath — enrich in background.
            if !fetched.isEmpty {
                Task { await enrichPosterPaths(for: fetched) }
            }
        } catch {
            AppLogger.warning("WatchlistViewModel: load failed (page=\(page)) — \(error)")
            if items.isEmpty {
                loadState = .error("Could not load your watchlist. Check your connection.")
            } else {
                loadState = .loaded(items)
            }
        }
    }

    /// Fetches poster paths and release years for watchlist items by calling the
    /// detail endpoints in parallel. The watchlist API does not include `posterPath`,
    /// `releaseDate`, or `firstAirDate`, so this enrichment step is required to
    /// display images and years.
    private func enrichPosterPaths(for items: [DiscoverMediaItem]) async {
        guard let mediaRepo = mediaDetailRepository else { return }
        await withTaskGroup(of: (Int, String?, String?).self) { group in
            for item in items {
                group.addTask {
                    let posterPath: String?
                    let year: String?
                    // Use effectiveTmdbId — for Jellyfin users item.id is an internal
                    // DB row ID, not a TMDB ID. tmdbId holds the real TMDB identifier.
                    let tmdbId = item.effectiveTmdbId
                    if item.isMovie {
                        let details = try? await mediaRepo.fetchMovieDetails(movieId: tmdbId)
                        posterPath = details?.posterPath
                        year = details?.releaseDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
                    } else if item.isTv {
                        let details = try? await mediaRepo.fetchTvDetails(tvId: tmdbId)
                        posterPath = details?.posterPath
                        let startYear = details?.firstAirDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
                        if let startYear {
                            if details?.inProduction == true {
                                year = "\(startYear)–Present"
                            } else if let endYr = details?.lastAirDate.flatMap({ $0.count >= 4 ? String($0.prefix(4)) : nil }) {
                                year = "\(startYear)–\(endYr)"
                            } else {
                                year = startYear
                            }
                        } else {
                            year = nil
                        }
                    } else {
                        posterPath = nil
                        year = nil
                    }
                    return (item.id, posterPath, year)
                }
            }
            for await (id, posterPath, year) in group {
                if let posterPath {
                    posterPaths[id] = posterPaths[id] ?? posterPath
                }
                if let year {
                    years[id] = years[id] ?? year
                }
            }
        }
    }

    private func loadMore() async {
        guard canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let previousVisibleCount = visibleItems.count
        await load(page: currentPage + 1, reset: false)
        await loadAdditionalPagesIfNeeded(previousVisibleCount: previousVisibleCount)
    }

    func applySelectedMediaSegment(_ mediaSegment: WatchlistMediaSegment) async {
        guard mediaSegment != selectedMediaSegment else { return }
        selectedMediaSegment = mediaSegment

        let shouldShowLoadingIndicator = visibleItems.isEmpty && canLoadMore
        if shouldShowLoadingIndicator {
            isLoadingMore = true
        }
        defer {
            if shouldShowLoadingIndicator {
                isLoadingMore = false
            }
        }

        await loadAdditionalPagesIfNeeded(previousVisibleCount: 0)
    }

    private func loadAdditionalPagesIfNeeded(previousVisibleCount: Int) async {
        guard !items.isEmpty else { return }

        while visibleItems.count == previousVisibleCount && hasMorePages {
            await load(page: currentPage + 1, reset: false)
        }
    }
}
