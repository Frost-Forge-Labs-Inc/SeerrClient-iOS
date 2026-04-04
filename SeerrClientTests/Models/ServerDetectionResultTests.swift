// ServerDetectionResultTests.swift
// SeerrClientTests
//
// Tests for ServerDetectionResult.availableAuthMethods computed property.
// Does NOT test the private detectBackendType method on ServerRepository.

@testable import SeerrClient
import XCTest

final class ServerDetectionResultTests: XCTestCase {

    // MARK: - Helpers

    private func makeResult(
        local: Bool = false,
        plex: Bool = false,
        jellyfin: Bool = false,
        title: String = "Test Server"
    ) -> ServerDetectionResult {
        ServerDetectionResult(
            baseURL: "http://192.168.1.1:5055",
            version: "1.0.0",
            backendType: .jellyseerr,
            localLoginEnabled: local,
            plexLoginEnabled: plex,
            jellyfinLoginEnabled: jellyfin,
            applicationTitle: title,
            isInitialized: true
        )
    }

    // MARK: - availableAuthMethods

    func test_availableAuthMethods_allEnabled() {
        let result = makeResult(local: true, plex: true, jellyfin: true)
        XCTAssertEqual(result.availableAuthMethods, [.local, .plex, .jellyfin])
    }

    func test_availableAuthMethods_localOnly() {
        let result = makeResult(local: true, plex: false, jellyfin: false)
        XCTAssertEqual(result.availableAuthMethods, [.local])
    }

    func test_availableAuthMethods_plexOnly() {
        let result = makeResult(local: false, plex: true, jellyfin: false)
        XCTAssertEqual(result.availableAuthMethods, [.plex])
    }

    func test_availableAuthMethods_jellyfinOnly() {
        let result = makeResult(local: false, plex: false, jellyfin: true)
        XCTAssertEqual(result.availableAuthMethods, [.jellyfin])
    }

    func test_availableAuthMethods_empty() {
        let result = makeResult(local: false, plex: false, jellyfin: false)
        XCTAssertEqual(result.availableAuthMethods, [])
    }

    func test_availableAuthMethods_order() {
        let result = makeResult(local: true, plex: true, jellyfin: true)
        let methods = result.availableAuthMethods
        XCTAssertEqual(methods.count, 3)
        XCTAssertEqual(methods[0], .local)
        XCTAssertEqual(methods[1], .plex)
        XCTAssertEqual(methods[2], .jellyfin)
    }

    func test_availableAuthMethods_localAndJellyfin() {
        let result = makeResult(local: true, plex: false, jellyfin: true)
        XCTAssertEqual(result.availableAuthMethods, [.local, .jellyfin])
    }

    // MARK: - Field storage

    func test_applicationTitle_stored() {
        let result = makeResult(title: "My Seerr")
        XCTAssertEqual(result.applicationTitle, "My Seerr")
    }
}
