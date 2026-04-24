@testable import SeerrClient
import XCTest

@MainActor
final class AppStateNavigationTests: XCTestCase {
    private let serversKey = "SeerrClient.servers"
    private let defaultServerKey = "SeerrClient.defaultServerID"

    override func setUpWithError() throws {
        clearPersistence()
    }

    override func tearDownWithError() throws {
        clearPersistence()
    }

    func testSelectServerMarksItAsLastUsedDefault() {
        let serverStore = ServerStore()
        let primary = makeServer(name: "Primary", url: "http://unit-primary:5055")
        let secondary = makeServer(name: "Secondary", url: "http://unit-secondary:5055")

        serverStore.add(primary)
        serverStore.add(secondary)

        let appState = AppState(serverStore: serverStore)
        appState.selectServer(secondary)

        XCTAssertEqual(appState.activeServer?.id, secondary.id)
        XCTAssertEqual(serverStore.defaultServer?.id, secondary.id)
        XCTAssertNotNil(appState.apiClient)
    }

    func testReturnToServerListClearsActiveSessionButPreservesLastUsedServer() {
        let serverStore = ServerStore()
        let server = makeServer(name: "Remembered", url: "http://unit-return:5055")
        serverStore.add(server)

        let appState = AppState(serverStore: serverStore)
        appState.selectServer(server)
        appState.setAuthenticatedUser(makeUser())

        appState.returnToServerList()

        XCTAssertNil(appState.activeServer)
        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.apiClient)
        XCTAssertEqual(serverStore.defaultServer?.id, server.id)
        XCTAssertTrue(appState.showServerSetup)
        XCTAssertFalse(appState.showMainInterface)
    }

    func testForgetSavedSignInClearsRememberedSessionButPreservesAPIKey() throws {
        let serverStore = ServerStore()
        let server = makeServer(name: "Stored", url: "http://unit-keychain:5055")
        serverStore.add(server)

        try KeychainManager.shared.save("api-key", for: .apiKey, server: server.baseURL)
        try KeychainManager.shared.save("local", for: .authMethod, server: server.baseURL)
        try KeychainManager.shared.save("session-token", for: .sessionToken, server: server.baseURL)
        try KeychainManager.shared.save("user@example.com", for: .username, server: server.baseURL)
        try KeychainManager.shared.save("secret", for: .password, server: server.baseURL)

        XCTAssertTrue(serverStore.hasSavedSignIn(for: server))

        serverStore.forgetSavedSignIn(for: server)

        XCTAssertFalse(serverStore.hasSavedSignIn(for: server))
        XCTAssertEqual(KeychainManager.shared.read(.apiKey, server: server.baseURL), "api-key")
        XCTAssertNil(KeychainManager.shared.read(.authMethod, server: server.baseURL))
        XCTAssertNil(KeychainManager.shared.read(.sessionToken, server: server.baseURL))
        XCTAssertNil(KeychainManager.shared.read(.username, server: server.baseURL))
        XCTAssertNil(KeychainManager.shared.read(.password, server: server.baseURL))
    }

    private func makeServer(name: String, url: String) -> ServerConfiguration {
        let capabilities = ServerCapabilities(
            backendType: .jellyseerr,
            publicSettings: PublicSettingsNormalized(
                initialized: true,
                applicationTitle: name,
                localLoginEnabled: true,
                mediaServerLoginEnabled: true,
                mediaServerKind: .jellyfin
            )
        )

        return ServerConfiguration(
            displayName: name,
            baseURL: url,
            backendType: .jellyseerr,
            authMethod: .local,
            availableAuthMethods: capabilities.availableAuthMethods,
            capabilities: capabilities
        )
    }

    private func makeUser() -> User {
        User(
            id: 1,
            email: "user@example.com",
            displayName: "Unit Tester",
            username: "tester",
            plexToken: nil,
            plexUsername: nil,
            userType: 2,
            permissions: 2,
            avatar: nil,
            createdAt: "2026-04-09T00:00:00.000Z",
            updatedAt: "2026-04-09T00:00:00.000Z",
            requestCount: 0
        )
    }

    private func clearPersistence() {
        UserDefaults.standard.removeObject(forKey: serversKey)
        UserDefaults.standard.removeObject(forKey: defaultServerKey)

        let urls = [
            "http://unit-primary:5055",
            "http://unit-secondary:5055",
            "http://unit-return:5055",
            "http://unit-keychain:5055"
        ]

        for url in urls {
            KeychainManager.shared.deleteAll(server: url)
        }
    }
}
