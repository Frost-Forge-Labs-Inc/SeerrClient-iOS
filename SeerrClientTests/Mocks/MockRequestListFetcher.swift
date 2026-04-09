// MockRequestListFetcher.swift
// SeerrClientTests
//
// Test double for request-list loading and inline moderation actions.

@testable import SeerrClient
import Foundation

final class MockRequestListFetcher: RequestListFetching, @unchecked Sendable {

    var stubbedResponse: PaginatedResponse<MediaRequest>?
    var stubbedResponsesByKey: [String: PaginatedResponse<MediaRequest>] = [:]
    var stubbedErrorsByKey: [String: Error] = [:]
    var stubbedError: Error?
    var delayNanoseconds: UInt64 = 0

    private(set) var fetchRequestsCallCount = 0

    func fetchRequests(
        filter: RequestFilter,
        skip: Int,
        take: Int
    ) async throws -> PaginatedResponse<MediaRequest> {
        fetchRequestsCallCount += 1

        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }

        let key = "\(filter.rawValue):\(skip):\(take)"
        if let stubbedError = stubbedErrorsByKey[key] {
            throw stubbedError
        }

        if let stubbedError {
            throw stubbedError
        }

        if let response = stubbedResponsesByKey[key] {
            return response
        }

        return stubbedResponse ?? PaginatedResponse(
            pageInfo: PageInfo(page: 1, pages: 1, results: 0),
            results: []
        )
    }

    func approveRequest(id: Int) async throws -> MediaRequest {
        throw URLError(.unsupportedURL)
    }

    func declineRequest(id: Int) async throws -> MediaRequest {
        throw URLError(.unsupportedURL)
    }

    func deleteRequest(id: Int) async throws {}
}
