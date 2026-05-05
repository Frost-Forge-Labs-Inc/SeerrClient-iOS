@testable import SeerrClient
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

    func test_highlightsCoverExpectedFeatureSet() {
        XCTAssertEqual(AboutFeature.allCases.count, 5)
        XCTAssertTrue(AboutFeature.allCases.contains(.discover))
        XCTAssertTrue(AboutFeature.allCases.contains(.search))
        XCTAssertTrue(AboutFeature.allCases.contains(.requests))
        XCTAssertTrue(AboutFeature.allCases.contains(.watchlist))
        XCTAssertTrue(AboutFeature.allCases.contains(.multiServer))
    }

    func test_supportLinksRouteThroughWebsite() {
        // Apple §3.1.1 path C: the iOS app exposes a single informational
        // "More ways to support" entry that opens the seerrclient.dev support
        // page. Direct external payment CTAs (BMaC, Ko-fi, GitHub Sponsors)
        // must NOT appear in-app — only on the website.
        let supportLinksByID = Dictionary(
            uniqueKeysWithValues: AboutContent.supportLinks.map { ($0.id, $0) }
        )

        XCTAssertEqual(supportLinksByID.count, 1)
        XCTAssertEqual(supportLinksByID["moreWaysToSupport"]?.label, "More ways to support")
        XCTAssertEqual(
            supportLinksByID["moreWaysToSupport"]?.url.absoluteString,
            "https://seerrclient.dev/support-development/"
        )

        XCTAssertFalse(AboutContent.supportLinks.contains { $0.label == "Funding Strategy" })
        XCTAssertFalse(
            AboutContent.supportLinks.contains { $0.url.host?.contains("buymeacoffee.com") == true },
            "Direct BMaC CTA must not appear in-app under §3.1.1 path C"
        )
        XCTAssertFalse(
            AboutContent.supportLinks.contains { $0.url.host?.contains("ko-fi.com") == true },
            "Direct Ko-fi CTA must not appear in-app under §3.1.1 path C"
        )
        XCTAssertFalse(
            AboutContent.supportLinks.contains {
                $0.url.host?.contains("github.com") == true
                    && $0.url.path.hasPrefix("/sponsors")
            },
            "Direct GitHub Sponsors CTA must not appear in-app under §3.1.1 path C"
        )
    }
}
