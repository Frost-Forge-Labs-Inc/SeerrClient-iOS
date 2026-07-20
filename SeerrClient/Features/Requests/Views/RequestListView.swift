// RequestListView.swift
// SeerrClient
//
// Request tab screen with filters, pagination, and navigation to request detail.

import SwiftUI

// MARK: - RequestNavDestination

struct RequestNavDestination: Hashable {
    let requestID: Int
}

// MARK: - RequestListView

struct RequestListView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState
    var selection: Binding<RequestNavDestination?>? = nil

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
        // Compact-path only: drives the push in the single-column NavigationStack.
        // When `selection` is non-nil (regular-width split layout) rows are Buttons
        // that set the selection binding instead of pushing, so this is inert there.
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
                loadedState(vm)
            }

        case .error(let message):
            errorState(vm, message: message)
        }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedState(_ vm: RequestListViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                mediaSegmentControl(vm)
                filterRow(vm)

                if vm.visibleRequests.isEmpty {
                    if vm.isLoadingMore {
                        filteredLoadingState(vm)
                    } else {
                        filteredEmptyState(vm)
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.visibleRequests, id: \.id) { request in
                            let metadata = vm.metadataByRequestID[request.id]
                            let destination = RequestNavDestination(requestID: request.id)
                            requestNavigationWrapper(destination: destination) {
                                RequestCardView(
                                    request: request,
                                    title: metadata?.title,
                                    posterPath: metadata?.posterPath,
                                    mediaType: metadata?.mediaType
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("requests.card.\(request.id)")
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
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .accessibilityIdentifier("requests.screen")
        .refreshable {
            await vm.refresh()
        }
    }

    @ViewBuilder
    private func requestNavigationWrapper<Label: View>(
        destination: RequestNavDestination,
        @ViewBuilder label: () -> Label
    ) -> some View {
        if let selection {
            Button {
                selection.wrappedValue = destination
            } label: {
                label()
            }
            .overlay {
                if selection.wrappedValue?.requestID == destination.requestID {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            }
        } else {
            NavigationLink(value: destination) {
                label()
            }
        }
    }

    // MARK: - Empty

    @ViewBuilder
    private func emptyState(_ vm: RequestListViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                mediaSegmentControl(vm)
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
        .accessibilityIdentifier("requests.screen")
        .refreshable {
            await vm.refresh()
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private func loadingState(_ vm: RequestListViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                mediaSegmentControl(vm)
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
        .accessibilityIdentifier("requests.screen")
    }

    // MARK: - Error

    @ViewBuilder
    private func errorState(_ vm: RequestListViewModel, message: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                mediaSegmentControl(vm)
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
        .accessibilityIdentifier("requests.screen")
        .refreshable {
            await vm.refresh()
        }
    }

    // MARK: - Segment + Filters

    @ViewBuilder
    private func mediaSegmentControl(_ vm: RequestListViewModel) -> some View {
        Picker(
            "Media Type",
            selection: Binding(
                get: { vm.selectedMediaSegment },
                set: vm.selectMediaSegment
            )
        ) {
            ForEach(RequestMediaSegment.allCases, id: \.self) { segment in
                Text(segment.title)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("requests.mediaSegment")
    }

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

    private func filteredEmptyState(_ vm: RequestListViewModel) -> some View {
        ContentUnavailableView {
            Label(vm.selectedMediaSegment.emptyTitle, systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text(vm.selectedMediaSegment.emptyMessage)
        }
        .accessibilityIdentifier("requests.filtered-empty")
    }

    private func filteredLoadingState(_ vm: RequestListViewModel) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading \(vm.selectedMediaSegment.title)...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityIdentifier("requests.filtered-loading")
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
