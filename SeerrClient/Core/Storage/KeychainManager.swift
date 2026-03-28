// KeychainManager.swift
// SeerrClient
//
// Thin wrapper around Keychain Services (kSecClassGenericPassword).
// All keys are scoped per server URL so credentials from different servers
// never collide. The shared singleton is the canonical interface used
// throughout the app — no third-party keychain library is required.

import Foundation
import Security

// MARK: - KeychainKey

/// Well-known keychain key names used by the app.
///
/// Keys are always combined with a server URL prefix via `KeychainManager`
/// to produce a per-server scoped key string.
public enum KeychainKey: String {
    /// Seerr API key (`X-Api-Key` header value).
    case apiKey        = "apiKey"
    /// Session cookie value set by `/auth/*` endpoints.
    case sessionToken  = "sessionToken"
    /// The user's local login email address (not sensitive, but stored with creds).
    case username      = "username"
    /// The user's local login password (local auth only).
    case password      = "password"
}

// MARK: - KeychainManager

/// Singleton wrapper for Keychain Services (`kSecClassGenericPassword`).
///
/// All operations are scoped per server URL — credentials from different
/// servers are stored under different keys and never interfere.
///
/// Usage:
/// ```swift
/// // Store
/// try KeychainManager.shared.save(apiKey, for: .apiKey, server: "http://192.168.1.50:5055")
///
/// // Read
/// let key = KeychainManager.shared.read(.apiKey, server: "http://192.168.1.50:5055")
///
/// // Delete
/// KeychainManager.shared.delete(.apiKey, server: "http://192.168.1.50:5055")
///
/// // Delete everything for a server
/// KeychainManager.shared.deleteAll(server: "http://192.168.1.50:5055")
/// ```
public final class KeychainManager: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared instance. Use this across the app.
    public static let shared = KeychainManager()

    // MARK: - Properties

    /// The service name stored in `kSecAttrService`.
    /// Using the app bundle ID keeps items distinct from other apps.
    private let service: String

    // MARK: - Init

    private init(service: String = "com.seerrclient.keychain") {
        self.service = service
    }

    // MARK: - Public API

    /// Saves (or updates) a string value in the Keychain under the given key, scoped to a server.
    ///
    /// - Parameters:
    ///   - value: The plaintext string value to store.
    ///   - key: The semantic `KeychainKey`.
    ///   - serverURL: The server's normalised base URL used as a scope prefix.
    /// - Throws: `KeychainError.saveFailed` if the underlying Keychain call fails.
    public func save(_ value: String, for key: KeychainKey, server serverURL: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(data, for: key, server: serverURL)
    }

    /// Saves (or updates) raw `Data` in the Keychain under the given key, scoped to a server.
    ///
    /// - Parameters:
    ///   - data: The data to store.
    ///   - key: The semantic `KeychainKey`.
    ///   - serverURL: The server's normalised base URL used as a scope prefix.
    /// - Throws: `KeychainError.saveFailed` if the underlying Keychain call fails.
    public func save(_ data: Data, for key: KeychainKey, server serverURL: String) throws {
        let account = scopedAccount(key: key, server: serverURL)

        // Try to update an existing item first.
        let query = baseQuery(account: account)
        let attributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            AppLogger.debug("Keychain: updated '\(key.rawValue)' for \(serverURL)")

        case errSecItemNotFound:
            // Item doesn't exist yet — add it.
            var addQuery = baseQuery(account: account)
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(status: addStatus)
            }
            AppLogger.debug("Keychain: saved '\(key.rawValue)' for \(serverURL)")

        default:
            throw KeychainError.saveFailed(status: updateStatus)
        }
    }

    /// Reads a string value from the Keychain for the given key and server.
    ///
    /// - Parameters:
    ///   - key: The semantic `KeychainKey`.
    ///   - serverURL: The server's normalised base URL.
    /// - Returns: The stored string, or `nil` if not found.
    public func read(_ key: KeychainKey, server serverURL: String) -> String? {
        guard let data = readData(key, server: serverURL) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Reads raw `Data` from the Keychain for the given key and server.
    ///
    /// - Parameters:
    ///   - key: The semantic `KeychainKey`.
    ///   - serverURL: The server's normalised base URL.
    /// - Returns: The stored data, or `nil` if not found.
    public func readData(_ key: KeychainKey, server serverURL: String) -> Data? {
        let account = scopedAccount(key: key, server: serverURL)
        var query = baseQuery(account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    /// Convenience: reads the stored API key for a given server base URL.
    ///
    /// - Parameter serverURL: The server's normalised base URL.
    /// - Returns: The API key string, or `nil` if none is stored.
    public func readAPIKey(for serverURL: String) -> String? {
        read(.apiKey, server: serverURL)
    }

    /// Deletes the stored value for a specific key and server.
    ///
    /// Silently succeeds if no item exists.
    ///
    /// - Parameters:
    ///   - key: The semantic `KeychainKey`.
    ///   - serverURL: The server's normalised base URL.
    @discardableResult
    public func delete(_ key: KeychainKey, server serverURL: String) -> Bool {
        let account = scopedAccount(key: key, server: serverURL)
        let query = baseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)
        let success = status == errSecSuccess || status == errSecItemNotFound
        if success {
            AppLogger.debug("Keychain: deleted '\(key.rawValue)' for \(serverURL)")
        } else {
            AppLogger.warning("Keychain: delete '\(key.rawValue)' failed — OSStatus \(status)")
        }
        return success
    }

    /// Deletes ALL stored credentials for a given server.
    ///
    /// Call this when the user removes a server or signs out.
    ///
    /// - Parameter serverURL: The server's normalised base URL.
    public func deleteAll(server serverURL: String) {
        for key in KeychainKey.allCases {
            delete(key, server: serverURL)
        }
        AppLogger.info("Keychain: cleared all credentials for \(serverURL)")
    }

    // MARK: - Private Helpers

    /// Builds a scoped account string: `"<serverURL>|<keyRawValue>"`.
    private func scopedAccount(key: KeychainKey, server serverURL: String) -> String {
        "\(serverURL)|\(key.rawValue)"
    }

    /// Returns the base Keychain query dictionary for a given account string.
    private func baseQuery(account: String) -> [CFString: Any] {
        [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }
}

// MARK: - KeychainKey + CaseIterable

extension KeychainKey: CaseIterable {}

// MARK: - KeychainError

/// Errors that can be thrown by `KeychainManager`.
public enum KeychainError: Error, LocalizedError {
    /// The provided data could not be converted to/from the expected format.
    case invalidData
    /// A Keychain `SecItemAdd` or `SecItemUpdate` call failed.
    case saveFailed(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid keychain data format."
        case .saveFailed(let status):
            return "Keychain save failed with status \(status)."
        }
    }
}
