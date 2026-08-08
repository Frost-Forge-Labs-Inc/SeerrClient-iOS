// TVRequestsView.swift
// SeerrClientTV (Octopus Explorer)

import SwiftUI

struct RequestNavDestination: Hashable {
    let requestID: Int
}

struct TVRequestsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: RequestListViewModel?

    private let visibleFilters: [RequestFilter] = [.all, .pending, .approved, .declined, .available]

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                TVLoadingStateView(title: "Requests")
            }
        }
        .accessibilityIdentifier("tvos.requests.screen")
        .task {
            guard viewModel == nil else { return }
            guard let client = appState.apiClient else { return }
            let repository = RequestRepository(apiClient: client)
            let mediaDetailRepository = MediaDetailRepository(apiClient: client)
            let viewModel = RequestListViewModel(
                repository: repository,
                mediaDetailRepository: mediaDetailRepository,
                userPermissions: appState.currentUser?.permissions
            )
            self.viewModel = viewModel
            viewModel.loadRequestsIfNeeded()
        }
    }

    @ViewBuilder
    private func content(for viewModel: RequestListViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            TVLoadingStateView(title: "Requests")
        case .loaded(let requests):
            if requests.isEmpty {
                empty(viewModel)
            } else {
                loaded(viewModel)
            }
        case .error(let message):
            TVMessageStateView(
                title: "Requests",
                message: message,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Try Again"
            ) {
                viewModel.retry()
            }
        }
    }

    private func loaded(_ viewModel: RequestListViewModel) -> some View {
        TVScreenScaffold(title: "Requests", subtitle: "Track media requests") {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    ForEach(RequestMediaSegment.allCases, id: \.self) { segment in
                        Button(segment.title) {
                            viewModel.selectMediaSegment(segment)
                        }
                        .buttonStyle(.bordered)
                        .tint(viewModel.selectedMediaSegment == segment ? .accentColor : .white.opacity(0.25))
                    }
                }

                HStack(spacing: 14) {
                    ForEach(visibleFilters, id: \.self) { filter in
                        Button(filter.displayName) {
                            viewModel.selectFilter(filter)
                        }
                        .buttonStyle(.bordered)
                        .tint(viewModel.selectedFilter == filter ? .accentColor : .white.opacity(0.25))
                    }
                }

                if viewModel.visibleRequests.isEmpty {
                    Text(emptyMessage(for: viewModel))
                        .font(.system(size: 29, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(viewModel.visibleRequests, id: \.id) { request in
                            NavigationLink(value: RequestNavDestination(requestID: request.id)) {
                                TVRequestRow(
                                    request: request,
                                    metadata: viewModel.metadataByRequestID[request.id]
                                )
                            }
                            .buttonStyle(.card)
                            .accessibilityIdentifier("tvos.requests.card.\(request.id)")
                            .onAppear { viewModel.onRequestAppear(request) }
                        }
                        if viewModel.isLoadingMore {
                            ProgressView()
                        }
                    }
                }

                Button("Refresh") {
                    Task { await viewModel.refresh() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func empty(_ viewModel: RequestListViewModel) -> some View {
        TVMessageStateView(
            title: "Requests",
            message: "No requests match the selected filters.",
            systemImage: "tray",
            actionTitle: "Refresh"
        ) {
            Task { await viewModel.refresh() }
        }
    }

    private func emptyMessage(for viewModel: RequestListViewModel) -> String {
        if viewModel.selectedFilter == .all {
            return viewModel.selectedMediaSegment.emptyTitle
        }
        return "No \(viewModel.selectedMediaSegment.title.lowercased()) match \(viewModel.selectedFilter.displayName.lowercased())."
    }
}

private struct TVRequestRow: View {
    let request: MediaRequest
    let metadata: RequestMediaMetadata?

    var body: some View {
        HStack(spacing: 24) {
            RoundedRectangle(cornerRadius: TVMetrics.cornerRadius)
                .fill(Color.white.opacity(0.12))
                .frame(width: 96, height: 144)
                .overlay {
                    // Load the real poster (RequestMediaMetadata carries posterPath);
                    // fall back to a media-type icon while loading or when absent.
                    if let url = TMDBImageURL.poster(path: metadata?.posterPath, size: .w342) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                // Fallback for empty/failure/unknown — avoids an
                                // icon -> spinner -> poster flash as metadata resolves.
                                posterFallback
                            }
                        }
                    } else {
                        posterFallback
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))

            VStack(alignment: .leading, spacing: 12) {
                Text(metadata?.title ?? fallbackTitle)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 14) {
                    Text(statusLabel)
                    Text(mediaTypeLabel)
                    if let requester = request.requestedBy?.displayName ?? request.requestedBy?.username ?? request.requestedBy?.plexUsername {
                        Text("by \(requester)")
                    }
                }
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(22)
    }

    private var posterFallback: some View {
        // Use the request's own inferred type so the fallback icon is correct even
        // before the async metadata (title/poster) has resolved.
        Image(systemName: request.inferredMediaType == .tv ? "tv" : "film")
            .font(.system(size: 38, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
    }

    private var fallbackTitle: String {
        if let tmdbID = request.media?.tmdbId {
            return "\(mediaTypeLabel) #\(tmdbID)"
        }
        return "Requested Media"
    }

    private var mediaTypeLabel: String {
        request.inferredMediaType == .tv ? "TV Show" : "Movie"
    }

    private var statusLabel: String {
        // Show the request moderation status for known values (like the shipped iOS
        // request list) so filtering by Pending/Approved/Declined stays truthful.
        // Only for an unexpected/unknown request.status do we fall back to the media
        // availability (Available/Processing/Partial/Pending via the shared
        // MediaStatusCode) so the row never shows a bare "Unknown".
        switch request.status {
        case 1: return "Pending"
        case 2: return "Approved"
        case 3: return "Declined"
        default:
            if let mediaStatus = request.media?.status,
               let code = MediaStatusCode(rawValue: mediaStatus),
               code.showsBadge {
                return code.label
            }
            return "Requested"
        }
    }
}

struct TVRequestDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let requestID: Int
    @State private var viewModel: RequestDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                TVLoadingStateView(title: "Request")
            }
        }
        .task {
            guard viewModel == nil else { return }
            guard let client = appState.apiClient else { return }
            let viewModel = RequestDetailViewModel(
                requestID: requestID,
                repository: RequestRepository(apiClient: client),
                mediaDetailRepository: MediaDetailRepository(apiClient: client),
                userPermissions: appState.currentUser?.permissions,
                currentUserID: appState.currentUser?.id
            )
            self.viewModel = viewModel
            viewModel.loadDetail()
        }
        .onChange(of: viewModel?.didDelete ?? false) { _, didDelete in
            if didDelete {
                dismiss()
            }
        }
        .onDisappear { viewModel?.cancelAll() }
    }

    @ViewBuilder
    private func content(for viewModel: RequestDetailViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            TVLoadingStateView(title: "Request")
        case .loaded(let request):
            let isAdmin = ((appState.currentUser?.permissions ?? 0) & 2) != 0
            let isOwnerOfPendingRequest = request.status == 1
                && request.requestedBy?.id != nil
                && request.requestedBy?.id == viewModel.currentUserID
            let canDelete = isAdmin || isOwnerOfPendingRequest
            let isActionInFlight = viewModel.isApproving || viewModel.isDeclining || viewModel.isDeleting
            TVScreenScaffold(title: viewModel.mediaMetadata?.title ?? "Request", subtitle: statusLabel(request.status)) {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(spacing: 18) {
                        TVInfoPill(title: "Type", value: request.inferredMediaType == .tv ? "TV Show" : "Movie")
                        TVInfoPill(title: "Requested By", value: request.requestedBy?.displayName ?? request.requestedBy?.username ?? "Unknown")
                        if let created = request.createdAt {
                            TVInfoPill(title: "Created", value: SeerrDateFormatter.displayDate(created))
                        }
                    }

                    // `canDelete` already includes admin (canDelete = isAdmin || ownerOfPending),
                    // so it subsumes the approve/decline visibility; no extra status clause needed.
                    if canDelete {
                        VStack(alignment: .leading, spacing: 18) {
                            // A non-admin owner sees only the Delete button, so don't label it "Admin".
                            Text(isAdmin ? "Admin Actions" : "Manage Request")
                                .font(.system(size: 27, weight: .semibold))
                                .foregroundStyle(.white)

                            HStack(spacing: 22) {
                                if isAdmin && request.status == 1 {
                                    Button {
                                        viewModel.approveRequest()
                                    } label: {
                                        if viewModel.isApproving {
                                            ProgressView()
                                                .accessibilityLabel("Approving")
                                        } else {
                                            Text("Approve")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                    .disabled(isActionInFlight)
                                    .accessibilityIdentifier("tvos.request.approve")
                                }

                                if isAdmin && (request.status == 1 || request.status == 2) {
                                    Button {
                                        viewModel.declineRequest()
                                    } label: {
                                        if viewModel.isDeclining {
                                            ProgressView()
                                                .accessibilityLabel("Declining")
                                        } else {
                                            Text("Decline")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                    .disabled(isActionInFlight)
                                    .accessibilityIdentifier("tvos.request.decline")
                                }

                                if canDelete {
                                    Button(role: .destructive) {
                                        viewModel.deleteRequest()
                                    } label: {
                                        if viewModel.isDeleting {
                                            ProgressView()
                                                .accessibilityLabel("Deleting")
                                        } else {
                                            Text("Delete")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                    .disabled(isActionInFlight)
                                    .accessibilityIdentifier("tvos.request.delete")
                                }
                            }
                            .font(.system(size: 25, weight: .semibold))
                        }
                    }

                    if let actionError = viewModel.actionError {
                        Text(actionError)
                            .font(.system(size: 23, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(maxWidth: 1000, alignment: .leading)
                    }
                }
                .accessibilityIdentifier("tvos.request.detail.content")
            }
        case .error(let message):
            TVMessageStateView(title: "Request", message: message, systemImage: "exclamationmark.triangle", actionTitle: "Try Again") {
                viewModel.retry()
            }
        }
    }

    private func statusLabel(_ status: Int) -> String {
        switch status {
        case 1: return "Pending"
        case 2: return "Approved"
        case 3: return "Declined"
        default: return "Requested"
        }
    }
}
