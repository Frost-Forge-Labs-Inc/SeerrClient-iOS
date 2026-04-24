// LoginView.swift
// SeerrClient
//
// Authentication screen. Shows the active server header, an auth method picker
// (segmented tabs, only for enabled methods), and the appropriate form for the
// selected method. Presented when a server is configured but no session exists.

import SwiftUI

// MARK: - LoginView

/// Authentication screen for a specific server.
///
/// Reads the available auth methods from `AuthViewModel.availableAuthMethods`
/// and renders only the relevant tabs. Supports local, Plex, and Jellyfin login.
///
/// States:
/// - **Idle** — form ready for input
/// - **Authenticating** — loading overlay obscures the form
/// - **Error** — inline banner shown; form remains editable
/// - **Authenticated** — `AppState` is updated; this view dismisses
struct LoginView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState
    @Environment(ServerStore.self) private var serverStore

    // MARK: - State

    @State var viewModel: AuthViewModel

    /// Controls whether the Plex OAuth sheet is presented.
    @State private var showPlexOAuth = false

    // MARK: - Init

    /// Creates a `LoginView` for the given server using the active server's
    /// cached capability snapshot.
    ///
    /// - Parameters:
    ///   - server: The server configuration to authenticate against.
    ///   - appState: Shared application state.
    ///   - serverStore: Shared server store.
    init(
        server: ServerConfiguration,
        appState: AppState,
        serverStore: ServerStore
    ) {
        let capabilities = appState.activeServerCapabilities ?? server.resolvedCapabilities
        // `apiClient` is guaranteed non-nil here because `AppState.selectServer`
        // always creates one. Assert in DEBUG, fall back gracefully in release.
        guard let client = appState.apiClient else {
            assertionFailure("LoginView: apiClient is nil — selectServer was not called")
            // Create a temporary client so the view can render without crashing.
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

                    // Error banner
                    if let error = viewModel.errorMessage {
                        errorBanner(message: error)
                            .padding(.bottom, 16)
                    }
                }
                .padding(.horizontal)
            }
            .accessibilityIdentifier("login.screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back to Servers") {
                        appState.returnToServerList()
                    }
                    .font(.subheadline)
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
            }
            .task {
                // Attempt to restore an existing session on first appear.
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

            // Backend type badge
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
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(
                        Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .padding(12)
                    .background(
                        Color(uiColor: .secondarySystemBackground),
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
            // Plex branding area
            VStack(spacing: 12) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(red: 0.9, green: 0.56, blue: 0.0)) // Plex orange

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
                    Text("Continue with Plex")
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
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(
                    Color(uiColor: .secondarySystemBackground),
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
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(
                        Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                SecureField("Password", text: $viewModel.jellyfinPassword)
                    .textContentType(.password)
                    .padding(12)
                    .background(
                        Color(uiColor: .secondarySystemBackground),
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
        }
        .padding(14)
        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Remember Me Toggle

    /// Shared "Remember me" toggle shown in every login form.
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
            Color(uiColor: .systemBackground)
                .opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                Text("Signing in…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
@MainActor
private func makeLoginPreview(server: ServerConfiguration) -> some View {
    let store = ServerStore()
    let appState = AppState(serverStore: store)
    appState.selectServer(server)

    return LoginView(
        server: server,
        appState: appState,
        serverStore: store
    )
    .environment(appState)
    .environment(store)
}

private func makeLocalLoginPreviewServer() -> ServerConfiguration {
    ServerConfiguration(
        displayName: "Local Login",
        baseURL: "http://192.168.1.50:5055",
        backendType: .overseerr,
        capabilities: ServerCapabilities(
            backendType: .overseerr,
            publicSettings: PublicSettingsNormalized(
                initialized: true,
                applicationTitle: "Local Login",
                localLoginEnabled: true,
                newPlexLoginEnabled: true,
                mediaServerLoginEnabled: true,
                mediaServerKind: .plex
            )
        )
    )
}

private func makePlexOnlyPreviewServer() -> ServerConfiguration {
    ServerConfiguration(
        displayName: "Plex Server",
        baseURL: "http://192.168.1.100:5055",
        backendType: .overseerr,
        capabilities: ServerCapabilities(
            backendType: .overseerr,
            publicSettings: PublicSettingsNormalized(
                initialized: true,
                applicationTitle: "Plex Server",
                localLoginEnabled: false,
                newPlexLoginEnabled: true,
                mediaServerLoginEnabled: true,
                mediaServerKind: .plex
            )
        )
    )
}

private func makeJellyfinPreviewServer() -> ServerConfiguration {
    ServerConfiguration(
        displayName: "Jellyseerr",
        baseURL: "http://192.168.1.50:5055",
        backendType: .jellyseerr,
        capabilities: ServerCapabilities(
            backendType: .jellyseerr,
            publicSettings: PublicSettingsNormalized(
                initialized: true,
                applicationTitle: "Jellyseerr",
                localLoginEnabled: true,
                newPlexLoginEnabled: true,
                mediaServerLoginEnabled: true,
                mediaServerKind: .jellyfin,
                jellyfinForgotPasswordURL: "http://192.168.1.50:8096/web/#/forgotpassword"
            )
        )
    )
}

#Preview("Local Login") {
    makeLoginPreview(server: makeLocalLoginPreviewServer())
}

#Preview("Plex Only") {
    makeLoginPreview(server: makePlexOnlyPreviewServer())
}

#Preview("Jellyfin") {
    makeLoginPreview(server: makeJellyfinPreviewServer())
}
#endif
