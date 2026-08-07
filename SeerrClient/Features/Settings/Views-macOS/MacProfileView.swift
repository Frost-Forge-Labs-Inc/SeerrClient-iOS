// MacProfileView.swift
// SeerrClientMac
//
// macOS Profile pane (session/account). Appearance + About live in Settings{}.
// Reuses ProfileViewModel VERBATIM — sign-out goes through viewModel.signOut().

import SwiftUI

// MARK: - MacProfileView

/// macOS fork of the Profile tab: Form-based session/account UI.
/// Does not include Appearance or About (those belong in the Preferences window).
struct MacProfileView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var viewModel: ProfileViewModel?

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Profile")
        .task {
            guard viewModel == nil else { return }
            guard let client = appState.apiClient else { return }
            guard let server = appState.activeServer else { return }

            let vm = ProfileViewModel(apiClient: client, appState: appState, server: server)
            viewModel = vm
            vm.loadProfile()
        }
        .onDisappear {
            viewModel?.cancelAll()
        }
        .alert("Sign Out", isPresented: signOutDialogBinding) {
            if let viewModel {
                Button("Sign Out", role: .destructive) {
                    viewModel.signOut()
                }
                .disabled(viewModel.isSigningOut)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to sign in again to continue.")
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private func content(for viewModel: ProfileViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            loadingState

        case .loaded:
            loadedState(viewModel)

        case .error(let message):
            errorState(viewModel, message: message)
        }
    }

    // MARK: - Loaded

    private func loadedState(_ viewModel: ProfileViewModel) -> some View {
        Form {
            if let user = viewModel.user {
                ProfileHeaderSection(
                    user: user,
                    serverBaseURL: appState.activeServer?.baseURL ?? ""
                )
            } else {
                Section {
                    Text("Profile information is unavailable.")
                        .foregroundStyle(.secondary)
                }
            }

            if let server = appState.activeServer {
                activeServerSection(server: server, viewModel: viewModel)
            }

            RequestSummarySection(
                requestCounts: viewModel.requestCounts,
                isAdmin: viewModel.isAdmin
            )

            if let server = appState.activeServer {
                ServerInfoSection(server: server, serverStatus: viewModel.serverStatus)
            }

            dangerSection(viewModel)
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("profile.screen")
    }

    // MARK: - Loading

    private var loadingState: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    Circle()
                        .fill(Color.platformFill)
                        .frame(width: 80, height: 80)
                        .overlay { ShimmerView() }

                    VStack(alignment: .leading, spacing: 10) {
                        skeletonBar(width: 180, height: 20)
                        skeletonBar(width: 150, height: 14)
                        skeletonBar(width: 120, height: 14)
                        skeletonBar(width: 140, height: 12)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 6)
            }

            Section("Request Summary") {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.platformFill)
                            .frame(height: 82)
                            .overlay { ShimmerView() }
                    }
                }
            }

            Section("Server") {
                ForEach(0..<4, id: \.self) { _ in
                    skeletonBar(width: nil, height: 16)
                }
            }
        }
        .formStyle(.grouped)
        .disabled(true)
    }

    // MARK: - Error

    private func errorState(_ viewModel: ProfileViewModel, message: String) -> some View {
        ContentUnavailableView {
            Label("Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                viewModel.loadProfile()
            }
            .buttonStyle(.borderedProminent)

            Button("Back to Server List") {
                viewModel.returnToServerList()
            }
        }
    }

    // MARK: - Active Server

    private func activeServerSection(
        server: ServerConfiguration,
        viewModel: ProfileViewModel
    ) -> some View {
        Section {
            Button {
                viewModel.returnToServerList()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Switch Server / Account")
                            .font(.body.weight(.semibold))

                        Text(server.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityIdentifier("profile.switchServer")
            .buttonStyle(.plain)
        } header: {
            Text("Active Server")
        } footer: {
            Text("Return to the server list to choose another server or forget a saved sign-in.")
        }
    }

    // MARK: - Danger

    private func dangerSection(_ viewModel: ProfileViewModel) -> some View {
        Section("Danger Zone") {
            Button(role: .destructive) {
                viewModel.showSignOutConfirmation = true
            } label: {
                HStack {
                    Text("Sign Out")
                    Spacer()
                    if viewModel.isSigningOut {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(viewModel.isSigningOut)
        }
    }

    // MARK: - Dialog Bindings

    private var signOutDialogBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showSignOutConfirmation ?? false },
            set: { viewModel?.showSignOutConfirmation = $0 }
        )
    }

    // MARK: - Skeleton

    private func skeletonBar(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.platformFill)
            .frame(width: width, height: height)
            .overlay { ShimmerView() }
    }
}
