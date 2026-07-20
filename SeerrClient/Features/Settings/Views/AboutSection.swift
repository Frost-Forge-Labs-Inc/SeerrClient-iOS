// AboutSection.swift
// SeerrClient
//
// Inline About/support content for the Profile screen.

import SwiftUI

// MARK: - AboutSection

struct AboutSection: View {

    var body: some View {
        Group {
            appInfoSection
            featuresSection
            documentationSection
            supportSection
            acknowledgementsSection
        }
    }

    private var appInfoSection: some View {
        Section("About") {
            infoRow(title: "Version", value: AppMetadata.versionString)
            infoRow(title: "Build", value: AppMetadata.buildString)

            if let sourceCodeURL = AboutContent.sourceCodeURL {
                linkRow(
                    link: AboutLink(
                        id: "sourceCode",
                        label: "Source Code",
                        caption: "Browse the app repository",
                        icon: "chevron.left.forwardslash.chevron.right",
                        url: sourceCodeURL
                    ),
                    identifier: "about.app.sourceCode"
                )
            }

            if let privacyPolicyURL = AboutContent.privacyPolicyURL {
                linkRow(
                    link: AboutLink(
                        id: "privacyPolicy",
                        label: "Privacy Policy",
                        caption: "Review the app privacy statement",
                        icon: "hand.raised",
                        url: privacyPolicyURL
                    ),
                    identifier: "about.app.privacyPolicy"
                )
            }
        }
    }

    private var featuresSection: some View {
        Section("Highlights") {
            ForEach(AboutFeature.allCases, id: \.self) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.icon)
                        .foregroundStyle(.tint)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline.weight(.medium))
                        Text(feature.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var documentationSection: some View {
        Section {
            ForEach(AboutContent.documentationLinks) { link in
                linkRow(link: link, identifier: "about.doc.\(link.id)")
            }
        } header: {
            Text("Documentation")
        } footer: {
            Text("Documentation links open in Safari and should remain useful even when the app is offline.")
        }
    }

    private var supportSection: some View {
        Section {
            ForEach(AboutContent.supportLinks) { link in
                supportLinkRow(link, identifier: "about.support.\(link.id)")
            }
        } header: {
            Text("Support Development")
        } footer: {
            Text("Support helps fund ongoing Octopus Explorer development.")
        }
    }

    private var acknowledgementsSection: some View {
        Section("Acknowledgements") {
            ForEach(AboutContent.acknowledgements) { acknowledgement in
                if let url = acknowledgement.url {
                    Link(destination: url) {
                        acknowledgementRow(for: acknowledgement)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("about.ack.\(acknowledgement.id)")
                    }
                } else {
                    acknowledgementRow(for: acknowledgement)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("about.ack.\(acknowledgement.id)")
                }
            }
        }
    }

    @ViewBuilder
    private func linkRow(link: AboutLink, identifier: String) -> some View {
        Link(destination: link.url) {
            externalLinkRow(
                title: link.label,
                caption: link.caption,
                icon: link.icon,
                iconTint: Color.accentColor
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
        }
    }

    @ViewBuilder
    private func supportLinkRow(_ link: SupportLink, identifier: String) -> some View {
        Link(destination: link.url) {
            externalLinkRow(
                title: link.label,
                caption: link.caption,
                icon: link.icon,
                iconTint: link.iconTint
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)

            Spacer(minLength: 8)

            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func acknowledgementRow(for acknowledgement: Acknowledgement) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(acknowledgement.name)
                    .font(.subheadline)
                Text(acknowledgement.role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if acknowledgement.url != nil {
                Image(systemName: "arrow.up.right.square")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func externalLinkRow(
        title: String,
        caption: String,
        icon: String,
        iconTint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconTint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right.square")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - AppMetadata

enum AppMetadata {
    static var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var buildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

// MARK: - AboutContent

enum AboutContent {
    static let sourceCodeURL = URL(string: "https://github.com/Frost-Forge-Labs-Inc/SeerrClient-iOS")
    static let privacyPolicyURL = URL(string: "https://seerrclient.dev/legal/privacy/")

    static let documentationLinks: [AboutLink] = [
        AboutLink(
            id: "gettingStarted",
            label: "Getting Started",
            caption: "Seerr documentation and setup help",
            icon: "book",
            url: URL(string: "https://docs.seerr.dev/")!
        ),
        AboutLink(
            id: "seerrGithub",
            label: "Seerr on GitHub",
            caption: "Browse the upstream Seerr project",
            icon: "safari",
            url: URL(string: "https://github.com/seerr-team/seerr")!
        ),
        AboutLink(
            id: "releaseNotes",
            label: "Release Notes",
            caption: "Track Octopus Explorer app releases",
            icon: "sparkles.rectangle.stack",
            url: URL(string: "https://github.com/Frost-Forge-Labs-Inc/SeerrClient-iOS/releases")!
        ),
        AboutLink(
            id: "reportBug",
            label: "Report a Bug",
            caption: "Open an issue with reproduction details",
            icon: "ladybug",
            url: URL(string: "https://github.com/Frost-Forge-Labs-Inc/SeerrClient-iOS/issues/new/choose")!
        ),
    ]

    static let supportLinks: [SupportLink] = [
        SupportLink(
            id: "moreWaysToSupport",
            label: "More ways to support",
            caption: "Tip, sponsor, or learn how to contribute on seerrclient.dev",
            icon: "heart",
            iconTint: .pink,
            url: URL(string: "https://seerrclient.dev/support-development/")!
        ),
    ]

    static let acknowledgements: [Acknowledgement] = [
        Acknowledgement(
            id: "seerr",
            name: "Seerr",
            role: "The active open-source media request platform this client primarily targets.",
            url: URL(string: "https://github.com/seerr-team/seerr")
        ),
        Acknowledgement(
            id: "jellyseerr",
            name: "Jellyseerr",
            role: "The Jellyfin and Emby-focused fork whose API lineage still matters for compatibility work.",
            url: URL(string: "https://github.com/Fallenbagel/jellyseerr")
        ),
        Acknowledgement(
            id: "overseerr",
            name: "Overseerr",
            role: "The original Plex-focused project that established the earlier API and UX baseline.",
            url: URL(string: "https://github.com/sct/overseerr")
        ),
        Acknowledgement(
            id: "tmdb",
            name: "The Movie Database (TMDB)",
            role: "Movie and TV metadata, images, and collection information.",
            url: URL(string: "https://www.themoviedb.org/")
        ),
        Acknowledgement(
            id: "frostForgeLabs",
            name: "Frost Forge Labs Inc.",
            role: "Design, implementation, and ongoing maintenance of Octopus Explorer.",
            url: URL(string: "https://github.com/Frost-Forge-Labs-Inc")
        ),
    ]
}

// MARK: - About Models

struct AboutLink: Identifiable, Equatable {
    let id: String
    let label: String
    let caption: String
    let icon: String
    let url: URL
}

struct SupportLink: Identifiable {
    let id: String
    let label: String
    let caption: String
    let icon: String
    let iconTint: Color
    let url: URL
}

struct Acknowledgement: Identifiable, Equatable {
    let id: String
    let name: String
    let role: String
    let url: URL?
}

// MARK: - AboutFeature

enum AboutFeature: CaseIterable {
    case discover
    case search
    case requests
    case watchlist
    case multiServer

    var title: String {
        switch self {
        case .discover:
            return "Discover"
        case .search:
            return "Search"
        case .requests:
            return "Requests"
        case .watchlist:
            return "Watchlist"
        case .multiServer:
            return "Multi-Server"
        }
    }

    var description: String {
        switch self {
        case .discover:
            return "Browse trending movies and TV shows with curated sliders."
        case .search:
            return "Find movies, shows, people, and collections through TMDB-backed search."
        case .requests:
            return "Submit, track, approve, and decline media requests from your phone."
        case .watchlist:
            return "View and manage watchlists when the connected server supports them."
        case .multiServer:
            return "Switch between Seerr, Jellyseerr, and Overseerr servers from one client."
        }
    }

    var icon: String {
        switch self {
        case .discover:
            return "film.stack"
        case .search:
            return "magnifyingglass"
        case .requests:
            return "tray.full"
        case .watchlist:
            return "bookmark"
        case .multiServer:
            return "server.rack"
        }
    }
}
