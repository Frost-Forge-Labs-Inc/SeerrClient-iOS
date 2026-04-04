// CastCarouselView.swift
// SeerrClient
//
// Horizontal scrolling carousel of cast members. Limits display to 15 members
// for performance. Reuses CastCardView for each entry.

import SwiftUI

// MARK: - CastCarouselView

/// Horizontal carousel showing up to 15 cast members.
struct CastCarouselView: View {

    /// The credits object containing cast and crew.
    let credits: Credits?

    /// Maximum number of cast members to display.
    private let maxCast = 15

    var body: some View {
        let castList = credits?.cast?.prefix(maxCast) ?? []
        if !castList.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cast")
                    .font(.title3.bold())
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(Array(castList.enumerated()), id: \.offset) { _, member in
                            CastCardView(cast: member)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
