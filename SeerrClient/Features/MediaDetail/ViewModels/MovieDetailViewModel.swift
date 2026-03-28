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
