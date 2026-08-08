// MacServerListView.swift
// SeerrClientMac
//
// macOS server list card. Reuses ServerSetupViewModel verbatim.

import SwiftUI

// MARK: - MacServerListView

/// Root view of the macOS Server Setup flow.
///
/// Mirrors iOS `ServerListView` behaviour (list/select/add/delete/forget) in a
/// centered desktop card layout.
struct MacServerListView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState
    @Environment(ServerStore.self) private var serverStore

    // MARK: - State

    @State private var viewModel: ServerSetupViewModel?
    @State private var isAddServerPresented = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if serverStore.servers.isEmpty {
                    emptyStateView
                } else {
                    serverListContent
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddServerPresented = true
                    } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                    .accessibilityLabel("Add Server")
                }
            }
            .sheet(isPresented: $isAddServerPresented) {
                MacAddServerView(serverStore: serverStore) { savedServer in
                    appState.selectServer(savedServer)
                }
                .frame(minWidth: 480, minHeight: 420)
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = ServerSetupViewModel(serverStore: serverStore)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Servers Added")
                    .font(.title2.bold())

                Text("Add your Overseerr, Jellyseerr, or Seerr server to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            Button {
                isAddServerPresented = true
            } label: {
                Label("Add Server", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("serverList.screen")
    }

    // MARK: - Populated List

    @ViewBuilder
    private var serverListContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(serverStore.servers) { server in
                    let isLastUsed = serverStore.defaultServerID == server.id
                    let hasSavedSignIn = serverStore.hasSavedSignIn(for: server)

                    MacServerRowCell(
                        server: server,
                        isLastUsed: isLastUsed,
                        hasSavedSignIn: hasSavedSignIn,
                        onSelect: { appState.selectServer(server) },
                        onForget: { viewModel?.forgetSavedSignIn(for: server) },
                        onDelete: { viewModel?.deleteServer(server) }
                    )
                    .accessibilityIdentifier("serverList.select.\(server.id.uuidString)")
                }
            }
            .frame(maxWidth: 460)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityIdentifier("serverList.screen")
    }
}

// MARK: - MacServerRowCell

private struct MacServerRowCell: View {

    let server: ServerConfiguration
    let isLastUsed: Bool
    let hasSavedSignIn: Bool
    let onSelect: () -> Void
    let onForget: () -> Void
    let onDelete: () -> Void

    private var statusText: String {
        switch (isLastUsed, hasSavedSignIn) {
        case (true, true):
            return "Last used · Saved sign-in"
        case (true, false):
            return "Last used · Requires sign-in"
        case (false, true):
            return "Saved sign-in"
        case (false, false):
            return "Requires sign-in"
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: server.backendType.symbolName)
                    .font(.title3)
                    .foregroundStyle(isLastUsed ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.displayName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    Text(URLNormalizer.displayHost(from: server.baseURL))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let lastConnected = server.lastConnected {
                        Text("Last connected \(lastConnected.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(statusText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(hasSavedSignIn ? .green : .secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    if isLastUsed {
                        Text("Last Used")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.14), in: Capsule())
                            .foregroundStyle(.green)
                    }

                    Text(server.backendType.displayName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(.tint)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                isLastUsed
                    ? Color.accentColor.opacity(0.08)
                    : Color.platformSecondaryGroupedBackground,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if hasSavedSignIn {
                Button {
                    onForget()
                } label: {
                    Label("Forget Sign-In", systemImage: "person.crop.circle.badge.xmark")
                }
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty State") {
    let store = ServerStore()
    let state = AppState(serverStore: store)
    MacServerListView()
        .environment(state)
        .environment(store)
}
#endif
