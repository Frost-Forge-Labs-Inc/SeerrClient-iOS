// TvShowDetailViewModel.swift
// SeerrClient
//
// Manages state for the TV Show Detail screen. Uses dual state machines:
// one for the show details and one for the selected season's episodes.
// Season details load on demand when the user changes the picker selection.

import Foundation

// MARK: - TvDetailLoadState

public enum TvDetailLoadState: Equatable {
    case idle
    case loading
    case loaded(TvDetails)
    case error(String)

    public static func == (lhs: TvDetailLoadState, rhs: TvDetailLoadState) -> Bool {
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

// MARK: - SeasonLoadState

public enum SeasonLoadState: Equatable {
    case idle
    case loading
    case loaded(Season)
    case error(String)

    public static func == (lhs: SeasonLoadState, rhs: SeasonLoadState) -> Bool {
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

// MARK: - TvShowDetailViewModel

@MainActor @Observable
public final class TvShowDetailViewModel {

    // MARK: - Public State

    /// Main show detail state.
    public private(set) var detailState: TvDetailLoadState = .idle

    /// Selected season detail state (episodes).
    public private(set) var seasonState: SeasonLoadState = .idle

    /// Currently selected season number (bound to picker).
    /// Uses a computed property to intercept external changes and trigger season loading.
    public var selectedSeasonNumber: Int {
        get { _selectedSeasonNumber }
        set {
            guard newValue != _selectedSeasonNumber else { return }
            _selectedSeasonNumber = newValue
            loadSeasonTask?.cancel()
            loadSeasonTask = Task { await loadSeasonDetails() }
        }
    }

    @ObservationIgnored
    private var _selectedSeasonNumber: Int = 1

    public var showRequestSheet: Bool = false

    /// Convenience accessor for loaded TV details.
    public var tvShow: TvDetails? {
        if case .loaded(let details) = detailState { return details }
        return nil
    }

    /// Convenience accessor for loaded season.
    public var season: Season? {
        if case .loaded(let s) = seasonState { return s }
        return nil
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let repository: MediaDetailRepository
    @ObservationIgnored
    private let tvId: Int
    @ObservationIgnored
    private var loadSeasonTask: Task<Void, Never>?

    // MARK: - Init

    public init(tvId: Int, repository: MediaDetailRepository) {
        self.tvId = tvId
        self.repository = repository
    }

    // MARK: - Show Details

    /// Loads TV show details. Idempotent — only loads from .idle state.
    public func loadDetails() async {
        guard detailState == .idle else { return }
        detailState = .loading

        do {
            let details = try await repository.fetchTvDetails(tvId: tvId)
            guard !Task.isCancelled else { return }
            detailState = .loaded(details)

            // Auto-select the first non-specials season, or season 1.
            // Write to _selectedSeasonNumber directly to avoid triggering didSet Task.
            if let seasons = details.seasons {
                let firstRegular = seasons.first(where: { ($0.seasonNumber ?? 0) > 0 })
                _selectedSeasonNumber = firstRegular?.seasonNumber ?? seasons.first?.seasonNumber ?? 1
            }
            // Load episodes for the selected season
            await loadSeasonDetails()
        } catch {
            guard !Task.isCancelled else { return }
            AppLogger.warning("TvShowDetailViewModel: failed to load TV \(tvId): \(error)")
            detailState = .error(userFacingMessage(from: error))
        }
    }

    /// Retries loading show details from scratch.
    public func retryDetails() async {
        detailState = .idle
        seasonState = .idle
        await loadDetails()
    }

    // MARK: - Season Details

    /// Loads episode details for the currently selected season.
    public func loadSeasonDetails() async {
        seasonState = .loading

        do {
            let seasonDetail = try await repository.fetchSeasonDetails(
                tvId: tvId,
                seasonNumber: selectedSeasonNumber
            )
            guard !Task.isCancelled else { return }
            seasonState = .loaded(seasonDetail)
        } catch {
            guard !Task.isCancelled else { return }
            AppLogger.warning("TvShowDetailViewModel: failed to load season \(selectedSeasonNumber): \(error)")
            seasonState = .error("Failed to load season episodes.")
        }
    }

    /// Retries loading the current season.
    public func retrySeason() async {
        seasonState = .idle
        await loadSeasonDetails()
    }

    // MARK: - Private

    private func userFacingMessage(from error: Error) -> String {
        if let apiError = error as? SeerrAPIError {
            switch apiError {
            case .networkError:
                return "Unable to load show details. Check your connection."
            case .notFound:
                return "TV show not found."
            case .httpError(statusCode: let code, message: _):
                return "Server error (\(code)). Please try again."
            default:
                return "Something went wrong. Please try again."
            }
        }
        return "Something went wrong. Please try again."
    }
}
