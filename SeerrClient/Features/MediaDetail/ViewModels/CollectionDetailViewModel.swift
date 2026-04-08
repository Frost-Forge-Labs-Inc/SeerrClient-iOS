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

    /// The movie ID currently being requested individually via the sheet.
    /// `nil` when using the multi-select flow.
    public private(set) var requestingMovieId: Int? = nil

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

    // MARK: - Selection

    /// Toggles a movie's selection state.
    ///
    /// - Parameter movieId: The TMDB movie identifier.
    public func toggleSelection(movieId: Int) {
        if selectedMovieIDs.contains(movieId) {
            selectedMovieIDs.remove(movieId)
        } else {
            selectedMovieIDs.insert(movieId)
        }
    }

    /// Selects all requestable movies.
    public func selectAll() {
        selectedMovieIDs = Set(requestableMovies.compactMap { $0.id as Int? })
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
        showRequestSheet = true
    }

    /// Opens the request sheet for a single movie.
    ///
    /// - Parameter movieId: The TMDB movie identifier to request.
    public func requestSingle(movieId: Int) {
        requestingMovieId = movieId
        showRequestSheet = true
    }

    /// Opens the request sheet for the currently selected movies.
    public func requestSelected() {
        requestingMovieId = nil
        showRequestSheet = true
    }

    /// Dismisses the request sheet and resets transient request state.
    public func dismissRequestSheet() {
        showRequestSheet = false
        requestingMovieId = nil
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
}
