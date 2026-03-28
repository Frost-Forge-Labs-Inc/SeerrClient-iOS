// CreateRequestView.swift
// SeerrClient
//
// Sheet form used to submit a new media request.

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
    let onSuccess: (@MainActor () -> Void)?

    // MARK: - State

    @State private var repository: RequestRepository?
    @State private var is4K = false
    @State private var allSeasons = true
    @State private var selectedSeasonNumbers = Set<Int>()
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var submitTask: Task<Void, Never>?

    // MARK: - Init

    init(
        mediaType: MediaRequestMediaType,
        mediaId: Int,
        tvdbId: Int? = nil,
        seasons: [Season]? = nil,
        onSuccess: (@MainActor () -> Void)? = nil
    ) {
        self.mediaType = mediaType
        self.mediaId = mediaId
        self.tvdbId = tvdbId
        self.seasons = seasons
        self.onSuccess = onSuccess
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Form {
                Section("Request Options") {
                    Toggle("Request in 4K", isOn: $is4K)
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
            repository = RequestRepository(apiClient: client)
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
            Toggle("All Seasons", isOn: $allSeasons)

            if !allSeasons {
                if availableSeasonNumbers.isEmpty {
                    Text("No seasons available for selection.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableSeasonNumbers, id: \.self) { seasonNumber in
                        Button {
                            toggleSeason(seasonNumber)
                        } label: {
                            HStack {
                                Text("Season \(seasonNumber)")
                                Spacer()
                                if selectedSeasonNumbers.contains(seasonNumber) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.accent)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
            if !allSeasons && selectedSeasonNumbers.isEmpty {
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

        if mediaType == .tv, !allSeasons, selectedSeasonNumbers.isEmpty {
            errorMessage = "Select at least one season, or choose All Seasons."
            return
        }

        isSubmitting = true
        errorMessage = nil

        let requestBody = MediaRequestBody(
            mediaType: mediaType,
            mediaId: mediaId,
            tvdbId: mediaType == .tv ? tvdbId : nil,
            seasons: mediaType == .tv && !allSeasons ? selectedSeasonNumbers.sorted() : nil,
            seasonsAll: mediaType == .tv ? allSeasons : nil,
            is4k: is4K,
            serverId: nil,
            profileId: nil,
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
