// MacLoginView.swift
// SeerrClientMac
//
// macOS login card. Reuses AuthViewModel verbatim; desktop-centered layout.

import SwiftUI

// MARK: - MacLoginView

/// Authentication screen for a specific server on macOS.
///
/// Mirrors iOS `LoginView` view-model calls (availableAuthMethods, selectedMethod,
/// loginLocal / loginJellyfin / loginPlex, restoreSessionIfPossible) in a centered
/// fixed-width card suitable for a desktop window.
struct MacLoginView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState
    @Environment(ServerStore.self) private var serverStore

    // MARK: - State

    @State var viewModel: AuthViewModel
    @State private var showPlexOAuth = false

    // MARK: - Init

    init(
        server: ServerConfiguration,
        appState: AppState,
        serverStore: ServerStore
    ) {
        let capabilities = appState.activeServerCapabilities ?? server.resolvedCapabilities
        guard let client = appState.apiClient else {
            assertionFailure("MacLoginView: apiClient is nil — selectServer was not called")
            let tempClient = SeerrAPIClient(server: server, serverStore: serverStore)
            _viewModel = State(initialValue: AuthViewModel(
                server: server,
                serverCapabilities: capabilities,
                apiClient: tempClient,
                appState: appState,
                serverStore: serverStore
            ))
            return
        }
        _viewModel = State(initialValue: AuthViewModel(
            server: server,
            serverCapabilities: capabilities,
            apiClient: client,
            appState: appState,
            serverStore: serverStore
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    serverHeaderSection
                        .padding(.top, 20)
                        .padding(.bottom, 28)

                    if viewModel.availableAuthMethods.count > 1 {
                        authMethodPicker
                            .padding(.bottom, 24)
                    }

                    authFormSection
                        .padding(.bottom, 32)

                    if let error = viewModel.errorMessage {
                        errorBanner(message: error)
                            .padding(.bottom, 16)
                    }
                }
                .frame(maxWidth: 460)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .accessibilityIdentifier("login.screen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back to Servers") {
                        appState.returnToServerList()
                    }
                }
            }
            .overlay {
                if viewModel.isAuthenticating && !viewModel.isRestoringSession {
                    loadingOverlay
                }
            }
            .sheet(isPresented: $showPlexOAuth) {
                PlexOAuthView { token in
                    Task { await viewModel.loginPlex(authToken: token) }
                }
                .frame(width: 420, height: 460)
            }
            .task {
                await viewModel.restoreSessionIfPossible()
            }
        }
    }

    // MARK: - Server Header

    @ViewBuilder
    private var serverHeaderSection: some View {
        VStack(spacing: 10) {
            Image(systemName: viewModel.server.backendType.symbolName)
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.tint)

            Text(viewModel.server.displayName)
                .font(.title2.bold())
                .lineLimit(1)

            Text(URLNormalizer.displayHost(from: viewModel.server.baseURL))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(viewModel.server.backendType.displayName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .foregroundStyle(.tint)
        }
    }

    // MARK: - Auth Method Picker

    @ViewBuilder
    private var authMethodPicker: some View {
        Picker("Sign In With", selection: $viewModel.selectedMethod) {
            ForEach(viewModel.availableAuthMethods) { method in
                Text(method.displayName).tag(method)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedMethod) {
            viewModel.clearError()
        }
    }

    // MARK: - Auth Form Section

    @ViewBuilder
    private var authFormSection: some View {
        switch viewModel.selectedMethod {
        case .local:
            localLoginForm
        case .plex:
            plexLoginPanel
        case .jellyfin:
            jellyfinLoginForm
        case .apiKeyOnly, .none:
            EmptyView()
        }
    }

    // MARK: - Local Login Form

    @ViewBuilder
    private var localLoginForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("you@example.com", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        Color.platformSecondaryBackground,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        Color.platformSecondaryBackground,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }

            rememberMeToggle

            Button {
                Task { await viewModel.loginLocal() }
            } label: {
                Text("Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canSubmitLocal)
        }
    }

    // MARK: - Plex Login Panel

    @ViewBuilder
    private var plexLoginPanel: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(red: 0.9, green: 0.56, blue: 0.0))

                Text("Sign in with your Plex account to connect to this server.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 8)

            Button {
                showPlexOAuth = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                    Text("Sign in with Plex")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color(red: 0.9, green: 0.56, blue: 0.0))
            .disabled(viewModel.isAuthenticating)

            rememberMeToggle
        }
    }

    // MARK: - Jellyfin Login Form

    @ViewBuilder
    private var jellyfinLoginForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Jellyfin Server URL (optional)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(
                    "Leave blank to use server default",
                    text: $viewModel.jellyfinServerURL
                )
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    Color.platformSecondaryBackground,
                    in: RoundedRectangle(cornerRadius: 10)
                )

                Text("Only required if your Jellyfin instance is at a different address than this Seerr server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Jellyfin username", text: $viewModel.jellyfinUsername)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        Color.platformSecondaryBackground,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                SecureField("Password", text: $viewModel.jellyfinPassword)
                    .textContentType(.password)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        Color.platformSecondaryBackground,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }

            rememberMeToggle

            Button {
                Task { await viewModel.loginJellyfin() }
            } label: {
                Text("Sign In with Jellyfin")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canSubmitJellyfin)
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.body)
                .padding(.top, 1)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer()

            Button {
                viewModel.clearError()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Remember Me Toggle

    @ViewBuilder
    private var rememberMeToggle: some View {
        Toggle(isOn: $viewModel.rememberCredentials) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Remember me on this device")
                    .font(.subheadline)
                Text("Your credentials are stored securely in the Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.accentColor)
        .padding(.vertical, 4)
    }

    // MARK: - Loading Overlay

    @ViewBuilder
    private var loadingOverlay: some View {
        ZStack {
            Color.platformSystemBackground
                .opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Signing in…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
