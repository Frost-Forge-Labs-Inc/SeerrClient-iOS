// TvShowDetailView.swift
// SeerrClient
//
// Full detail screen for a TV show. Shows hero backdrop+poster, metadata,
// cast carousel, season picker, episode list, and request button.
// Uses dual state machines: one for show details, one for season episodes.

import SwiftUI

// MARK: - TvShowDetailView

/// Full TV show detail screen accessible from Discover and Search.
struct TvShowDetailView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState

    /// The TMDB TV show ID to load.
    let tvId: Int
    /// The show title for the navigation bar (known before detail loads).
    let showTitle: String

    // MARK: - State

    @State private var viewModel: TvShowDetailViewModel?

    #if DEBUG
    /// The stable destination for the season picker and episode list.
    private static let screenshotDemoEpisodesSectionID = "screenshot-demo-episodes-section"

    /// Limits automatic screenshot-demo scrolls so they do not override user interaction.
    @State private var screenshotDemoEpisodesScrollAttempts = 0
    #endif

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                contentForState(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(showTitle)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
            if let vm = viewModel, vm.tvShow != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Request") {
                        vm.showRequestSheet = true
                    }
                    .accessibilityLabel("Request this media")
                }
                if vm.allowsWatchlistMutations {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            vm.toggleWatchlist()
                        } label: {
                            if vm.isTogglingWatchlist {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: vm.isOnWatchlist ? "bookmark.fill" : "bookmark")
                                    .symbolRenderingMode(.hierarchical)
                            }
                        }
                        .accessibilityLabel(vm.isOnWatchlist ? "Remove from Watchlist" : "Add to Watchlist")
                        .accessibilityIdentifier("tv-detail.watchlist-button")
                    }
                }
            }
            #else
            if let vm = viewModel, vm.tvShow != nil, vm.allowsWatchlistMutations {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        vm.toggleWatchlist()
                    } label: {
                        if vm.isTogglingWatchlist {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: vm.isOnWatchlist ? "bookmark.fill" : "bookmark")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                    .accessibilityLabel(vm.isOnWatchlist ? "Remove from Watchlist" : "Add to Watchlist")
                    .accessibilityIdentifier("tv-detail.watchlist-button")
                }
            }
            #endif
        }
        .task {
            if viewModel == nil {
                guard let client = appState.apiClient else { return }
                let repo = MediaDetailRepository(apiClient: client)
                let vm = TvShowDetailViewModel(
                    tvId: tvId,
                    repository: repo,
                    initiallyOnWatchlist: appState.watchlistedTmdbIds.contains(tvId),
                    allowsWatchlistMutations: appState.activeServerCapabilities?.supportsWatchlistWrite ?? false
                )
                // Keep AppState.watchlistedTmdbIds in sync when the user taps the bookmark.
                vm.onWatchlistChanged = { [weak appState] tmdbId, isNowOnWatchlist in
                    appState?.recordWatchlistMembershipChange(
                        tmdbId: tmdbId,
                        isOnWatchlist: isNowOnWatchlist
                    )
                }
                viewModel = vm
            }
            await viewModel?.loadDetails()
#if DEBUG
            if ScreenshotDemoConfiguration.current.isEnabled,
               ScreenshotDemoConfiguration.current.scene == .requestFlow {
                viewModel?.showRequestSheet = true
            }
#endif
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private func contentForState(_ vm: TvShowDetailViewModel) -> some View {
        switch vm.detailState {
        case .idle, .loading:
            loadingContent

        case .loaded(let tvShow):
            loadedContent(tvShow, vm: vm)

        case .error(let message):
            errorContent(message: message, vm: vm)
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.platformFill)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay { ShimmerView() }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.platformFill)
                            .frame(height: 14)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ tvShow: TvDetails, vm: TvShowDetailViewModel) -> some View {
        #if os(macOS)
        GeometryReader { geo in
            if geo.size.width >= 900 {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            MediaDetailHeroView(
                                backdropPath: tvShow.backdropPath,
                                posterPath: tvShow.posterPath,
                                mediaInfo: tvShow.mediaInfo
                            )
                            tvMetadata(tvShow)
                            RequestButtonView(
                                mediaInfo: tvShow.mediaInfo,
                                isTvShow: true,
                                showRequestSheet: Binding(
                                    get: { vm.showRequestSheet },
                                    set: { vm.showRequestSheet = $0 }
                                ),
                                activeRequestId: tvShow.mediaInfo?.requests?.first { $0.status == 1 || $0.status == 2 }?.id
                            )
                            Spacer(minLength: 40)
                        }
                    }
                    .frame(minWidth: 380, idealWidth: 440, maxWidth: 520)

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            CastCarouselView(credits: tvShow.credits)
                            if let seasons = tvShow.seasons, !seasons.isEmpty {
                                seasonSection(seasons: seasons, vm: vm)
                            }
                            if !vm.recommendations.isEmpty {
                                MediaHorizontalRowView(title: "Recommendations", items: vm.recommendations)
                            }
                            if !vm.similar.isEmpty {
                                MediaHorizontalRowView(title: "Similar Shows", items: vm.similar)
                            }
                            Spacer(minLength: 40)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                singleColumnLoadedContent(tvShow, vm: vm)
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.showRequestSheet },
            set: { vm.showRequestSheet = $0 }
        )) {
            CreateRequestView(
                mediaType: .tv,
                mediaId: tvShow.id ?? tvId,
                tvdbId: tvShow.externalIds?.tvdbId,
                seasons: tvShow.seasons,
                mediaInfo: tvShow.mediaInfo
            ) {
                Task { await vm.retryDetails() }
            }
            .frame(width: 480, height: 620)
        }
        #else
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero
                    MediaDetailHeroView(
                        backdropPath: tvShow.backdropPath,
                        posterPath: tvShow.posterPath,
                        mediaInfo: tvShow.mediaInfo
                    )

                    // Metadata
                    let firstYear = tvShow.firstAirDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
                    let endYear: String? = {
                        // For shows still in production, show "Present".
                        // For shows that have ended (Ended, Canceled, etc.) show the last air year.
                        if tvShow.inProduction == true {
                            return "Present"
                        }
                        // Treat any non-in-production show with a lastAirDate as ended.
                        return tvShow.lastAirDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
                    }()
                    let runtime: String? = {
                        if let eps = tvShow.numberOfEpisodes, let seasons = tvShow.numberOfSeason {
                            let seasonLabel = seasons == 1 ? "season" : "seasons"
                            let episodeLabel = eps == 1 ? "episode" : "episodes"
                            return "\(seasons) \(seasonLabel), \(eps) \(episodeLabel)"
                        }
                        return nil
                    }()

                    MediaMetadataView(
                        title: tvShow.name ?? showTitle,
                        tagline: tvShow.tagline,
                        overview: tvShow.overview,
                        year: firstYear,
                        endYear: endYear,
                        runtime: runtime,
                        rating: tvShow.voteAverage,
                        genres: tvShow.genres,
                        status: tvShow.status
                    )

                    // Cast
                    CastCarouselView(credits: tvShow.credits)

                    // Season Picker + Episodes
                    if let seasons = tvShow.seasons, !seasons.isEmpty {
                        #if DEBUG
                        seasonSection(seasons: seasons, vm: vm)
                            .id(Self.screenshotDemoEpisodesSectionID)
                        #else
                        seasonSection(seasons: seasons, vm: vm)
                        #endif
                    }

                    // Recommendations
                    if !vm.recommendations.isEmpty {
                        MediaHorizontalRowView(title: "Recommendations", items: vm.recommendations)
                    }

                    // Similar Shows
                    if !vm.similar.isEmpty {
                        MediaHorizontalRowView(title: "Similar Shows", items: vm.similar)
                    }

                    // Request Button
                    RequestButtonView(
                        mediaInfo: tvShow.mediaInfo,
                        isTvShow: true,
                        showRequestSheet: Binding(
                            get: { vm.showRequestSheet },
                            set: { vm.showRequestSheet = $0 }
                        ),
                        activeRequestId: tvShow.mediaInfo?.requests?.first { $0.status == 1 || $0.status == 2 }?.id
                    )

                    Spacer(minLength: 40)
                }
            }
            #if DEBUG
            .onChange(of: vm.season) { _, season in
                guard season != nil,
                      ScreenshotDemoConfiguration.current.isEnabled,
                      ScreenshotDemoConfiguration.current.scrollAnchor == .episodes,
                      screenshotDemoEpisodesScrollAttempts == 0 else { return }

                screenshotDemoEpisodesScrollAttempts = 1
                withAnimation(nil) {
                    proxy.scrollTo(Self.screenshotDemoEpisodesSectionID, anchor: .top)
                }

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)

                    guard screenshotDemoEpisodesScrollAttempts == 1 else { return }

                    screenshotDemoEpisodesScrollAttempts = 2
                    withAnimation(nil) {
                        proxy.scrollTo(Self.screenshotDemoEpisodesSectionID, anchor: .top)
                    }
                }
            }
            #endif
        }
        .sheet(isPresented: Binding(
            get: { vm.showRequestSheet },
            set: { vm.showRequestSheet = $0 }
        )) {
            CreateRequestView(
                mediaType: .tv,
                mediaId: tvShow.id ?? tvId,
                tvdbId: tvShow.externalIds?.tvdbId,
                seasons: tvShow.seasons,
                mediaInfo: tvShow.mediaInfo
            ) {
                Task { await vm.retryDetails() }
            }
            .presentationDetents(Self.requestSheetDetents)
        }
        #endif
    }

    /// The request sheet detents. Screenshot Demo Mode pins iPad to the large
    /// detent so the full season list and submit action stay in frame.
    private static var requestSheetDetents: Set<PresentationDetent> {
#if DEBUG
        if ScreenshotDemoConfiguration.current.isEnabled,
           UIDevice.current.userInterfaceIdiom == .pad {
            return [.large]
        }
#endif
        return [.medium, .large]
    }

    #if os(macOS)
    @ViewBuilder
    private func singleColumnLoadedContent(_ tvShow: TvDetails, vm: TvShowDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MediaDetailHeroView(
                    backdropPath: tvShow.backdropPath,
                    posterPath: tvShow.posterPath,
                    mediaInfo: tvShow.mediaInfo
                )
                tvMetadata(tvShow)
                CastCarouselView(credits: tvShow.credits)
                if let seasons = tvShow.seasons, !seasons.isEmpty {
                    seasonSection(seasons: seasons, vm: vm)
                }
                if !vm.recommendations.isEmpty {
                    MediaHorizontalRowView(title: "Recommendations", items: vm.recommendations)
                }
                if !vm.similar.isEmpty {
                    MediaHorizontalRowView(title: "Similar Shows", items: vm.similar)
                }
                RequestButtonView(
                    mediaInfo: tvShow.mediaInfo,
                    isTvShow: true,
                    showRequestSheet: Binding(
                        get: { vm.showRequestSheet },
                        set: { vm.showRequestSheet = $0 }
                    ),
                    activeRequestId: tvShow.mediaInfo?.requests?.first { $0.status == 1 || $0.status == 2 }?.id
                )
                Spacer(minLength: 40)
            }
        }
    }

    @ViewBuilder
    private func tvMetadata(_ tvShow: TvDetails) -> some View {
        let firstYear = tvShow.firstAirDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
        let endYear: String? = {
            if tvShow.inProduction == true {
                return "Present"
            }
            return tvShow.lastAirDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
        }()
        let runtime: String? = {
            if let eps = tvShow.numberOfEpisodes, let seasons = tvShow.numberOfSeason {
                let seasonLabel = seasons == 1 ? "season" : "seasons"
                let episodeLabel = eps == 1 ? "episode" : "episodes"
                return "\(seasons) \(seasonLabel), \(eps) \(episodeLabel)"
            }
            return nil
        }()

        MediaMetadataView(
            title: tvShow.name ?? showTitle,
            tagline: tvShow.tagline,
            overview: tvShow.overview,
            year: firstYear,
            endYear: endYear,
            runtime: runtime,
            rating: tvShow.voteAverage,
            genres: tvShow.genres,
            status: tvShow.status
        )
    }
    #endif

    // MARK: - Season Section

    @ViewBuilder
    private func seasonSection(seasons: [Season], vm: TvShowDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Season Picker
            HStack {
                Text("Season")
                    .font(.title3.bold())

                Spacer()

                Picker("Season", selection: Binding(
                    get: { vm.selectedSeasonNumber },
                    set: { vm.selectedSeasonNumber = $0 }
                )) {
                    ForEach(seasons, id: \.seasonNumber) { season in
                        Text(season.name ?? "Season \(season.seasonNumber ?? 0)")
                            .tag(season.seasonNumber ?? 0)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)

            // Episode List
            if let loadedSeason = vm.season {
                EpisodeListView(season: loadedSeason, loadState: vm.seasonState)
            } else {
                switch vm.seasonState {
                case .loading:
                    ProgressView("Loading episodes...")
                        .frame(maxWidth: .infinity)
                        .padding()
                case .error(let message):
                    VStack(spacing: 8) {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await vm.retrySeason() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private func errorContent(message: String, vm: TvShowDetailViewModel) -> some View {
        ContentUnavailableView {
            Label("Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await vm.retryDetails() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
