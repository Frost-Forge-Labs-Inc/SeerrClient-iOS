// WatchlistViewModel.swift
// SeerrClient
//
// Manages loading and pagination for the user's Plex watchlist.

import Foundation

// MARK: - WatchlistLoadState

public enum WatchlistLoadState: Equatable {
    case idle
    case loading
    case loaded([DiscoverMediaItem])
    case empty
    case error(String)
}

// MARK: - WatchlistViewModel

@MainActor
@Observable
public final class WatchlistViewModel {

    // MARK: - Public State

    public private(set) var loadState: WatchlistLoadState = .idle
    public private(set) var items: [DiscoverMediaItem] = []
    public private(set) var isLoadingMore = false
    public private(set) var currentPage = 1
    public private(set) var totalPages = 1
    /// Poster paths fetched from detail API to supplement the watchlist response,
    /// which does not include `posterPath`. Keyed by TMDB item ID.
    public private(set) var posterPaths: [Int: String] = [:]

    public var canLoadMore: Bool {
        currentPage < totalPages && !isLoadingMore
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let repository: DiscoverRepository
    @ObservationIgnored
    private let mediaDetailRepository: MediaDetailRepository?

    // MARK: - Init

    public init(repository: DiscoverRepository, mediaDetailRepository: MediaDetailRepository? = nil) {
        self.repository = repository
        self.mediaDetailRepository = mediaDetailRepository
    }

    // MARK: - Actions

    public func loadIfNeeded() {
        guard case .idle = loadState else { return }
        Task { await load(page: 1, reset: true) }
    }

    public func refresh() async {
        await load(page: 1, reset: true)
    }

    public func retry() {
        Task { await load(page: 1, reset: true) }
    }

    public func onItemAppear(_ item: DiscoverMediaItem) {
        guard canLoadMore else { return }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if index >= items.count - 4 {
            Task { await loadMore() }
        }
    }

    // MARK: - Private

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

    /// Fetches poster paths for watchlist items by calling the detail endpoints
    /// in parallel. The watchlist API does not include `posterPath`, so this
    /// enrichment step is required to display images.
    private func enrichPosterPaths(for items: [DiscoverMediaItem]) async {
        guard let mediaRepo = mediaDetailRepository else { return }
        await withTaskGroup(of: (Int, String?).self) { group in
            for item in items {
                group.addTask {
                    let posterPath: String?
                    // Use effectiveTmdbId — for Jellyfin users item.id is an internal
                    // DB row ID, not a TMDB ID. tmdbId holds the real TMDB identifier.
                    let tmdbId = item.effectiveTmdbId
                    if item.isMovie {
                        posterPath = try? await mediaRepo.fetchMovieDetails(movieId: tmdbId).posterPath
                    } else if item.isTv {
                        posterPath = try? await mediaRepo.fetchTvDetails(tvId: tmdbId).posterPath
                    } else {
                        posterPath = nil
                    }
                    return (item.id, posterPath)
                }
            }
            for await (id, posterPath) in group {
                if let posterPath {
                    posterPaths[id] = posterPath
                }
            }
        }
    }

    private func loadMore() async {
        guard canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await load(page: currentPage + 1, reset: false)
    }
}
