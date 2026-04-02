// RequestListView.swift
// SeerrClient
//
// Request tab screen with filters, pagination, and navigation to request detail.

import SwiftUI

// MARK: - RequestNavDestination

private struct RequestNavDestination: Hashable {
    let requestID: Int
}

// MARK: - RequestListView

struct RequestListView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var viewModel: RequestListViewModel?

    // .processing is omitted — it's a transient server state, not a user-facing filter.
    private let visibleFilters: [RequestFilter] = [.all, .pending, .approved, .declined, .available]

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Requests")
        .navigationDestination(for: RequestNavDestination.self) { destination in
            RequestDetailView(requestID: destination.requestID)
        }
        .task {
            guard viewModel == nil else { return }
            guard let client = appState.apiClient else { return }

            let repository = RequestRepository(apiClient: client)
            let mediaDetailRepository = MediaDetailRepository(apiClient: client)
            let vm = RequestListViewModel(
                repository: repository,
                mediaDetailRepository: mediaDetailRepository,
                userPermissions: appState.currentUser?.permissions
            )
            viewModel = vm
            vm.loadRequestsIfNeeded()
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private func content(for vm: RequestListViewModel) -> some View {
        switch vm.loadState {
        case .idle, .loading:
            loadingState(vm)

        case .loaded(let requests):
            if requests.isEmpty {
                emptyState(vm)
            } else {
                loadedState(vm, requests: requests)
            }

        case .error(let message):
            errorState(vm, message: message)
        }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedState(_ vm: RequestListViewModel, requests: [MediaRequest]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                filterRow(vm)

                LazyVStack(spacing: 12) {
                    ForEach(requests, id: \.id) { request in
                        let metadata = vm.metadataByRequestID[request.id]
                        NavigationLink(value: RequestNavDestination(requestID: request.id)) {
                            RequestCardView(
                                request: request,
                                title: metadata?.title,
                                posterPath: metadata?.posterPath,
                                mediaType: metadata?.mediaType
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear { vm.onRequestAppear(request) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // Delete — admin or request owner (pending only)
                            if vm.canDelete(request, currentUserID: appState.currentUser?.id) {
                                Button(role: .destructive) {
                                    vm.deleteRequest(request, currentUserID: appState.currentUser?.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            // Approve — admin, pending requests only
                            if vm.isAdmin && request.status == 1 {
                                Button {
                                    vm.approveRequest(request)
                                } label: {
                                    Label("Approve", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                            // Decline — admin, pending or approved requests
                            if vm.isAdmin && (request.status == 1 || request.status == 2) {
                                Button {
                                    vm.declineRequest(request)
                                } label: {
                                    Label("Decline", systemImage: "xmark")
                                }
                                .tint(.orange)
                            }
                        }
                    }

                    if vm.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .refreshable {
            await vm.refresh()
        }
    }

    // MARK: - Empty

    @ViewBuilder
    private func emptyState(_ vm: RequestListViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                filterRow(vm)

                ContentUnavailableView {
                    Label("No Requests", systemImage: "tray")
                } description: {
                    Text("No requests match the selected filter.")
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .refreshable {
            await vm.refresh()
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private func loadingState(_ vm: RequestListViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                filterRow(vm)

                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 114)
                        .overlay { ShimmerView() }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - Error

    @ViewBuilder
    private func errorState(_ vm: RequestListViewModel, message: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                filterRow(vm)

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
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .refreshable {
            await vm.refresh()
        }
    }

    // MARK: - Filters

    @ViewBuilder
    private func filterRow(_ vm: RequestListViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleFilters, id: \.self) { filter in
                    RequestFilterChip(
                        label: filter.displayName,
                        isSelected: vm.selectedFilter == filter
                    ) {
                        vm.selectFilter(filter)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - RequestFilterChip

private struct RequestFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
