// ServerListView.swift
// SeerrClient
//
// Displays the list of configured Seerr servers. Entry point for first-time
// users (empty state with CTA) and for users who manage multiple servers.
// Selecting a server sets it as the active server in AppState.

import SwiftUI

// MARK: - ServerListView

/// Root view of the Server Setup flow.
///
/// Shows all saved `ServerConfiguration` entries in an inset-grouped list.
/// When no servers are configured, shows an illustrated empty state with an
/// "Add Server" call-to-action button.
///
/// Navigation:
/// - "Add" / "Add Server" → presents `AddServerView` as a sheet
/// - Tap server row → calls `appState.selectServer(_:)` and dismisses the setup flow
/// - Swipe leading → "Switch To" (sets default)
/// - Swipe trailing → "Delete" (destructive)
struct ServerListView: View {

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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddServerPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Server")
                }
            }
            .sheet(isPresented: $isAddServerPresented) {
                AddServerView(serverStore: serverStore) { savedServer, authMethods in
                    // After a server is saved, select it and kick off auth.
                    appState.selectServer(savedServer, authMethods: authMethods)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = ServerSetupViewModel(serverStore: serverStore)
                }
            }
        }
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
                    .padding(.horizontal, 40)
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
    }

    // MARK: - Populated List

    @ViewBuilder
    private var serverListContent: some View {
        List {
            ForEach(serverStore.servers) { server in
                ServerRowCell(
                    server: server,
                    isActive: appState.activeServer?.id == server.id
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.selectServer(server)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel?.deleteServer(server)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        serverStore.setDefault(id: server.id)
                    } label: {
                        Label("Switch To", systemImage: "checkmark.circle.fill")
                    }
                    .tint(.green)
                }
                .listRowBackground(
                    appState.activeServer?.id == server.id
                        ? Color.accentColor.opacity(0.08)
                        : Color(uiColor: .secondarySystemGroupedBackground)
                )
            }
            .onDelete { offsets in
                viewModel?.deleteServers(at: offsets)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - ServerRowCell

/// A single row in the server list.
///
/// Displays the backend type badge, display name, URL, active indicator,
/// and last-connected time.
private struct ServerRowCell: View {

    let server: ServerConfiguration
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Backend type icon.
            Image(systemName: server.backendType.symbolName)
                .font(.title3)
                .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 32, height: 32)

            // Name + URL stack.
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
            }

            Spacer()

            // Active indicator.
            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
            }

            // Backend type badge.
            Text(server.backendType.displayName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .foregroundStyle(.tint)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty State") {
    let store = ServerStore()
    let state = AppState(serverStore: store)
    return ServerListView()
        .environment(state)
        .environment(store)
}

#Preview("Populated") {
    @Previewable @State var store = ServerStore()
    let state = AppState(serverStore: store)

    let _ = {
        store.add(ServerConfiguration(
            displayName: "Home Jellyseerr",
            baseURL: "http://192.168.1.50:5055",
            backendType: .jellyseerr,
            isDefault: true,
            lastConnected: Date().addingTimeInterval(-3600)
        ))
        store.add(ServerConfiguration(
            displayName: "Family Server",
            baseURL: "https://media.example.com",
            backendType: .overseerr,
            lastConnected: Date().addingTimeInterval(-86400)
        ))
        state.selectServer(store.servers[0])
    }()

    ServerListView()
        .environment(state)
        .environment(store)
}
#endif
