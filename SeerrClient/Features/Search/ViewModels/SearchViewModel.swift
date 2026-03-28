// SearchViewModel.swift
// SeerrClient
//
// Manages the Search screen UI state: debounced query input, type filter
// selection, paginated results, and infinite scroll triggering.
// Uses a Task-based 300ms debounce to avoid excessive API calls.

import Foundation
import SwiftUI

// MARK: - SearchLoadState

/// Represents the current state of the search screen.
public enum SearchLoadState: Equatable {
    /// No query entered and search bar not focused.
    case idle
    /// API call in flight (initial search or filter change).
    case loading
    /// Results loaded successfully.
    case loaded
    /// Query returned zero results.
    case empty
    /// An error occurred.
    case error(String)

    public static func == (lhs: SearchLoadState, rhs: SearchLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded), (.empty, .empty):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - SearchViewModel

/// ViewModel for the Search screen.
///
/// Manages query input with 300ms debounce, type filter selection, paginated
/// results with infinite scroll, and error handling.
@MainActor @Observable
public final class SearchViewModel {

    // MARK: - Public State

    /// The current search query text (bound to the search bar).
    public var searchQuery: String = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            onQueryChanged()
        }
    }

    /// The currently selected type filter.
    public private(set) var selectedType: SearchType = .all

    /// The current load state.
    public private(set) var loadState: SearchLoadState = .idle

    /// The accumulated search results across pages.
    public private(set) var results: [SearchResultItem] = []

    /// Current page number (1-based).
    public private(set) var currentPage: Int = 0

    /// Total pages available for the current query.
    public private(set) var totalPages: Int = 0

    /// Total result count for the current query.
    public private(set) var totalResults: Int = 0

    /// Whether a next-page load is in progress.
    public private(set) var isLoadingMore: Bool = false

    /// Whether more pages can be loaded.
    public var canLoadMore: Bool {
        currentPage > 0 && currentPage < totalPages && !isLoadingMore
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let repository: SearchRepository

    // MARK: - Private

    @ObservationIgnored
    private var searchTask: Task<Void, Never>?

    @ObservationIgnored
    private var loadMoreTask: Task<Void, Never>?

    // MARK: - Init

    /// Creates a SearchViewModel with the given repository.
    ///
    /// - Parameter repository: The `SearchRepository` to fetch results from.
    public init(repository: SearchRepository) {
        self.repository = repository
    }

    // MARK: - Public Methods

    /// Changes the type filter and re-runs the search from page 1.
    ///
    /// - Parameter type: The new search type to filter by.
    public func selectType(_ type: SearchType) {
        guard type != selectedType else { return }
        selectedType = type
        resetAndSearch()
    }

    /// Triggers a fresh search (used by pull-to-refresh or retry).
    public func refresh() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        resetResults()
        await executeSearch(page: 1)
    }

    /// Loads the next page of results for infinite scroll.
    public func loadMoreIfNeeded() {
        guard canLoadMore else { return }
        isLoadingMore = true
        loadMoreTask?.cancel()
        loadMoreTask = Task {
            defer { isLoadingMore = false }
            await executeSearch(page: currentPage + 1)
        }
    }

    /// Called when a result item appears on screen. Triggers load-more when
    /// within 3 items of the end.
    ///
    /// - Parameter item: The item that just appeared.
    public func onItemAppear(_ item: SearchResultItem) {
        guard let index = results.firstIndex(where: { $0.id == item.id && $0.mediaType == item.mediaType }) else {
            return
        }
        if index >= results.count - 3 {
            loadMoreIfNeeded()
        }
    }

    // MARK: - Private Methods

    /// Called when the query text changes. Debounces by 300ms then searches.
    private func onQueryChanged() {
        searchTask?.cancel()
        loadMoreTask?.cancel()

        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            resetResults()
            loadState = .idle
            return
        }

        loadState = .loading
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            } catch {
                return // cancelled
            }
            guard !Task.isCancelled else { return }
            resetResults()
            await executeSearch(page: 1)
        }
    }

    /// Resets results and triggers a new search from page 1 (used on filter change).
    private func resetAndSearch() {
        searchTask?.cancel()
        loadMoreTask?.cancel()

        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            resetResults()
            loadState = .idle
            return
        }

        loadState = .loading
        resetResults()
        searchTask = Task {
            await executeSearch(page: 1)
        }
    }

    /// Executes the actual search API call.
    private func executeSearch(page: Int) async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        do {
            let response = try await repository.search(
                query: query,
                type: selectedType,
                page: page
            )

            guard !Task.isCancelled else { return }

            if page == 1 {
                results = response.results
            } else {
                results.append(contentsOf: response.results)
            }

            currentPage = response.page
            totalPages = response.totalPages
            totalResults = response.totalResults

            if results.isEmpty {
                loadState = .empty
            } else {
                loadState = .loaded
            }
        } catch {
            guard !Task.isCancelled else { return }
            AppLogger.warning("SearchViewModel: search failed for '\(query)' page \(page): \(error)")

            // Only show error if we have no results yet (don't wipe existing results on page-load failure)
            if results.isEmpty {
                loadState = .error(userFacingMessage(from: error))
            }
        }
    }

    /// Clears accumulated results and pagination state.
    private func resetResults() {
        results = []
        currentPage = 0
        totalPages = 0
        totalResults = 0
        isLoadingMore = false
    }

    /// Maps API errors to user-friendly messages.
    private func userFacingMessage(from error: Error) -> String {
        if let apiError = error as? SeerrAPIError {
            switch apiError {
            case .networkError:
                return "Unable to search. Check your connection and try again."
            case .decodingError:
                return "Invalid response from server."
            case .httpError(let statusCode, _) where statusCode == 429:
                return "Too many requests. Please wait a moment and try again."
            case .httpError(let statusCode, _):
                return "Server error (\(statusCode)). Please try again."
            default:
                return "Something went wrong. Please try again."
            }
        }
        if error is CancellationError { return "Search was interrupted. Please try again." }
        return "Something went wrong. Please try again."
    }
}
