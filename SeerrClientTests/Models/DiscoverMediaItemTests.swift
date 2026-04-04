// DiscoverMediaItemTests.swift
// SeerrClientTests
//
// Tests for DiscoverMediaItem computed properties:
// year, displayTitle, isMovie, isTv, effectiveTmdbId.

@testable import SeerrClient
import XCTest

final class DiscoverMediaItemTests: XCTestCase {

    // MARK: - Helpers

    private func makeItem(
        id: Int = 1,
        tmdbId: Int? = nil,
        mediaType: String? = "movie",
        title: String? = nil,
        name: String? = nil,
        releaseDate: String? = nil,
        firstAirDate: String? = nil
    ) -> DiscoverMediaItem {
        DiscoverMediaItem(
            id: id,
            tmdbId: tmdbId,
            mediaType: mediaType,
            title: title,
            name: name,
            posterPath: nil,
            backdropPath: nil,
            overview: nil,
            voteAverage: nil,
            releaseDate: releaseDate,
            firstAirDate: firstAirDate,
            genreIds: nil,
            mediaInfo: nil
        )
    }

    // MARK: - year

    func test_year_fromReleaseDate() {
        let item = makeItem(releaseDate: "1999-03-31")
        XCTAssertEqual(item.year, "1999")
    }

    func test_year_fromFirstAirDate_whenNoReleaseDate() {
        let item = makeItem(releaseDate: nil, firstAirDate: "2005-09-22")
        XCTAssertEqual(item.year, "2005")
    }

    func test_year_nil_whenBothDatesNil() {
        let item = makeItem(releaseDate: nil, firstAirDate: nil)
        XCTAssertNil(item.year)
    }

    func test_year_nil_whenDateTooShort() {
        let item = makeItem(releaseDate: "99")
        XCTAssertNil(item.year)
    }

    func test_year_preferReleaseDateOverFirstAirDate() {
        let item = makeItem(releaseDate: "2001-01-01", firstAirDate: "2003-05-10")
        XCTAssertEqual(item.year, "2001")
    }

    // MARK: - displayTitle

    func test_displayTitle_usesTitle_forMovie() {
        let item = makeItem(title: "The Matrix", name: nil)
        XCTAssertEqual(item.displayTitle, "The Matrix")
    }

    func test_displayTitle_usesName_whenTitleNil() {
        let item = makeItem(title: nil, name: "Lost")
        XCTAssertEqual(item.displayTitle, "Lost")
    }

    func test_displayTitle_unknownFallback() {
        let item = makeItem(title: nil, name: nil)
        XCTAssertEqual(item.displayTitle, "Unknown")
    }

    // MARK: - isMovie / isTv

    func test_isMovie_true() {
        let item = makeItem(mediaType: "movie")
        XCTAssertTrue(item.isMovie)
    }

    func test_isMovie_false_forTv() {
        let item = makeItem(mediaType: "tv")
        XCTAssertFalse(item.isMovie)
    }

    func test_isTv_true() {
        let item = makeItem(mediaType: "tv")
        XCTAssertTrue(item.isTv)
    }

    func test_isTv_false_forMovie() {
        let item = makeItem(mediaType: "movie")
        XCTAssertFalse(item.isTv)
    }

    // MARK: - effectiveTmdbId

    func test_effectiveTmdbId_usesTmdbId_whenPresent() {
        let item = makeItem(id: 999, tmdbId: 603)
        XCTAssertEqual(item.effectiveTmdbId, 603)
    }

    func test_effectiveTmdbId_fallsBackToId() {
        let item = makeItem(id: 603, tmdbId: nil)
        XCTAssertEqual(item.effectiveTmdbId, 603)
    }
}
