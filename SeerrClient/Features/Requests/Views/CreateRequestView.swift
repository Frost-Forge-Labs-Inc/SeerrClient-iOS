// CreateRequestView.swift
// SeerrClient
//
// Sheet form used to submit a new media request. For TV shows, displays
// per-season status (available, requested, pending) and only allows
// requesting unrequested seasons — matching the Jellyseerr web UI behavior.

import SwiftUI

// MARK: - CreateRequestView

struct CreateRequestView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // MARK: - Input

    let mediaType: MediaRequestMediaType
    let mediaId: Int
    let tvdbId: Int?
    let seasons: [Season]?
    let mediaInfo: MediaInfo?
    let onSuccess: (@MainActor () -> Void)?

    // MARK: - State

    @State private var repository: RequestRepository?
    @State private var is4K = false
    @State private var allSeasons = true
    @State private var selectedSeasonNumbers = Set<Int>()
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var submitTask: Task<Void, Never>?
    @State private var qualityProfiles: [ServiceProfile] = []
    @State private var selectedProfileId: Int? = nil

    // MARK: - Init

    init(
        mediaType: MediaRequestMediaType,
        mediaId: Int,
        tvdbId: Int? = nil,
        seasons: [Season]? = nil,
        mediaInfo: MediaInfo? = nil,
        onSuccess: (@MainActor () -> Void)? = nil
    ) {
        self.mediaType = mediaType
        self.mediaId = mediaId
        self.tvdbId = tvdbId
        self.seasons = seasons
        self.mediaInfo = mediaInfo
        self.onSuccess = onSuccess
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Form {
                Section("Request Options") {
                    Toggle("Request in 4K", isOn: $is4K)

                    if !qualityProfiles.isEmpty {
                        Picker("Quality Profile", selection: $selectedProfileId) {
                            Text("Server Default").tag(Optional<Int>.none)
                            ForEach(qualityProfiles, id: \.id) { profile in
                                Text(profile.name ?? "Profile \(profile.id ?? 0)")
                                    .tag(Optional(profile.id))
                            }
                        }
                    }
                }

                if mediaType == .tv {
                    tvSeasonSection
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        submitRequest()
                    } label: {
                        if isSubmitting {
                            HStack {
                                ProgressView()
                                Text("Submitting...")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Submit Request")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitDisabled)
                }
            }
        }
        .task {
            guard repository == nil else { return }
            guard let client = appState.apiClient else { return }
            let repo = RequestRepository(apiClient: client)
            repository = repo
            // Load quality profiles in background — failure is silent (picker just won't show)
            Task {
                let profiles = (try? await mediaType == .movie
                    ? repo.fetchRadarrProfiles()
                    : repo.fetchSonarrProfiles()) ?? []
                qualityProfiles = profiles
            }
        }
        .onAppear {
            // If there are already requested seasons, default to individual selection mode
            if mediaType == .tv && !requestableSeasonNumbers.isEmpty && hasAnyRequestedOrAvailableSeasons {
                allSeasons = false
            }
        }
        .onDisappear {
            submitTask?.cancel()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }

            Spacer()

            Text("Create Request")
                .font(.headline)

            Spacer()

            // Keeps title visually centered against the Cancel button.
            Color.clear.frame(width: 52, height: 1)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - TV Seasons

    @ViewBuilder
    private var tvSeasonSection: some View {
        Section("Seasons") {
            if requestableSeasonNumbers.isEmpty && hasAnyRequestedOrAvailableSeasons {
                Text("All seasons have already been requested or are available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if hasAnyRequestedOrAvailableSeasons {
                    // Some seasons already requested — show individual selection only
                    seasonListView
                } else {
                    // No seasons requested yet — show All Seasons toggle
                    Toggle("All Seasons", isOn: $allSeasons)

                    if !allSeasons {
                        seasonListView
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var seasonListView: some View {
        if availableSeasonNumbers.isEmpty {
            Text("No seasons available for selection.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ForEach(availableSeasonNumbers, id: \.self) { (seasonNumber: Int) in
                let status = seasonStatus(for: seasonNumber)
                HStack {
                    Button {
                        if status == .requestable {
                            toggleSeason(seasonNumber)
                        }
                    } label: {
                        HStack {
                            Text("Season \(seasonNumber)")
                                .foregroundStyle(status == .requestable ? .primary : .secondary)
                            Spacer()
                            seasonStatusView(status: status, seasonNumber: seasonNumber)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(status != .requestable)
                }
            }
        }
    }

    @ViewBuilder
    private func seasonStatusView(status: SeasonAvailability, seasonNumber: Int) -> some View {
        switch status {
        case .available:
            Label("Available", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .partiallyAvailable:
            Label("Partial", systemImage: "circle.lefthalf.filled")
                .font(.caption)
                .foregroundStyle(.purple)
        case .requested:
            Label("Requested", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.purple)
        case .pending:
            Label("Pending", systemImage: "clock.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .requestable:
            if selectedSeasonNumbers.contains(seasonNumber) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Season Status Logic

    private enum SeasonAvailability {
        case available
        case partiallyAvailable
        case requested
        case pending
        case requestable
    }

    private func seasonStatus(for seasonNumber: Int) -> SeasonAvailability {
        // Check availability from mediaInfo.seasons (media server status)
        if let mediaSeasons = mediaInfo?.seasons {
            if let mediaSeason = mediaSeasons.first(where: { $0.seasonNumber == seasonNumber }) {
                switch mediaSeason.status {
                case 5: return .available
                case 4: return .partiallyAvailable
                default: break
                }
            }
        }

        // Check if season is in any active (non-declined, non-completed) request
        if let requests = mediaInfo?.requests {
            for request in requests {
                // Skip declined (3) and completed (5) requests
                guard request.status != 3 else { continue }
                if let seasonRequests = request.seasons {
                    if seasonRequests.contains(where: { $0.seasonNumber == seasonNumber }) {
                        return request.status == 1 ? .pending : .requested
                    }
                }
            }
        }

        return .requestable
    }

    private var hasAnyRequestedOrAvailableSeasons: Bool {
        availableSeasonNumbers.contains { seasonStatus(for: $0) != .requestable }
    }

    private var requestableSeasonNumbers: [Int] {
        availableSeasonNumbers.filter { seasonStatus(for: $0) == .requestable }
    }

    // MARK: - Helpers

    private var availableSeasonNumbers: [Int] {
        let numbers = (seasons ?? [])
            .compactMap { $0.seasonNumber }
            .filter { $0 > 0 }
        return Array(Set(numbers)).sorted()
    }

    private var isSubmitDisabled: Bool {
        if isSubmitting || repository == nil {
            return true
        }

        if mediaType == .tv {
            if tvdbId == nil {
                return true
            }
            // If there are requested seasons, "all seasons" toggle is hidden — must select individual seasons
            if hasAnyRequestedOrAvailableSeasons {
                if selectedSeasonNumbers.isEmpty {
                    return true
                }
            } else if !allSeasons && selectedSeasonNumbers.isEmpty {
                return true
            }
            // Disable if all seasons are already requested
            if requestableSeasonNumbers.isEmpty {
                return true
            }
        }

        return false
    }

    private func toggleSeason(_ season: Int) {
        if selectedSeasonNumbers.contains(season) {
            selectedSeasonNumbers.remove(season)
        } else {
            selectedSeasonNumbers.insert(season)
        }
    }

    private func submitRequest() {
        guard let repository else { return }

        if mediaType == .tv, tvdbId == nil {
            errorMessage = "TV requests require a TVDB identifier."
            return
        }

        let seasonsToRequest: [Int]?
        let requestAllSeasons: Bool?

        if mediaType == .tv {
            if hasAnyRequestedOrAvailableSeasons {
                // When some seasons are already requested, always send specific season numbers
                let selected = selectedSeasonNumbers.sorted()
                if selected.isEmpty {
                    errorMessage = "Select at least one season to request."
                    return
                }
                seasonsToRequest = selected
                requestAllSeasons = false
            } else if allSeasons {
                seasonsToRequest = nil
                requestAllSeasons = true
            } else {
                let selected = selectedSeasonNumbers.sorted()
                if selected.isEmpty {
                    errorMessage = "Select at least one season, or choose All Seasons."
                    return
                }
                seasonsToRequest = selected
                requestAllSeasons = false
            }
        } else {
            seasonsToRequest = nil
            requestAllSeasons = nil
        }

        isSubmitting = true
        errorMessage = nil

        let requestBody = MediaRequestBody(
            mediaType: mediaType,
            mediaId: mediaId,
            tvdbId: mediaType == .tv ? tvdbId : nil,
            seasons: seasonsToRequest,
            seasonsAll: requestAllSeasons,
            is4k: is4K,
            serverId: nil,
            profileId: selectedProfileId,
            rootFolder: nil,
            languageProfileId: nil,
            userId: nil
        )

        submitTask?.cancel()
        submitTask = Task { @MainActor in
            defer { isSubmitting = false }

            do {
                _ = try await repository.createRequest(body: requestBody)
                guard !Task.isCancelled else { return }
                AppLogger.info("CreateRequestView: request created for mediaID \(mediaId) type \(mediaType.rawValue)")
                onSuccess?()
                dismiss()
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.warning("CreateRequestView: failed to create request for mediaID \(mediaId): \(error)")
                errorMessage = mapError(error)
            }
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? SeerrAPIError {
            switch apiError {
            case .unauthorized:
                return "Your session expired. Please sign in again."
            case .conflict(let message):
                return message ?? "A request already exists for this media."
            case .forbidden:
                return "You don't have permission to create this request."
            case .httpError(let statusCode, let message):
                if let message, !message.isEmpty {
                    return message
                }
                return "Server error (\(statusCode))."
            case .networkError:
                return "Unable to submit request. Check your connection."
            default:
                return "Unable to submit request right now."
            }
        }
        return "Unable to submit request right now."
    }
}
