// TVSearchView.swift
// SeerrClientTV (Octopus Explorer)
//
// Milestone 3 Search tab. Reuses the SHARED SearchViewModel / SearchRepository /
// SearchResultItem (identical business logic to iOS) and renders a tvOS-native,
// focus-driven surface:
//   - `.searchable` supplies the tvOS system keyboard AND Siri Remote dictation
//     for free (the mic button dictates into the same field) — no custom keyboard.
//   - Movie/TV filter chips + a 5-wide poster grid with `.card` focus scaling.
//   - Movie/TV posters push to the existing tvOS Media Detail via concrete typed
//     NavigationLink values (keeps the app-wide no-AnyHashable rule).
//   - Infinite scroll via the shared `onItemAppear` pagination trigger.
//
// Follow-up (not in this slice): a "Trending" browse rail on the zero-typing idle
// state (reusing DiscoverRepository) so the couch has something to graze before a
// query is entered.

import SwiftUI

struct TVSearchView: View {
    @Environment(AppState.self) private var appState

    @State private var viewModel: SearchViewModel?
    /// Buffers keystrokes/dictation that arrive before the ViewModel is created.
    @State private var pendingQuery: String = ""

    private let columns = Array(
        repeating: GridItem(.fixed(TVMetrics.compactPosterWidth), spacing: 34),
        count: 5
    )

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.067, blue: 0.11).ignoresSafeArea()
            Group {
                if let viewModel {
                    content(for: viewModel)
                } else {
                    idleState
                }
            }
        }
        .accessibilityIdentifier("tvos.search.screen")
        .searchable(
            text: Binding(
                get: { viewModel?.searchQuery ?? pendingQuery },
                set: { newValue in
                    if viewModel != nil {
                        viewModel?.searchQuery = newValue
                    } else {
                        pendingQuery = newValue
                    }
                }
            ),
            prompt: "Movies, TV shows, people…"
        )
        .task {
            guard viewModel == nil else { return }
            guard let client = appState.apiClient else { return }
            let vm = SearchViewModel(repository: SearchRepository(apiClient: client))
            if !pendingQuery.isEmpty {
                vm.searchQuery = pendingQuery
                pendingQuery = ""
            }
            viewModel = vm
        }
    }

    // MARK: - State-driven content

    @ViewBuilder
    private func content(for vm: SearchViewModel) -> some View {
        switch vm.loadState {
        case .idle:
            idleState
        case .loading:
            VStack(alignment: .leading, spacing: 28) {
                filterChips(vm)
                loadingIndicator
            }
            .padding(.horizontal, TVMetrics.horizontalInset)
            .padding(.vertical, TVMetrics.verticalInset)
        case .loaded:
            loadedState(vm)
        case .empty:
            messageState(vm, message: "No results for \"\(vm.searchQuery)\". Try a different search or filter.", systemImage: "magnifyingglass")
        case .error(let message):
            messageState(vm, message: message, systemImage: "exclamationmark.triangle", retry: true)
        }
    }

    // MARK: - Loaded grid

    private func loadedState(_ vm: SearchViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                filterChips(vm)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 46) {
                    // Key by whole value (SearchResultItem is Hashable): TMDB movie/TV/person
                    // id namespaces overlap, so keying by `.id` alone can collide and corrupt
                    // SwiftUI identity + focus. The shared VM already matches on id+mediaType.
                    ForEach(vm.results, id: \.self) { item in
                        resultCard(item)
                            .onAppear { vm.onItemAppear(item) }
                    }
                    if vm.isLoadingMore {
                        ProgressView()
                    }
                }
                // Local breathing room so the `.card` focus scale isn't clipped by
                // the ScrollView (kept local, not `.scrollClipDisabled()` on shared
                // chrome, to avoid content bleeding under the tab bar).
                .padding(.vertical, 24)
            }
            .padding(.horizontal, TVMetrics.horizontalInset)
            .padding(.vertical, TVMetrics.verticalInset)
        }
    }

    @ViewBuilder
    private func resultCard(_ item: SearchResultItem) -> some View {
        if item.isPerson {
            // No person-detail screen exists (iOS person taps are inert too), but the
            // card must still be focusable or a People-filtered grid can't be scrolled
            // by the remote. An empty-action `.card` button gives the standard focus
            // affordance without navigating anywhere.
            Button(action: {}) {
                TVPersonResultCard(
                    name: item.displayTitle,
                    subtitle: item.knownForDepartment,
                    profilePath: item.profilePath,
                    width: TVMetrics.compactPosterWidth
                )
            }
            .buttonStyle(.card)
            .accessibilityHint("No details available")
            .accessibilityIdentifier("tvos.search.person.\(item.id)")
        } else if item.isMovie {
            NavigationLink(value: MovieNavDestination(id: item.id, title: item.displayTitle)) {
                posterCard(item)
            }
            .buttonStyle(.card)
            .accessibilityIdentifier("tvos.search.card.movie.\(item.id)")
        } else if item.isTv {
            NavigationLink(value: TvNavDestination(id: item.id, title: item.displayTitle)) {
                posterCard(item)
            }
            .buttonStyle(.card)
            .accessibilityIdentifier("tvos.search.card.tv.\(item.id)")
        } else {
            // Unknown media type (multi-search normally returns only movie/tv/person).
            // Still wrap in a focusable inert card so an odd result never blocks grid
            // scrolling — same reasoning as the person branch above.
            Button(action: {}) {
                posterCard(item)
            }
            .buttonStyle(.card)
            .accessibilityIdentifier("tvos.search.card.other.\(item.id)")
        }
    }

    private func posterCard(_ item: SearchResultItem) -> some View {
        TVMediaPosterCard(
            title: item.displayTitle,
            subtitle: item.year,
            posterPath: item.posterPath,
            status: item.mediaInfo?.status,
            width: TVMetrics.compactPosterWidth
        )
    }

    // MARK: - Filter chips

    private func filterChips(_ vm: SearchViewModel) -> some View {
        HStack(spacing: 14) {
            ForEach(SearchType.allCases, id: \.self) { type in
                Button(type.displayName) {
                    vm.selectType(type)
                }
                .buttonStyle(.bordered)
                .tint(vm.selectedType == type ? .accentColor : .white.opacity(0.25))
            }
        }
    }

    // MARK: - Non-result states

    private var idleState: some View {
        VStack(spacing: 22) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 84, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text("Search")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.white)
            Text("Find movies, TV shows, and people to request. Open the search field and use the on-screen keyboard, or hold the mic button on your remote to dictate.")
                .font(.system(size: 27))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: 960)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(TVMetrics.horizontalInset)
    }

    private var loadingIndicator: some View {
        HStack(spacing: 24) {
            ProgressView().scaleEffect(1.8)
            Text("Searching")
                .font(.system(size: 29, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
    }

    private func messageState(_ vm: SearchViewModel, message: String, systemImage: String, retry: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            filterChips(vm)
            VStack(spacing: 24) {
                Image(systemName: systemImage)
                    .font(.system(size: 84, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text(message)
                    .font(.system(size: 29))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: 900)
                if retry {
                    Button("Try Again") {
                        Task { await vm.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        }
        .padding(.horizontal, TVMetrics.horizontalInset)
        .padding(.vertical, TVMetrics.verticalInset)
    }
}

// MARK: - Person result card

private struct TVPersonResultCard: View {
    let name: String
    let subtitle: String?
    let profilePath: String?
    var width: CGFloat

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.12))
                if let url = TMDBImageURL.profile(path: profilePath, size: .h632) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty:
                            ProgressView()
                        default:
                            personFallback
                        }
                    }
                    .clipShape(Circle())
                } else {
                    personFallback
                }
            }
            .frame(width: width, height: width)
            .clipShape(Circle())

            VStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .frame(width: width)
        }
        .frame(width: width, alignment: .top)
    }

    private var personFallback: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 58, weight: .semibold))
            .foregroundStyle(.white.opacity(0.35))
    }
}
