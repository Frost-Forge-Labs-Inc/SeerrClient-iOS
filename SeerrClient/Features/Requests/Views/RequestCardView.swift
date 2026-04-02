// RequestCardView.swift
// SeerrClient
//
// Reusable request row card with poster, metadata, and status badge.

import SwiftUI

// MARK: - RequestPresentation

enum RequestPresentation {
    static func statusTitle(for status: Int) -> String {
        switch status {
        case 1:
            return "Pending"
        case 2:
            return "Approved"
        case 3:
            return "Declined"
        default:
            return "Unknown"
        }
    }

    static func statusColor(for status: Int) -> Color {
        switch status {
        case 1:
            return .orange
        case 2:
            return .green
        case 3:
            return .red
        default:
            return .gray
        }
    }

    static func requesterName(for request: MediaRequest) -> String {
        // Prefer username, then plexUsername, then email (Jellyfin users), then ID fallback.
        request.requestedBy?.username
            ?? request.requestedBy?.plexUsername
            ?? request.requestedBy?.email
            ?? "User #\(request.requestedBy?.id ?? 0)"
    }

    static func mediaType(for request: MediaRequest, explicitType: MediaRequestMediaType?) -> MediaRequestMediaType? {
        if let explicitType {
            return explicitType
        }
        return request.media?.tvdbId == nil ? .movie : .tv
    }

    static func mediaTypeLabel(for request: MediaRequest, explicitType: MediaRequestMediaType?) -> String {
        switch mediaType(for: request, explicitType: explicitType) {
        case .movie:
            return "Movie"
        case .tv:
            return "TV"
        case .none:
            return "Media"
        }
    }

    static func title(for request: MediaRequest, preferredTitle: String?, explicitType: MediaRequestMediaType?) -> String {
        if let preferredTitle, !preferredTitle.isEmpty {
            return preferredTitle
        }

        let mediaLabel = mediaTypeLabel(for: request, explicitType: explicitType)
        if let tmdbId = request.media?.tmdbId {
            return "\(mediaLabel) #\(tmdbId)"
        }

        return "Requested Media"
    }

    static func relativeDate(for request: MediaRequest) -> String {
        let relative = SeerrDateFormatter.relativeDate(request.createdAt)
        if relative != "Unknown" {
            return relative
        }
        return SeerrDateFormatter.displayDate(request.createdAt)
    }
}

// MARK: - RequestStatusBadgeView

struct RequestStatusBadgeView: View {
    let status: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = RequestPresentation.statusColor(for: status)
        Text(RequestPresentation.statusTitle(for: status))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(colorScheme == .dark ? color : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorScheme == .dark ? color.opacity(0.25) : color, in: Capsule())
    }
}

// MARK: - RequestCardView

struct RequestCardView: View {
    let request: MediaRequest
    var title: String? = nil
    var posterPath: String? = nil
    var mediaType: MediaRequestMediaType? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            posterThumbnail

            VStack(alignment: .leading, spacing: 6) {
                Text(RequestPresentation.title(for: request, preferredTitle: title, explicitType: mediaType))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(RequestPresentation.mediaTypeLabel(for: request, explicitType: mediaType))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Requested by \(RequestPresentation.requesterName(for: request))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(RequestPresentation.relativeDate(for: request))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    RequestStatusBadgeView(status: request.status)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Poster

    @ViewBuilder
    private var posterThumbnail: some View {
        AsyncImage(url: TMDBImageURL.poster(path: posterPath, size: .w185)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            default:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "film")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 60, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let labelTitle = RequestPresentation.title(for: request, preferredTitle: title, explicitType: mediaType)
        let type = RequestPresentation.mediaTypeLabel(for: request, explicitType: mediaType)
        let status = RequestPresentation.statusTitle(for: request.status)
        let requester = RequestPresentation.requesterName(for: request)
        let created = RequestPresentation.relativeDate(for: request)
        return "\(labelTitle), \(type), \(status), requested by \(requester), \(created)"
    }
}
