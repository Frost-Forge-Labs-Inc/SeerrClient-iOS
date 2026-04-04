// DiscoverSliderView.swift
// SeerrClient
//
// A single horizontal content row on the Discover screen. Shows a section
// header with the slider title and a horizontally-scrolling list of media cards.

import SwiftUI

// MARK: - DiscoverSliderView

/// Displays a single discover slider row with a title header and a horizontal
/// scroll of media cards.
///
/// Usage:
/// ```swift
/// DiscoverSliderView(content: sliderContent)
/// ```
struct DiscoverSliderView: View {

    /// The resolved content for this slider row.
    let content: SliderContent

    /// Size of the media cards in this row.
    var cardSize: MediaCardSize = .medium

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection
            cardScrollView
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text(content.displayTitle)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Spacer()

            // "See All" button — disabled until Week 5 paginated grid view.
            if content.totalPages > 1 {
                Button("See All") {
                    // Week 5+ — navigate to paginated grid view
                }
                .font(.subheadline.weight(.medium))
                .disabled(true)
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Card Scroll

    @ViewBuilder
    private var cardScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(content.items) { item in
                    if item.isMovie {
                        NavigationLink(value: MovieNavDestination(id: item.id, title: item.displayTitle)) {
                            MediaCardView(item: item, size: cardSize)
                        }
                        .buttonStyle(MediaCardNavigationStyle())
                    } else if item.isTv {
                        NavigationLink(value: TvNavDestination(id: item.id, title: item.displayTitle)) {
                            MediaCardView(item: item, size: cardSize)
                        }
                        .buttonStyle(MediaCardNavigationStyle())
                    } else {
                        MediaCardView(item: item, size: cardSize)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Skeleton Slider

/// Placeholder skeleton for a slider row, shown during initial loading.
struct SkeletonSliderView: View {

    var cardSize: MediaCardSize = .medium

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 140, height: 20)
                .padding(.horizontal)

            // Card skeletons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: cardSize.width, height: cardSize.posterHeight)
                                .overlay { ShimmerView() }
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                                .frame(width: cardSize.width * 0.8, height: 12)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray6))
                                .frame(width: cardSize.width * 0.4, height: 10)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Previews

#Preview("Slider Row") {
    let items = (1...10).map { i in
        DiscoverMediaItem(
            id: i,
            tmdbId: nil,
            mediaType: "movie",
            title: "Movie \(i)",
            name: nil,
            posterPath: nil,
            backdropPath: nil,
            overview: nil,
            voteAverage: Double.random(in: 5...9),
            releaseDate: "2024-0\(min(i, 9))-15",
            firstAirDate: nil,
            genreIds: nil,
            mediaInfo: nil
        )
    }

    let content = SliderContent(
        id: 1,
        slider: DiscoverSlider(id: 1, type: 1, title: "Trending Movies", isBuiltIn: true, enabled: true, data: nil),
        displayTitle: "Trending Movies",
        items: items,
        page: 1,
        totalPages: 5
    )

    DiscoverSliderView(content: content)
}

#Preview("Skeleton") {
    SkeletonSliderView()
}
