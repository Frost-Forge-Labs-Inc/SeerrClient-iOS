#if os(macOS)
@testable import SeerrClientMac
#else
@testable import SeerrClient
#endif
import XCTest

final class AboutContentTests: XCTestCase {

    func test_acknowledgementsIncludeDistinctSeerrLineageEntries() {
        let acknowledgementIDs = Set(AboutContent.acknowledgements.map(\.id))

        XCTAssertTrue(acknowledgementIDs.contains("seerr"))
        XCTAssertTrue(acknowledgementIDs.contains("jellyseerr"))
        XCTAssertTrue(acknowledgementIDs.contains("overseerr"))
    }

    func test_acknowledgementsDescribeDistinctRoles() {
        let acknowledgementsByID = Dictionary(
            uniqueKeysWithValues: AboutContent.acknowledgements.map { ($0.id, $0.role) }
        )

        XCTAssertEqual(
            acknowledgementsByID["seerr"],
            "The active open-source media request platform this client primarily targets."
        )
        XCTAssertEqual(
            acknowledgementsByID["jellyseerr"],
            "The Jellyfin and Emby-focused fork whose API lineage still matters for compatibility work."
        )
        XCTAssertEqual(
            acknowledgementsByID["overseerr"],
            "The original Plex-focused project that established the earlier API and UX baseline."
        )
    }

    func test_documentationLinksIncludeReleaseNotesAndBugReport() {
        let linkIDs = Set(AboutContent.documentationLinks.map(\.id))

        XCTAssertTrue(linkIDs.contains("gettingStarted"))
        XCTAssertTrue(linkIDs.contains("releaseNotes"))
        XCTAssertTrue(linkIDs.contains("reportBug"))
    }

    func test_appInfoURLsArePresent() {
        XCTAssertNotNil(AboutContent.sourceCodeURL)
        XCTAssertNotNil(AboutContent.privacyPolicyURL)
    }

    func test_privacyPolicyURLPointsToWebsite() {
        // Privacy Policy lives at seerrclient.dev/legal/privacy/ — the website is the
        // canonical legal/policy host (App Store Connect submission also points here).
        // Reverting to the GitHub blob URL would break App Review submission consistency
        // and deviate from the website-as-canonical-legal-host posture.
        XCTAssertEqual(
            AboutContent.privacyPolicyURL?.absoluteString,
            "https://seerrclient.dev/legal/privacy/"
        )
        XCTAssertFalse(
            AboutContent.privacyPolicyURL?.host?.contains("github.com") ?? false,
            "Privacy Policy must not point to the GitHub blob URL — use the website."
        )
    }

    func test_highlightsCoverExpectedFeatureSet() {
        XCTAssertEqual(AboutFeature.allCases.count, 5)
        XCTAssertTrue(AboutFeature.allCases.contains(.discover))
        XCTAssertTrue(AboutFeature.allCases.contains(.search))
        XCTAssertTrue(AboutFeature.allCases.contains(.requests))
        XCTAssertTrue(AboutFeature.allCases.contains(.watchlist))
        XCTAssertTrue(AboutFeature.allCases.contains(.multiServer))
    }

    func test_noPaymentOrSponsorshipSurfaceInApp() {
        // App Review rejected build 1.0(3) on 2026-08-28 under Guideline 3.1.1
        // (In-App Purchase): the former "Support Development" section linked to the
        // seerrclient.dev support page (BMaC / Ko-fi / GitHub Sponsors). Apple's
        // stated remedy was IAP or removal; we removed it. The Apple binaries must
        // expose NO tipping/sponsorship surface. Re-adding one requires a
        // StoreKit 2 IAP implementation, not an external link.
        var allURLs: [URL] = []
        if let url = AboutContent.sourceCodeURL { allURLs.append(url) }
        if let url = AboutContent.privacyPolicyURL { allURLs.append(url) }
        allURLs.append(contentsOf: AboutContent.documentationLinks.map(\.url))
        allURLs.append(contentsOf: AboutContent.acknowledgements.compactMap(\.url))
        XCTAssertFalse(allURLs.isEmpty)

        let blockedHosts = ["buymeacoffee.com", "ko-fi.com", "patreon.com", "liberapay.com", "opencollective.com"]
        for url in allURLs {
            let host = url.host?.lowercased() ?? ""
            let path = url.path.lowercased()
            for blocked in blockedHosts {
                XCTAssertFalse(
                    host == blocked || host.hasSuffix("." + blocked),
                    "External payment host \(blocked) must not appear in-app: \(url)"
                )
            }
            XCTAssertFalse(
                host.hasSuffix("github.com") && path.hasPrefix("/sponsors"),
                "GitHub Sponsors link must not appear in-app: \(url)"
            )
            XCTAssertFalse(
                path.contains("support-development"),
                "The website support/funding page must not be linked from the app: \(url)"
            )
        }

        let allLabels = AboutContent.documentationLinks.map(\.label)
            + AboutContent.documentationLinks.map(\.caption)
            + AboutContent.acknowledgements.map(\.name)
            + AboutContent.acknowledgements.map(\.role)
            + AboutFeature.allCases.map(\.title)
            + AboutFeature.allCases.map(\.description)
        let forbiddenCopyPatterns = [
            #"\btip(s|ping)?\b"#,
            #"\bsponsor(s|ship|ships|ing)?\b"#,
            #"\bdonat(e|es|ion|ions|ing)\b"#,
            #"buy me a coffee"#,
            #"\bko-?fi\b"#,
        ]
        for text in allLabels {
            for pattern in forbiddenCopyPatterns {
                XCTAssertNil(
                    text.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
                    "Funding copy matching /\(pattern)/ must not appear in About content: \(text)"
                )
            }
        }
    }
}
