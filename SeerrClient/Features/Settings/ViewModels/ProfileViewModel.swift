// ProfileViewModel.swift
// SeerrClient
//
// Manages Profile + Settings state, loading, and account actions.

import Foundation
import SwiftUI

// MARK: - AppTheme

public enum AppTheme: Int, CaseIterable, Identifiable, Sendable {
    case system = 0
    case light = 1
    case dark = 2

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - ProfileLoadState

public enum ProfileLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)

    public static func == (lhs: ProfileLoadState, rhs: ProfileLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
            return true
        case (.error(let left), .error(let right)):
            return left == right
        default:
            return false
        }
    }
}

// MARK: - ProfileViewModel

@MainActor @Observable
public final class ProfileViewModel {

    // MARK: - Public State

    public private(set) var loadState: ProfileLoadState = .idle

    public private(set) var user: User?
    public private(set) var requestCounts: RequestCounts?
    public private(set) var serverStatus: ServerStatus?

    public private(set) var isSigningOut: Bool = false
    public private(set) var isDisconnecting: Bool = false

    public var showSignOutConfirmation: Bool = false
    public var showDisconnectConfirmation: Bool = false

    public var selectedTheme: AppTheme {
        didSet {
            persistTheme(selectedTheme)
        }
    }

    public var isAdmin: Bool {
        ((user?.permissions ?? 0) & 2) != 0
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let appState: AppState
    @ObservationIgnored
    private let authRepository: AuthRepository
    @ObservationIgnored
    private let profileRepository: ProfileRepository
    @ObservationIgnored
    private let userDefaults: UserDefaults

    // MARK: - Tasks

    @ObservationIgnored
    private var loadTask: Task<Void, Never>?
    @ObservationIgnored
    private var signOutTask: Task<Void, Never>?

    // MARK: - Constants

    @ObservationIgnored
    private static let themeKey = "seerr.appTheme"

    // MARK: - Init

    init(
        apiClient: SeerrAPIClient,
        appState: AppState,
        server: ServerConfiguration,
        userDefaults: UserDefaults = .standard
    ) {
        self.appState = appState
        self.profileRepository = ProfileRepository(apiClient: apiClient)
        self.authRepository = AuthRepository(apiClient: apiClient, server: server)
        self.userDefaults = userDefaults

        let storedRawValue = userDefaults.integer(forKey: Self.themeKey)
        self.selectedTheme = AppTheme(rawValue: storedRawValue) ?? .system
    }

    // MARK: - Lifecycle

    public func cancelAll() {
        loadTask?.cancel()
        signOutTask?.cancel()
    }

    // MARK: - Actions

    public func loadProfile() {
        guard loadState != .loading else { return }

        loadTask?.cancel()
        loadState = .loading

        loadTask = Task {
            do {
                let fetchedUser = try await authRepository.fetchCurrentUser()
                guard !Task.isCancelled else { return }

                async let statusTask = profileRepository.fetchServerStatus()

                let fetchedCounts: RequestCounts?
                if ((fetchedUser.permissions ?? 0) & 2) != 0 {
                    async let countsTask = profileRepository.fetchRequestCounts()
                    fetchedCounts = try await countsTask
                } else {
                    fetchedCounts = nil
                }

                let fetchedStatus = try await statusTask
                guard !Task.isCancelled else { return }

                user = fetchedUser
                requestCounts = fetchedCounts
                serverStatus = fetchedStatus
                appState.setAuthenticatedUser(fetchedUser)
                loadState = .loaded

                AppLogger.info("ProfileViewModel: loaded profile for user id=\(fetchedUser.id)")
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.warning("ProfileViewModel: load failed: \(mapError(error))")
                loadState = .error(mapError(error))
            }
        }
    }

    public func refresh() async {
        loadProfile()
        // Await the internal task so .refreshable spinner stays visible
        await loadTask?.value
    }

    public func signOut() {
        guard !isSigningOut else { return }

        showSignOutConfirmation = false
        signOutTask?.cancel()
        isSigningOut = true

        signOutTask = Task {
            defer { isSigningOut = false }

            // authRepository.logout() clears in-memory cookies BEFORE the POST,
            // so the POST is sent without a cookie and the server returns 401.
            // A 401 here is expected — the session is already invalidated locally.
            // Any error (401 or otherwise) does NOT block sign-out.
            do {
                try await authRepository.logout()
            } catch {
                AppLogger.warning("ProfileViewModel: server logout call failed (continuing) — \(error)")
            }

            guard !Task.isCancelled else { return }

            // Always clear Keychain so session restore cannot re-authenticate after sign-out.
            authRepository.clearStoredCredentials()

            // Disconnect fully — resets activeServer so ContentView shows ServerListView,
            // not LoginView (which would immediately re-run session restore from Keychain).
            appState.disconnectFromServer()
        }
    }

    public func disconnectServer() {
        guard !isDisconnecting else { return }

        showDisconnectConfirmation = false
        isDisconnecting = true
        cancelAll()
        appState.disconnectFromServer()
        isDisconnecting = false
    }

    // MARK: - Private

    private func persistTheme(_ theme: AppTheme) {
        userDefaults.set(theme.rawValue, forKey: Self.themeKey)
    }

    private func mapError(_ error: Error) -> String {
        guard let apiError = error as? SeerrAPIError else {
            return "Something went wrong. Please try again."
        }

        switch apiError {
        case .unauthorized:
            return "Your session expired. Please sign in again."
        case .forbidden:
            return "You don't have permission to view this profile."
        case .notFound:
            return "Profile information was not found."
        case .networkError:
            return "Unable to reach the server. Check your connection."
        case .timeout:
            return "The request timed out. Please try again."
        case .decodingError:
            return "The server returned an unexpected response."
        case .serverError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (\(statusCode)). Please try again."
        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                return message
            }
            return "Server error (\(statusCode)). Please try again."
        case .rateLimited:
            return "Too many requests. Please wait and try again."
        case .sslError:
            return "A secure connection could not be established."
        case .invalidURL:
            return "The server URL is invalid."
        case .conflict(let message):
            return message ?? "A conflict occurred. Please try again."
        case .cancelled:
            return "Request cancelled."
        case .sliderSkipped:
            return "Something went wrong. Please try again."
        }
    }
}

#if DEBUG

extension ProfileViewModel {
    static func makeAboutNavigationUITestModel(
        apiClient: SeerrAPIClient,
        appState: AppState,
        server: ServerConfiguration
    ) -> ProfileViewModel {
        let viewModel = ProfileViewModel(
            apiClient: apiClient,
            appState: appState,
            server: server
        )

        viewModel.user = appState.currentUser ?? User(
            id: 1,
            email: "uitest@example.com",
            displayName: "UI Tester",
            username: "uitester",
            plexToken: nil,
            plexUsername: nil,
            userType: 2,
            permissions: 2,
            avatar: nil,
            createdAt: "2026-04-08T00:00:00.000Z",
            updatedAt: "2026-04-08T00:00:00.000Z",
            requestCount: 0
        )
        viewModel.requestCounts = RequestCounts(
            total: 0,
            movie: 0,
            tv: 0,
            pending: 0,
            approved: 0,
            declined: 0,
            processing: 0,
            available: 0
        )
        viewModel.serverStatus = ServerStatus(
            version: "2.0.0-uitest",
            commitTag: "uitest",
            updateAvailable: false,
            commitsBehind: 0,
            restartRequired: false
        )
        viewModel.loadState = .loaded
        return viewModel
    }
}

#endif
