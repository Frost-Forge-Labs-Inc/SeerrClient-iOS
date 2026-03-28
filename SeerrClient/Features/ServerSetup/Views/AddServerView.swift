// AddServerView.swift
// SeerrClient
//
// Sheet view that collects a server URL, runs the detection sequence, shows
// the result (or error), and saves the ServerConfiguration to ServerStore.
// Presented from ServerListView via .sheet(isPresented:).

import SwiftUI

// MARK: - AddServerView

/// Sheet that guides the user through adding a new Seerr-compatible server.
///
/// States (driven by `ServerSetupViewModel.detectionState`):
/// - **URL Input** — blank text field with "Connect" button
/// - **Detecting** — spinner + status label while API calls run
/// - **Success** — detected server info, editable display name, "Save & Continue"
/// - **Failure** — error message, "Try Again" button, optional "Trust Certificate" link
///
/// On "Save & Continue" the view:
/// 1. Calls `viewModel.saveDetectedServer()`
/// 2. Calls the `onServerSaved` callback with the new `ServerConfiguration`
/// 3. Dismisses itself
struct AddServerView: View {

    // MARK: - Dependencies

    @Environment(\.dismiss) private var dismiss

    // MARK: - Callback

    /// Called when the server has been saved and the user taps "Save & Continue".
    /// The second parameter contains the auth methods available on the server.
    let onServerSaved: (ServerConfiguration, [AuthMethod]) -> Void

    // MARK: - State

    @State private var viewModel: ServerSetupViewModel

    // MARK: - Init

    /// Creates an `AddServerView` bound to the given server store.
    ///
    /// - Parameters:
    ///   - serverStore: The shared `ServerStore` where the new server will be saved.
    ///   - onServerSaved: Callback fired after the server is persisted.
    init(serverStore: ServerStore, onServerSaved: @escaping (ServerConfiguration, [AuthMethod]) -> Void) {
        self.onServerSaved = onServerSaved
        _viewModel = State(initialValue: ServerSetupViewModel(serverStore: serverStore))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    switch viewModel.detectionState {
                    case .idle:
                        urlInputSection

                    case .detecting:
                        detectingSection

                    case .detected(let result):
                        detectionSuccessSection(result)

                    case .failed:
                        detectionFailureSection
                    }
                }
                .padding()
            }
            .navigationTitle({
                switch viewModel.detectionState {
                case .detected: return "Server Found"
                default: return "Add Server"
                }
            }())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Trust Certificate for \"\(viewModel.certTrustHostname)\"?",
                isPresented: $viewModel.showCertTrustAlert,
                titleVisibility: .visible
            ) {
                Button("Trust Certificate") {
                    Task { await viewModel.retryWithCertificateTrust() }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.showCertTrustAlert = false
                }
            } message: {
                Text(
                    "This server uses a self-signed certificate that cannot be automatically verified. " +
                    "Only trust it if you control this server or recognise it."
                )
            }
        }
    }

    // MARK: - URL Input State

    @ViewBuilder
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            VStack(alignment: .leading, spacing: 6) {
                Text("Server URL")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                TextField(
                    "192.168.1.50:5055 or https://seerr.example.com",
                    text: $viewModel.urlInput
                )
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.go)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .onSubmit {
                    Task { await viewModel.connectToServer() }
                }

                Text("Enter the address of your Overseerr, Jellyseerr, or Seerr instance. Include the port if it uses a non-standard one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // HTTP warning banner
            if viewModel.isHTTPWarningVisible {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("HTTP connections are not encrypted. Use HTTPS if possible.")
                        .font(.footnote)
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            // Connect button
            Button {
                Task { await viewModel.connectToServer() }
            } label: {
                Text("Connect")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canConnect)
        }
    }

    // MARK: - Detecting State

    @ViewBuilder
    private var detectingSection: some View {
        VStack(spacing: 32) {
            ProgressView()
                .scaleEffect(1.4)
                .padding(.top, 60)

            VStack(spacing: 8) {
                Text("Connecting to server…")
                    .font(.headline)
                Text("Detecting backend type and available features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(minHeight: 300)
    }

    // MARK: - Detection Success State

    @ViewBuilder
    private func detectionSuccessSection(_ result: ServerDetectionResult) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Success header
            HStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Server Found")
                        .font(.title3.bold())

                    HStack(spacing: 6) {
                        Image(systemName: result.backendType.symbolName)
                            .font(.caption)
                        Text(result.backendType.displayName)
                            .font(.caption.weight(.semibold))
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("v\(result.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(.tint)
                }
            }
            .padding(16)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            Divider()

            // Available auth methods
            VStack(alignment: .leading, spacing: 10) {
                Text("Available Sign-In Methods")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                FlowRow(items: result.availableAuthMethods) { method in
                    HStack(spacing: 6) {
                        Image(systemName: method.symbolName)
                            .font(.caption)
                        Text(method.displayName)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                }
            }

            Divider()

            // Display name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Display Name")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                TextField("My Server", text: $viewModel.displayNameInput)
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                Text("A friendly name to identify this server in the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Save & Continue button
            Button {
                if let config = viewModel.saveDetectedServer() {
                    onServerSaved(config, result.availableAuthMethods)
                    dismiss()
                }
            } label: {
                Text("Save & Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Detection Failure State

    @ViewBuilder
    private var detectionFailureSection: some View {
        VStack(spacing: 32) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
                .padding(.top, 40)

            VStack(spacing: 10) {
                Text("Cannot Connect")
                    .font(.title3.bold())

                if let errorMessage = viewModel.detectionError {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            VStack(spacing: 12) {
                Button {
                    viewModel.resetDetection()
                } label: {
                    Text("Try Again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Show cert trust option if SSL error was detected
                if viewModel.showCertTrustAlert || viewModel.detectionError?.contains("certificate") == true {
                    Button {
                        viewModel.showCertTrustAlert = true
                    } label: {
                        Label(
                            "Advanced: Trust custom certificate",
                            systemImage: "lock.shield"
                        )
                        .font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .frame(minHeight: 300)
    }
}

// MARK: - FlowRow (helper for auth method chips)

/// A simple horizontal chip row that wraps to the next line if needed.
private struct FlowRow<Item: Identifiable, Content: View>: View {

    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        // SwiftUI doesn't have a built-in flow layout pre-iOS 16, so we use
        // a LazyHStack within a ScrollView for compact display.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    content(item)
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("URL Input") {
    let store = ServerStore()
    AddServerView(serverStore: store) { _, _ in }
}

#Preview("Success") {
    let store = ServerStore()

    // We can't directly set viewModel state in preview without reflection,
    // so this preview shows the input state. Run the app for full flow.
    return AddServerView(serverStore: store) { _, _ in }
}
#endif
