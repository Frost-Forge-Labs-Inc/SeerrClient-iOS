// CastCardView.swift
// SeerrClient
//
// A compact card for a single cast member. Shows a circular profile photo,
// the actor's name, and the character they portray.

import SwiftUI

// MARK: - CastCardView

/// Displays a single cast member with circular profile, name, and character.
struct CastCardView: View {

    let cast: Cast
    private let profileSize: CGFloat = 72

    var body: some View {
        VStack(spacing: 6) {
            profileImage
            nameSection
        }
        .frame(width: 90)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Profile Image

    @ViewBuilder
    private var profileImage: some View {
        AsyncImage(url: TMDBImageURL.profile(path: cast.profilePath)) { phase in
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
            Circle().fill(Color(.systemGray5))
        }
    }

    @ViewBuilder
    private var profilePlaceholder: some View {
        ZStack {
            Circle().fill(Color(.systemGray5))
            Image(systemName: "person.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(width: profileSize, height: profileSize)
    }

    // MARK: - Name

    @ViewBuilder
    private var nameSection: some View {
        VStack(spacing: 2) {
            Text(cast.name ?? "Unknown")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let character = cast.character, !character.isEmpty {
                Text(character)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var desc = cast.name ?? "Unknown actor"
        if let character = cast.character {
            desc += " as \(character)"
        }
        return desc
    }
}
