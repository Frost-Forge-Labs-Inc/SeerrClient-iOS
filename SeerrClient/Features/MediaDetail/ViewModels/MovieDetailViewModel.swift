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

    /// Whether the active backend supports watchlist mutation endpoints.
    public let allowsWatchlistMutations: Bool

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

    /// Called whenever the watchlist toggle succeeds.
    /// The view supplies a closure that updates `AppState.watchlistedTmdbIds`.
    @ObservationIgnored
    var onWatchlistChanged: ((Int, Bool) -> Void)?

    // MARK: - Init

    /// Creates a `MovieDetailViewModel`.
    ///
    /// - Parameters:
    ///   - movieId: The TMDB movie ID to load.
    ///   - repository: The `MediaDetailRepository` used for all API calls.
    ///   - initiallyOnWatchlist: Whether this movie is already on the user's watchlist,
    ///     determined from `AppState.watchlistedTmdbIds` before the detail network call
    ///     completes. Seeds `isOnWatchlist` immediately so the toolbar icon is correct
    ///     before the detail response arrives. Defaults to `false`.
    public init(
        movieId: Int,
        repository: MediaDetailRepository,
        initiallyOnWatchlist: Bool = false,
        allowsWatchlistMutations: Bool = true
    ) {
        self.movieId = movieId
        self.repository = repository
        self.isOnWatchlist = initiallyOnWatchlist
        self.allowsWatchlistMutations = allowsWatchlistMutations
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
            // NOTE: details.mediaInfo?.watchlisted is always nil in Jellyseerr's
            // GET /movie/{id} response, so we do NOT overwrite isOnWatchlist here.
            // The correct value was seeded at init time from AppState.watchlistedTmdbIds.

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
    /// Uses the TMDB movie ID directly; no Seerr media record is required.
    public func toggleWatchlist() {
        guard allowsWatchlistMutations else {
            AppLogger.info("MovieDetailViewModel: watchlist mutation skipped — unsupported by active backend")
            return
        }
        guard movie != nil else {
            AppLogger.warning("MovieDetailViewModel: toggleWatchlist called before movie loaded")
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
                    try await repository.removeFromWatchlist(tmdbId: movieId)
                    AppLogger.info("MovieDetailViewModel: removed movie \(movieId) from watchlist")
                } else {
                    try await repository.addToWatchlist(tmdbId: movieId, mediaType: "movie")
                    AppLogger.info("MovieDetailViewModel: added movie \(movieId) to watchlist")
                }
                // Notify the view so AppState.watchlistedTmdbIds stays in sync.
                onWatchlistChanged?(movieId, !wasOnWatchlist)
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
