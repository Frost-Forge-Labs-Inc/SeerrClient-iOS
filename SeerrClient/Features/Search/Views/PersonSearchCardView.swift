// PersonSearchCardView.swift
// SeerrClient
//
// A card view for person search results. Displays a circular profile image,
// the person's name, and their known-for department (e.g. "Acting", "Directing").

import SwiftUI

// MARK: - PersonSearchCardView

/// Displays a person search result as a compact card with circular profile photo.
///
/// Usage:
/// ```swift
/// PersonSearchCardView(person: searchResult) {
///     // navigate to person detail
/// }
/// ```
struct PersonSearchCardView: View {

    /// The person search result item.
    let person: SearchResultItem
    /// Action triggered when the card is tapped.
    var onTap: (() -> Void)?

    private let profileSize: CGFloat = 80

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 8) {
                profileImage
                nameSection
            }
            .frame(width: 100)
            .padding(.vertical, 10)
        }
        .buttonStyle(PersonCardButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Profile Image

    @ViewBuilder
    private var profileImage: some View {
        AsyncImage(url: TMDBImageURL.profile(path: person.profilePath)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                profilePlaceholder
            case .empty:
                ProgressView()
                    .frame(width: profileSize, height: profileSize)
            @unknown default:
                profilePlaceholder
            }
        }
        .frame(width: profileSize, height: profileSize)
        .clipShape(Circle())
        .background {
            Circle()
                .fill(Color(.systemGray5))
        }
    }

    /// Placeholder shown when no profile image is available.
    @ViewBuilder
    private var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
            Image(systemName: "person.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(width: profileSize, height: profileSize)
    }

    // MARK: - Name

    @ViewBuilder
    private var nameSection: some View {
        VStack(spacing: 2) {
            Text(person.displayTitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let dept = person.knownForDepartment {
                Text(dept)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var desc = person.displayTitle
        if let dept = person.knownForDepartment {
            desc += ", \(dept)"
        }
        return desc
    }
}

// MARK: - Button Style

/// Custom button style with subtle scale animation on press.
private struct PersonCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Person Card") {
    let person = SearchResultItem(
        id: 6193,
        mediaType: "person",
        title: nil,
        name: "Leonardo DiCaprio",
        posterPath: nil,
        backdropPath: nil,
        overview: nil,
        voteAverage: nil,
        releaseDate: nil,
        firstAirDate: nil,
        genreIds: nil,
        mediaInfo: nil,
        profilePath: "/wo2hJpn04vbtmh0B9utCFa3BPKA.jpg",
        knownForDepartment: "Acting"
    )

    PersonSearchCardView(person: person)
        .padding()
}

#Preview("No Photo") {
    let person = SearchResultItem(
        id: 1,
        mediaType: "person",
        title: nil,
        name: "Unknown Director With A Very Long Name",
        posterPath: nil,
        backdropPath: nil,
        overview: nil,
        voteAverage: nil,
        releaseDate: nil,
        firstAirDate: nil,
        genreIds: nil,
        mediaInfo: nil,
        profilePath: nil,
        knownForDepartment: "Directing"
    )

    PersonSearchCardView(person: person)
        .padding()
}
