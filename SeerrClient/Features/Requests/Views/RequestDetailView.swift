// RequestDetailView.swift
// SeerrClient
//
// Detail screen for an individual media request.

import SwiftUI

// MARK: - RequestDetailView

struct RequestDetailView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // MARK: - Input

    let requestID: Int
    var onDeleted: (() -> Void)? = nil

    // MARK: - State

    @State private var viewModel: RequestDetailViewModel?

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let vm = viewModel,
               let request = vm.request,
               canDeleteRequest(request, currentUserID: vm.currentUserID) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        vm.deleteRequest()
                    } label: {
                        if vm.isDeleting {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                        }
                    }
                    .disabled(vm.isDeleting || vm.isApproving || vm.isDeclining)
                    .accessibilityLabel("Delete request")
                }
            }
        }
        .onChange(of: viewModel?.didDelete ?? false) { _, didDelete in
            if didDelete {
                if let onDeleted {
                    onDeleted()
                } else {
                    dismiss()
                }
            }
        }
        .task {
            guard viewModel == nil else { return }
            guard let client = appState.apiClient else { return }

            let repository = RequestRepository(apiClient: client)
            let mediaDetailRepository = MediaDetailRepository(apiClient: client)
            let vm = RequestDetailViewModel(
                requestID: requestID,
                repository: repository,
                mediaDetailRepository: mediaDetailRepository,
                userPermissions: appState.currentUser?.permissions,
                currentUserID: appState.currentUser?.id
            )
            viewModel = vm
            vm.loadDetail()
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private func content(for vm: RequestDetailViewModel) -> some View {
        switch vm.loadState {
        case .idle, .loading:
            loadingContent

        case .loaded(let request):
            loadedContent(request: request, vm: vm)

        case .error(let message):
            errorContent(message: message, vm: vm)
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading request...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(request: MediaRequest, vm: RequestDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                mediaHeader(request, metadata: vm.mediaMetadata)

                VStack(alignment: .leading, spacing: 10) {
                    detailRow(title: "Status", value: RequestPresentation.statusTitle(for: request.status))
                    detailRow(
                        title: "Type",
                        value: RequestPresentation.mediaTypeLabel(
                            for: request,
                            explicitType: vm.mediaMetadata?.mediaType
                        )
                    )
                    detailRow(title: "Requested by", value: RequestPresentation.requesterName(for: request))
                    detailRow(title: "Created", value: SeerrDateFormatter.displayDate(request.createdAt))
                    detailRow(title: "Updated", value: SeerrDateFormatter.displayDate(request.updatedAt))

                    if let modifiedBy = request.modifiedBy {
                        detailRow(title: "Reviewed by", value: modifiedBy.username ?? modifiedBy.plexUsername ?? modifiedBy.email ?? "Admin")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                // Admin actions: approve (pending only), decline (pending or approved)
                // Compute isAdmin from appState directly — avoids stale value from ViewModel init.
                if isAdmin && (request.status == 1 || request.status == 2) {
                    adminActions(request: request, vm: vm)
                }

                if let actionError = vm.actionError {
                    Text(actionError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .accessibilityIdentifier("requests.detail.content")
    }

    // MARK: - Media Header

    @ViewBuilder
    private func mediaHeader(_ request: MediaRequest, metadata: RequestMediaMetadata?) -> some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: TMDBImageURL.poster(path: metadata?.posterPath, size: .w342)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "film")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 10) {
                Text(
                    RequestPresentation.title(
                        for: request,
                        preferredTitle: metadata?.title,
                        explicitType: metadata?.mediaType
                    )
                )
                    .font(.title3.weight(.semibold))
                    .lineLimit(3)

                RequestStatusBadgeView(status: request.status)

                if request.is4k == true {
                    Text("4K")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Admin Actions

    @ViewBuilder
    private func adminActions(request: MediaRequest, vm: RequestDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Admin Actions")
                .font(.headline)

            HStack(spacing: 12) {
                // Approve only visible for pending requests
                if request.status == 1 {
                    Button {
                        vm.approveRequest()
                    } label: {
                        if vm.isApproving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Approve")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(vm.isApproving || vm.isDeclining || vm.isDeleting)
                }

                // Decline visible for pending and approved requests
                Button {
                    vm.declineRequest()
                } label: {
                    if vm.isDeclining {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Decline")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(vm.isApproving || vm.isDeclining || vm.isDeleting)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Error

    @ViewBuilder
    private func errorContent(message: String, vm: RequestDetailViewModel) -> some View {
        ContentUnavailableView {
            Label("Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                vm.retry()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    /// Computed from AppState so it stays current if the user object loads after
    /// the ViewModel is initialised — fixes buttons not appearing on first visit.
    private var isAdmin: Bool {
        ((appState.currentUser?.permissions ?? 0) & 2) != 0
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    private func canDeleteRequest(_ request: MediaRequest, currentUserID: Int?) -> Bool {
        // Admin can delete any request; owner can delete own pending request
        if isAdmin { return true }
        return request.status == 1 && request.requestedBy?.id == currentUserID
    }
}
