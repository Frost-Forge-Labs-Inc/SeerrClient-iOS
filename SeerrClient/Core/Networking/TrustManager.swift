// TrustManager.swift
// SeerrClient
//
// URLSessionDelegate that implements Trust-On-First-Use (TOFU) for self-signed
// certificates. On first connection to a server we record the SHA-256 fingerprint
// of the leaf certificate and store it in the matching ServerConfiguration via
// the ServerStore. On subsequent connections we verify against the stored
// fingerprint — a mismatch causes the connection to fail with an SSL error.

import Foundation
import CommonCrypto

// MARK: - TrustManager

/// A `URLSessionDelegate` that handles server certificate challenges using the
/// Trust-On-First-Use (TOFU) model.
///
/// - On the **first** connection to a server, any certificate (including
///   self-signed ones) is accepted and its SHA-256 fingerprint is persisted in
///   `ServerStore` against the server's base URL.
/// - On **subsequent** connections the presented certificate's fingerprint must
///   match the stored one. A mismatch results in a cancelled challenge and a
///   `SeerrAPIError.sslError`.
///
/// Set `allowAllForCurrentChallenge = true` **before** a single challenge to
/// accept and record a new certificate (e.g. when the user deliberately
/// re-trusts after a certificate rotation).
///
/// Usage:
/// ```swift
/// let trustManager = TrustManager(
///     serverURL: server.baseURL,
///     serverStore: serverStore
/// )
/// let session = URLSession(
///     configuration: .default,
///     delegate: trustManager,
///     delegateQueue: nil
/// )
/// ```
final class TrustManager: NSObject, URLSessionDelegate, Sendable {

    // MARK: - Properties

    /// The base URL of the server this manager is scoped to.
    nonisolated let serverURL: String

    /// Backing store used to read and write the persisted certificate fingerprint.
    nonisolated let serverStore: ServerStore

    /// When `true`, the next server trust challenge is accepted unconditionally
    /// and its fingerprint is stored. Reset to `false` after one use.
    ///
    /// Set this to `true` when the user explicitly agrees to trust a new
    /// certificate (e.g. after a "Do you trust this server?" prompt).
    ///
    /// Thread-safe via `NSLock` — written from the actor-isolated `SeerrAPIClient`
    /// and read from URLSession's delegate queue.
    private let _lock = NSLock()
    private var _allowAllForCurrentChallenge: Bool = false

    var allowAllForCurrentChallenge: Bool {
        get { _lock.withLock { _allowAllForCurrentChallenge } }
        set { _lock.withLock { _allowAllForCurrentChallenge = newValue } }
    }

    // MARK: - Init

    /// Creates a `TrustManager` for a specific server.
    ///
    /// - Parameters:
    ///   - serverURL: The normalised base URL of the server.
    ///   - serverStore: The store where fingerprints are persisted.
    init(serverURL: String, serverStore: ServerStore) {
        self.serverURL = serverURL
        self.serverStore = serverStore
        super.init()
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod
                == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            // Not a server trust challenge — use default handling.
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate the trust object first (ATS may still enforce some rules).
        var error: CFError?
        let trusted = SecTrustEvaluateWithError(serverTrust, &error)

        // Compute the leaf certificate's SHA-256 fingerprint.
        // SecTrustCopyCertificateChain is the non-deprecated API (iOS 15+).
        guard
            let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
            let leafCert = chain.first,
            let fingerprint = sha256Fingerprint(of: leafCert)
        else {
            AppLogger.warning("TrustManager: could not compute fingerprint for \(serverURL)")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // --- TOFU Logic ---

        if allowAllForCurrentChallenge {
            // Explicit user trust: accept anything and record the fingerprint.
            allowAllForCurrentChallenge = false
            persistFingerprint(fingerprint)
            AppLogger.info("TrustManager: TOFU — stored fingerprint for \(serverURL): \(fingerprint)")
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }

        if let storedFingerprint = serverStore.certFingerprint(for: serverURL) {
            // Fingerprint on record — verify it matches.
            if storedFingerprint == fingerprint {
                AppLogger.debug("TrustManager: fingerprint verified for \(serverURL)")
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                AppLogger.warning(
                    "TrustManager: fingerprint MISMATCH for \(serverURL). " +
                    "Stored=\(storedFingerprint)  Presented=\(fingerprint)"
                )
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
            return
        }

        // No fingerprint stored yet.
        if trusted {
            // System-trusted cert (CA-signed): accept without TOFU prompt.
            AppLogger.debug("TrustManager: CA-trusted cert for \(serverURL) — no TOFU needed")
            completionHandler(.performDefaultHandling, nil)
        } else {
            // Self-signed cert with no prior trust decision: reject until the
            // caller sets `allowAllForCurrentChallenge = true`.
            AppLogger.info(
                "TrustManager: untrusted self-signed cert for \(serverURL) — " +
                "caller must set allowAllForCurrentChallenge = true to proceed"
            )
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    // MARK: - Private Helpers

    /// Computes the SHA-256 fingerprint of a `SecCertificate` as a hex string.
    ///
    /// - Parameter cert: The certificate to hash.
    /// - Returns: A lowercase hex string of 64 characters, or `nil` on failure.
    private func sha256Fingerprint(of cert: SecCertificate) -> String? {
        let data = SecCertificateCopyData(cert) as Data
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Persists a newly observed certificate fingerprint to the `ServerStore`.
    ///
    /// - Parameter fingerprint: The SHA-256 hex fingerprint to store.
    private func persistFingerprint(_ fingerprint: String) {
        Task { @MainActor in
            serverStore.setCertFingerprint(fingerprint, for: serverURL)
        }
    }
}

// MARK: - TrustDecision

/// The result of a TOFU certificate evaluation, communicated back to callers
/// that need to present UI (e.g. "Trust this server?" sheet).
public enum TrustDecision: Sendable {
    /// The certificate is valid and matches the stored fingerprint (or is CA-signed).
    case trusted
    /// A new self-signed certificate was encountered. The user should be prompted.
    /// The associated value is the fingerprint they will be trusting.
    case newSelfSigned(fingerprint: String)
    /// The certificate fingerprint does not match the stored one — possible MITM.
    case fingerprintMismatch(stored: String, presented: String)
}
