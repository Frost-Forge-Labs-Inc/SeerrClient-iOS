// TVServerSetupView.swift
// SeerrClientTV (Octopus Explorer)

import SwiftUI

struct TVServerSetupView: View {
    @Environment(AppState.self) private var appState
    @Environment(ServerStore.self) private var serverStore

    @State private var viewModel: ServerSetupViewModel?
    @State private var isAddingServer = false
    /// Seeds initial remote focus onto the Server URL field when the add-server
    /// panel appears, so the Siri Remote lands on a reachable control.
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                TVLoadingStateView(title: "Servers")
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ServerSetupViewModel(serverStore: serverStore)
                isAddingServer = serverStore.servers.isEmpty
            }
        }
    }

    private func content(_ viewModel: ServerSetupViewModel) -> some View {
        TVScreenScaffold(title: "Servers", subtitle: "Connect Octopus Explorer to your media request server") {
            HStack(alignment: .top, spacing: 48) {
                savedServers(viewModel)
                    .frame(width: 660, alignment: .topLeading)

                if isAddingServer || serverStore.servers.isEmpty {
                    addServerPanel(viewModel)
                        .frame(maxWidth: 920, alignment: .topLeading)
                } else {
                    introPanel
                        .frame(maxWidth: 920, alignment: .topLeading)
                }
            }
        }
        .confirmationDialog(
            "Trust Certificate for \(viewModel.certTrustHostname)?",
            isPresented: Binding(
                get: { viewModel.showCertTrustAlert },
                set: { viewModel.showCertTrustAlert = $0 }
            ),
            titleVisibility: .visible
        ) {
            Button("Trust Certificate") {
                Task { await viewModel.retryWithCertificateTrust() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.showCertTrustAlert = false
            }
        } message: {
            Text("Only trust this certificate if you control this server or recognize it.")
        }
    }

    private func savedServers(_ viewModel: ServerSetupViewModel) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Saved Servers")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                // Only show "+" when the add panel is NOT already showing. The panel is
                // shown when `isAddingServer || servers.isEmpty` (see content()), so the
                // "+" must be hidden in BOTH cases — otherwise (e.g. after deleting the
                // last server) the panel is force-shown while "+" remains an invisible
                // no-op, re-creating the focus trap this fix closes.
                if !isAddingServer && !serverStore.servers.isEmpty {
                    Button {
                        isAddingServer = true
                        viewModel.resetDetection()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Add Server")
                }
            }

            if serverStore.servers.isEmpty {
                TVEmptyServerList()
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(serverStore.servers) { server in
                        Button {
                            appState.selectServer(server)
                        } label: {
                            TVServerRow(
                                server: server,
                                isDefault: serverStore.defaultServerID == server.id,
                                hasSavedSignIn: serverStore.hasSavedSignIn(for: server)
                            )
                        }
                        .buttonStyle(.card)
                        .contextMenu {
                            if serverStore.hasSavedSignIn(for: server) {
                                Button("Forget Sign-In") {
                                    viewModel.forgetSavedSignIn(for: server)
                                }
                            }
                            Button("Remove", role: .destructive) {
                                viewModel.deleteServer(server)
                            }
                        }
                    }
                }
            }
        }
    }

    private var introPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 74, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text("Choose a server")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)
            Text("Select a saved server to restore a session or sign in. Add another server if you use more than one Seerr-compatible instance.")
                .font(.system(size: 27))
                .foregroundStyle(.white.opacity(0.64))
                .lineSpacing(5)
                .frame(maxWidth: 820, alignment: .leading)
            Button {
                isAddingServer = true
            } label: {
                Label("Add Server", systemImage: "plus.circle.fill")
                    .font(.system(size: 29, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(34)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }

    @ViewBuilder
    private func addServerPanel(_ viewModel: ServerSetupViewModel) -> some View {
        switch viewModel.detectionState {
        case .idle:
            urlInput(viewModel)
        case .detecting:
            detecting
        case .detected(let result):
            detected(result, viewModel: viewModel)
        case .failed:
            failed(viewModel)
        }
    }

    private func urlInput(_ viewModel: ServerSetupViewModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Add Server")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                Text("Server URL")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
                // No `.textFieldStyle(.plain)`: on tvOS the default (automatic) style
                // provides the focus chrome/reachability that lets the remote land on
                // the field. `.plain` stripped it, which was the core focus deadlock.
                TextField(
                    "192.168.1.50:5055 or https://seerr.example.com",
                    text: Binding(
                        get: { viewModel.urlInput },
                        set: { viewModel.urlInput = $0 }
                    )
                )
                .font(.system(size: 29, weight: .medium))
                .focused($urlFieldFocused)
                // Mirrors iOS AddServerView: the keyboard action submits directly.
                // (The tvOS keyboard renders function keys lowercase — "go"/"done" —
                // by system design; that casing is not app-controllable.)
                .submitLabel(.go)
                .onSubmit {
                    guard viewModel.canConnect else { return }
                    Task { await viewModel.connectToServer() }
                }
                .padding(22)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
            }

            if viewModel.isHTTPWarningVisible {
                Label("HTTP connections are not encrypted. Use HTTPS if possible.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(.yellow)
            }

            HStack(spacing: 18) {
                Button {
                    Task { await viewModel.connectToServer() }
                } label: {
                    Label("Connect", systemImage: "network")
                        .font(.system(size: 29, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canConnect)

                if !serverStore.servers.isEmpty {
                    Button("Cancel") {
                        isAddingServer = false
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(34)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
        // `.defaultFocus` is the idiomatic tvOS API for "land focus here when this
        // focus scope appears" — more reliable than a one-shot `.task` write, which
        // can run before the focus engine will accept the field.
        .defaultFocus($urlFieldFocused, true)
    }

    private var detecting: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.8)
            Text("Connecting to server")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Text("Detecting backend type and available sign-in methods.")
                .font(.system(size: 25))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }

    private func detected(_ result: ServerDetectionResult, viewModel: ServerSetupViewModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Server Found")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(result.backendType.displayName) \(result.version)")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            HStack(spacing: 12) {
                ForEach(result.availableAuthMethods) { method in
                    Label(method.displayName, systemImage: method.symbolName)
                        .font(.system(size: 22, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Display Name")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
                // Default tvOS text-field style (no `.plain`) keeps the field
                // remote-focusable — see the Server URL field above.
                TextField(
                    "Home Server",
                    text: Binding(
                        get: { viewModel.displayNameInput },
                        set: { viewModel.displayNameInput = $0 }
                    )
                )
                .font(.system(size: 29, weight: .medium))
                .padding(22)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
            }

            HStack(spacing: 18) {
                Button {
                    if let server = viewModel.saveDetectedServer() {
                        appState.selectServer(server)
                    }
                } label: {
                    Label("Save & Continue", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 29, weight: .bold))
                }
                .buttonStyle(.borderedProminent)

                Button("Try Another URL") {
                    viewModel.resetDetection()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(34)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }

    private func failed(_ viewModel: ServerSetupViewModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("Cannot Connect", systemImage: "xmark.circle.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.red)
            Text(viewModel.detectionError ?? "Check the URL and try again.")
                .font(.system(size: 27))
                .foregroundStyle(.white.opacity(0.68))
                .lineSpacing(5)
                .frame(maxWidth: 820, alignment: .leading)
            HStack(spacing: 18) {
                Button("Try Again") {
                    viewModel.resetDetection()
                }
                .buttonStyle(.borderedProminent)

                if viewModel.showCertTrustAlert || viewModel.detectionError?.contains("certificate") == true {
                    Button("Trust Certificate") {
                        viewModel.showCertTrustAlert = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(34)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }
}

private struct TVServerRow: View {
    let server: ServerConfiguration
    let isDefault: Bool
    let hasSavedSignIn: Bool

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: server.backendType.symbolName)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 58)

            VStack(alignment: .leading, spacing: 7) {
                Text(server.displayName)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(URLNormalizer.displayHost(from: server.baseURL))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                HStack(spacing: 10) {
                    if isDefault {
                        Text("Last Used")
                    }
                    Text(hasSavedSignIn ? "Saved Sign-In" : "Requires Sign-In")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(hasSavedSignIn ? .green : .white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(22)
    }
}

private struct TVEmptyServerList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "server.rack")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
            Text("No servers added")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Text("Add your self-hosted request server to continue.")
                .font(.system(size: 23))
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }
}
