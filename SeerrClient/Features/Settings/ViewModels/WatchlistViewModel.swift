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

    public var canLoadMore: Bool {
        currentPage < totalPages && !isLoadingMore
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let repository: DiscoverRepository

    // MARK: - Init

    public init(repository: DiscoverRepository) {
        self.repository = repository
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
            let fetched = response.results ?? []

            if reset {
                items = fetched
            } else {
                items.append(contentsOf: fetched)
            }

            currentPage = response.page ?? page
            totalPages = response.totalPages ?? 1

            loadState = items.isEmpty ? .empty : .loaded(items)
        } catch {
            AppLogger.warning("WatchlistViewModel: load failed (page=\(page)) — \(error)")
            if items.isEmpty {
                loadState = .error("Could not load your watchlist. Check your connection.")
            } else {
                loadState = .loaded(items)
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
