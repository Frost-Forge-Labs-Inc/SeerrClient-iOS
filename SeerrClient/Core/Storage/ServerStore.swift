// ServerStore.swift
// SeerrClient
//
// Observable store that manages the list of configured Seerr servers.
// Non-sensitive metadata (display name, base URL, backend type, etc.) lives in
// UserDefaults as JSON. Credentials (API keys, session tokens) are stored in
// the Keychain via KeychainManager.

import Foundation
import Observation

// MARK: - ServerStore

/// Observable store for the list of configured Seerr servers.
///
/// Inject via `.environment(serverStore)` and access with:
/// ```swift
/// @Environment(ServerStore.self) private var serverStore
/// ```
///
/// The store is the single source of truth for:
/// - The ordered list of `ServerConfiguration` objects.
/// - The ID of the user's default server.
/// - Per-server certificate fingerprints (TOFU).
///
/// Credentials (API keys, session tokens) are read from and written to
/// `KeychainManager` — they are never stored in `UserDefaults`.
@Observable
@MainActor
public final class ServerStore {

    // MARK: - Constants

    private let serversKey    = "SeerrClient.servers"
    private let defaultKeyKey = "SeerrClient.defaultServerID"

    // MARK: - Stored State

    /// The ordered list of configured servers.
    public private(set) var servers: [ServerConfiguration] = []

    /// The ID of the user's primary/default server.
    public private(set) var defaultServerID: UUID?

    // MARK: - Init

    public init() {
        loadFromDefaults()
    }

    // MARK: - Computed

    /// The default server, if one is set and present in `servers`.
    public var defaultServer: ServerConfiguration? {
        guard let id = defaultServerID else { return servers.first }
        return servers.first { $0.id == id } ?? servers.first
    }

    // MARK: - CRUD

    /// Adds a new server to the store and persists it.
    ///
    /// If this is the first server added, it is automatically set as the default.
    ///
    /// - Parameter server: The `ServerConfiguration` to add.
    public func add(_ server: ServerConfiguration) {
        servers.append(server)
        if servers.count == 1 {
            defaultServerID = server.id
        }
        saveToDefaults()
        AppLogger.info("ServerStore: added '\(server.displayName)' (\(server.baseURL))")
    }

    /// Updates an existing server's configuration in place.
    ///
    /// Identified by `server.id` — if no matching server is found, this is a no-op.
    ///
    /// - Parameter server: The updated `ServerConfiguration`.
    public func update(_ server: ServerConfiguration) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else {
            AppLogger.warning("ServerStore: update called for unknown server id=\(server.id)")
            return
        }
        servers[index] = server
        saveToDefaults()
        AppLogger.debug("ServerStore: updated '\(server.displayName)'")
    }

    /// Removes a server from the store and deletes its Keychain credentials.
    ///
    /// If the removed server was the default, the new default becomes the first
    /// remaining server (or `nil` if the list is empty).
    ///
    /// - Parameter server: The `ServerConfiguration` to remove.
    public func remove(_ server: ServerConfiguration) {
        servers.removeAll { $0.id == server.id }
        KeychainManager.shared.deleteAll(server: server.baseURL)
        if defaultServerID == server.id {
            defaultServerID = servers.first?.id
        }
        saveToDefaults()
        AppLogger.info("ServerStore: removed '\(server.displayName)'")
    }

    /// Removes a server by its unique ID.
    ///
    /// - Parameter id: The `UUID` of the server to remove.
    public func remove(id: UUID) {
        if let server = servers.first(where: { $0.id == id }) {
            remove(server)
        }
    }

    /// Sets the default server to the one with the given ID.
    ///
    /// - Parameter id: The `UUID` of the server to promote to default.
    public func setDefault(id: UUID) {
        guard servers.contains(where: { $0.id == id }) else { return }
        defaultServerID = id
        saveToDefaults()
    }

    // MARK: - Last Connected

    /// Records the current timestamp as `lastConnected` for the given server.
    ///
    /// - Parameter server: The server that was just successfully contacted.
    public func markConnected(_ server: ServerConfiguration) {
        guard var updated = servers.first(where: { $0.id == server.id }) else { return }
        updated = ServerConfiguration(
            id: updated.id,
            displayName: updated.displayName,
            baseURL: updated.baseURL,
            backendType: updated.backendType,
            apiVersion: updated.apiVersion,
            authMethod: updated.authMethod,
            isDefault: updated.isDefault,
            lastConnected: Date(),
            certFingerprint: updated.certFingerprint
        )
        update(updated)
    }

    // MARK: - Certificate Fingerprint (TOFU)

    /// Returns the stored SHA-256 certificate fingerprint for a server URL.
    ///
    /// Used by `TrustManager` to validate self-signed certificates.
    ///
    /// - Parameter serverURL: The server's normalised base URL.
    /// - Returns: The fingerprint hex string, or `nil` if none is stored.
    nonisolated public func certFingerprint(for serverURL: String) -> String? {
        // Read directly from UserDefaults (thread-safe) so TrustManager can call
        // this from its non-main-actor URLSession delegate callback.
        let decoder = JSONDecoder()
        guard let data = UserDefaults.standard.data(forKey: serversKey),
              let stored = try? decoder.decode([ServerConfiguration].self, from: data) else {
            return nil
        }
        return stored.first { $0.baseURL == serverURL }?.certFingerprint
    }

    /// Stores a new certificate fingerprint for the server matching `serverURL`.
    ///
    /// Called by `TrustManager` after the user accepts a self-signed certificate.
    ///
    /// - Parameters:
    ///   - fingerprint: The SHA-256 hex fingerprint to store.
    ///   - serverURL: The server's normalised base URL.
    public func setCertFingerprint(_ fingerprint: String, for serverURL: String) {
        guard var server = servers.first(where: { $0.baseURL == serverURL }) else { return }
        server = ServerConfiguration(
            id: server.id,
            displayName: server.displayName,
            baseURL: server.baseURL,
            backendType: server.backendType,
            apiVersion: server.apiVersion,
            authMethod: server.authMethod,
            isDefault: server.isDefault,
            lastConnected: server.lastConnected,
            certFingerprint: fingerprint
        )
        update(server)
        AppLogger.info("ServerStore: stored cert fingerprint for \(serverURL)")
    }

    // MARK: - Persistence (UserDefaults)

    private func saveToDefaults() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(servers)
            UserDefaults.standard.set(data, forKey: serversKey)
        } catch {
            AppLogger.error("ServerStore: failed to persist servers — \(error)")
        }
        if let id = defaultServerID {
            UserDefaults.standard.set(id.uuidString, forKey: defaultKeyKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultKeyKey)
        }
    }

    private func loadFromDefaults() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: serversKey),
           let loaded = try? decoder.decode([ServerConfiguration].self, from: data) {
            servers = loaded
        }
        if let uuidString = UserDefaults.standard.string(forKey: defaultKeyKey),
           let uuid = UUID(uuidString: uuidString) {
            defaultServerID = uuid
        }
    }
}
