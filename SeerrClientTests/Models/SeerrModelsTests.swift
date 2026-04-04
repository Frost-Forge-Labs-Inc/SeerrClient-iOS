// SeerrModelsTests.swift
// SeerrClientTests
//
// Codable round-trip tests for MediaRequest, SeasonRequest, ServiceProfile,
// DiscoverResponse, and BackendType.

@testable import SeerrClient
import XCTest

final class SeerrModelsTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - MediaRequest

    func test_mediaRequest_codableRoundTrip() throws {
        let original = MediaRequest(
            id: 1,
            status: 2,
            media: nil,
            createdAt: nil,
            updatedAt: nil,
            requestedBy: nil,
            modifiedBy: nil,
            is4k: false,
            serverId: nil,
            profileId: nil,
            rootFolder: nil,
            seasons: nil
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MediaRequest.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_mediaRequest_decodesFromJSON() throws {
        let json = #"{"id":42,"status":1}"#.data(using: .utf8)!
        let decoded = try decoder.decode(MediaRequest.self, from: json)
        XCTAssertEqual(decoded.id, 42)
        XCTAssertEqual(decoded.status, 1)
    }

    // MARK: - SeasonRequest

    func test_seasonRequest_codableRoundTrip() throws {
        let original = SeasonRequest(id: 5, seasonNumber: 2, status: 1)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SeasonRequest.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_seasonRequest_optionalIdNil() throws {
        let json = #"{"seasonNumber":1,"status":2}"#.data(using: .utf8)!
        let decoded = try decoder.decode(SeasonRequest.self, from: json)
        XCTAssertNil(decoded.id)
        XCTAssertEqual(decoded.seasonNumber, 1)
        XCTAssertEqual(decoded.status, 2)
    }

    // MARK: - ServiceProfile

    func test_serviceProfile_codableRoundTrip() throws {
        let original = ServiceProfile(id: 7, name: "HD-1080p")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ServiceProfile.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_serviceProfile_allNilFields() throws {
        let json = #"{}"#.data(using: .utf8)!
        let decoded = try decoder.decode(ServiceProfile.self, from: json)
        XCTAssertNil(decoded.id)
        XCTAssertNil(decoded.name)
    }

    // MARK: - DiscoverResponse

    func test_discoverResponse_codableRoundTrip() throws {
        let item = DiscoverMediaItem(
            id: 100, tmdbId: 100, mediaType: "movie",
            title: "Test Movie", name: nil,
            posterPath: nil, backdropPath: nil,
            overview: nil, voteAverage: 7.5,
            releaseDate: "2020-06-15", firstAirDate: nil,
            genreIds: [28], mediaInfo: nil
        )
        let original = DiscoverResponse<DiscoverMediaItem>(
            page: 1,
            totalPages: 5,
            totalResults: 100,
            results: [item]
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DiscoverResponse<DiscoverMediaItem>.self, from: data)
        XCTAssertEqual(decoded.page, original.page)
        XCTAssertEqual(decoded.totalPages, original.totalPages)
        XCTAssertEqual(decoded.totalResults, original.totalResults)
        XCTAssertEqual(decoded.results.count, 1)
        XCTAssertEqual(decoded.results.first?.id, item.id)
    }

    func test_discoverResponse_emptyResults() throws {
        let json = #"{"page":1,"totalPages":1,"totalResults":0,"results":[]}"#.data(using: .utf8)!
        let decoded = try decoder.decode(DiscoverResponse<DiscoverMediaItem>.self, from: json)
        XCTAssertTrue(decoded.results.isEmpty)
    }

    // MARK: - BackendType

    func test_backendType_rawValues() {
        XCTAssertEqual(BackendType.overseerr.rawValue, "overseerr")
        XCTAssertEqual(BackendType.jellyseerr.rawValue, "jellyseerr")
        XCTAssertEqual(BackendType.seerr.rawValue, "seerr")
        XCTAssertEqual(BackendType.unknown.rawValue, "unknown")
    }

    func test_backendType_decodesFromRawValue() throws {
        func decode(_ raw: String) throws -> BackendType {
            let json = "\"\(raw)\"".data(using: .utf8)!
            return try decoder.decode(BackendType.self, from: json)
        }
        XCTAssertEqual(try decode("overseerr"), .overseerr)
        XCTAssertEqual(try decode("jellyseerr"), .jellyseerr)
        XCTAssertEqual(try decode("seerr"), .seerr)
        XCTAssertEqual(try decode("unknown"), .unknown)
    }
}
