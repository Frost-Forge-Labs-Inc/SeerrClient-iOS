// ServerSetupViewModel.swift
// SeerrClient
//
// @Observable ViewModel that drives both the server list screen and the
// "Add Server" flow. Manages URL normalisation, detection state machine,
// and final server persistence to ServerStore.

import Foundation
import Observation

// MARK: - DetectionState

/// The state machine for the server detection flow in AddServerView.
public enum DetectionState: Equatable {
    /// Initial state — nothing is happening yet.
    case idle
    /// URL normalisation and API calls are in progress.
    case detecting
    /// Detection succeeded; contains the structured result.
    case detected(ServerDetectionResult)
    /// Detection failed; contains a user-facing message.
    case failed(String)

    public static func == (lhs: DetectionState, rhs: DetectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.detecting, .detecting):
            return true
        case (.detected(let a), .detected(let b)):
            return a.baseURL == b.baseURL
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - ServerSetupViewModel

/// ViewModel that backs `ServerListView` and `AddServerView`.
///
/// Responsibilities:
/// - Exposes the current server list from `ServerStore`.
/// - Manages the URL text field and detection state machine for `AddServerView`.
/// - Normalises raw URL input via `URLNormalizer`.
/// - Runs `ServerRepository.detectServer()` and transitions `detectionState`.
/// - Saves a finalised `ServerConfiguration` to `ServerStore`.
/// - Handles the TOFU (Trust On First Use) self-signed certificate prompt.
///
/// Usage:
/// ```swift
/// let vm = ServerSetupViewModel(serverStore: store)
/// vm.urlInput = "192.168.1.50"
/// await vm.connectToServer()
/// ```
@Observable
@MainActor
public final class ServerSetupViewModel {

    // MARK: - Dependencies

    private let serverStore: ServerStore

    // MARK: - Server List State

    /// The ordered list of configured servers, read from `ServerStore`.
    public var servers: [ServerConfiguration] {
        serverStore.servers
    }

    // MARK: - Add Server Flow State

    /// The raw URL string entered by the user.
    public var urlInput: String = ""

    /// The display name the user wants to assign to the server.
    /// Pre-filled from the hostname after successful detection.
    public var displayNameInput: String = ""

    /// The current detection flow state.
    public var detectionState: DetectionState = .idle

    /// Whether the TOFU certificate trust alert should be shown.
    public var showCertTrustAlert: Bool = false

    /// The hostname shown in the certificate trust alert (extracted from the URL).
    public var certTrustHostname: String = ""

    // MARK: - Init

    /// Creates a `ServerSetupViewModel` bound to the given `ServerStore`.
    ///
    /// - Parameter serverStore: The store where `ServerConfiguration` objects live.
    public init(serverStore: ServerStore) {
        self.serverStore = serverStore
    }

    // MARK: - Computed Helpers

    /// `true` when `urlInput` is non-empty and detection is not already running.
    public var canConnect: Bool {
        !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && detectionState != .detecting
    }

    /// Whether the URL input appears to use HTTP (for the inline warning banner).
    public var isHTTPWarningVisible: Bool {
        urlInput.lowercased().hasPrefix("http://")
    }

    /// The detected result, if available.
    public var detectedResult: ServerDetectionResult? {
        if case .detected(let result) = detectionState { return result }
        return nil
    }

    /// A user-facing error message, if detection failed.
    public var detectionError: String? {
        if case .failed(let msg) = detectionState { return msg }
        return nil
    }

    // MARK: - Server Detection

    /// Normalises `urlInput` and runs the server detection sequence.
    ///
    /// Transitions `detectionState` through `.detecting` → `.detected` or `.failed`.
    /// If a self-signed certificate blocks the connection, `showCertTrustAlert` is
    /// set to `true` instead of failing, giving the user a chance to trust.
    public func connectToServer() async {
        let raw = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        detectionState = .detecting

        // Step 1: Normalise the URL.
        let normalizedURL: String
        do {
            normalizedURL = try URLNormalizer.normalize(raw)
        } catch {
            detectionState = .failed("The URL you entered appears to be invalid. Please check and try again.")
            return
        }

        // Step 2: Run detection.
        let repo = ServerRepository(baseURL: normalizedURL, serverStore: serverStore)
        do {
            let result = try await repo.detectServer()
            applyDetectionSuccess(result)
        } catch let error as SeerrAPIError {
            handleDetectionError(error, normalizedURL: normalizedURL)
        } catch {
            detectionState = .failed("An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    /// Retries detection after the user has agreed to trust a self-signed certificate.
    ///
    /// Should be called in the `.confirmationDialog` / alert action when the user
    /// taps "Trust Certificate".
    public func retryWithCertificateTrust() async {
        guard case .failed = detectionState else { return }

        let raw = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedURL = try? URLNormalizer.normalize(raw) else { return }

        detectionState = .detecting
        showCertTrustAlert = false

        let repo = ServerRepository(baseURL: normalizedURL, serverStore: serverStore)
        do {
            let result = try await repo.detectServerTrustingCertificate()
            applyDetectionSuccess(result)
        } catch let error as SeerrAPIError {
            detectionState = .failed(error.userMessage)
        } catch {
            detectionState = .failed("An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    /// Resets the detection state back to `.idle`, preserving `urlInput`.
    ///
    /// Called when the user taps "Try Again" in the failure state.
    public func resetDetection() {
        detectionState = .idle
        showCertTrustAlert = false
    }

    // MARK: - Save Server

    /// Finalises the detected server and saves it to `ServerStore`.
    ///
    /// Must only be called when `detectionState == .detected(...)`. Uses
    /// `displayNameInput` (or the detected application title as a fallback) as
    /// the `ServerConfiguration.displayName`.
    ///
    /// - Returns: The saved `ServerConfiguration`, ready for passing to the
    ///   `AuthViewModel` and `LoginView`.
    @discardableResult
    public func saveDetectedServer() -> ServerConfiguration? {
        guard let result = detectedResult else { return nil }

        let name = displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? result.applicationTitle
            : displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines)

        let config = ServerConfiguration(
            displayName: name,
            baseURL: result.baseURL,
            backendType: result.backendType,
            apiVersion: .v1,
            authMethod: .none,
            availableAuthMethods: result.availableAuthMethods,
            capabilities: result.capabilities,
            isDefault: serverStore.servers.isEmpty,
            lastConnected: nil
        )

        serverStore.add(config)
        AppLogger.info("ServerSetupViewModel: saved server '\(name)' (\(result.baseURL))")
        return config
    }

    // MARK: - Delete Server

    /// Removes a server from `ServerStore` and deletes its Keychain credentials.
    ///
    /// - Parameter server: The `ServerConfiguration` to remove.
    public func deleteServer(_ server: ServerConfiguration) {
        serverStore.remove(server)
    }

    /// Removes servers at the given index set from the displayed list.
    ///
    /// Designed for use with `List` swipe-to-delete via `onDelete(perform:)`.
    ///
    /// - Parameter offsets: The index set returned by the `onDelete` closure.
    public func deleteServers(at offsets: IndexSet) {
        let toDelete = offsets.map { serverStore.servers[$0] }
        toDelete.forEach { serverStore.remove($0) }
    }

    // MARK: - Private Helpers

    private func applyDetectionSuccess(_ result: ServerDetectionResult) {
        // Pre-fill the display name with the hostname extracted from the URL.
        if displayNameInput.isEmpty {
            displayNameInput = result.applicationTitle
        }
        detectionState = .detected(result)
    }

    private func handleDetectionError(_ error: SeerrAPIError, normalizedURL: String) {
        switch error {
        case .sslError:
            // Self-signed cert detected: offer to trust.
            certTrustHostname = URLNormalizer.displayHost(from: normalizedURL)
            showCertTrustAlert = true
            detectionState = .failed(error.userMessage)
        case .timeout:
            detectionState = .failed(
                "Connection timed out. Check that the server is running and reachable on your network."
            )
        case .networkError:
            detectionState = .failed(
                "Could not reach the server. Check the URL and your network connection."
            )
        case .invalidURL:
            detectionState = .failed(
                "The URL you entered is not valid. Try a format like \"192.168.1.50:5055\" or \"https://seerr.example.com\"."
            )
        case .notFound:
            detectionState = .failed(
                "The server responded but does not appear to be a Seerr-compatible server. Check the URL."
            )
        default:
            detectionState = .failed(error.userMessage)
        }
    }
}
