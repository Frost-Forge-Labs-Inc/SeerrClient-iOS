// MovieDetailViewModel.swift
// SeerrClient
//
// Manages state for the Movie Detail screen. Fetches movie details on appear,
// exposes load state, and controls the request sheet presentation.

import Foundation

// MARK: - MovieDetailLoadState

public enum MovieDetailLoadState: Equatable {
    case idle
    case loading
    case loaded(MovieDetails)
    case error(String)

    public static func == (lhs: MovieDetailLoadState, rhs: MovieDetailLoadState) -> Bool {
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

// MARK: - MovieDetailViewModel

@MainActor @Observable
public final class MovieDetailViewModel {

    // MARK: - Public State

    public private(set) var loadState: MovieDetailLoadState = .idle
    public var showRequestSheet: Bool = false
    public private(set) var recommendations: [DiscoverMediaItem] = []
    public private(set) var similar: [DiscoverMediaItem] = []

    /// Whether this movie is on the user's watchlist.
    /// Populated from `mediaInfo.watchlisted` on load; then updated optimistically on toggle.
    public private(set) var isOnWatchlist: Bool = false

    /// `true` while a watchlist add/remove request is in flight.
    public private(set) var isTogglingWatchlist: Bool = false

    /// Convenience accessor for loaded movie details.
    public var movie: MovieDetails? {
        if case .loaded(let details) = loadState { return details }
        return nil
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let repository: MediaDetailRepository
    @ObservationIgnored
    private let movieId: Int

    // MARK: - Init

    public init(movieId: Int, repository: MediaDetailRepository) {
        self.movieId = movieId
        self.repository = repository
    }

    // MARK: - Loading

    /// Loads movie details. Idempotent — only loads from .idle state.
    public func loadDetails() async {
        guard loadState == .idle else { return }
        loadState = .loading

        do {
            let details = try await repository.fetchMovieDetails(movieId: movieId)
            guard !Task.isCancelled else { return }
            loadState = .loaded(details)
            // Seed watchlist state from the API response.
            isOnWatchlist = details.mediaInfo?.watchlisted ?? false

            // Fetch recommendations and similar concurrently; failures are non-fatal.
            async let recs = (try? await repository.fetchMovieRecommendations(movieId: movieId)) ?? []
            async let sim = (try? await repository.fetchSimilarMovies(movieId: movieId)) ?? []
            let (fetchedRecs, fetchedSim) = await (recs, sim)
            guard !Task.isCancelled else { return }
            recommendations = fetchedRecs
            similar = fetchedSim
        } catch {
            guard !Task.isCancelled else { return }
            AppLogger.warning("MovieDetailViewModel: failed to load movie \(movieId): \(error)")
            loadState = .error(userFacingMessage(from: error))
        }
    }

    /// Retries loading by resetting to idle and reloading.
    public func retry() async {
        loadState = .idle
        await loadDetails()
    }

    /// Toggles watchlist membership for this movie.
    ///
    /// Uses optimistic UI — the state flips immediately, then the API call confirms.
    /// If the call fails the state is reverted and a log warning is emitted.
    /// Requires the media to have a Seerr media record (`mediaInfo.id` must be non-nil).
    public func toggleWatchlist() {
        guard let mediaId = movie?.mediaInfo?.id else {
            AppLogger.warning("MovieDetailViewModel: toggleWatchlist called but mediaInfo.id is nil")
            return
        }
        guard !isTogglingWatchlist else { return }

        let wasOnWatchlist = isOnWatchlist
        isOnWatchlist = !wasOnWatchlist      // Optimistic update
        isTogglingWatchlist = true

        Task {
            defer { isTogglingWatchlist = false }
            do {
                if wasOnWatchlist {
                    try await repository.removeFromWatchlist(mediaId: mediaId)
                    AppLogger.info("MovieDetailViewModel: removed movie \(movieId) from watchlist")
                } else {
                    try await repository.addToWatchlist(mediaId: mediaId)
                    AppLogger.info("MovieDetailViewModel: added movie \(movieId) to watchlist")
                }
            } catch {
                // Revert on failure
                isOnWatchlist = wasOnWatchlist
                AppLogger.warning("MovieDetailViewModel: watchlist toggle failed for movie \(movieId) — \(error)")
            }
        }
    }

    // MARK: - Private

    private func userFacingMessage(from error: Error) -> String {
        if let apiError = error as? SeerrAPIError {
            switch apiError {
            case .networkError:
                return "Unable to load movie details. Check your connection."
            case .notFound:
                return "Movie not found."
            case .httpError(statusCode: let code, message: _):
                return "Server error (\(code)). Please try again."
            default:
                return "Something went wrong. Please try again."
            }
        }
        return "Something went wrong. Please try again."
    }
}
