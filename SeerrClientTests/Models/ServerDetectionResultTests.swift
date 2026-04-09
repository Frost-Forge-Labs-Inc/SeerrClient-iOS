// ServerDetectionResultTests.swift
// SeerrClientTests
//
// Tests for the shared runtime compatibility model used by server detection and
// saved-server reconnect flows.

@testable import SeerrClient
import XCTest

final class ServerDetectionResultTests: XCTestCase {

    // MARK: - Helpers

    private func makeCapabilities(
        backendType: BackendType = .jellyseerr,
        mediaServerKind: MediaServerKind = .jellyfin,
        localLoginEnabled: Bool? = true,
        mediaServerLoginEnabled: Bool? = true,
        newPlexLoginEnabled: Bool? = false,
        applicationTitle: String = "Test Server"
    ) -> ServerCapabilities {
        ServerCapabilities(
            backendType: backendType,
            publicSettings: PublicSettingsNormalized(
                initialized: true,
                applicationTitle: applicationTitle,
                localLoginEnabled: localLoginEnabled,
                newPlexLoginEnabled: newPlexLoginEnabled,
                mediaServerLoginEnabled: mediaServerLoginEnabled,
                mediaServerKind: mediaServerKind
            )
        )
    }

    private func makeResult(capabilities: ServerCapabilities) -> ServerDetectionResult {
        ServerDetectionResult(
            baseURL: "http://192.168.1.1:5055",
            version: "1.0.0",
            capabilities: capabilities
        )
    }

    // MARK: - Auth Method Resolution

    func test_availableAuthMethods_overseerrIncludesLocalAndPlex() {
        let result = makeResult(
            capabilities: makeCapabilities(
                backendType: .overseerr,
                mediaServerKind: .plex,
                localLoginEnabled: true,
                mediaServerLoginEnabled: true,
                newPlexLoginEnabled: true
            )
        )

        XCTAssertEqual(result.availableAuthMethods, [.local, .plex])
        XCTAssertTrue(result.plexLoginEnabled)
        XCTAssertFalse(result.jellyfinLoginEnabled)
    }

    func test_availableAuthMethods_jellyfinFamilyIgnoresNewPlexLoginFlag() {
        let capabilities = makeCapabilities(
            backendType: .jellyseerr,
            mediaServerKind: .jellyfin,
            localLoginEnabled: true,
            mediaServerLoginEnabled: true,
            newPlexLoginEnabled: true
        )
        let result = makeResult(capabilities: capabilities)

        XCTAssertEqual(result.availableAuthMethods, [.local, .jellyfin])
        XCTAssertFalse(result.plexLoginEnabled)
        XCTAssertTrue(result.jellyfinLoginEnabled)
    }

    func test_availableAuthMethods_localOnly() {
        let result = makeResult(
            capabilities: makeCapabilities(
                mediaServerKind: .jellyfin,
                localLoginEnabled: true,
                mediaServerLoginEnabled: false
            )
        )

        XCTAssertEqual(result.availableAuthMethods, [.local])
    }

    func test_availableAuthMethods_emptyWhenAllLoginPathsDisabled() {
        let result = makeResult(
            capabilities: makeCapabilities(
                backendType: .overseerr,
                mediaServerKind: .plex,
                localLoginEnabled: false,
                mediaServerLoginEnabled: false,
                newPlexLoginEnabled: false
            )
        )

        XCTAssertEqual(result.availableAuthMethods, [])
    }

    // MARK: - Backend Feature Gating

    func test_overseerrCapabilities_disableJellyseerrOnlyFeatures() {
        let capabilities = makeCapabilities(
            backendType: .overseerr,
            mediaServerKind: .plex,
            newPlexLoginEnabled: true
        )

        XCTAssertFalse(capabilities.supportsWatchlistWrite)
        XCTAssertFalse(capabilities.supportsBlacklist)
        XCTAssertFalse(capabilities.supportsLinkedAccounts)
        XCTAssertFalse(capabilities.supportsJellyfinAdmin)
        XCTAssertFalse(capabilities.supportsNtfy)
        XCTAssertTrue(capabilities.supportsLunaSea)
    }

    func test_jellyseerrCapabilities_enableJellyseerrOnlyFeatures() {
        let capabilities = makeCapabilities(
            backendType: .jellyseerr,
            mediaServerKind: .jellyfin,
            newPlexLoginEnabled: true
        )

        XCTAssertTrue(capabilities.supportsWatchlistWrite)
        XCTAssertTrue(capabilities.supportsBlacklist)
        XCTAssertTrue(capabilities.supportsLinkedAccounts)
        XCTAssertTrue(capabilities.supportsJellyfinAdmin)
        XCTAssertTrue(capabilities.supportsNtfy)
        XCTAssertFalse(capabilities.supportsLunaSea)
    }

    // MARK: - Legacy Migration

    func test_legacyResolvedCapabilities_forOverseerrServer() {
        let server = ServerConfiguration(
            displayName: "Legacy Overseerr",
            baseURL: "http://192.168.1.10:5055",
            backendType: .overseerr,
            availableAuthMethods: [.local, .plex]
        )

        let capabilities = server.resolvedCapabilities
        XCTAssertEqual(capabilities.mediaServerKind, .plex)
        XCTAssertEqual(capabilities.availableAuthMethods, [.local, .plex])
        XCTAssertFalse(capabilities.supportsWatchlistWrite)
        XCTAssertTrue(capabilities.supportsLunaSea)
    }

    func test_legacyResolvedCapabilities_forJellyseerrServer() {
        let server = ServerConfiguration(
            displayName: "Legacy Jellyseerr",
            baseURL: "http://192.168.1.11:5055",
            backendType: .jellyseerr,
            availableAuthMethods: [.local, .jellyfin]
        )

        let capabilities = server.resolvedCapabilities
        XCTAssertEqual(capabilities.mediaServerKind, .jellyfin)
        XCTAssertEqual(capabilities.availableAuthMethods, [.local, .jellyfin])
        XCTAssertTrue(capabilities.supportsWatchlistWrite)
        XCTAssertFalse(capabilities.supportsLunaSea)
    }

    // MARK: - Field Storage

    func test_applicationTitle_storedOnCapabilities() {
        let result = makeResult(
            capabilities: makeCapabilities(applicationTitle: "My Seerr")
        )

        XCTAssertEqual(result.applicationTitle, "My Seerr")
    }
}
