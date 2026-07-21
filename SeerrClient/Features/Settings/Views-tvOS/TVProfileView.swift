// TVProfileView.swift
// SeerrClientTV (Octopus Explorer)

import SwiftUI

struct TVProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: ProfileViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                TVLoadingStateView(title: "Profile")
            }
        }
        .accessibilityIdentifier("tvos.profile.screen")
        .task {
            guard viewModel == nil else { return }
            guard let client = appState.apiClient, let server = appState.activeServer else { return }
            let viewModel = ProfileViewModel(apiClient: client, appState: appState, server: server)
            self.viewModel = viewModel
            viewModel.loadProfile()
        }
        .onDisappear { if viewModel?.isSigningOut == false { viewModel?.cancelAll() } }
    }

    @ViewBuilder
    private func content(for viewModel: ProfileViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            TVLoadingStateView(title: "Profile")
        case .loaded:
            loaded(viewModel)
        case .error(let message):
            TVMessageStateView(title: "Profile", message: message, systemImage: "exclamationmark.triangle", actionTitle: "Try Again") {
                viewModel.loadProfile()
            }
        }
    }

    private func loaded(_ viewModel: ProfileViewModel) -> some View {
        TVScreenScaffold(title: displayName(viewModel), subtitle: appState.activeServer?.displayName) {
            VStack(alignment: .leading, spacing: 34) {
                HStack(spacing: 18) {
                    if let counts = viewModel.requestCounts {
                        TVInfoPill(title: "Total Requests", value: "\(counts.total)")
                        TVInfoPill(title: "Pending", value: "\(counts.pending)")
                        TVInfoPill(title: "Approved", value: "\(counts.approved)")
                    } else {
                        TVInfoPill(title: "Requests", value: "\(viewModel.user?.requestCount ?? 0)")
                    }
                    TVInfoPill(title: "Role", value: viewModel.isAdmin ? "Admin" : "User")
                }

                if let status = viewModel.serverStatus {
                    HStack(spacing: 18) {
                        TVInfoPill(title: "Backend", value: appState.activeServer?.backendType.displayName ?? "Server")
                        TVInfoPill(title: "Version", value: status.version)
                        TVInfoPill(title: "Update", value: status.updateAvailable == true ? "Available" : "Current")
                    }
                }

                HStack(spacing: 18) {
                    Button("Refresh") {
                        Task { await viewModel.refresh() }
                    }
                    .buttonStyle(.bordered)

                    Button("Sign Out", role: .destructive) {
                        viewModel.showSignOutConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSigningOut)
                }

                Text("Server switching and detailed account settings stay on iPhone, iPad, and web for v1.")
                    .font(.system(size: 23))
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
        .alert("Sign Out?", isPresented: Binding(
            get: { viewModel.showSignOutConfirmation },
            set: { viewModel.showSignOutConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                viewModel.signOut()
            }
        } message: {
            Text("You will need to sign in again before using Octopus Explorer on Apple TV.")
        }
    }

    private func displayName(_ viewModel: ProfileViewModel) -> String {
        let user = viewModel.user ?? appState.currentUser
        return user?.displayName ?? user?.username ?? user?.plexUsername ?? "Profile"
    }
}
