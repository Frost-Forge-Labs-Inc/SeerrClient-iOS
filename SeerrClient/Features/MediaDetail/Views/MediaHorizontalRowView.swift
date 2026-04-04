// MediaHorizontalRowView.swift
// SeerrClient
//
// A titled horizontal scroll row of media cards, used in detail screens
// for Recommendations and Similar sections.

import SwiftUI

// MARK: - MediaHorizontalRowView

/// Displays a titled horizontal scrolling row of `DiscoverMediaItem` cards.
/// Navigates to MovieDetailView or TvShowDetailView on tap.
struct MediaHorizontalRowView: View {

    let title: String
    let items: [DiscoverMediaItem]
    var cardSize: MediaCardSize = .medium

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
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
}
