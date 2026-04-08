// PlexOAuthView.swift
// SeerrClient
//
// Implements the Plex pin-based OAuth flow without third-party libraries.
//
// Flow:
//  1. POST https://plex.tv/api/v2/pins → receive pin { id, code }
//  2. Open https://app.plex.tv/auth#?clientID=...&code=... in Safari via UIApplication.shared.open()
//  3. Poll GET https://plex.tv/api/v2/pins/{id} at 2-second intervals until
//     the `authToken` field is non-nil (or the user cancels)
//  4. Call the `onAuthenticated(authToken:)` callback so the caller can POST
//     /auth/plex on the Seerr server

import SwiftUI
import UIKit

// MARK: - Plex OAuth Constants

private enum PlexOAuth {
    /// The Plex API base URL.
    static let plexAPIBase    = "https://plex.tv/api/v2"
    /// The Plex auth web app URL used to open the browser.
    static let plexAuthWebApp = "https://app.plex.tv/auth"
    /// A stable client identifier unique to this app. Generated once and reused.
    /// In production this would be a registered Plex app client ID.
    static let clientID       = "seerr-local-client-ios"
    /// The product name sent to Plex for branding in the user's device list.
    static let product        = "Seerr Local Client"
    /// Polling interval while waiting for the user to authorise in the browser.
    static let pollInterval: TimeInterval = 2.0
    /// Maximum time to wait before giving up.
    static let pollTimeout: TimeInterval  = 120.0
}

// MARK: - Plex API Models

/// The pin object returned by `POST plex.tv/api/v2/pins`.
private struct PlexPin: Decodable {
    let id: Int
    let code: String
    let authToken: String?
}

// MARK: - PlexOAuthViewModel

/// ViewModel that manages the Plex pin flow state machine.
@Observable
@MainActor
private final class PlexOAuthViewModel {

    // MARK: - State

    enum State {
        case idle
        case requestingPin
        case awaitingAuth
        case polling
        case success
        case failed(String)
        case cancelled
    }

    var state: State = .idle
    var isInProgress: Bool {
        switch state {
        case .requestingPin, .awaitingAuth, .polling: return true
        default: return false
        }
    }

    // MARK: - Private

    private var pinID: Int?
    private var pollTask: Task<Void, Never>?

    // MARK: - Start Flow

    /// Begins the Plex pin OAuth flow.
    ///
    /// - Parameter onSuccess: Called with the auth token when the user completes auth.
    func start(onSuccess: @escaping (String) -> Void) {
        guard !isInProgress else { return }
        pollTask?.cancel()
        state = .requestingPin

        pollTask = Task {
            do {
                let pin = try await requestPin()
                pinID = pin.id
                state = .awaitingAuth

                // Open the Plex web auth URL.
                openPlexAuth(code: pin.code)

                // Start polling for token.
                state = .polling
                try await pollForToken(pinID: pin.id, onSuccess: onSuccess)
            } catch let error as PlexOAuthError {
                state = .failed(error.userMessage)
            } catch {
                state = .failed("Plex sign-in failed: \(error.localizedDescription)")
            }
        }
    }

    /// Cancels an in-progress flow.
    func cancel() {
        pollTask?.cancel()
        state = .cancelled
    }

    // MARK: - Step 1: Request Pin

    /// `POST https://plex.tv/api/v2/pins`
    private func requestPin() async throws -> PlexPin {
        guard var components = URLComponents(string: "\(PlexOAuth.plexAPIBase)/pins") else {
            throw PlexOAuthError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "strong", value: "true")
        ]
        guard let url = components.url else {
            throw PlexOAuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(PlexOAuth.clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue(PlexOAuth.product,  forHTTPHeaderField: "X-Plex-Product")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
            throw PlexOAuthError.pinRequestFailed
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(PlexPin.self, from: data)
    }

    // MARK: - Step 2: Open Browser

    private func openPlexAuth(code: String) {
        guard var components = URLComponents(string: PlexOAuth.plexAuthWebApp) else { return }

        // Plex auth URL uses a fragment for params (not query string).
        // Use percentEncodedFragment (raw property) so pre-encoded characters like
        // %5B and %5D are not double-encoded to %255B/%255D by the decoded setter.
        let params = [
            "clientID=\(PlexOAuth.clientID)",
            "code=\(code)",
            "context%5Bdevice%5D%5Bproduct%5D=\(PlexOAuth.product.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? PlexOAuth.product)"
        ].joined(separator: "&")
        components.percentEncodedFragment = "?" + params

        guard let authURL = components.url else { return }

        // Open in Safari via UIApplication.shared.open() — this is the standard
        // approach for Plex OAuth. The app does not expect a redirect callback;
        // the polling loop handles completion independently. Using the system browser
        // also lets Plex reuse existing browser cookies if the user is already signed in.
        UIApplication.shared.open(authURL)
    }

    // MARK: - Step 3: Poll for Token

    /// `GET https://plex.tv/api/v2/pins/{id}`
    private func pollForToken(pinID: Int, onSuccess: @escaping (String) -> Void) async throws {
        let url = URL(string: "\(PlexOAuth.plexAPIBase)/pins/\(pinID)")!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let deadline = Date().addingTimeInterval(PlexOAuth.pollTimeout)

        while Date() < deadline {
            try Task.checkCancellation()

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(PlexOAuth.clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
            request.setValue(PlexOAuth.product,  forHTTPHeaderField: "X-Plex-Product")

            let (data, _) = try await URLSession.shared.data(for: request)
            let pin = try decoder.decode(PlexPin.self, from: data)

            if let token = pin.authToken, !token.isEmpty {
                // Success — user has authorised the app.
                state = .success
                onSuccess(token)
                return
            }

            // Not yet authorised — wait and retry.
            try await Task.sleep(nanoseconds: UInt64(PlexOAuth.pollInterval * 1_000_000_000))
        }

        throw PlexOAuthError.timeout
    }
}

// MARK: - PlexOAuthError

private enum PlexOAuthError: Error {
    case invalidURL
    case pinRequestFailed
    case timeout

    var userMessage: String {
        switch self {
        case .invalidURL:        return "Could not build the Plex authentication URL."
        case .pinRequestFailed:  return "Could not start Plex sign-in. Check your connection."
        case .timeout:           return "Plex sign-in timed out. Please try again."
        }
    }
}

// MARK: - PlexOAuthView

/// Presents the Plex pin-based OAuth flow in a sheet.
///
/// Steps displayed to the user:
/// 1. A loading indicator while the pin is requested.
/// 2. A browser opens automatically at `app.plex.tv/auth`. The user signs in.
/// 3. A polling indicator while the app waits for the token.
/// 4. On success, the sheet calls `onAuthenticated` and dismisses.
/// 5. On failure, an error message and retry button are shown.
///
/// Usage:
/// ```swift
/// PlexOAuthView { authToken in
///     Task { await authViewModel.loginPlex(authToken: authToken) }
/// }
/// ```
struct PlexOAuthView: View {

    // MARK: - Callback

    /// Called with the Plex auth token when the flow succeeds.
    let onAuthenticated: (String) -> Void

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @State private var oauthVM = PlexOAuthViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Plex branding
                VStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color(red: 0.9, green: 0.56, blue: 0.0))

                    Text("Sign in with Plex")
                        .font(.title2.bold())
                }

                // State-specific content
                Group {
                    switch oauthVM.state {
                    case .idle:
                        idleContent

                    case .requestingPin:
                        statusContent(
                            icon: nil,
                            message: "Starting Plex authentication…"
                        )

                    case .awaitingAuth:
                        statusContent(
                            icon: "safari",
                            message: "Complete sign-in in Safari, then return to this app."
                        )

                    case .polling:
                        statusContent(
                            icon: nil,
                            message: "Waiting for Plex authorisation…"
                        )

                    case .success:
                        statusContent(
                            icon: "checkmark.circle.fill",
                            message: "Signed in successfully."
                        )

                    case .failed(let message):
                        failureContent(message: message)

                    case .cancelled:
                        idleContent
                    }
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        oauthVM.cancel()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            oauthVM.start { token in
                onAuthenticated(token)
                dismiss()
            }
        }
    }

    // MARK: - Sub-Views

    @ViewBuilder
    private var idleContent: some View {
        VStack(spacing: 16) {
            Text("You'll be redirected to Plex to sign in to your account.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                oauthVM.start { token in
                    onAuthenticated(token)
                    dismiss()
                }
            } label: {
                Text("Continue with Plex")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.9, green: 0.56, blue: 0.0))
        }
    }

    @ViewBuilder
    private func statusContent(icon: String?, message: String) -> some View {
        VStack(spacing: 20) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(icon == "checkmark.circle.fill" ? AnyShapeStyle(.green) : AnyShapeStyle(.tint))
            } else {
                ProgressView()
                    .scaleEffect(1.3)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func failureContent(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                oauthVM.start { token in
                    onAuthenticated(token)
                    dismiss()
                }
            } label: {
                Text("Try Again")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Idle") {
    PlexOAuthView { _ in }
}
#endif
