// ProfileView.swift
// SeerrClient
//
// Main Profile + Settings screen shown in the fourth tab.

import SwiftUI

// MARK: - ProfileView

struct ProfileView: View {

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
            }
        }
        .navigationTitle("Profile")
        .preferredColorScheme(viewModel?.selectedTheme.colorScheme)
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
                .disabled(viewModel.isSigningOut || viewModel.isDisconnecting)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to sign in again to continue.")
        }
        .alert("Disconnect Server", isPresented: disconnectDialogBinding) {
            if let viewModel {
                Button("Disconnect", role: .destructive) {
                    viewModel.disconnectServer()
                }
                .disabled(viewModel.isSigningOut || viewModel.isDisconnecting)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the current server selection and returns to setup.")
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
        List {
            if let user = viewModel.user {
                ProfileHeaderSection(user: user, serverBaseURL: appState.activeServer?.baseURL ?? "")
            } else {
                Section {
                    Text("Profile information is unavailable.")
                        .foregroundStyle(.secondary)
                }
            }

            RequestSummarySection(requestCounts: viewModel.requestCounts, isAdmin: viewModel.isAdmin)

            AppearanceSection(
                selectedTheme: Binding(
                    get: { viewModel.selectedTheme },
                    set: { viewModel.selectedTheme = $0 }
                )
            )

            if let server = appState.activeServer {
                ServerInfoSection(server: server, serverStatus: viewModel.serverStatus)
            }

            AboutSection()
            dangerSection(viewModel)
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    Circle()
                        .fill(Color(.systemGray5))
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
                            .fill(Color(.systemGray5))
                            .frame(height: 82)
                            .overlay { ShimmerView() }
                    }
                }
            }

            Section("Appearance") {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(height: 32)
                    .overlay { ShimmerView() }
            }

            Section("Server") {
                ForEach(0..<4, id: \.self) { _ in
                    skeletonBar(width: nil, height: 16)
                }
            }

            Section("About") {
                skeletonBar(width: 160, height: 16)
                skeletonBar(width: 180, height: 16)
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
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
                            .tint(.red)
                    }
                }
            }
            .disabled(viewModel.isSigningOut || viewModel.isDisconnecting)

            Button(role: .destructive) {
                viewModel.showDisconnectConfirmation = true
            } label: {
                HStack {
                    Text("Disconnect Server")
                    Spacer()
                    if viewModel.isDisconnecting {
                        ProgressView()
                            .tint(.red)
                    }
                }
            }
            .disabled(viewModel.isSigningOut || viewModel.isDisconnecting)
        }
    }

    // MARK: - Dialog Bindings

    private var signOutDialogBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showSignOutConfirmation ?? false },
            set: { viewModel?.showSignOutConfirmation = $0 }
        )
    }

    private var disconnectDialogBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showDisconnectConfirmation ?? false },
            set: { viewModel?.showDisconnectConfirmation = $0 }
        )
    }

    // MARK: - Skeleton

    private func skeletonBar(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .overlay { ShimmerView() }
    }
}
