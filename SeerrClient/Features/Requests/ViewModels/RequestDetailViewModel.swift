// RequestDetailViewModel.swift
// SeerrClient
//
// Manages request detail loading and moderation actions.

import Foundation

// MARK: - RequestDetailLoadState

public enum RequestDetailLoadState: Equatable {
    case idle
    case loading
    case loaded(MediaRequest)
    case error(String)

    public static func == (lhs: RequestDetailLoadState, rhs: RequestDetailLoadState) -> Bool {
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

// MARK: - RequestDetailViewModel

@MainActor
@Observable
public final class RequestDetailViewModel {

    // MARK: - Public State

    public private(set) var loadState: RequestDetailLoadState = .idle
    public private(set) var isApproving = false
    public private(set) var isDeclining = false
    public private(set) var isDeleting = false
    public private(set) var actionError: String?
    public private(set) var didDelete = false
    public private(set) var mediaMetadata: RequestMediaMetadata?
    public let isAdmin: Bool
    public let currentUserID: Int?

    public var request: MediaRequest? {
        if case .loaded(let request) = loadState {
            return request
        }
        return nil
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let repository: RequestRepository
    @ObservationIgnored
    private let mediaDetailRepository: MediaDetailRepository
    @ObservationIgnored
    private let requestID: Int

    // MARK: - Tasks

    @ObservationIgnored
    private var loadTask: Task<Void, Never>?
    @ObservationIgnored
    private var actionTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        requestID: Int,
        repository: RequestRepository,
        mediaDetailRepository: MediaDetailRepository,
        userPermissions: Int?,
        currentUserID: Int?
    ) {
        self.requestID = requestID
        self.repository = repository
        self.mediaDetailRepository = mediaDetailRepository
        self.isAdmin = ((userPermissions ?? 0) & 2) != 0
        self.currentUserID = currentUserID
    }

    /// Cancels all in-flight tasks. Called by the view's .onDisappear.
    public func cancelAll() {
        loadTask?.cancel()
        actionTask?.cancel()
    }

    // MARK: - Actions

    public func loadDetail() {
        guard case .idle = loadState else { return }
        loadState = .loading
        loadTask?.cancel()
        loadTask = Task {
            do {
                let detail = try await repository.fetchRequestDetail(id: requestID)
                guard !Task.isCancelled else { return }
                loadState = .loaded(detail)
                await fetchMediaMetadata(for: detail)
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.warning("RequestDetailViewModel: failed to load request \(requestID): \(error)")
                loadState = .error(mapError(error))
            }
        }
    }

    public func retry() {
        loadTask?.cancel()
        loadTask = nil
        actionTask?.cancel()
        actionTask = nil
        loadState = .idle
        actionError = nil
        mediaMetadata = nil
        loadDetail()
    }

    public func approveRequest() {
        guard isAdmin else { return }
        guard let request, request.status == 1 else { return }
        guard !isApproving && !isDeclining && !isDeleting else { return }

        isApproving = true
        actionError = nil
        actionTask?.cancel()
        actionTask = Task {
            defer { isApproving = false }

            do {
                let updated = try await repository.approveRequest(id: request.id)
                guard !Task.isCancelled else { return }
                loadState = .loaded(updated)
                await fetchMediaMetadata(for: updated)
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.warning("RequestDetailViewModel: approve failed for request \(request.id): \(error)")
                actionError = mapError(error)
            }
        }
    }

    public func declineRequest() {
        guard isAdmin else { return }
        // Can decline pending (1) or approved (2) requests
        guard let request, request.status == 1 || request.status == 2 else { return }
        guard !isApproving && !isDeclining && !isDeleting else { return }

        isDeclining = true
        actionError = nil
        actionTask?.cancel()
        actionTask = Task {
            defer { isDeclining = false }

            do {
                let updated = try await repository.declineRequest(id: request.id)
                guard !Task.isCancelled else { return }
                loadState = .loaded(updated)
                await fetchMediaMetadata(for: updated)
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.warning("RequestDetailViewModel: decline failed for request \(request.id): \(error)")
                actionError = mapError(error)
            }
        }
    }

    public func deleteRequest() {
        guard let request else { return }
        // Admin can delete any request; owner can delete their own pending request
        let isOwner = request.requestedBy?.id == currentUserID
        guard isAdmin || (isOwner && request.status == 1) else { return }
        guard !isApproving && !isDeclining && !isDeleting else { return }

        isDeleting = true
        actionError = nil
        actionTask?.cancel()
        actionTask = Task {
            defer { isDeleting = false }

            do {
                try await repository.deleteRequest(id: request.id)
                guard !Task.isCancelled else { return }
                didDelete = true
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.warning("RequestDetailViewModel: delete failed for request \(request.id): \(error)")
                actionError = mapError(error)
            }
        }
    }

    private func fetchMediaMetadata(for request: MediaRequest) async {
        guard let tmdbID = request.media?.tmdbId else {
            mediaMetadata = fallbackMetadata(for: request)
            return
        }

        let inferredType: MediaRequestMediaType = request.media?.tvdbId == nil ? .movie : .tv

        do {
            switch inferredType {
            case .movie:
                let movie = try await mediaDetailRepository.fetchMovieDetails(movieId: tmdbID)
                mediaMetadata = RequestMediaMetadata(
                    title: movie.title ?? movie.originalTitle ?? "Movie #\(tmdbID)",
                    posterPath: movie.posterPath,
                    mediaType: .movie
                )
            case .tv:
                let tvShow = try await mediaDetailRepository.fetchTvDetails(tvId: tmdbID)
                mediaMetadata = RequestMediaMetadata(
                    title: tvShow.name ?? tvShow.originalName ?? "TV #\(tmdbID)",
                    posterPath: tvShow.posterPath,
                    mediaType: .tv
                )
            }
        } catch {
            AppLogger.warning("RequestDetailViewModel: failed to fetch media metadata for request \(request.id): \(error)")
            mediaMetadata = fallbackMetadata(for: request)
        }
    }

    private func fallbackMetadata(for request: MediaRequest) -> RequestMediaMetadata {
        let inferredType: MediaRequestMediaType = request.media?.tvdbId == nil ? .movie : .tv
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
                return "Request not found."
            case .networkError:
                return "Unable to reach the server. Check your connection."
            case .forbidden:
                return "You do not have permission to perform this action."
            case .serverError:
                return "Server error. Please try again later."
            case .httpError(let statusCode, let message):
                if let message, !message.isEmpty {
                    return message
                }
                return "Server error (\(statusCode))."
            default:
                return "Something went wrong. Please try again."
            }
        }
        return "Something went wrong. Please try again."
    }
}
