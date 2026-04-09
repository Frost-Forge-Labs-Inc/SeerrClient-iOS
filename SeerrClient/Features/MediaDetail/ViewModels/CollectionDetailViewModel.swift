// CollectionDetailViewModel.swift
// SeerrClient
//
// Manages state for the Collection Detail screen. Loads the full TMDB collection
// (name, overview, member movies) and drives the request-all / select-and-request flow.

import Foundation

// MARK: - CollectionLoadState

public enum CollectionLoadState: Equatable {
    case idle
    case loading
    case loaded(Collection)
    case error(String)

    public static func == (lhs: CollectionLoadState, rhs: CollectionLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - CollectionDetailViewModel

@MainActor @Observable
public final class CollectionDetailViewModel {

    // MARK: - Public State

    public private(set) var loadState: CollectionLoadState = .idle

    /// IDs of movies the user has selected for a partial request.
    public private(set) var selectedMovieIDs: Set<Int> = []

    /// Whether the "Request Selected" sheet is presented.
    public var showRequestSheet: Bool = false

    /// Ordered queue of movie IDs currently being requested through the shared
    /// single-movie request sheet.
    public private(set) var queuedRequestMovieIDs: [Int] = []

    /// The movie ID currently being requested via the request sheet.
    public var requestingMovieId: Int? {
        queuedRequestMovieIDs.first
    }

    /// Convenience accessor for the loaded collection.
    public var collection: Collection? {
        if case .loaded(let c) = loadState { return c }
        return nil
    }

    /// Requestable movies: those not already available or pending.
    public var requestableMovies: [MovieResult] {
        collection?.parts?.filter { !isUnavailable($0) } ?? []
    }

    /// `true` when at least one movie is selected for a partial request.
    public var hasSelection: Bool { !selectedMovieIDs.isEmpty }

    /// Requestable selected movie IDs in collection order.
    public var selectedRequestMovieIDs: [Int] {
        orderedRequestableMovieIDs.filter { selectedMovieIDs.contains($0) }
    }

    /// `true` when every requestable movie is currently selected.
    public var allRequestableMoviesSelected: Bool {
        !requestableMovies.isEmpty && selectedRequestMovieIDs.count == requestableMovies.count
    }

    /// The movie currently shown in the request sheet.
    public var activeRequestMovie: MovieResult? {
        guard let requestingMovieId else { return nil }
        return collection?.parts?.first(where: { $0.id == requestingMovieId })
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let repository: MediaDetailRepository
    @ObservationIgnored
    private let collectionId: Int

    // MARK: - Init

    public init(collectionId: Int, repository: MediaDetailRepository) {
        self.collectionId = collectionId
        self.repository = repository
    }

    // MARK: - Loading

    /// Loads the collection. Idempotent — only loads from .idle state.
    public func loadCollection() async {
        guard loadState == .idle else { return }
        loadState = .loading

        do {
            let collection = try await repository.fetchCollection(collectionId: collectionId)
            guard !Task.isCancelled else { return }
            loadState = .loaded(collection)
        } catch {
            guard !Task.isCancelled else { return }
            AppLogger.warning("CollectionDetailViewModel: failed to load collection \(collectionId): \(error)")
            loadState = .error(userFacingMessage(from: error))
        }
    }

    /// Retries loading by resetting to idle.
    public func retry() async {
        loadState = .idle
        await loadCollection()
    }

    /// Replaces the currently loaded collection state while preserving view-model
    /// ownership of selection and request-queue reconciliation.
    func replaceLoadedCollection(_ collection: Collection) {
        loadState = .loaded(collection)
        reconcileSelectionAndQueue()
    }

    // MARK: - Selection

    /// Toggles a movie's selection state.
    ///
    /// - Parameter movieId: The TMDB movie identifier.
    public func toggleSelection(movieId: Int) {
        guard isRequestable(movieId: movieId) else { return }

        if selectedMovieIDs.contains(movieId) {
            selectedMovieIDs.remove(movieId)
        } else {
            selectedMovieIDs.insert(movieId)
        }
    }

    /// Selects all requestable movies.
    public func selectAll() {
        selectedMovieIDs = Set(orderedRequestableMovieIDs)
    }

    /// Clears all selections.
    public func clearSelection() {
        selectedMovieIDs = []
    }

    // MARK: - Request Actions

    /// Opens the request sheet to request all movies in the collection.
    /// Each movie is individually requestable via the collection's parts list.
    public func requestAll() {
        selectAll()
        beginRequestFlow(movieIDs: orderedRequestableMovieIDs)
    }

    /// Opens the request sheet for a single movie.
    ///
    /// - Parameter movieId: The TMDB movie identifier to request.
    public func requestSingle(movieId: Int) {
        beginRequestFlow(movieIDs: [movieId])
    }

    /// Opens the request sheet for the currently selected movies.
    public func requestSelected() {
        beginRequestFlow(movieIDs: selectedRequestMovieIDs)
    }

    /// Dismisses the request sheet and resets transient request state.
    public func dismissRequestSheet() {
        showRequestSheet = false
        queuedRequestMovieIDs = []
    }

    /// Applies a successful request submission for the currently active movie,
    /// updates its visible status to pending, and advances the request queue.
    public func handleRequestSuccess() {
        guard let movieId = requestingMovieId else { return }

        selectedMovieIDs.remove(movieId)
        queuedRequestMovieIDs = Array(queuedRequestMovieIDs.dropFirst())
        markMovieAsPending(movieId: movieId)

        if queuedRequestMovieIDs.isEmpty {
            showRequestSheet = false
        }
    }

    // MARK: - Status Helpers

    /// `true` if the movie is already available — no need to request.
    public func isAvailable(_ movie: MovieResult) -> Bool {
        movie.mediaInfo?.status == 5   // AVAILABLE
    }

    /// `true` if the movie is already requested/processing.
    public func isPending(_ movie: MovieResult) -> Bool {
        guard let status = movie.mediaInfo?.status else { return false }
        return status == 2 || status == 3   // PENDING or PROCESSING
    }

    /// `true` if the movie cannot be requested (available or pending).
    public func isUnavailable(_ movie: MovieResult) -> Bool {
        isAvailable(movie) || isPending(movie)
    }

    /// `true` when the movie can be selected/requested from the collection flow.
    public func isRequestable(movieId: Int) -> Bool {
        requestableMovies.contains(where: { $0.id == movieId })
    }

    /// `true` when the movie is currently selected in the collection flow.
    public func isSelected(movieId: Int) -> Bool {
        selectedMovieIDs.contains(movieId)
    }

    // MARK: - Private

    private func userFacingMessage(from error: Error) -> String {
        if let apiError = error as? SeerrAPIError {
            switch apiError {
            case .networkError:
                return "Unable to load collection. Check your connection."
            case .notFound:
                return "Collection not found."
            default:
                return "Something went wrong. Please try again."
            }
        }
        return "Something went wrong. Please try again."
    }

    private var orderedRequestableMovieIDs: [Int] {
        requestableMovies.map(\.id)
    }

    private func beginRequestFlow(movieIDs: [Int]) {
        let filteredMovieIDs = orderedRequestableMovieIDs.filter { movieIDs.contains($0) }
        guard !filteredMovieIDs.isEmpty else { return }

        queuedRequestMovieIDs = filteredMovieIDs
        showRequestSheet = true
    }

    private func reconcileSelectionAndQueue() {
        let requestable = Set(orderedRequestableMovieIDs)
        selectedMovieIDs.formIntersection(requestable)
        queuedRequestMovieIDs = queuedRequestMovieIDs.filter { requestable.contains($0) }

        if queuedRequestMovieIDs.isEmpty {
            showRequestSheet = false
        }
    }

    private func markMovieAsPending(movieId: Int) {
        guard case .loaded(let collection) = loadState else { return }

        let updatedParts = collection.parts?.map { movie in
            guard movie.id == movieId else { return movie }
            return movieByUpdatingStatus(movie, status: 2)
        }

        let updatedCollection = Collection(
            id: collection.id,
            name: collection.name,
            overview: collection.overview,
            posterPath: collection.posterPath,
            backdropPath: collection.backdropPath,
            parts: updatedParts
        )

        replaceLoadedCollection(updatedCollection)
    }

    private func movieByUpdatingStatus(_ movie: MovieResult, status: Int) -> MovieResult {
        let updatedMediaInfo = MediaInfo(
            id: movie.mediaInfo?.id,
            tmdbId: movie.mediaInfo?.tmdbId ?? movie.id,
            tvdbId: movie.mediaInfo?.tvdbId,
            status: status,
            seasons: movie.mediaInfo?.seasons,
            requests: movie.mediaInfo?.requests,
            createdAt: movie.mediaInfo?.createdAt,
            updatedAt: movie.mediaInfo?.updatedAt,
            watchlisted: movie.mediaInfo?.watchlisted
        )

        return MovieResult(
            id: movie.id,
            mediaType: movie.mediaType,
            popularity: movie.popularity,
            posterPath: movie.posterPath,
            backdropPath: movie.backdropPath,
            voteCount: movie.voteCount,
            voteAverage: movie.voteAverage,
            genreIds: movie.genreIds,
            overview: movie.overview,
            originalLanguage: movie.originalLanguage,
            title: movie.title,
            originalTitle: movie.originalTitle,
            releaseDate: movie.releaseDate,
            adult: movie.adult,
            video: movie.video,
            mediaInfo: updatedMediaInfo
        )
    }
}
