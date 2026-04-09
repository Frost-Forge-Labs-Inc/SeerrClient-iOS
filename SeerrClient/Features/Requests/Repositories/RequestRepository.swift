// RequestRepository.swift
// SeerrClient
//
// Data layer for request CRUD and moderation actions.

import Foundation

// MARK: - RequestFilter

public enum RequestFilter: String, Sendable, CaseIterable, Hashable {
    case all
    case pending
    case approved
    case declined
    case processing
    case available

    public var displayName: String {
        switch self {
        case .all:
            return "All"
        case .pending:
            return "Pending"
        case .approved:
            return "Approved"
        case .declined:
            return "Declined"
        case .processing:
            return "Processing"
        case .available:
            return "Available"
        }
    }
}

// MARK: - RequestMediaMetadata

public struct RequestMediaMetadata: Sendable, Hashable {
    public let title: String
    public let posterPath: String?
    public let mediaType: MediaRequestMediaType

    public init(title: String, posterPath: String?, mediaType: MediaRequestMediaType) {
        self.title = title
        self.posterPath = posterPath
        self.mediaType = mediaType
    }
}

public extension MediaRequest {
    var inferredMediaType: MediaRequestMediaType? {
        if media?.tvdbId != nil {
            return .tv
        }
        if let seasons, !seasons.isEmpty {
            return .tv
        }
        if let mediaSeasons = media?.seasons, !mediaSeasons.isEmpty {
            return .tv
        }
        if media?.tmdbId != nil {
            return .movie
        }
        return nil
    }
}

// MARK: - RequestListFetching

public protocol RequestListFetching: Sendable {
    func fetchRequests(
        filter: RequestFilter,
        skip: Int,
        take: Int
    ) async throws -> PaginatedResponse<MediaRequest>

    func approveRequest(id: Int) async throws -> MediaRequest
    func declineRequest(id: Int) async throws -> MediaRequest
    func deleteRequest(id: Int) async throws
}

// MARK: - RequestRepository

public final class RequestRepository: RequestListFetching, Sendable {

    // MARK: - Dependencies

    private let apiClient: SeerrAPIClient

    // MARK: - Init

    public init(apiClient: SeerrAPIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Requests List

    public func fetchRequests(
        filter: RequestFilter,
        skip: Int,
        take: Int
    ) async throws -> PaginatedResponse<MediaRequest> {
        let path = apiClient.endpoints.request
        // Note: "sort=added" is omitted — some Seerr versions return 400 for
        // the "declined" filter when a sort parameter is supplied. The server
        // default (most-recent-first) is the desired behaviour anyway.
        let queryItems = [
            URLQueryItem(name: "take", value: "\(take)"),
            URLQueryItem(name: "skip", value: "\(skip)"),
            URLQueryItem(name: "filter", value: filter.rawValue)
        ]

        return try await apiClient.get(path, queryItems: queryItems)
    }

    public func fetchRequestCounts() async throws -> RequestCounts {
        let path = apiClient.endpoints.requestCount
        return try await apiClient.get(path)
    }

    // MARK: - Request Detail

    public func fetchRequestDetail(id: Int) async throws -> MediaRequest {
        let path = apiClient.endpoints.request(id: id)
        return try await apiClient.get(path)
    }

    // MARK: - Create/Update/Delete

    public func createRequest(body: MediaRequestBody) async throws -> MediaRequest {
        let path = apiClient.endpoints.request
        return try await apiClient.post(path, body: body)
    }

    public func updateRequest(id: Int, body: MediaRequestBody) async throws -> MediaRequest {
        let path = apiClient.endpoints.request(id: id)
        return try await apiClient.put(path, body: body)
    }

    public func deleteRequest(id: Int) async throws {
        let path = apiClient.endpoints.request(id: id)
        try await apiClient.deleteVoid(path)
    }

    // MARK: - Quality Profiles

    /// Fetches the default Radarr server and its quality profiles.
    /// Returns an empty array if no Radarr server is configured.
    public func fetchRadarrProfiles() async throws -> [ServiceProfile] {
        let endpoints = apiClient.endpoints
        let servers: [RadarrSettings] = try await apiClient.get(endpoints.settingsRadarr)
        guard let defaultServer = servers.first(where: { $0.isDefault }) ?? servers.first,
              let id = defaultServer.id else { return [] }
        return try await apiClient.get(endpoints.settingsRadarrProfiles(id: id))
    }

    /// Fetches the default Sonarr server and its quality profiles.
    /// Returns an empty array if no Sonarr server is configured.
    ///
    /// Uses `GET /service/sonarr/{id}` — the `/settings/sonarr/{id}/profiles` endpoint
    /// does not exist in Jellyseerr (only in Overseerr).
    public func fetchSonarrProfiles() async throws -> [ServiceProfile] {
        let endpoints = apiClient.endpoints
        let servers: [SonarrSettings] = try await apiClient.get(endpoints.settingsSonarr)
        guard let defaultServer = servers.first(where: { $0.isDefault }) ?? servers.first,
              let id = defaultServer.id else { return [] }
        let details: ServiceInstanceDetails = try await apiClient.get(endpoints.serviceSonarr(id: id))
        return details.profiles
    }

    // MARK: - Moderation

    public func approveRequest(id: Int) async throws -> MediaRequest {
        let path = apiClient.endpoints.requestApprove(id: id)
        return try await apiClient.post(path)
    }

    public func declineRequest(id: Int) async throws -> MediaRequest {
        let path = apiClient.endpoints.requestDecline(id: id)
        return try await apiClient.post(path)
    }
}
