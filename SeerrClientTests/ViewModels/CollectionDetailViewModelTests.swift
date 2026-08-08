// CollectionDetailViewModelTests.swift
// SeerrClientTests
//
// Covers the one-tap batch collection-request flow with pure view-model tests
// plus an integration-style load via the real repository and a stubbed URLProtocol.

#if os(macOS)
@testable import SeerrClientMac
#else
@testable import SeerrClient
#endif
import XCTest

@MainActor
final class CollectionDetailViewModelTests: XCTestCase {

    private var serverStore: ServerStore!
    private var sut: CollectionDetailViewModel!

    override func setUp() async throws {
        serverStore = ServerStore()
        CollectionDetailTestURLProtocol.reset()
        CollectionDetailTestURLProtocol.collectionResponse = nil
        sut = makeSUT(collectionId: 42)
    }

    override func tearDown() async throws {
        sut = nil
        serverStore = nil
        CollectionDetailTestURLProtocol.reset()
    }

    func test_requestAll_createsRequestForEveryRequestableMovieAndMarksPending() async {
        sut.replaceLoadedCollection(makeCollection())

        await sut.requestAll()

        XCTAssertEqual(CollectionDetailTestURLProtocol.createRequestBodies.map(\.mediaId), [101, 104])
        XCTAssertTrue(CollectionDetailTestURLProtocol.createRequestBodies.allSatisfy { body in
            body.mediaType == .movie
                && body.tvdbId == nil
                && body.seasons == nil
                && body.seasonsAll == nil
                && body.is4k == false
        })
        XCTAssertEqual(movie(withId: 101)?.mediaInfo?.status, 2)
        XCTAssertEqual(movie(withId: 104)?.mediaInfo?.status, 2)
        XCTAssertTrue(sut.selectedMovieIDs.isEmpty)
        XCTAssertEqual(sut.requestableMovies.map(\.id), [])
        XCTAssertNil(sut.batchErrorMessage)
        XCTAssertFalse(sut.isRequesting)
    }

    func test_requestSelected_createsRequestOnlyForSelectedMoviesInCollectionOrder() async {
        sut.replaceLoadedCollection(makeCollection())

        sut.toggleSelection(movieId: 104)
        sut.toggleSelection(movieId: 101)

        await sut.requestSelected()

        XCTAssertEqual(CollectionDetailTestURLProtocol.createRequestBodies.map(\.mediaId), [101, 104])
        XCTAssertEqual(movie(withId: 101)?.mediaInfo?.status, 2)
        XCTAssertEqual(movie(withId: 104)?.mediaInfo?.status, 2)
        XCTAssertTrue(sut.selectedMovieIDs.isEmpty)
        XCTAssertNil(sut.batchErrorMessage)
    }

    func test_requestSelected_singleSelection_requestsOnlyThatMovie() async {
        sut.replaceLoadedCollection(makeCollection())
        sut.toggleSelection(movieId: 104)

        await sut.requestSelected()

        XCTAssertEqual(CollectionDetailTestURLProtocol.createRequestBodies.map(\.mediaId), [104])
        XCTAssertEqual(movie(withId: 104)?.mediaInfo?.status, 2)
        XCTAssertEqual(movie(withId: 101)?.mediaInfo?.status, nil)
        XCTAssertTrue(sut.selectedMovieIDs.isEmpty)
        XCTAssertEqual(sut.requestableMovies.map(\.id), [101])
    }

    func test_requestSelected_partialFailure_marksSuccessesPendingKeepsFailuresSelected() async {
        sut.replaceLoadedCollection(makeCollection())
        CollectionDetailTestURLProtocol.failingMediaIDs = [104]
        sut.toggleSelection(movieId: 101)
        sut.toggleSelection(movieId: 104)

        await sut.requestSelected()

        XCTAssertEqual(CollectionDetailTestURLProtocol.createRequestBodies.map(\.mediaId), [101, 104])
        XCTAssertEqual(movie(withId: 101)?.mediaInfo?.status, 2)
        XCTAssertEqual(movie(withId: 104)?.mediaInfo?.status, 4)
        XCTAssertEqual(sut.selectedMovieIDs, Set([104]))
        XCTAssertEqual(sut.batchErrorMessage, "Couldn't request 1 of 2 movies")
        XCTAssertEqual(sut.requestableMovies.map(\.id), [104])
        XCTAssertFalse(sut.isRequesting)
    }

    func test_requestAll_partialFailure_surfacesErrorAndLeavesFailedSelected() async {
        sut.replaceLoadedCollection(makeCollection())
        CollectionDetailTestURLProtocol.failingMediaIDs = [101]

        await sut.requestAll()

        XCTAssertEqual(CollectionDetailTestURLProtocol.createRequestBodies.map(\.mediaId), [101, 104])
        XCTAssertNil(movie(withId: 101)?.mediaInfo?.status)
        XCTAssertEqual(movie(withId: 104)?.mediaInfo?.status, 2)
        XCTAssertEqual(sut.selectedMovieIDs, Set([101]))
        XCTAssertEqual(sut.batchErrorMessage, "Couldn't request 1 of 2 movies")
    }

    func test_toggleSelection_ignoresUnavailableMovies() {
        sut.replaceLoadedCollection(makeCollection())

        sut.toggleSelection(movieId: 102)
        sut.toggleSelection(movieId: 103)

        XCTAssertTrue(sut.selectedMovieIDs.isEmpty)
        XCTAssertFalse(sut.hasSelection)
    }

    func test_requestAll_isNoOpWhenAlreadyRequesting() async {
        sut.replaceLoadedCollection(makeCollection())

        // Gate the first createRequest so the batch stays in flight under our control
        // (no sleep/yield races). Subsequent createRequests are not held.
        let firstCreateEntered = expectation(description: "first createRequest entered")
        let releaseFirstCreate = DispatchSemaphore(value: 0)
        CollectionDetailTestURLProtocol.createRequestHold = {
            CollectionDetailTestURLProtocol.createRequestHold = nil
            firstCreateEntered.fulfill()
            releaseFirstCreate.wait()
        }

        async let first: Void = sut.requestAll()
        await fulfillment(of: [firstCreateEntered], timeout: 5)

        // First batch is mid-flight: isRequesting must be true before we re-enter.
        XCTAssertTrue(sut.isRequesting)

        // Clear selection while the batch holds. A buggy requestAll that selectAll()s
        // before its isRequesting guard would re-populate selection even though the
        // batch itself no-ops. The guard must prevent that mutation.
        sut.clearSelection()
        XCTAssertTrue(sut.selectedMovieIDs.isEmpty)

        await sut.requestAll()

        XCTAssertTrue(
            sut.selectedMovieIDs.isEmpty,
            "requestAll must not call selectAll while a batch is already in flight"
        )
        // Only the held first createRequest has run so far (still blocked).
        XCTAssertEqual(CollectionDetailTestURLProtocol.createRequestBodies.map(\.mediaId), [])

        releaseFirstCreate.signal()
        await first

        // Exactly one batch: both requestable movies once each.
        XCTAssertEqual(CollectionDetailTestURLProtocol.createRequestBodies.map(\.mediaId), [101, 104])
        XCTAssertFalse(sut.isRequesting)
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
        let requestRepository = RequestRepository(apiClient: client)
        return CollectionDetailViewModel(
            collectionId: collectionId,
            repository: repository,
            requestRepository: requestRepository
        )
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

// MARK: - CollectionDetailTestURLProtocol

private final class CollectionDetailTestURLProtocol: URLProtocol, @unchecked Sendable {
    static var collectionResponse: Collection?
    static var failingMediaIDs: Set<Int> = []
    /// Optional blocking hook invoked on the URL-loading thread before a createRequest
    /// is recorded/completed. Tests use this to keep a batch deterministically in flight.
    static var createRequestHold: (() -> Void)?

    private static let lock = NSLock()
    private static var _createRequestBodies: [MediaRequestBody] = []
    private static var nextRequestID = 9000

    static var createRequestBodies: [MediaRequestBody] {
        lock.withLock { _createRequestBodies }
    }

    static func reset() {
        lock.withLock {
            collectionResponse = nil
            failingMediaIDs = []
            createRequestHold = nil
            _createRequestBodies = []
            nextRequestID = 9000
        }
    }

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

        let method = request.httpMethod ?? "GET"

        if method == "GET", url.path == "/api/v1/collection/42",
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

        if method == "POST", url.path == "/api/v1/request" {
            handleCreateRequest(url: url)
            return
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

    private func handleCreateRequest(url: URL) {
        guard let bodyData = request.httpBody ?? requestBodyFromStream(),
              let body = try? JSONDecoder().decode(MediaRequestBody.self, from: bodyData) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
            return
        }

        // Optional test hold (runs on URL-loading thread). Taken before the body is
        // recorded so tests can observe an empty body list while a batch is mid-flight.
        let hold = Self.lock.withLock { Self.createRequestHold }
        hold?()

        Self.lock.withLock {
            Self._createRequestBodies.append(body)
        }

        let shouldFail = Self.lock.withLock { Self.failingMediaIDs.contains(body.mediaId) }
        if shouldFail {
            let response = HTTPURLResponse(
                url: url,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data("{\"message\":\"stub failure\"}".utf8)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let requestID = Self.lock.withLock { () -> Int in
            Self.nextRequestID += 1
            return Self.nextRequestID
        }

        let payload: [String: Any] = [
            "id": requestID,
            "status": 1,
            "media": [
                "id": body.mediaId,
                "tmdbId": body.mediaId,
                "status": 2
            ]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    private func requestBodyFromStream() -> Data? {
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }
        return data.isEmpty ? nil : data
    }
}
