import XCTest
@testable import SeerrClient

@MainActor
final class TipJarTests: XCTestCase {
    func testProductIDs() {
        XCTAssertEqual(SupportProduct.allCases.map(\.productID), [
            "com.frostforgelabs.OctopusExplorer.support.tip.small",
            "com.frostforgelabs.OctopusExplorer.support.tip.medium",
            "com.frostforgelabs.OctopusExplorer.support.tip.large"
        ])
        XCTAssertTrue(TipJarViewModel.disclosure.contains("does not unlock any features"))
    }

    func testLoadPurchaseCancellationPendingAndThankYou() async {
        let repository = StubRepository()
        let model = TipJarViewModel(repository: repository)
        XCTAssertEqual(model.state, .idle)
        await model.load()
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.products, [repository.product])
        repository.result = .cancelled
        await model.purchase(repository.product)
        XCTAssertEqual(model.state, .ready)
        repository.result = .pending
        await model.purchase(repository.product)
        XCTAssertEqual(model.state, .pending)
        repository.onCompletion?()
        XCTAssertEqual(model.state, .thankYou)
        repository.result = .purchased
        await model.purchase(repository.product)
        XCTAssertEqual(model.state, .thankYou)
        XCTAssertEqual(repository.purchases, 3)
    }

    func testFailuresAndRetry() async {
        let repository = StubRepository()
        let model = TipJarViewModel(repository: repository)
        repository.fail = true
        await model.load()
        guard case .error = model.state else { return XCTFail("Expected loading failure") }
        repository.fail = false
        repository.empty = true
        await model.load()
        guard case .error = model.state else { return XCTFail("Expected unavailable products") }
        repository.empty = false
        await model.load()
        repository.fail = true
        await model.purchase(repository.product)
        guard case .error = model.state else { return XCTFail("Expected purchase failure") }
        XCTAssertFalse(model.isBusy)
        repository.fail = false
        await model.purchase(repository.product)
        XCTAssertEqual(model.state, .thankYou)
    }

    func testPurchaseIsSerializedAndShowsProgress() async {
        let repository = StubRepository()
        let model = TipJarViewModel(repository: repository)
        await model.load()
        repository.pause = true
        let purchase = Task { await model.purchase(repository.product) }
        while repository.continuation == nil { await Task.yield() }
        XCTAssertEqual(model.state, .purchasing(repository.product.id))
        XCTAssertTrue(model.isBusy)
        await model.purchase(repository.product)
        await model.load()
        XCTAssertEqual(repository.purchases, 1)
        repository.continuation?.resume()
        await purchase.value
        XCTAssertEqual(model.state, .thankYou)
    }

    func testApprovalSurvivesConcurrentFailureOrCancellation() async {
        for fails in [false, true] {
            let repository = StubRepository()
            let model = TipJarViewModel(repository: repository)
            await model.load()
            repository.pause = true
            repository.result = .cancelled
            repository.fail = fails
            let purchase = Task { await model.purchase(repository.product) }
            while repository.continuation == nil { await Task.yield() }
            repository.onCompletion?()
            repository.continuation?.resume()
            await purchase.value
            XCTAssertEqual(model.state, .thankYou)
            XCTAssertFalse(model.isBusy)
        }
    }

}

@MainActor
private final class StubRepository: TipJarPurchasing {
    var onCompletion: (() -> Void)?
    let product = TipJarProduct(id: SupportProduct.small.productID, displayName: "Small Tip", displayPrice: "$1.99")
    var result: TipJarPurchaseResult = .purchased
    var fail = false
    var empty = false
    var pause = false
    var purchases = 0
    var continuation: CheckedContinuation<Void, Never>?
    func loadProducts() async throws -> [TipJarProduct] {
        if fail { throw TipJarError.unavailable }
        return empty ? [] : [product]
    }
    func purchase(_ id: String) async throws -> TipJarPurchaseResult {
        purchases += 1
        if pause { await withCheckedContinuation { continuation = $0 } }
        if fail { throw TipJarError.unverified }
        return result
    }
}
