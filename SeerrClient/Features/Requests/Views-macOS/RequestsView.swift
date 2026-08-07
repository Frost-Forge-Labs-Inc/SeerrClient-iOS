// RequestsView.swift
// SeerrClientMac
//
// macOS Requests screen: Table master + inspector detail.
// Reuses RequestListViewModel verbatim; presentation-only fork.

import SwiftUI

// MARK: - RequestRow

/// Lightweight, sortable row mapped from `MediaRequest` for the macOS Table.
struct RequestRow: Identifiable {
    let id: Int
    let title: String
    let typeLabel: String
    let statusTitle: String
    let statusValue: Int
    let requestedBy: String
    let date: String
    let sortDate: String
}

// MARK: - RequestsView

/// macOS Requests feature: sortable table with context-menu moderation and
/// an inspector column hosting `RequestDetailView`.
struct RequestsView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var viewModel: RequestListViewModel?
    @State private var selectedID: RequestRow.ID?
    @State private var showInspector = true
    @State private var sortOrder: [KeyPathComparator<RequestRow>] = [
        .init(\.sortDate, order: .reverse)
    ]

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
        .onDisappear {
            viewModel?.cancelAll()
        }
        .onChange(of: selectedID) { _, newValue in
            if newValue != nil {
                showInspector = true
            }
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private func content(for vm: RequestListViewModel) -> some View {
        switch vm.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar { requestsToolbar(vm) }
                .inspector(isPresented: $showInspector) {
                    inspectorContent
                }
                .inspectorColumnWidth(min: 320, ideal: 380, max: 480)

        case .loaded:
            if vm.visibleRequests.isEmpty {
                emptyContent(vm)
            } else {
                tableContent(vm)
            }

        case .error(let message):
            errorContent(vm, message: message)
        }
    }

    // MARK: - Table

    @ViewBuilder
    private func tableContent(_ vm: RequestListViewModel) -> some View {
        let rows = makeRows(from: vm)
        let requestByID = Dictionary(uniqueKeysWithValues: vm.visibleRequests.map { ($0.id, $0) })
        let sortedRows = rows.sorted(using: sortOrder)
        let currentUserID = appState.currentUser?.id

        Table(sortedRows, selection: $selectedID, sortOrder: $sortOrder) {
            TableColumn("Title", value: \.title)
            TableColumn("Type", value: \.typeLabel)
            TableColumn("Status", value: \.statusValue) { row in
                RequestStatusBadgeView(status: row.statusValue)
            }
            TableColumn("Requested By", value: \.requestedBy)
            TableColumn("Date", value: \.sortDate) { row in
                Text(row.date)
            }
        }
        .contextMenu(forSelectionType: RequestRow.ID.self) { ids in
            contextMenuItems(
                ids: ids,
                requestByID: requestByID,
                vm: vm,
                currentUserID: currentUserID
            )
        }
        .toolbar { requestsToolbar(vm) }
        .inspector(isPresented: $showInspector) {
            inspectorContent
        }
        .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
        .accessibilityIdentifier("requests.screen")
    }

    // MARK: - Empty / Error

    @ViewBuilder
    private func emptyContent(_ vm: RequestListViewModel) -> some View {
        ContentUnavailableView {
            Label("No Requests", systemImage: "tray")
        } description: {
            Text("No requests match the selected filter.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar { requestsToolbar(vm) }
        .inspector(isPresented: $showInspector) {
            inspectorContent
        }
        .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
        .accessibilityIdentifier("requests.screen")
    }

    @ViewBuilder
    private func errorContent(_ vm: RequestListViewModel, message: String) -> some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar { requestsToolbar(vm) }
        .inspector(isPresented: $showInspector) {
            inspectorContent
        }
        .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
        .accessibilityIdentifier("requests.screen")
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspectorContent: some View {
        if let id = selectedID {
            RequestDetailView(requestID: id)
        } else {
            ContentUnavailableView("No Request Selected", systemImage: "sidebar.right")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func requestsToolbar(_ vm: RequestListViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker(
                "Filter",
                selection: Binding(
                    get: { vm.selectedFilter },
                    set: { vm.selectFilter($0) }
                )
            ) {
                ForEach(RequestFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("requests.filter")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showInspector.toggle()
            } label: {
                Image(systemName: "sidebar.right")
            }
            .help("Toggle Inspector")
            .accessibilityLabel("Toggle Inspector")
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(
        ids: Set<RequestRow.ID>,
        requestByID: [Int: MediaRequest],
        vm: RequestListViewModel,
        currentUserID: Int?
    ) -> some View {
        if let id = ids.first, let request = requestByID[id] {
            if vm.isAdmin {
                Button("Approve") {
                    vm.approveRequest(request)
                }
                Button("Decline") {
                    vm.declineRequest(request)
                }
            }

            if vm.canDelete(request, currentUserID: currentUserID) {
                Divider()
                Button("Delete", role: .destructive) {
                    vm.deleteRequest(request, currentUserID: currentUserID)
                }
            }
        }
    }

    // MARK: - Row Mapping

    private func makeRows(from vm: RequestListViewModel) -> [RequestRow] {
        vm.visibleRequests.map { request in
            let metadata = vm.metadataByRequestID[request.id]
            let preferredTitle = metadata?.title
            let explicitType = metadata?.mediaType
            return RequestRow(
                id: request.id,
                title: RequestPresentation.title(
                    for: request,
                    preferredTitle: preferredTitle,
                    explicitType: explicitType
                ),
                typeLabel: RequestPresentation.mediaTypeLabel(
                    for: request,
                    explicitType: explicitType
                ),
                statusTitle: RequestPresentation.statusTitle(for: request.status),
                statusValue: request.status,
                requestedBy: request.requestedBy?.username
                    ?? request.requestedBy?.plexUsername
                    ?? request.requestedBy?.email
                    ?? "User #\(request.requestedBy?.id ?? 0)",
                date: SeerrDateFormatter.displayDate(request.createdAt),
                sortDate: request.createdAt ?? ""
            )
        }
    }
}
