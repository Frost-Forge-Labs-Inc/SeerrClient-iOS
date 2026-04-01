// ProfileRepository.swift
// SeerrClient
//
// Data layer for profile-specific settings fetches.

import Foundation

// MARK: - ProfileRepository

public final class ProfileRepository: Sendable {

    // MARK: - Dependencies

    private let apiClient: SeerrAPIClient

    // MARK: - Init

    public init(apiClient: SeerrAPIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Profile Fetches

    public func fetchRequestCounts() async throws -> RequestCounts {
        let path = apiClient.endpoints.requestCount
        return try await apiClient.get(path)
    }

    public func fetchServerStatus() async throws -> ServerStatus {
        let path = apiClient.endpoints.status
        return try await apiClient.get(path)
    }
}
