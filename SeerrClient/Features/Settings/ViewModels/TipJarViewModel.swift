import Foundation
import Observation

@MainActor
@Observable
final class TipJarViewModel {
    static let shared = TipJarViewModel(repository: TipJarRepository())
    static func start() {
        #if DEBUG
        // Hosted unit tests create their own repository after configuring SKTestSession.
        // An earlier StoreKit call would cache the sandbox environment for the process.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        #endif
        _ = shared
    }

    static let disclosure = "Tipping helps fund ongoing development. It does not unlock any features in the app."

    enum State: Equatable {
        case idle, loading, ready, purchasing(String), pending, thankYou, error(String)
    }
    private(set) var state: State = .idle
    private(set) var products: [TipJarProduct] = []
    @ObservationIgnored private let repository: any TipJarPurchasing
    private var operationInProgress = false
    @ObservationIgnored private var completionGeneration = 0

    init(repository: any TipJarPurchasing) {
        self.repository = repository
        repository.onCompletion = { [weak self] in
            guard let self else { return }
            self.completionGeneration += 1
            self.state = .thankYou
        }
    }

    var isBusy: Bool { operationInProgress }

    func load() async {
        guard !operationInProgress else { return }
        operationInProgress = true
        defer { operationInProgress = false }
        let generation = completionGeneration
        state = .loading
        do {
            products = try await repository.loadProducts()
            // Preserve an approval delivered while loading metadata.
            if generation == completionGeneration {
                state = products.isEmpty ? .error(TipJarError.unavailable.localizedDescription) : .ready
            }
        } catch {
            if generation == completionGeneration { state = .error(error.localizedDescription) }
        }
    }

    func purchase(_ product: TipJarProduct) async {
        guard !operationInProgress, products.contains(product) else { return }
        operationInProgress = true
        defer { operationInProgress = false }
        let generation = completionGeneration
        state = .purchasing(product.id)
        do {
            switch try await repository.purchase(product.id) {
            case .purchased: state = .thankYou
            case .cancelled: if generation == completionGeneration { state = .ready }
            case .pending: if generation == completionGeneration { state = .pending }
            }
        } catch {
            if generation == completionGeneration { state = .error(error.localizedDescription) }
        }
    }
}
