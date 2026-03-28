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

// MARK: - RequestRepository

public final class RequestRepository: Sendable {

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
        let queryItems = [
            URLQueryItem(name: "take", value: "\(take)"),
            URLQueryItem(name: "skip", value: "\(skip)"),
            URLQueryItem(name: "filter", value: filter.rawValue),
            URLQueryItem(name: "sort", value: "added")
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
