// AuthViewModel.swift
// SeerrClient
//
// @Observable ViewModel that drives the LoginView and PlexOAuthView.
// Manages auth state, form field binding, method selection, and session
// restoration. On success it calls AppState.setAuthenticatedUser(_:).

import Foundation
import Observation

// MARK: - AuthState

/// The authentication flow state machine.
public enum AuthState: Equatable {
    /// Initial state — form is ready for input.
    case idle
    /// An authentication request is in flight.
    case authenticating
    /// Authentication succeeded. The associated value is the authenticated user.
    case authenticated(User)
    /// Authentication failed. The associated value is a user-facing message.
    case failed(String)

    public static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.authenticating, .authenticating):
            return true
        case (.authenticated(let a), .authenticated(let b)):
            return a.id == b.id
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - AuthViewModel

/// ViewModel that backs `LoginView` and drives the full authentication flow.
///
/// Responsibilities:
/// - Exposes the server and its available auth methods for the UI
/// - Manages selected auth method and all form field bindings
/// - Calls `AuthRepository` methods for each auth type
/// - Handles session restoration (`GET /auth/me`) on app launch
/// - Calls `AppState.setAuthenticatedUser(_:)` on success
/// - Calls `AppState.signOut()` on logout
///
/// Usage:
/// ```swift
/// let vm = AuthViewModel(
///     server: appState.activeServer!,
///     apiClient: appState.apiClient!,
///     appState: appState
/// )
/// await vm.restoreSessionIfPossible()
/// ```
@Observable
@MainActor
public final class AuthViewModel {

    // MARK: - Dependencies

    private let authRepository: AuthRepository
    private let appState: AppState
    private let serverStore: ServerStore

    // MARK: - Server Info (read-only)

    /// The server being authenticated against.
    public let server: ServerConfiguration

    /// Auth methods available on this server (from `ServerDetectionResult`).
    /// Falls back to all methods if none were specified (conservative default).
    public let availableAuthMethods: [AuthMethod]

    // MARK: - Auth State

    /// The current authentication flow state.
    public var authState: AuthState = .idle

    // MARK: - Selected Method

    /// The auth method the user has selected in the picker.
    public var selectedMethod: AuthMethod

    // MARK: - Form Fields

    // --- Local Login ---

    /// Email for local login.
    public var email: String = ""

    /// Password for local login.
    public var password: String = ""

    // --- Jellyfin Login ---

    /// Jellyfin username.
    public var jellyfinUsername: String = ""

    /// Jellyfin password.
    public var jellyfinPassword: String = ""

    /// Jellyfin server URL (optional — leave blank to use the Seerr server's host).
    public var jellyfinServerURL: String = ""

    // MARK: - Computed

    /// `true` while an auth request is in progress.
    public var isAuthenticating: Bool {
        authState == .authenticating
    }

    /// The user-facing error message, if auth has failed.
    public var errorMessage: String? {
        if case .failed(let msg) = authState { return msg }
        return nil
    }

    /// `true` when the local login form has sufficient input to submit.
    public var canSubmitLocal: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
            && !isAuthenticating
    }

    /// `true` when the Jellyfin login form has sufficient input to submit.
    public var canSubmitJellyfin: Bool {
        !jellyfinUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !jellyfinPassword.isEmpty
            && !isAuthenticating
    }

    // MARK: - Init

    /// Creates an `AuthViewModel` bound to a specific server.
    ///
    /// - Parameters:
    ///   - server: The `ServerConfiguration` to authenticate against.
    ///   - availableAuthMethods: Auth methods exposed by the server's `/settings/public`.
    ///   - apiClient: The `SeerrAPIClient` for the active server.
    ///   - appState: Global app state; receives the authenticated user on success.
    ///   - serverStore: Used for logging `lastConnected` timestamps.
    init(
        server: ServerConfiguration,
        availableAuthMethods: [AuthMethod],
        apiClient: SeerrAPIClient,
        appState: AppState,
        serverStore: ServerStore
    ) {
        self.server = server
        self.availableAuthMethods = availableAuthMethods.isEmpty
            ? [.local]      // Safe fallback
            : availableAuthMethods
        self.selectedMethod = availableAuthMethods.first ?? .local
        self.authRepository = AuthRepository(apiClient: apiClient, server: server)
        self.appState = appState
        self.serverStore = serverStore
    }

    // MARK: - Session Restoration

    /// Attempts to restore an existing session by calling `GET /auth/me`.
    ///
    /// Call this on app launch when a server is already configured. If the stored
    /// session is valid the user is set in `AppState` without showing the login UI.
    /// A `401` silently fails — the login screen is then shown normally.
    public func restoreSessionIfPossible() async {
        authState = .authenticating
        do {
            let user = try await authRepository.fetchCurrentUser()
            apply(authenticatedUser: user)
        } catch let error as SeerrAPIError {
            switch error {
            case .unauthorized, .forbidden:
                // Session expired — show login form cleanly.
                authState = .idle
            default:
                // Network unavailable, etc. — still show login form.
                authState = .idle
                AppLogger.warning("AuthViewModel: session restore failed — \(error.userMessage)")
            }
        } catch {
            authState = .idle
        }
    }

    // MARK: - Local Login

    /// Submits the local email/password form.
    ///
    /// Validates that `email` and `password` are non-empty before proceeding.
    /// On success, calls `AppState.setAuthenticatedUser(_:)`.
    public func loginLocal() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            authState = .failed("Please enter your email address and password.")
            return
        }

        authState = .authenticating
        do {
            let user = try await authRepository.loginLocal(
                email: trimmedEmail,
                password: password
            )
            apply(authenticatedUser: user)
        } catch let error as SeerrAPIError {
            authState = .failed(localizedAuthError(error))
        } catch {
            authState = .failed("An unexpected error occurred. Please try again.")
        }
    }

    // MARK: - Plex Login

    /// Completes Plex auth using the token obtained from the pin-based OAuth flow.
    ///
    /// This is called by `PlexOAuthView` after polling confirms the user has
    /// authenticated at `app.plex.tv`.
    ///
    /// - Parameter authToken: The `authToken` from `GET plex.tv/api/v2/pins/{id}`.
    public func loginPlex(authToken: String) async {
        authState = .authenticating
        do {
            let user = try await authRepository.loginPlex(authToken: authToken)
            apply(authenticatedUser: user)
        } catch let error as SeerrAPIError {
            authState = .failed(localizedAuthError(error))
        } catch {
            authState = .failed("Plex sign-in failed. Please try again.")
        }
    }

    // MARK: - Jellyfin Login

    /// Submits the Jellyfin username/password form.
    ///
    /// - Note: `jellyfinServerURL` is optional. When blank, Seerr uses its own
    ///   configured Jellyfin host.
    public func loginJellyfin() async {
        let trimmedUsername = jellyfinUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty, !jellyfinPassword.isEmpty else {
            authState = .failed("Please enter your Jellyfin username and password.")
            return
        }

        let hostname = jellyfinServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ? nil : jellyfinServerURL.trimmingCharacters(in: .whitespacesAndNewlines)

        authState = .authenticating
        do {
            let user = try await authRepository.loginJellyfin(
                username: trimmedUsername,
                password: jellyfinPassword,
                hostname: hostname
            )
            apply(authenticatedUser: user)
        } catch let error as SeerrAPIError {
            authState = .failed(localizedAuthError(error))
        } catch {
            authState = .failed("Jellyfin sign-in failed. Please try again.")
        }
    }

    // MARK: - Logout

    /// Signs out the current user and clears all stored credentials.
    ///
    /// Calls `POST /auth/logout`, clears the Keychain, and calls
    /// `appState.signOut()` to reset navigation to the login screen.
    public func logout() async {
        do {
            try await authRepository.logout()
        } catch {
            // Log but don't block sign-out — local state must always be cleared.
            AppLogger.warning("AuthViewModel: server logout call failed — \(error)")
        }

        authRepository.clearStoredCredentials()
        appState.signOut()
        authState = .idle
    }

    // MARK: - Error Reset

    /// Clears the current error state, returning the ViewModel to `.idle`.
    ///
    /// Call when switching auth method tabs to dismiss stale error banners.
    public func clearError() {
        if case .failed = authState {
            authState = .idle
        }
    }

    // MARK: - Private Helpers

    private func apply(authenticatedUser user: User) {
        authState = .authenticated(user)
        appState.setAuthenticatedUser(user)
        serverStore.markConnected(server)
        AppLogger.info("AuthViewModel: authenticated user id=\(user.id)")
    }

    /// Maps `SeerrAPIError` cases to user-appropriate auth error messages.
    private func localizedAuthError(_ error: SeerrAPIError) -> String {
        switch error {
        case .unauthorized:
            return "Invalid credentials. Please check your email and password and try again."
        case .forbidden:
            return "Your account does not have permission to access this server."
        case .timeout:
            return "The connection timed out. Check your network and server address."
        case .networkError:
            return "Could not reach the server. Check your network connection."
        case .sslError:
            return "A secure connection could not be established."
        default:
            return error.userMessage
        }
    }
}
