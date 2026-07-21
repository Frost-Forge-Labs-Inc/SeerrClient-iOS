// TVMediaDetailView.swift
// SeerrClientTV (Octopus Explorer)

import SwiftUI

struct TVMovieDetailView: View {
    @Environment(AppState.self) private var appState

    let movieId: Int
    let movieTitle: String

    @State private var viewModel: MovieDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                TVLoadingStateView(title: movieTitle)
            }
        }
        .navigationTitle(movieTitle)
        .task {
            if viewModel == nil {
                guard let client = appState.apiClient else { return }
                let vm = MovieDetailViewModel(
                    movieId: movieId,
                    repository: MediaDetailRepository(apiClient: client),
                    initiallyOnWatchlist: appState.watchlistedTmdbIds.contains(movieId),
                    allowsWatchlistMutations: appState.activeServerCapabilities?.supportsWatchlistWrite ?? false
                )
                vm.onWatchlistChanged = { [weak appState] tmdbId, isNowOnWatchlist in
                    appState?.recordWatchlistMembershipChange(
                        tmdbId: tmdbId,
                        isOnWatchlist: isNowOnWatchlist
                    )
                }
                viewModel = vm
            }
            await viewModel?.loadDetails()
        }
    }

    @ViewBuilder
    private func content(for viewModel: MovieDetailViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            TVLoadingStateView(title: movieTitle)
        case .loaded(let movie):
            loaded(movie, viewModel: viewModel)
        case .error(let message):
            TVMessageStateView(
                title: movieTitle,
                message: message,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Try Again"
            ) {
                Task { await viewModel.retry() }
            }
        }
    }

    private func loaded(_ movie: MovieDetails, viewModel: MovieDetailViewModel) -> some View {
        TVDetailScaffold(
            title: movie.title ?? movieTitle,
            subtitle: TVMediaText.movieSubtitle(movie),
            backdropPath: movie.backdropPath,
            posterPath: movie.posterPath,
            mediaInfo: movie.mediaInfo
        ) {
            TVDetailActionRow(
                requestTitle: TVMediaText.requestButtonTitle(mediaInfo: movie.mediaInfo, isTvShow: false),
                requestEnabled: TVMediaText.canRequest(mediaInfo: movie.mediaInfo, isTvShow: false),
                watchlistEnabled: viewModel.allowsWatchlistMutations,
                isOnWatchlist: viewModel.isOnWatchlist,
                isTogglingWatchlist: viewModel.isTogglingWatchlist,
                requestAction: { viewModel.showRequestSheet = true },
                watchlistAction: { viewModel.toggleWatchlist() }
            )

            TVOverviewSection(overview: movie.overview, tagline: movie.tagline)
            TVMetadataPillRow(items: TVMediaText.movieMetadata(movie))
            TVCastRail(credits: movie.credits)

            if !viewModel.recommendations.isEmpty {
                TVMediaRail(title: "Recommendations", items: viewModel.recommendations)
            }
            if !viewModel.similar.isEmpty {
                TVMediaRail(title: "Similar Movies", items: viewModel.similar)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showRequestSheet },
            set: { viewModel.showRequestSheet = $0 }
        )) {
            TVCreateRequestView(
                mediaType: .movie,
                mediaId: movie.id ?? movieId
            ) {
                Task { await viewModel.retry() }
            }
        }
    }
}

struct TVShowDetailView: View {
    @Environment(AppState.self) private var appState

    let tvId: Int
    let showTitle: String

    @State private var viewModel: TvShowDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                TVLoadingStateView(title: showTitle)
            }
        }
        .navigationTitle(showTitle)
        .task {
            if viewModel == nil {
                guard let client = appState.apiClient else { return }
                let vm = TvShowDetailViewModel(
                    tvId: tvId,
                    repository: MediaDetailRepository(apiClient: client),
                    initiallyOnWatchlist: appState.watchlistedTmdbIds.contains(tvId),
                    allowsWatchlistMutations: appState.activeServerCapabilities?.supportsWatchlistWrite ?? false
                )
                vm.onWatchlistChanged = { [weak appState] tmdbId, isNowOnWatchlist in
                    appState?.recordWatchlistMembershipChange(
                        tmdbId: tmdbId,
                        isOnWatchlist: isNowOnWatchlist
                    )
                }
                viewModel = vm
            }
            await viewModel?.loadDetails()
        }
    }

    @ViewBuilder
    private func content(for viewModel: TvShowDetailViewModel) -> some View {
        switch viewModel.detailState {
        case .idle, .loading:
            TVLoadingStateView(title: showTitle)
        case .loaded(let tvShow):
            loaded(tvShow, viewModel: viewModel)
        case .error(let message):
            TVMessageStateView(
                title: showTitle,
                message: message,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Try Again"
            ) {
                Task { await viewModel.retryDetails() }
            }
        }
    }

    private func loaded(_ tvShow: TvDetails, viewModel: TvShowDetailViewModel) -> some View {
        TVDetailScaffold(
            title: tvShow.name ?? showTitle,
            subtitle: TVMediaText.tvSubtitle(tvShow),
            backdropPath: tvShow.backdropPath,
            posterPath: tvShow.posterPath,
            mediaInfo: tvShow.mediaInfo
        ) {
            TVDetailActionRow(
                requestTitle: TVMediaText.requestButtonTitle(mediaInfo: tvShow.mediaInfo, isTvShow: true),
                requestEnabled: TVMediaText.canRequest(mediaInfo: tvShow.mediaInfo, isTvShow: true),
                watchlistEnabled: viewModel.allowsWatchlistMutations,
                isOnWatchlist: viewModel.isOnWatchlist,
                isTogglingWatchlist: viewModel.isTogglingWatchlist,
                requestAction: { viewModel.showRequestSheet = true },
                watchlistAction: { viewModel.toggleWatchlist() }
            )

            TVOverviewSection(overview: tvShow.overview, tagline: tvShow.tagline)
            TVMetadataPillRow(items: TVMediaText.tvMetadata(tvShow))
            TVCastRail(credits: tvShow.credits)

            if let seasons = tvShow.seasons, !seasons.isEmpty {
                TVSeasonSection(seasons: seasons, viewModel: viewModel)
            }
            if !viewModel.recommendations.isEmpty {
                TVMediaRail(title: "Recommendations", items: viewModel.recommendations)
            }
            if !viewModel.similar.isEmpty {
                TVMediaRail(title: "Similar Shows", items: viewModel.similar)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showRequestSheet },
            set: { viewModel.showRequestSheet = $0 }
        )) {
            TVCreateRequestView(
                mediaType: .tv,
                mediaId: tvShow.id ?? tvId,
                tvdbId: tvShow.externalIds?.tvdbId,
                seasons: tvShow.seasons,
                mediaInfo: tvShow.mediaInfo
            ) {
                Task { await viewModel.retryDetails() }
            }
        }
    }
}

private struct TVDetailScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    let backdropPath: String?
    let posterPath: String?
    let mediaInfo: MediaInfo?
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.067, blue: 0.11).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    hero
                    content
                }
                .padding(.horizontal, TVMetrics.horizontalInset)
                .padding(.vertical, 36)
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: TVMetrics.cornerRadius)
                .fill(Color.white.opacity(0.08))
                .frame(height: 620)
                .overlay {
                    if let url = TMDBImageURL.backdrop(path: backdropPath, size: .w1280) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Image(systemName: "film.stack")
                                    .font(.system(size: 90, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.25))
                            }
                        }
                    }
                }
                .overlay {
                    LinearGradient(
                        colors: [.clear, Color(red: 0.05, green: 0.067, blue: 0.11).opacity(0.98)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))

            HStack(alignment: .bottom, spacing: 34) {
                TVPosterImage(posterPath: posterPath)

                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.system(size: 68, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 29, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    if let status = mediaInfo?.status,
                       let code = MediaStatusCode(rawValue: status),
                       code.showsBadge {
                        Text(code.label)
                            .font(.system(size: 23, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(TVMediaText.statusColor(code), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 18)
            }
            .padding(38)
        }
    }
}

private struct TVPosterImage: View {
    let posterPath: String?

    var body: some View {
        RoundedRectangle(cornerRadius: TVMetrics.cornerRadius)
            .fill(Color.white.opacity(0.14))
            .frame(width: 260, height: 390)
            .overlay {
                if let url = TMDBImageURL.poster(path: posterPath, size: .w500) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            fallback
                        }
                    }
                } else {
                    fallback
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }

    private var fallback: some View {
        Image(systemName: "film")
            .font(.system(size: 64, weight: .semibold))
            .foregroundStyle(.white.opacity(0.38))
    }
}

private struct TVDetailActionRow: View {
    let requestTitle: String
    let requestEnabled: Bool
    let watchlistEnabled: Bool
    let isOnWatchlist: Bool
    let isTogglingWatchlist: Bool
    let requestAction: () -> Void
    let watchlistAction: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Button {
                requestAction()
            } label: {
                Label(requestTitle, systemImage: requestEnabled ? "plus.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 29, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!requestEnabled)

            if watchlistEnabled {
                Button {
                    watchlistAction()
                } label: {
                    if isTogglingWatchlist {
                        HStack {
                            ProgressView()
                            Text("Updating")
                        }
                        .font(.system(size: 27, weight: .semibold))
                    } else {
                        Label(
                            isOnWatchlist ? "Remove Bookmark" : "Add Bookmark",
                            systemImage: isOnWatchlist ? "bookmark.fill" : "bookmark"
                        )
                        .font(.system(size: 27, weight: .semibold))
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct TVOverviewSection: View {
    let overview: String?
    let tagline: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            Text(overview?.isEmpty == false ? overview! : "No overview is available.")
                .font(.system(size: 27, weight: .regular))
                .foregroundStyle(.white.opacity(0.68))
                .lineSpacing(6)
                .frame(maxWidth: 1160, alignment: .leading)
        }
    }
}

private struct TVMetadataPillRow: View {
    let items: [(String, String)]

    var body: some View {
        HStack(spacing: 18) {
            ForEach(items, id: \.0) { title, value in
                TVInfoPill(title: title, value: value)
            }
        }
    }
}

private struct TVCastRail: View {
    let credits: Credits?

    private var cast: [Cast] {
        Array((credits?.cast ?? []).prefix(12))
    }

    var body: some View {
        if !cast.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cast")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 28) {
                        ForEach(Array(cast.enumerated()), id: \.offset) { _, member in
                            VStack(spacing: 12) {
                                TVProfileImage(path: member.profilePath)
                                Text(member.name ?? "Unknown")
                                    .font(.system(size: 23, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .frame(width: 180)
                                if let character = member.character, !character.isEmpty {
                                    Text(character)
                                        .font(.system(size: 19, weight: .regular))
                                        .foregroundStyle(.white.opacity(0.56))
                                        .lineLimit(1)
                                        .frame(width: 180)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }
}

private struct TVProfileImage: View {
    let path: String?

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 150, height: 150)
            .overlay {
                if let url = TMDBImageURL.profile(path: path, size: .w185) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .font(.system(size: 54, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.42))
                        }
                    }
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            .clipShape(Circle())
    }
}

private struct TVSeasonSection: View {
    let seasons: [Season]
    let viewModel: TvShowDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Text("Seasons")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(Array(seasons.enumerated()), id: \.offset) { _, season in
                            let number = season.seasonNumber ?? 0
                            Button(season.name ?? "Season \(number)") {
                                viewModel.selectedSeasonNumber = number
                            }
                            .buttonStyle(.bordered)
                            .tint(viewModel.selectedSeasonNumber == number ? .accentColor : .white.opacity(0.25))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            switch viewModel.seasonState {
            case .loaded(let season):
                TVEpisodeRail(season: season)
            case .loading:
                HStack(spacing: 16) {
                    ProgressView()
                    Text("Loading episodes")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                }
                .frame(maxWidth: .infinity, minHeight: 170)
            case .error(let message):
                TVMessageInline(message: message) {
                    Task { await viewModel.retrySeason() }
                }
            case .idle:
                EmptyView()
            }
        }
    }
}

private struct TVEpisodeRail: View {
    let season: Season

    var body: some View {
        if let episodes = season.episodes, !episodes.isEmpty {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 28) {
                    ForEach(Array(episodes.enumerated()), id: \.offset) { _, episode in
                        VStack(alignment: .leading, spacing: 10) {
                            RoundedRectangle(cornerRadius: TVMetrics.cornerRadius)
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 320, height: 180)
                                .overlay {
                                    if let url = TMDBImageURL.still(path: episode.stillPath, size: .w300) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            default:
                                                Image(systemName: "play.rectangle")
                                                    .font(.system(size: 52, weight: .semibold))
                                                    .foregroundStyle(.white.opacity(0.35))
                                            }
                                        }
                                    } else {
                                        Image(systemName: "play.rectangle")
                                            .font(.system(size: 52, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.35))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))

                            Text("Episode \(episode.episodeNumber ?? 0)")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(.white.opacity(0.52))
                            Text(episode.name ?? "Untitled")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .frame(width: 320, alignment: .leading)
                        }
                        .frame(width: 320, alignment: .topLeading)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }
}

private struct TVMediaRail: View {
    let title: String
    let items: [DiscoverMediaItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            ScrollView(.horizontal) {
                LazyHStack(spacing: TVMetrics.railSpacing) {
                    ForEach(items) { item in
                        if item.isMovie {
                            NavigationLink(value: MovieNavDestination(id: item.effectiveTmdbId, title: item.displayTitle)) {
                                poster(item)
                            }
                            .buttonStyle(.card)
                        } else if item.isTv {
                            NavigationLink(value: TvNavDestination(id: item.effectiveTmdbId, title: item.displayTitle)) {
                                poster(item)
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func poster(_ item: DiscoverMediaItem) -> some View {
        TVMediaPosterCard(
            title: item.displayTitle,
            subtitle: item.year,
            posterPath: item.posterPath,
            status: item.mediaInfo?.status
        )
    }
}

private struct TVMessageInline: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .semibold))
            Text(message)
                .font(.system(size: 25, weight: .medium))
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
        .foregroundStyle(.white.opacity(0.72))
        .padding(24)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }
}

private struct TVCreateRequestView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let mediaType: MediaRequestMediaType
    let mediaId: Int
    var tvdbId: Int? = nil
    var seasons: [Season]? = nil
    var mediaInfo: MediaInfo? = nil
    var onSuccess: (@MainActor () -> Void)? = nil

    @State private var repository: RequestRepository?
    @State private var is4K = false
    @State private var allSeasons = true
    @State private var selectedSeasonNumbers = Set<Int>()
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var qualityProfiles: [ServiceProfile] = []
    @State private var selectedProfileId: Int?

    var body: some View {
        TVScreenScaffold(title: "Create Request", subtitle: mediaType == .tv ? "TV show" : "Movie") {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 18) {
                    Button {
                        is4K.toggle()
                    } label: {
                        Label(is4K ? "4K Enabled" : "Standard Quality", systemImage: is4K ? "4k.tv.fill" : "tv")
                    }
                    .buttonStyle(.bordered)
                    .tint(is4K ? .accentColor : .white.opacity(0.25))

                    if !qualityProfiles.isEmpty {
                        Menu(selectedProfileName) {
                            Button("Server Default") { selectedProfileId = nil }
                            ForEach(qualityProfiles, id: \.id) { profile in
                                Button(profile.name ?? "Profile \(profile.id ?? 0)") {
                                    selectedProfileId = profile.id
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if mediaType == .tv {
                    tvSeasonOptions
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: 980, alignment: .leading)
                }

                HStack(spacing: 18) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        submitRequest()
                    } label: {
                        if isSubmitting {
                            HStack {
                                ProgressView()
                                Text("Submitting")
                            }
                        } else {
                            Label("Submit Request", systemImage: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitDisabled)
                }
            }
        }
        .task {
            guard repository == nil, let client = appState.apiClient else { return }
            let repo = RequestRepository(apiClient: client)
            repository = repo
            do {
                qualityProfiles = try await mediaType == .movie
                    ? repo.fetchRadarrProfiles()
                    : repo.fetchSonarrProfiles()
            } catch {
                AppLogger.warning("TVCreateRequestView: quality profiles fetch failed for \(mediaType.rawValue): \(error)")
            }
        }
        .onAppear {
            if mediaType == .tv && !requestableSeasonNumbers.isEmpty && hasAnyRequestedOrAvailableSeasons {
                allSeasons = false
            }
        }
    }

    private var tvSeasonOptions: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Seasons")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)

            if requestableSeasonNumbers.isEmpty && hasAnyRequestedOrAvailableSeasons {
                Text("All seasons have already been requested or are available.")
                    .font(.system(size: 25))
                    .foregroundStyle(.white.opacity(0.62))
            } else {
                if !hasAnyRequestedOrAvailableSeasons {
                    Button {
                        allSeasons.toggle()
                    } label: {
                        Label(allSeasons ? "All Seasons" : "Selected Seasons", systemImage: allSeasons ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(allSeasons ? .accentColor : .white.opacity(0.25))
                }

                if hasAnyRequestedOrAvailableSeasons || !allSeasons {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(210), spacing: 16), count: 4),
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(availableSeasonNumbers, id: \.self) { number in
                            seasonButton(number)
                        }
                    }
                }
            }
        }
    }

    private func seasonButton(_ number: Int) -> some View {
        let availability = seasonStatus(for: number)
        return Button {
            guard availability == .requestable else { return }
            toggleSeason(number)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Season \(number)")
                    .font(.system(size: 24, weight: .bold))
                Text(label(for: availability, seasonNumber: number))
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(width: 170, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .tint(selectedSeasonNumbers.contains(number) ? .accentColor : .white.opacity(0.25))
        .disabled(availability != .requestable)
    }

    private var selectedProfileName: String {
        guard let selectedProfileId else { return "Server Default" }
        return qualityProfiles.first { $0.id == selectedProfileId }?.name ?? "Profile \(selectedProfileId)"
    }

    private enum SeasonAvailability {
        case available
        case partiallyAvailable
        case requested
        case pending
        case requestable
    }

    private func seasonStatus(for seasonNumber: Int) -> SeasonAvailability {
        if let mediaSeasons = mediaInfo?.seasons,
           let mediaSeason = mediaSeasons.first(where: { $0.seasonNumber == seasonNumber }) {
            switch mediaSeason.status {
            case 5: return .available
            case 4: return .partiallyAvailable
            default: break
            }
        }

        if let requests = mediaInfo?.requests {
            for request in requests where request.status != 3 {
                if request.seasons?.contains(where: { $0.seasonNumber == seasonNumber }) == true {
                    return request.status == 1 ? .pending : .requested
                }
            }
        }

        return .requestable
    }

    private func label(for status: SeasonAvailability, seasonNumber: Int) -> String {
        switch status {
        case .available: return "Available"
        case .partiallyAvailable: return "Partial"
        case .requested: return "Requested"
        case .pending: return "Pending"
        case .requestable:
            return selectedSeasonNumbers.contains(seasonNumber) ? "Selected" : "Requestable"
        }
    }

    private var availableSeasonNumbers: [Int] {
        let numbers = (seasons ?? [])
            .compactMap { $0.seasonNumber }
            .filter { $0 > 0 }
        return Array(Set(numbers)).sorted()
    }

    private var hasAnyRequestedOrAvailableSeasons: Bool {
        availableSeasonNumbers.contains { seasonStatus(for: $0) != .requestable }
    }

    private var requestableSeasonNumbers: [Int] {
        availableSeasonNumbers.filter { seasonStatus(for: $0) == .requestable }
    }

    private var isSubmitDisabled: Bool {
        if isSubmitting || repository == nil {
            return true
        }
        if mediaType == .tv {
            if tvdbId == nil || requestableSeasonNumbers.isEmpty {
                return true
            }
            if hasAnyRequestedOrAvailableSeasons {
                return selectedSeasonNumbers.isEmpty
            }
            if !allSeasons {
                return selectedSeasonNumbers.isEmpty
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
                let selected = selectedSeasonNumbers.sorted()
                guard !selected.isEmpty else {
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
                guard !selected.isEmpty else {
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

        let body = MediaRequestBody(
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

        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                _ = try await repository.createRequest(body: body)
                AppLogger.info("TVCreateRequestView: request created for mediaID \(mediaId) type \(mediaType.rawValue)")
                onSuccess?()
                dismiss()
            } catch {
                AppLogger.warning("TVCreateRequestView: failed to create request for mediaID \(mediaId): \(error)")
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

private enum TVMediaText {
    static func movieSubtitle(_ movie: MovieDetails) -> String? {
        [year(movie.releaseDate), movie.runtime.map { "\($0) min" }, rating(movie.voteAverage)]
            .compactMap { $0 }
            .joined(separator: "  |  ")
            .nilIfEmpty
    }

    static func tvSubtitle(_ tvShow: TvDetails) -> String? {
        let seasonsAndEpisodes: String? = {
            guard let seasons = tvShow.numberOfSeason, let episodes = tvShow.numberOfEpisodes else { return nil }
            return "\(seasons) seasons, \(episodes) episodes"
        }()
        return [year(tvShow.firstAirDate), seasonsAndEpisodes, rating(tvShow.voteAverage)]
            .compactMap { $0 }
            .joined(separator: "  |  ")
            .nilIfEmpty
    }

    static func movieMetadata(_ movie: MovieDetails) -> [(String, String)] {
        [
            ("Status", movie.status ?? "Unknown"),
            ("Released", SeerrDateFormatter.displayDate(movie.releaseDate)),
            ("Genres", genreList(movie.genres))
        ]
    }

    static func tvMetadata(_ tvShow: TvDetails) -> [(String, String)] {
        [
            ("Status", tvShow.status ?? "Unknown"),
            ("First Aired", SeerrDateFormatter.displayDate(tvShow.firstAirDate)),
            ("Genres", genreList(tvShow.genres))
        ]
    }

    static func requestButtonTitle(mediaInfo: MediaInfo?, isTvShow: Bool) -> String {
        guard let code = mediaInfo?.status.flatMap(MediaStatusCode.init(rawValue:)) else {
            return "Request"
        }
        switch code {
        case .available:
            return "Available"
        case .pending:
            return isTvShow ? "Request More" : "Pending"
        case .processing:
            return isTvShow ? "Request More" : "Requested"
        case .partiallyAvailable:
            return "Request More"
        case .unknown, .deleted:
            return "Request"
        }
    }

    static func canRequest(mediaInfo: MediaInfo?, isTvShow: Bool) -> Bool {
        guard let code = mediaInfo?.status.flatMap(MediaStatusCode.init(rawValue:)) else {
            return true
        }
        switch code {
        case .available:
            return false
        case .pending, .processing:
            return isTvShow
        case .partiallyAvailable:
            return true
        case .unknown, .deleted:
            return true
        }
    }

    static func statusColor(_ code: MediaStatusCode) -> Color {
        switch code {
        case .available:
            return .green
        case .pending, .partiallyAvailable:
            return .orange
        case .processing:
            return .purple
        case .unknown, .deleted:
            return .gray
        }
    }

    private static func year(_ date: String?) -> String? {
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    private static func rating(_ voteAverage: Double?) -> String? {
        guard let voteAverage else { return nil }
        return String(format: "%.1f", voteAverage)
    }

    private static func genreList(_ genres: [Genre]?) -> String {
        let names = (genres ?? []).compactMap(\.name)
        return names.isEmpty ? "Unknown" : names.prefix(3).joined(separator: ", ")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
