import Foundation

/// Stable identifiers shared by all Apple platforms. Prices come only from StoreKit.
enum SupportProduct: String, CaseIterable, Sendable {
    case small, medium, large

    var productID: String { "com.frostforgelabs.OctopusExplorer.support.tip.\(rawValue)" }
}

struct TipJarProduct: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
}
