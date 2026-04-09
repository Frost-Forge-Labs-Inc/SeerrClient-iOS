// CollectionDetailViewModelTests.swift
// SeerrClientTests
//
// Covers the selectable collection-request flow with pure view-model tests plus
// one integration-style test that loads the collection via the real repository
// and API client using a stubbed URLProtocol.

@testable import SeerrClient
import XCTest

@MainActor
final class CollectionDetailViewModelTests: XCTestCase {

    private var serverStore: ServerStore!
    private var sut: CollectionDetailViewModel!

    override func setUp() async throws {
        serverStore = ServerStore()
        CollectionDetailTestURLProtocol.collectionResponse = nil
        sut = makeSUT(collectionId: 42)
    }

    override func tearDown() async throws {
        sut = nil
        serverStore = nil
        CollectionDetailTestURLProtocol.collectionResponse = nil
    }

    func test_requestAll_selectsAllRequestableMoviesAndStartsQueue() {
        sut.replaceLoadedCollection(makeCollection())

        sut.requestAll()

        XCTAssertEqual(sut.selectedMovieIDs, Set([101, 104]))
        XCTAssertEqual(sut.selectedRequestMovieIDs, [101, 104])
        XCTAssertEqual(sut.queuedRequestMovieIDs, [101, 104])
        XCTAssertEqual(sut.requestingMovieId, 101)
        XCTAssertTrue(sut.showRequestSheet)
        XCTAssertTrue(sut.allRequestableMoviesSelected)
    }

    func test_requestSelected_usesSelectedRequestableMoviesInCollectionOrder() {
        sut.replaceLoadedCollection(makeCollection())

        sut.toggleSelection(movieId: 104)
        sut.toggleSelection(movieId: 101)

        sut.requestSelected()

        XCTAssertEqual(sut.selectedRequestMovieIDs, [101, 104])
        XCTAssertEqual(sut.queuedRequestMovieIDs, [101, 104])
        XCTAssertEqual(sut.activeRequestMovie?.id, 101)
        XCTAssertTrue(sut.showRequestSheet)
    }

    func test_toggleSelection_ignoresUnavailableMovies() {
        sut.replaceLoadedCollection(makeCollection())

        sut.toggleSelection(movieId: 102)
        sut.toggleSelection(movieId: 103)

        XCTAssertTrue(sut.selectedMovieIDs.isEmpty)
        XCTAssertFalse(sut.hasSelection)
    }

    func test_handleRequestSuccess_marksMoviePendingAdvancesQueueAndClearsCompletedSelection() {
        sut.replaceLoadedCollection(makeCollection())
        sut.requestAll()

        sut.handleRequestSuccess()

        XCTAssertEqual(sut.queuedRequestMovieIDs, [104])
        XCTAssertEqual(sut.selectedMovieIDs, Set([104]))
        XCTAssertEqual(sut.requestingMovieId, 104)
        XCTAssertTrue(sut.showRequestSheet)
        XCTAssertEqual(movie(withId: 101)?.mediaInfo?.status, 2)
        XCTAssertEqual(sut.requestableMovies.map(\.id), [104])
    }

    func test_handleRequestSuccess_onLastQueuedMovieClosesSheetAndLeavesNoSelection() {
        sut.replaceLoadedCollection(makeCollection())
        sut.toggleSelection(movieId: 104)
        sut.requestSelected()

        sut.handleRequestSuccess()

        XCTAssertTrue(sut.queuedRequestMovieIDs.isEmpty)
        XCTAssertTrue(sut.selectedMovieIDs.isEmpty)
        XCTAssertFalse(sut.showRequestSheet)
        XCTAssertEqual(movie(withId: 104)?.mediaInfo?.status, 2)
    }

    func test_loadCollection_integrationLoadsCollectionFromRepositoryStub() async throws {
        CollectionDetailTestURLProtocol.collectionResponse = makeCollection(
            requestableStatus: nil,
            partialStatus: 4
        )
        sut = makeSUT(collectionId: 42)

        await sut.loadCollection()

        guard case .loaded(let collection) = sut.loadState else {
            return XCTFail("Expected loaded collection state, got \(sut.loadState)")
        }

        XCTAssertEqual(collection.parts?.map(\.id), [101, 102, 103, 104])
        XCTAssertEqual(sut.requestableMovies.map(\.id), [101, 104])
        XCTAssertEqual(sut.collection?.name, "UI Test Collection")
    }

    // MARK: - Helpers

    private func makeSUT(collectionId: Int) -> CollectionDetailViewModel {
        let server = ServerConfiguration(
            displayName: "Collection Tests",
            baseURL: "http://collection-tests.local:5055",
            backendType: .jellyseerr
        )
        let client = SeerrAPIClient(
            server: server,
            serverStore: serverStore,
            additionalProtocolClasses: [CollectionDetailTestURLProtocol.self]
        )
        let repository = MediaDetailRepository(apiClient: client)
        return CollectionDetailViewModel(collectionId: collectionId, repository: repository)
    }

    private func movie(withId movieId: Int) -> MovieResult? {
        sut.collection?.parts?.first(where: { $0.id == movieId })
    }

    private func makeCollection(
        requestableStatus: Int? = nil,
        partialStatus: Int? = 4
    ) -> Collection {
        Collection(
            id: 42,
            name: "UI Test Collection",
            overview: "Collection request selection tests.",
            posterPath: nil,
            backdropPath: nil,
            parts: [
                makeMovie(id: 101, title: "Requestable Movie", status: requestableStatus),
                makeMovie(id: 102, title: "Pending Movie", status: 2),
                makeMovie(id: 103, title: "Available Movie", status: 5),
                makeMovie(id: 104, title: "Partial Movie", status: partialStatus)
            ]
        )
    }

    private func makeMovie(id: Int, title: String, status: Int?) -> MovieResult {
        MovieResult(
            id: id,
            mediaType: "movie",
            popularity: nil,
            posterPath: nil,
            backdropPath: nil,
            voteCount: nil,
            voteAverage: nil,
            genreIds: nil,
            overview: nil,
            originalLanguage: nil,
            title: title,
            originalTitle: nil,
            releaseDate: "2024-01-01",
            adult: nil,
            video: nil,
            mediaInfo: MediaInfo(
                id: id,
                tmdbId: id,
                tvdbId: nil,
                status: status,
                seasons: nil,
                requests: nil,
                createdAt: nil,
                updatedAt: nil,
                watchlisted: nil
            )
        )
    }
}

private final class CollectionDetailTestURLProtocol: URLProtocol {
    static var collectionResponse: Collection?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "collection-tests.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if request.httpMethod == "GET", url.path == "/api/v1/collection/42",
           let responseObject = Self.collectionResponse {
            do {
                let data = try JSONEncoder().encode(responseObject)
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
                return
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 404,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"message\":\"missing stub\"}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
