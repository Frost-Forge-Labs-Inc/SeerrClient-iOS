// RequestsTabView.swift
// SeerrClient
//
// Requests tab container that adapts between compact push navigation and a
// regular-width split layout with request selection and detail presentation.

import SwiftUI

// MARK: - RequestsTabView

/// Container for the Requests tab.
///
/// Presents the existing single-column push navigation on compact layouts and
/// a two-column list/detail split view on regular-width iPad layouts.
struct RequestsTabView: View {

    // MARK: - Dependencies

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var selectedRequest: RequestNavDestination? = nil

    // MARK: - Body

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .onChange(of: appState.activeServer?.id) { _, _ in
            selectedRequest = nil
        }
    }

    // MARK: - Layouts

    @ViewBuilder
    private var compactLayout: some View {
        NavigationStack {
            RequestListView()
                .navigationDestination(for: MovieNavDestination.self) { dest in
                    MovieDetailView(movieId: dest.id, movieTitle: dest.title)
                }
                .navigationDestination(for: TvNavDestination.self) { dest in
                    TvShowDetailView(tvId: dest.id, showTitle: dest.title)
                }
                .navigationDestination(for: CollectionNavDestination.self) { dest in
                    CollectionDetailView(collectionId: dest.id, collectionName: dest.name)
                }
        }
    }

    @ViewBuilder
    private var regularLayout: some View {
        NavigationSplitView {
            RequestListView(selection: $selectedRequest)
        } detail: {
            NavigationStack {
                if let selectedRequest {
                    RequestDetailView(requestID: selectedRequest.requestID, onDeleted: { self.selectedRequest = nil })
                        .id(selectedRequest.requestID)
                } else {
                    ContentUnavailableView("No Request Selected", systemImage: "sidebar.left")
                        .accessibilityIdentifier("requests.detail.placeholder")
                }
            }
        }
    }
}
