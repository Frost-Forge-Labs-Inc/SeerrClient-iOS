// AboutSection.swift
// SeerrClient
//
// Full About section for the Profile screen. Displays app info, features,
// documentation links, acknowledgements, and support/funding options.
//
// Funding research summary:
//   - GitHub Sponsors: zero-fee for first year, simple link, no Apple restrictions
//   - Ko-fi / Buy Me a Coffee: link-out to web, no App Store rules apply
//   - In-App Purchase Tip Jar: requires StoreKit 2, Apple takes 30%; most
//     compliant path for in-app monetisation. Placeholder added here; wire up
//     with a StoreKit product ID when the App Store listing is created.
//   - Stripe / PayPal: web-only (Apple forbids in-app links to external payment
//     flows that bypass IAP). Directing users to a Safari page is allowed.
//
// Decision: expose GitHub Sponsors + Ko-fi as external links now.
// Add StoreKit tip jar in a future session once products are created in
// App Store Connect.

import SwiftUI

// MARK: - AboutSection

struct AboutSection: View {

    // MARK: - URLs

    private enum Links {
        static let githubRepo    = URL(string: "https://github.com/Frost-Forge-Labs-Inc/SeerrClient-iOS")
        static let githubIssues  = URL(string: "https://github.com/Frost-Forge-Labs-Inc/SeerrClient-iOS/issues/new/choose")
        static let githubSponsors = URL(string: "https://github.com/sponsors/Frost-Forge-Labs-Inc")
        static let kofi          = URL(string: "https://ko-fi.com/frostforgelabs")
        static let seerrDocs     = URL(string: "https://docs.seerr.dev/")
        static let seerrGithub   = URL(string: "https://github.com/seerr-team/seerr")
        static let privacyPolicy = URL(string: "https://github.com/Frost-Forge-Labs-Inc/SeerrClient-iOS/blob/main/PRIVACY.md")
    }

    // MARK: - Body

    var body: some View {
        Group {
            appInfoSection
            featuresSection
            documentationSection
            supportSection
            acknowledgementsSection
        }
    }

    // MARK: - App Info

    private var appInfoSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(versionString)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text(buildString)
                    .foregroundStyle(.secondary)
            }

            if let url = Links.githubRepo {
                Link(destination: url) {
                    externalLinkRow(
                        label: "Source Code",
                        icon: "chevron.left.forwardslash.chevron.right"
                    )
                }
            }

            if let url = Links.privacyPolicy {
                Link(destination: url) {
                    externalLinkRow(label: "Privacy Policy", icon: "hand.raised")
                }
            }
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        Section("Features") {
            ForEach(AppFeature.allCases, id: \.self) { feature in
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

    // MARK: - Documentation

    private var documentationSection: some View {
        Section("Documentation") {
            if let url = Links.seerrDocs {
                Link(destination: url) {
                    externalLinkRow(label: "Seerr Documentation", icon: "book")
                }
            }
            if let url = Links.seerrGithub {
                Link(destination: url) {
                    externalLinkRow(label: "Seerr on GitHub", icon: "safari")
                }
            }
            if let url = Links.githubIssues {
                Link(destination: url) {
                    externalLinkRow(label: "Report a Bug", icon: "ladybug")
                }
            }
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        Section {
            if let url = Links.githubSponsors {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sponsor on GitHub")
                                .font(.subheadline.weight(.medium))
                            Text("Monthly support for ongoing development")
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

            if let url = Links.kofi {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.0))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Buy a Coffee")
                                .font(.subheadline.weight(.medium))
                            Text("One-time tip via Ko-fi")
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
        } header: {
            Text("Support Development")
        } footer: {
            Text("SeerrClient is free and open-source. Your support helps fund ongoing development and new features.")
                .font(.caption)
        }
    }

    // MARK: - Acknowledgements

    private var acknowledgementsSection: some View {
        Section("Acknowledgements") {
            ForEach(Acknowledgement.all, id: \.name) { ack in
                if let url = ack.url {
                    Link(destination: url) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ack.name)
                                    .font(.subheadline)
                                Text(ack.role)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ack.name)
                            .font(.subheadline)
                        Text(ack.role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func externalLinkRow(label: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(label)
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

// MARK: - AppFeature

private enum AppFeature: CaseIterable {
    case discover
    case search
    case requests
    case watchlist
    case multiServer

    var title: String {
        switch self {
        case .discover:    return "Discover"
        case .search:      return "Search"
        case .requests:    return "Requests"
        case .watchlist:   return "Watchlist"
        case .multiServer: return "Multi-Server"
        }
    }

    var description: String {
        switch self {
        case .discover:
            return "Browse trending movies and TV shows with personalised sliders"
        case .search:
            return "Find any movie, TV show, or person using TMDB"
        case .requests:
            return "Submit, track, approve, and decline media requests"
        case .watchlist:
            return "View and manage your Plex watchlist from the app"
        case .multiServer:
            return "Connect to multiple Seerr, Jellyseerr, or Overseerr servers"
        }
    }

    var icon: String {
        switch self {
        case .discover:    return "film.stack"
        case .search:      return "magnifyingglass"
        case .requests:    return "tray.full"
        case .watchlist:   return "bookmark"
        case .multiServer: return "server.rack"
        }
    }
}

// MARK: - Acknowledgement

private struct Acknowledgement {
    let name: String
    let role: String
    let url: URL?

    static let all: [Acknowledgement] = [
        Acknowledgement(
            name: "Seerr Team",
            role: "Seerr — the open-source media request platform",
            url: URL(string: "https://github.com/seerr-team/seerr")
        ),
        Acknowledgement(
            name: "Overseerr",
            role: "Original project that Jellyseerr and Seerr are based on",
            url: URL(string: "https://github.com/sct/overseerr")
        ),
        Acknowledgement(
            name: "The Movie Database (TMDB)",
            role: "Movie and TV metadata, images, and collections",
            url: URL(string: "https://www.themoviedb.org/")
        ),
        Acknowledgement(
            name: "Frost Forge Labs Inc.",
            role: "Developed and maintained by Frost Forge Labs",
            url: URL(string: "https://github.com/Frost-Forge-Labs-Inc")
        ),
    ]
}
