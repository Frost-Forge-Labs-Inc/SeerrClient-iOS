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

    public private(set) var recommendations: [DiscoverMediaItem] = []
    public private(set) var similar: [DiscoverMediaItem] = []

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

    /// Whether this TV show is on the user's watchlist.
    /// Populated from `mediaInfo.watchlisted` on load; then updated optimistically on toggle.
    public private(set) var isOnWatchlist: Bool = false

    /// `true` while a watchlist add/remove request is in flight.
    public private(set) var isTogglingWatchlist: Bool = false

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
            // Seed watchlist state from the API response.
            isOnWatchlist = details.mediaInfo?.watchlisted ?? false

            // Auto-select the first non-specials season, or season 1.
            // Write to _selectedSeasonNumber directly to avoid triggering didSet Task.
            if let seasons = details.seasons {
                let firstRegular = seasons.first(where: { ($0.seasonNumber ?? 0) > 0 })
                _selectedSeasonNumber = firstRegular?.seasonNumber ?? seasons.first?.seasonNumber ?? 1
            }
            // Fetch recommendations and similar concurrently; failures are non-fatal.
            async let recs = (try? await repository.fetchTvRecommendations(tvId: tvId)) ?? []
            async let sim = (try? await repository.fetchSimilarTvShows(tvId: tvId)) ?? []
            let (fetchedRecs, fetchedSim) = await (recs, sim)
            guard !Task.isCancelled else { return }
            recommendations = fetchedRecs
            similar = fetchedSim

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

    // MARK: - Watchlist

    /// Toggles watchlist membership for this TV show.
    ///
    /// Uses optimistic UI — the state flips immediately, then the API call confirms.
    /// If the call fails the state is reverted and a log warning is emitted.
    /// Requires the media to have a Seerr media record (`mediaInfo.id` must be non-nil).
    public func toggleWatchlist() {
        guard let mediaId = tvShow?.mediaInfo?.id else {
            AppLogger.warning("TvShowDetailViewModel: toggleWatchlist called but mediaInfo.id is nil")
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
                    AppLogger.info("TvShowDetailViewModel: removed TV \(tvId) from watchlist")
                } else {
                    try await repository.addToWatchlist(mediaId: mediaId)
                    AppLogger.info("TvShowDetailViewModel: added TV \(tvId) to watchlist")
                }
            } catch {
                // Revert on failure
                isOnWatchlist = wasOnWatchlist
                AppLogger.warning("TvShowDetailViewModel: watchlist toggle failed for TV \(tvId) — \(error)")
            }
        }
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
