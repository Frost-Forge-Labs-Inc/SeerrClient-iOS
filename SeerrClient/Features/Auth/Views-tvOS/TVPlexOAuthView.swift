// TVPlexOAuthView.swift
// SeerrClientTV (Octopus Explorer — tvOS)
//
// Interactive Plex sign-in for Apple TV — the last open Milestone 3 item.
//
// Why this differs from the iOS PlexOAuthView:
//   iOS bounces to Safari via `UIApplication.shared.open(app.plex.tv/auth#…)`
//   and lets the user sign in there. tvOS has no browser and no
//   `UIApplication.shared.open`, so we use Plex's *code-linking* flow instead —
//   the same one Plex's own tvOS app and other 10-foot clients use:
//
//   1. POST https://plex.tv/api/v2/pins  → { id, code }  (short, human-typable
//      code — we deliberately DO NOT pass `strong=true`, which returns a long
//      code unsuitable for on-screen manual entry).
//   2. Show the `code` large on the TV and tell the user to open
//      https://plex.tv/link on a phone/computer and enter it.
//   3. Poll GET https://plex.tv/api/v2/pins/{id} every 2s until `authToken` is
//      non-nil (or timeout / cancel).
//   4. Call `onAuthenticated(authToken)` — the caller feeds it to the SHARED
//      `AuthViewModel.loginPlex(authToken:)`, so ALL Seerr-side auth logic
//      (POST /auth/plex, session persistence, remember-me) is reused verbatim.
//      No auth business logic is forked onto tvOS.

import SwiftUI

// MARK: - Plex OAuth constants

private enum TVPlexOAuth {
    /// Plex API base URL.
    static let plexAPIBase = "https://plex.tv/api/v2"
    /// The web page the viewer visits on a second device to enter the code.
    static let linkURL = "https://plex.tv/link"
    /// Product name shown in the user's Plex "authorized devices" list.
    static let product = "Seerr Local Client (Apple TV)"
    /// Polling interval while waiting for the viewer to link the code.
    static let pollInterval: TimeInterval = 2.0
    /// Give up after this long so a walked-away session never polls forever.
    static let pollTimeout: TimeInterval = 300.0
    /// Consecutive transient network failures tolerated before the poll aborts.
    /// A single Wi-Fi blip mid-poll must not kill a 5-minute link window.
    static let maxTransientFailures = 5

    private static let clientIdentifierKey = "seerr.plex.clientIdentifier.tvos"

    /// A stable, PER-INSTALL client identifier. Plex binds authorized-device
    /// records to `X-Plex-Client-Identifier`, so a single app-wide constant would
    /// make every Apple TV look like the same Plex device — sign-ins from
    /// different installs would collide and could invalidate each other's tokens.
    /// Generated once and persisted so a device keeps a stable identity across
    /// launches. (The shipped iOS PlexOAuthView still uses a static constant — a
    /// tracked follow-up covers migrating it to this same scheme.)
    static var clientIdentifier: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: clientIdentifierKey), !existing.isEmpty {
            return existing
        }
        let generated = "seerr-tvos-\(UUID().uuidString)"
        defaults.set(generated, forKey: clientIdentifierKey)
        return generated
    }
}

// MARK: - Plex API model

/// The pin object returned by `POST/GET plex.tv/api/v2/pins`.
private struct TVPlexPin: Decodable {
    let id: Int
    let code: String
    let authToken: String?
}

// MARK: - TVPlexOAuthViewModel

/// Drives the pin/link/poll state machine for the tvOS Plex flow.
@Observable
@MainActor
private final class TVPlexOAuthViewModel {

    enum State: Equatable {
        case requestingPin
        case awaitingLink(code: String)
        case success
        case failed(String)
    }

    private(set) var state: State = .requestingPin

    /// Persisted per-install identifier (see TVPlexOAuth.clientIdentifier). Read
    /// once so every request in a flow presents the same device identity.
    private let clientID = TVPlexOAuth.clientIdentifier
    private var pollTask: Task<Void, Never>?

    /// Begins (or restarts) the flow. Safe to call repeatedly — cancels any
    /// in-flight poll first so "Try Again" never leaves two loops running.
    func start(onSuccess: @escaping (String) -> Void) {
        pollTask?.cancel()
        state = .requestingPin

        pollTask = Task {
            do {
                let pin = try await requestPin()
                state = .awaitingLink(code: pin.code)
                try await pollForToken(pinID: pin.id, onSuccess: onSuccess)
            } catch {
                // A cancel or restart cancels the in-flight URLSession request,
                // which surfaces as URLError(.cancelled) — NOT CancellationError —
                // so key off Task.isCancelled to cover both. Never clobber a freshly
                // restarted flow's state with the superseded task's failure.
                if Task.isCancelled { return }
                if let plexError = error as? TVPlexOAuthError {
                    state = .failed(plexError.userMessage)
                } else {
                    state = .failed("Plex sign-in failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Stops any in-flight polling (called when the flow is dismissed).
    func cancel() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Step 1: request pin

    private func requestPin() async throws -> TVPlexPin {
        // No `strong=true`: we want the short, human-typable link code.
        guard let url = URL(string: "\(TVPlexOAuth.plexAPIBase)/pins") else {
            throw TVPlexOAuthError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue(TVPlexOAuth.product, forHTTPHeaderField: "X-Plex-Product")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
            throw TVPlexOAuthError.pinRequestFailed
        }

        // Plex v2 pins JSON is camelCase (id/code/authToken) — no snake_case
        // conversion needed; a plain decoder keeps intent clear.
        return try JSONDecoder().decode(TVPlexPin.self, from: data)
    }

    // MARK: - Step 2: poll for token

    private func pollForToken(pinID: Int, onSuccess: @escaping (String) -> Void) async throws {
        guard let url = URL(string: "\(TVPlexOAuth.plexAPIBase)/pins/\(pinID)") else {
            throw TVPlexOAuthError.invalidURL
        }
        let deadline = Date().addingTimeInterval(TVPlexOAuth.pollTimeout)
        var transientFailures = 0

        while Date() < deadline {
            try Task.checkCancellation()

            do {
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
                request.setValue(TVPlexOAuth.product, forHTTPHeaderField: "X-Plex-Product")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw TVPlexOAuthError.pinRequestFailed
                }
                // 404/410: Plex expired the pin before the viewer entered the code.
                // Surface a clear "expired" message instead of a raw decode error.
                if http.statusCode == 404 || http.statusCode == 410 {
                    throw TVPlexOAuthError.pinExpired
                }
                guard http.statusCode == 200 else {
                    // Unexpected server status — treat as a transient hiccup.
                    throw URLError(.badServerResponse)
                }

                let pin = try JSONDecoder().decode(TVPlexPin.self, from: data)
                transientFailures = 0

                // Re-check before delivering: a continuation already enqueued when a
                // restart cancelled this task must not fire a second onAuthenticated.
                try Task.checkCancellation()
                if let token = pin.authToken, !token.isEmpty {
                    state = .success
                    onSuccess(token)
                    return
                }
            } catch let error as TVPlexOAuthError {
                throw error                      // controlled failure — abort now
            } catch is CancellationError {
                throw CancellationError()        // propagate cancellation cleanly
            } catch {
                if Task.isCancelled { throw CancellationError() }
                // A Wi-Fi blip or decode glitch mid-window: tolerate a few in a row
                // rather than killing a 5-minute link session on one bad tick.
                transientFailures += 1
                if transientFailures > TVPlexOAuth.maxTransientFailures {
                    throw TVPlexOAuthError.pinRequestFailed
                }
            }

            try await Task.sleep(nanoseconds: UInt64(TVPlexOAuth.pollInterval * 1_000_000_000))
        }

        throw TVPlexOAuthError.timeout
    }
}

// MARK: - TVPlexOAuthError

private enum TVPlexOAuthError: Error {
    case invalidURL
    case pinRequestFailed
    case pinExpired
    case timeout

    var userMessage: String {
        switch self {
        case .invalidURL:       return "Could not build the Plex authentication URL."
        case .pinRequestFailed: return "Could not start Plex sign-in. Check this device's connection and try again."
        case .pinExpired:       return "The Plex code expired before it was entered. Please try again for a new code."
        case .timeout:          return "Plex sign-in timed out before the code was entered. Please try again."
        }
    }
}

// MARK: - TVPlexOAuthView

/// Full-screen tvOS Plex link-code flow. Reuses the shared Seerr auth path via
/// the `onAuthenticated` callback (see file header). Present it from a login
/// screen with `.fullScreenCover` and forward the token to
/// `AuthViewModel.loginPlex(authToken:)`.
struct TVPlexOAuthView: View {

    /// Called with the Plex `authToken` once the viewer links the code.
    let onAuthenticated: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TVPlexOAuthViewModel()

    private let plexOrange = Color(red: 0.9, green: 0.56, blue: 0.0)

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.067, blue: 0.11).ignoresSafeArea()

            VStack(spacing: 40) {
                header

                switch viewModel.state {
                case .requestingPin:
                    statusPanel(message: "Starting Plex sign-in…", showsSpinner: true)
                case .awaitingLink(let code):
                    linkInstructions(code: code)
                case .success:
                    statusPanel(message: "Signed in with Plex.", systemImage: "checkmark.circle.fill", tint: .green)
                case .failed(let message):
                    failurePanel(message: message)
                }

                Button("Cancel") {
                    viewModel.cancel()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .font(.system(size: 27, weight: .semibold))
            }
            .padding(80)
            .frame(maxWidth: 1200)
        }
        .accessibilityIdentifier("tvos.plex.oauth.screen")
        .task {
            viewModel.start { token in
                onAuthenticated(token)
                dismiss()
            }
        }
        // The poll loop is an UNSTRUCTURED Task, so `.task` auto-cancellation does
        // not reach it. On tvOS the Menu/Back button dismisses a fullScreenCover
        // without hitting the Cancel button, which would otherwise leave an
        // invisible poll running (and able to sign the user in from a screen they
        // backed out of). Cancel explicitly on teardown.
        .onDisappear { viewModel.cancel() }
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 76))
                .foregroundStyle(plexOrange)
            Text("Sign In with Plex")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func linkInstructions(code: String) -> some View {
        VStack(spacing: 30) {
            Text("On your phone or computer, go to")
                .font(.system(size: 31, weight: .regular))
                .foregroundStyle(.white.opacity(0.72))

            Text(TVPlexOAuth.linkURL.replacingOccurrences(of: "https://", with: ""))
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)

            Text("and enter this code")
                .font(.system(size: 31, weight: .regular))
                .foregroundStyle(.white.opacity(0.72))

            // The link code, large and spaced so it reads from across a room.
            Text(code)
                .font(.system(size: 92, weight: .heavy, design: .monospaced))
                .tracking(14)
                .foregroundStyle(plexOrange)
                .padding(.horizontal, 56)
                .padding(.vertical, 30)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
                .accessibilityLabel("Plex link code")
                .accessibilityValue(code.map { String($0) }.joined(separator: " "))

            HStack(spacing: 16) {
                ProgressView()
                Text("Waiting for you to enter the code…")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .padding(.top, 8)
        }
    }

    private func statusPanel(
        message: String,
        systemImage: String? = nil,
        tint: Color = .white,
        showsSpinner: Bool = false
    ) -> some View {
        VStack(spacing: 24) {
            if showsSpinner {
                ProgressView().scaleEffect(1.8)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(message)
                .font(.system(size: 31, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
        }
        .frame(minHeight: 320)
    }

    private func failurePanel(message: String) -> some View {
        VStack(spacing: 28) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 29, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 840)
            Button {
                viewModel.start { token in
                    onAuthenticated(token)
                    dismiss()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 29, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .tint(plexOrange)
        }
        .frame(minHeight: 320)
    }
}
