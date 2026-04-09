// RequestListViewModel.swift
// SeerrClient
//
// Manages request list loading, filtering, and infinite scroll pagination.

import Foundation

// MARK: - RequestListLoadState

public enum RequestListLoadState: Equatable {
    case idle
    case loading
    case loaded([MediaRequest])
    case error(String)

    public static func == (lhs: RequestListLoadState, rhs: RequestListLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.loaded(let left), .loaded(let right)):
            return left == right
        case (.error(let left), .error(let right)):
            return left == right
        default:
            return false
        }
    }
}

// MARK: - RequestMediaSegment

public enum RequestMediaSegment: String, CaseIterable, Sendable, Hashable {
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
            return "No Movie Requests"
        case .tvShows:
            return "No TV Requests"
        }
    }

    public var emptyMessage: String {
        switch self {
        case .movies:
            return "Switch to TV Shows or load more requests."
        case .tvShows:
            return "Switch to Movies or load more requests."
        }
    }

    public func matches(_ request: MediaRequest) -> Bool {
        switch (self, request.inferredMediaType) {
        case (.movies, .movie), (.tvShows, .tv):
            return true
        case (.movies, .none):
            return true
        default:
            return false
        }
    }
}

// MARK: - RequestListViewModel

@MainActor
@Observable
public final class RequestListViewModel {

    // MARK: - Public State

    public private(set) var loadState: RequestListLoadState = .idle
    public private(set) var selectedMediaSegment: RequestMediaSegment = .movies
    public private(set) var selectedFilter: RequestFilter = .all
    public private(set) var requests: [MediaRequest] = []
    public private(set) var metadataByRequestID: [Int: RequestMediaMetadata] = [:]
    public private(set) var isLoadingMore: Bool = false
    public private(set) var currentPage: Int = 0
    @ObservationIgnored
    private var totalPages: Int = 0
    public let isAdmin: Bool

    public var canLoadMore: Bool {
        hasMoreResults && !isLoadingMore && !isInitialLoading
    }

    public var visibleRequests: [MediaRequest] {
        requests.filter(selectedMediaSegment.matches)
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let repository: any RequestListFetching
    @ObservationIgnored
    private let mediaDetailRepository: MediaDetailRepository?

    // MARK: - Private State

    @ObservationIgnored
    private let pageSize = 20
    @ObservationIgnored
    private var currentSkip = 0
    private var hasMoreResults = true
    @ObservationIgnored
    private var loadTask: Task<Void, Never>?
    @ObservationIgnored
    private var loadMoreTask: Task<Void, Never>?
    @ObservationIgnored
    private var metadataTask: Task<Void, Never>?
    @ObservationIgnored
    private var mediaSegmentSelectionTask: Task<Void, Never>?

    private enum FetchPageOutcome {
        case success(appendedCount: Int)
        case failed
        case cancelled
    }

    private var isInitialLoading: Bool {
        if case .loading = loadState {
            return true
        }
        return false
    }

    // MARK: - Init

    public init(
        repository: any RequestListFetching,
        mediaDetailRepository: MediaDetailRepository?,
        userPermissions: Int?
    ) {
        self.repository = repository
        self.mediaDetailRepository = mediaDetailRepository
        self.isAdmin = ((userPermissions ?? 0) & 2) != 0
    }

    /// Cancels all in-flight tasks. Called by the view's .onDisappear or when
    /// the ViewModel is no longer needed. We avoid deinit because @MainActor
    /// properties cannot be safely accessed from nonisolated deinit.
    public func cancelAll() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        metadataTask?.cancel()
        mediaSegmentSelectionTask?.cancel()
    }

    // MARK: - Inline Moderation Actions

    /// Approves a pending request directly from the list. Admin only.
    public func approveRequest(_ request: MediaRequest) {
        Task {
            do {
                let updated = try await repository.approveRequest(id: request.id)
                replaceRequest(updated)
            } catch {
                AppLogger.warning("RequestListViewModel: approve failed for id=\(request.id) — \(error)")
            }
        }
    }

    /// Declines a pending or approved request directly from the list. Admin only.
    public func declineRequest(_ request: MediaRequest) {
        Task {
            do {
                let updated = try await repository.declineRequest(id: request.id)
                replaceRequest(updated)
            } catch {
                AppLogger.warning("RequestListViewModel: decline failed for id=\(request.id) — \(error)")
            }
        }
    }

    /// Deletes a request directly from the list.
    /// Admins can delete any request; owners can delete their own pending request.
    public func deleteRequest(_ request: MediaRequest, currentUserID: Int?) {
        guard canDelete(request, currentUserID: currentUserID) else { return }
        Task {
            do {
                try await repository.deleteRequest(id: request.id)
                removeRequest(id: request.id)
            } catch {
                AppLogger.warning("RequestListViewModel: delete failed for id=\(request.id) — \(error)")
            }
        }
    }

    /// Whether the current user can delete `request`.
    public func canDelete(_ request: MediaRequest, currentUserID: Int?) -> Bool {
        if isAdmin { return true }
        return request.status == 1 && request.requestedBy?.id == currentUserID
    }

    private func replaceRequest(_ updated: MediaRequest) {
        requests = requests.map { $0.id == updated.id ? updated : $0 }
        loadState = .loaded(requests)
    }

    private func removeRequest(id: Int) {
        requests.removeAll { $0.id == id }
        metadataByRequestID.removeValue(forKey: id)
        loadState = .loaded(requests)
    }

    // MARK: - Actions

    public func loadRequestsIfNeeded() {
        switch loadState {
        case .idle, .error:
            break
        default:
            return
        }
        mediaSegmentSelectionTask?.cancel()
        loadTask?.cancel()
        loadTask = Task { await reloadRequests(showLoading: true) }
    }

    public func retry() {
        mediaSegmentSelectionTask?.cancel()
        loadTask?.cancel()
        loadMoreTask?.cancel()
        loadTask = Task { await reloadRequests(showLoading: true) }
    }

    public func selectFilter(_ filter: RequestFilter) {
        guard filter != selectedFilter else { return }
        selectedFilter = filter
        mediaSegmentSelectionTask?.cancel()
        loadTask?.cancel()
        loadMoreTask?.cancel()
        loadTask = Task { await reloadRequests(showLoading: true) }
    }

    public func selectMediaSegment(_ mediaSegment: RequestMediaSegment) {
        guard mediaSegment != selectedMediaSegment else { return }
        mediaSegmentSelectionTask?.cancel()
        mediaSegmentSelectionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.mediaSegmentSelectionTask = nil }
            self.loadMoreTask?.cancel()
            if let loadMoreTask = self.loadMoreTask {
                await loadMoreTask.value
            }
            guard !Task.isCancelled else { return }
            await self.applySelectedMediaSegment(mediaSegment)
        }
    }

    public func refresh() async {
        mediaSegmentSelectionTask?.cancel()
        loadTask?.cancel()
        loadMoreTask?.cancel()
        await reloadRequests(showLoading: requests.isEmpty)
    }

    public func onRequestAppear(_ request: MediaRequest) {
        guard canLoadMore else { return }
        let visibleRequests = visibleRequests
        guard let index = visibleRequests.firstIndex(where: { $0.id == request.id }) else { return }
        let thresholdIndex = max(visibleRequests.count - 4, 0)
        if index >= thresholdIndex {
            loadMoreIfNeeded()
        }
    }

    // MARK: - Private Loading

    private func reloadRequests(showLoading: Bool) async {
        resetPagination()

        if showLoading {
            loadState = .loading
        } else if requests.isEmpty {
            loadState = .loading
        }

        let initialPage = await fetchPage(skip: 0, append: false)
        guard case .success = initialPage else { return }
        await loadAdditionalPagesIfNeeded(previousVisibleCount: 0)
    }

    private func loadMoreIfNeeded() {
        guard canLoadMore else { return }
        isLoadingMore = true

        let previousVisibleCount = visibleRequests.count
        let nextSkip = currentSkip
        loadMoreTask?.cancel()
        loadMoreTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isLoadingMore = false
                self.loadMoreTask = nil
            }

            let pageOutcome = await self.fetchPage(skip: nextSkip, append: true)
            guard case .success = pageOutcome else { return }
            await loadAdditionalPagesIfNeeded(previousVisibleCount: previousVisibleCount)
        }
    }

    @discardableResult
    private func fetchPage(skip: Int, append: Bool) async -> FetchPageOutcome {
        do {
            let response = try await repository.fetchRequests(
                filter: selectedFilter,
                skip: skip,
                take: pageSize
            )

            guard !Task.isCancelled else { return .cancelled }

            let fetched = response.results ?? []

            if append {
                requests.append(contentsOf: fetched)
            } else {
                requests = fetched
            }

            currentSkip = requests.count
            updatePagination(using: response, fetchedCount: fetched.count, skip: skip)
            loadState = .loaded(requests)
            metadataTask?.cancel()
            metadataTask = Task {
                await fetchMetadata(for: requests)
            }
            return .success(appendedCount: append ? fetched.count : requests.count)
        } catch {
            guard !Task.isCancelled else { return .cancelled }
            AppLogger.warning("RequestListViewModel: failed to fetch requests (skip=\(skip), filter=\(selectedFilter.rawValue)): \(error)")

            if requests.isEmpty || !append {
                loadState = .error(mapError(error))
            } else {
                loadState = .loaded(requests)
            }
            return .failed
        }
    }

    private func resetPagination() {
        metadataTask?.cancel()
        requests = []
        metadataByRequestID = [:]
        isLoadingMore = false
        currentPage = 0
        totalPages = 0
        currentSkip = 0
        hasMoreResults = true
    }

    private func updatePagination(using response: PaginatedResponse<MediaRequest>, fetchedCount: Int, skip: Int) {
        let inferredPage = (skip / pageSize) + 1
        currentPage = response.pageInfo?.page ?? inferredPage

        if let pages = response.pageInfo?.pages {
            totalPages = pages
            hasMoreResults = currentPage < pages
            return
        }

        hasMoreResults = fetchedCount == pageSize
        totalPages = hasMoreResults ? currentPage + 1 : currentPage
    }

    private func fetchMetadata(for requests: [MediaRequest]) async {
        guard let mediaDetailRepository else { return }
        let unresolvedRequests = requests.filter { metadataByRequestID[$0.id] == nil }
        guard !unresolvedRequests.isEmpty else { return }

        // Build input tuples off-MainActor to avoid blocking the main thread
        // during concurrent fetches.
        let inputs: [(id: Int, tmdbID: Int?, fallback: RequestMediaMetadata)] = unresolvedRequests.map {
            (id: $0.id, tmdbID: $0.media?.tmdbId, fallback: fallbackMetadata(for: $0))
        }

        let repository = mediaDetailRepository

        // Run all network fetches concurrently in a nonisolated context.
        let results: [(Int, RequestMediaMetadata)] = await withTaskGroup(
            of: (Int, RequestMediaMetadata).self,
            returning: [(Int, RequestMediaMetadata)].self
        ) { group in
            for input in inputs {
                guard let tmdbID = input.tmdbID else {
                    group.addTask { (input.id, input.fallback) }
                    continue
                }

                let mediaType = input.fallback.mediaType
                let fallback = input.fallback
                let requestID = input.id

                group.addTask {
                    do {
                        switch mediaType {
                        case .movie:
                            let movie = try await repository.fetchMovieDetails(movieId: tmdbID)
                            let title = movie.title ?? movie.originalTitle ?? fallback.title
                            return (requestID, RequestMediaMetadata(title: title, posterPath: movie.posterPath, mediaType: .movie))
                        case .tv:
                            let tvShow = try await repository.fetchTvDetails(tvId: tmdbID)
                            let title = tvShow.name ?? tvShow.originalName ?? fallback.title
                            return (requestID, RequestMediaMetadata(title: title, posterPath: tvShow.posterPath, mediaType: .tv))
                        }
                    } catch {
                        return (requestID, fallback)
                    }
                }
            }

            var collected: [(Int, RequestMediaMetadata)] = []
            for await result in group {
                if Task.isCancelled { group.cancelAll(); break }
                collected.append(result)
            }
            return collected
        }

        // Write results back on MainActor in one batch.
        guard !Task.isCancelled else { return }
        for (requestID, metadata) in results {
            metadataByRequestID[requestID] = metadata
        }
    }

    private func fallbackMetadata(for request: MediaRequest) -> RequestMediaMetadata {
        let inferredType: MediaRequestMediaType = request.inferredMediaType ?? .movie
        let prefix = inferredType == .movie ? "Movie" : "TV"
        let title: String

        if let tmdbID = request.media?.tmdbId {
            title = "\(prefix) #\(tmdbID)"
        } else {
            title = "Requested Media"
        }

        return RequestMediaMetadata(
            title: title,
            posterPath: nil,
            mediaType: inferredType
        )
    }

    // MARK: - Error Mapping

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? SeerrAPIError {
            switch apiError {
            case .unauthorized:
                return "Your session expired. Please sign in again."
            case .notFound:
                return "Requests could not be found."
            case .networkError:
                return "Unable to load requests. Check your connection."
            case .serverError:
                return "The server encountered an error. Please try again."
            case .httpError(let statusCode, let message):
                if let message, !message.isEmpty {
                    return message
                }
                return "Server error (\(statusCode)). Please try again."
            default:
                return "Something went wrong while loading requests."
            }
        }
        return "Something went wrong while loading requests."
    }

    func applySelectedMediaSegment(_ mediaSegment: RequestMediaSegment) async {
        selectedMediaSegment = mediaSegment

        let shouldShowLoadingIndicator = visibleRequests.isEmpty && hasMoreResults
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
        guard !requests.isEmpty else { return }

        while visibleRequests.count == previousVisibleCount && hasMoreResults {
            let previousSkip = currentSkip
            let previousRequestCount = requests.count
            let pageOutcome = await fetchPage(skip: currentSkip, append: true)

            guard case .success(let appendedCount) = pageOutcome else { break }

            let didAdvancePagination = currentSkip > previousSkip || requests.count > previousRequestCount
            if !didAdvancePagination || appendedCount == 0 {
                hasMoreResults = false
                break
            }
        }
    }
}
