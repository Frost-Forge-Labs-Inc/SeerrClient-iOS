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
        .onDisappear {
            viewModel?.cancelAll()
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
                    Image(systemName: metadata?.mediaType == .tv ? "tv" : "film")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }

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
        switch request.status {
        case 1: return "Pending"
        case 2: return "Approved"
        case 3: return "Declined"
        default: return "Unknown"
        }
    }
}

struct TVRequestDetailView: View {
    @Environment(AppState.self) private var appState
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
        .onDisappear { viewModel?.cancelAll() }
    }

    @ViewBuilder
    private func content(for viewModel: RequestDetailViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            TVLoadingStateView(title: "Request")
        case .loaded(let request):
            TVScreenScaffold(title: viewModel.mediaMetadata?.title ?? "Request", subtitle: statusLabel(request.status)) {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(spacing: 18) {
                        TVInfoPill(title: "Type", value: request.inferredMediaType == .tv ? "TV Show" : "Movie")
                        TVInfoPill(title: "Requested By", value: request.requestedBy?.displayName ?? request.requestedBy?.username ?? "Unknown")
                        if let created = request.createdAt {
                            TVInfoPill(title: "Created", value: SeerrDateFormatter.displayDate(created))
                        }
                    }
                    Text("Approval and deletion controls are intentionally left off tvOS for v1. Manage requests from iPhone, iPad, or the web UI.")
                        .font(.system(size: 25))
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(maxWidth: 1000, alignment: .leading)
                }
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
        default: return "Unknown"
        }
    }
}
