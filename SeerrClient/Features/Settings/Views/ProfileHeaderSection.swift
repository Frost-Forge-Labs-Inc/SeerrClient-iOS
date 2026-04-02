// ProfileHeaderSection.swift
// SeerrClient
//
// Profile header section with avatar, identity, and account badges.

import SwiftUI

// MARK: - ProfileHeaderSection

struct ProfileHeaderSection: View {
    let user: User
    /// The base URL of the active server, used to resolve relative avatar paths
    /// (e.g. `/avatarproxy/...`) into fully-qualified URLs.
    var serverBaseURL: String = ""

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 16) {
                avatarView

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayName)
                        .font(.title3.weight(.semibold))

                    Text(user.email ?? "—")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        badge(text: userTypeLabel, foreground: .accentColor, background: Color.accentColor.opacity(0.15))

                        if isAdmin {
                            badge(text: "Admin", foreground: .red, background: .red.opacity(0.15))
                        }
                    }

                    Text("Member since \(SeerrDateFormatter.displayDate(user.createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .empty:
                    avatarFallback
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                case .failure:
                    avatarFallback
                @unknown default:
                    avatarFallback
                }
            }
            .frame(width: 80, height: 80)
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))

            Text(initials)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 80, height: 80)
    }

    private func badge(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }

    private var avatarURL: URL? {
        guard let avatar = user.avatar?.trimmingCharacters(in: .whitespacesAndNewlines),
              !avatar.isEmpty else {
            return nil
        }
        // The avatar field may be a relative path (e.g. "/avatarproxy/...") served
        // by the Seerr server itself. Detect relative paths and prepend the server
        // base URL so AsyncImage receives a fully-qualified URL.
        if avatar.hasPrefix("/"), !serverBaseURL.isEmpty {
            return URL(string: serverBaseURL + avatar)
        }
        return URL(string: avatar)
    }

    private var displayName: String {
        if let username = user.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            return username
        }
        if let plexUsername = user.plexUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !plexUsername.isEmpty {
            return plexUsername
        }
        // Jellyfin users have no username or plexUsername — fall back to email.
        if let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        return "User #\(user.id)"
    }

    private var initials: String {
        let source: String?
        if let username = user.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            source = username
        } else if let plexUsername = user.plexUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !plexUsername.isEmpty {
            source = plexUsername
        } else if let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            source = email
        } else {
            source = nil
        }

        guard let source else { return "?" }

        let letters = source.filter { $0.isLetter }
        guard !letters.isEmpty else { return "?" }
        return String(letters.prefix(2)).uppercased()
    }

    private var userTypeLabel: String {
        switch user.userType {
        case 1:
            return "Plex User"
        case 2:
            return "Local User"
        case 3:
            return "Jellyfin User"
        default:
            return "Unknown User"
        }
    }

    private var isAdmin: Bool {
        ((user.permissions ?? 0) & 2) != 0
    }
}
