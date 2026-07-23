// TVLoginView.swift
// SeerrClientTV (Octopus Explorer)

import SwiftUI

struct TVLoginView: View {
    @Environment(AppState.self) private var appState
    @Environment(ServerStore.self) private var serverStore

    @State private var viewModel: AuthViewModel?
    @State private var didStartRestore = false
    /// Presents the tvOS Plex link-code OAuth flow.
    @State private var showPlexOAuth = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                TVLoadingStateView(title: "Sign In")
            }
        }
        .task {
            guard !didStartRestore else { return }
            guard let server = appState.activeServer else { return }
            let capabilities = appState.activeServerCapabilities ?? server.resolvedCapabilities
            let client = appState.apiClient ?? SeerrAPIClient(server: server, serverStore: serverStore)
            let vm = AuthViewModel(
                server: server,
                serverCapabilities: capabilities,
                apiClient: client,
                appState: appState,
                serverStore: serverStore
            )
            viewModel = vm
            didStartRestore = true
            await vm.restoreSessionIfPossible()
        }
        .fullScreenCover(isPresented: $showPlexOAuth) {
            // The token is handed to the SHARED AuthViewModel.loginPlex — no
            // Seerr-side auth logic is duplicated for tvOS. On success the view
            // model flips AppState to the main interface, tearing down this
            // login screen (and the cover) automatically.
            TVPlexOAuthView { authToken in
                Task { await viewModel?.loginPlex(authToken: authToken) }
            }
        }
    }

    private func content(_ viewModel: AuthViewModel) -> some View {
        TVScreenScaffold(title: "Sign In", subtitle: viewModel.server.displayName) {
            HStack(alignment: .top, spacing: 50) {
                serverSummary(viewModel)
                    .frame(width: 560, alignment: .topLeading)

                if viewModel.isRestoringSession {
                    restoringPanel
                        .frame(maxWidth: 900, alignment: .topLeading)
                } else {
                    loginPanel(viewModel)
                        .frame(maxWidth: 900, alignment: .topLeading)
                }
            }
        }
    }

    private func serverSummary(_ viewModel: AuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: viewModel.server.backendType.symbolName)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.server.displayName)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(URLNormalizer.displayHost(from: viewModel.server.baseURL))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Text(viewModel.server.backendType.displayName)
                Text(viewModel.serverCapabilities.mediaServerKind.displayName)
            }
            .font(.system(size: 20, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12), in: Capsule())
            .foregroundStyle(.white.opacity(0.82))

            Button {
                appState.returnToServerList()
            } label: {
                Label("Switch Server", systemImage: "server.rack")
                    .font(.system(size: 25, weight: .semibold))
            }
            .buttonStyle(.bordered)
        }
        .padding(34)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }

    private var restoringPanel: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.8)
            Text("Checking saved sign-in")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)
            Text("If there is no remembered session, the sign-in options will appear automatically.")
                .font(.system(size: 25))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 760)
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }

    private func loginPanel(_ viewModel: AuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            if viewModel.availableAuthMethods.count > 1 {
                authMethodRow(viewModel)
            }

            switch viewModel.selectedMethod {
            case .local:
                localForm(viewModel)
            case .jellyfin:
                jellyfinForm(viewModel)
            case .plex:
                plexPanel(viewModel)
            case .apiKeyOnly, .none:
                unsupportedPanel(title: "No sign-in method", message: "This server did not advertise a supported user sign-in method.")
            }

            if let message = viewModel.errorMessage {
                errorBanner(message: message, viewModel: viewModel)
            }
        }
        .padding(34)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }

    private func authMethodRow(_ viewModel: AuthViewModel) -> some View {
        HStack(spacing: 14) {
            ForEach(viewModel.availableAuthMethods) { method in
                Button {
                    viewModel.selectedMethod = method
                    viewModel.clearError()
                } label: {
                    Label(method.displayName, systemImage: method.symbolName)
                        .font(.system(size: 25, weight: .bold))
                }
                .buttonStyle(.bordered)
                .tint(viewModel.selectedMethod == method ? .accentColor : .white.opacity(0.25))
            }
        }
    }

    private func localForm(_ viewModel: AuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Local Account")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)

            TVLabeledTextField(
                title: "Email",
                placeholder: "you@example.com",
                text: Binding(
                    get: { viewModel.email },
                    set: { viewModel.email = $0 }
                )
            )

            TVLabeledSecureField(
                title: "Password",
                text: Binding(
                    get: { viewModel.password },
                    set: { viewModel.password = $0 }
                )
            )

            rememberButton(viewModel)

            Button {
                Task { await viewModel.loginLocal() }
            } label: {
                if viewModel.isAuthenticating {
                    HStack {
                        ProgressView()
                        Text("Signing In")
                    }
                    .font(.system(size: 29, weight: .bold))
                } else {
                    Label("Sign In", systemImage: "person.fill")
                        .font(.system(size: 29, weight: .bold))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmitLocal)
        }
    }

    private func jellyfinForm(_ viewModel: AuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Jellyfin Account")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)

            TVLabeledTextField(
                title: "Jellyfin Server URL (optional)",
                placeholder: "Leave blank to use server default",
                text: Binding(
                    get: { viewModel.jellyfinServerURL },
                    set: { viewModel.jellyfinServerURL = $0 }
                )
            )

            TVLabeledTextField(
                title: "Username",
                placeholder: "Jellyfin username",
                text: Binding(
                    get: { viewModel.jellyfinUsername },
                    set: { viewModel.jellyfinUsername = $0 }
                )
            )

            TVLabeledSecureField(
                title: "Password",
                text: Binding(
                    get: { viewModel.jellyfinPassword },
                    set: { viewModel.jellyfinPassword = $0 }
                )
            )

            rememberButton(viewModel)

            Button {
                Task { await viewModel.loginJellyfin() }
            } label: {
                if viewModel.isAuthenticating {
                    HStack {
                        ProgressView()
                        Text("Signing In")
                    }
                    .font(.system(size: 29, weight: .bold))
                } else {
                    Label("Sign In with Jellyfin", systemImage: "server.rack")
                        .font(.system(size: 29, weight: .bold))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmitJellyfin)
        }
    }

    private func plexPanel(_ viewModel: AuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Plex Sign-In")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)
            Text("Sign in with your Plex account using a linking code. Select Continue with Plex, then enter the code shown here at plex.tv/link on your phone or computer.")
                .font(.system(size: 27))
                .foregroundStyle(.white.opacity(0.68))
                .lineSpacing(5)
                .frame(maxWidth: 780, alignment: .leading)
            rememberButton(viewModel)
            Button {
                viewModel.clearError()
                showPlexOAuth = true
            } label: {
                if viewModel.isAuthenticating {
                    HStack {
                        ProgressView()
                        Text("Signing In")
                    }
                    .font(.system(size: 29, weight: .bold))
                } else {
                    Label("Continue with Plex", systemImage: "play.rectangle.fill")
                        .font(.system(size: 29, weight: .bold))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.9, green: 0.56, blue: 0.0))
            .disabled(viewModel.isAuthenticating)

            Button {
                appState.returnToServerList()
            } label: {
                Label("Back to Servers", systemImage: "server.rack")
                    .font(.system(size: 27, weight: .bold))
            }
            .buttonStyle(.bordered)
        }
    }

    private func unsupportedPanel(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 27))
                .foregroundStyle(.white.opacity(0.68))
                .frame(maxWidth: 780, alignment: .leading)
        }
    }

    private func rememberButton(_ viewModel: AuthViewModel) -> some View {
        Button {
            viewModel.rememberCredentials.toggle()
        } label: {
            Label(
                viewModel.rememberCredentials ? "Remember Sign-In" : "Do Not Remember",
                systemImage: viewModel.rememberCredentials ? "checkmark.circle.fill" : "circle"
            )
            .font(.system(size: 24, weight: .semibold))
        }
        .buttonStyle(.bordered)
        .tint(viewModel.rememberCredentials ? .accentColor : .white.opacity(0.25))
    }

    private func errorBanner(message: String, viewModel: AuthViewModel) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                viewModel.clearError()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }
}

private struct TVLabeledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white.opacity(0.56))
            TextField(placeholder, text: $text)
                .font(.system(size: 29, weight: .medium))
                .textFieldStyle(.plain)
                .padding(22)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
        }
    }
}

private struct TVLabeledSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white.opacity(0.56))
            SecureField("Password", text: $text)
                .font(.system(size: 29, weight: .medium))
                .textFieldStyle(.plain)
                .padding(22)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
        }
    }
}
