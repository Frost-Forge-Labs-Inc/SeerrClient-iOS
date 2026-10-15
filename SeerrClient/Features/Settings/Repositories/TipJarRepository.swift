import StoreKit

@MainActor
protocol TipJarPurchasing: AnyObject {
    var onCompletion: (() -> Void)? { get set }
    func loadProducts() async throws -> [TipJarProduct]
    func purchase(_ id: String) async throws -> TipJarPurchaseResult
}

enum TipJarPurchaseResult { case purchased, cancelled, pending }

enum TipJarError: LocalizedError {
    case unavailable, unverified
    var errorDescription: String? {
        switch self {
        case .unavailable: "Tips are unavailable right now. Please try again later."
        case .unverified: "Your purchase could not be verified. Please try again later."
        }
    }
}

/// App-lifetime owner: consumes only verified, non-revoked tip transactions.
@MainActor
final class TipJarRepository: TipJarPurchasing {
    var onCompletion: (() -> Void)?
    private var products: [String: Product] = [:]
    private var listener: Task<Void, Never>?
    private var recovery: Task<Void, Never>?
    private var completions: [UInt64: Task<Void, Never>] = [:]

    init() {
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                try? await self?.complete(result)
            }
        }
        recovery = Task { [weak self] in
            for await result in Transaction.unfinished {
                guard !Task.isCancelled else { return }
                try? await self?.complete(result)
            }
        }
    }

    deinit { listener?.cancel(); recovery?.cancel() }

    func loadProducts() async throws -> [TipJarProduct] {
        let loaded = try await Product.products(for: SupportProduct.allCases.map(\.productID))
        products = Dictionary(uniqueKeysWithValues: loaded.filter { $0.type == .consumable }.map { ($0.id, $0) })
        return SupportProduct.allCases.compactMap { tier in
            guard let product = products[tier.productID] else { return nil }
            return TipJarProduct(id: product.id, displayName: product.displayName, displayPrice: product.displayPrice)
        }
    }

    func purchase(_ id: String) async throws -> TipJarPurchaseResult {
        guard let product = products[id] else { throw TipJarError.unavailable }
        switch try await product.purchase() {
        case .success(let result):
            try await complete(result)
            return .purchased
        case .userCancelled: return .cancelled
        case .pending: return .pending
        @unknown default: throw TipJarError.unavailable
        }
    }

    private func complete(_ result: VerificationResult<Transaction>) async throws {
        guard case .verified(let transaction) = result else { throw TipJarError.unverified }
        guard SupportProduct.allCases.contains(where: { $0.productID == transaction.productID }),
              transaction.productType == .consumable, transaction.revocationDate == nil else { return }
        // Both delivery paths await the same finish, including when they race.
        if let completion = completions[transaction.id] {
            await completion.value
            return
        }
        let completion = Task { [weak self] in
            await transaction.finish()
            self?.onCompletion?()
        }
        completions[transaction.id] = completion
        await completion.value
    }
}
