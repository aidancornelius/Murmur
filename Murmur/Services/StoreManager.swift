import StoreKit
import SwiftUI
import os.log

@MainActor
class StoreManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle

    private let logger = Logger(subsystem: "app.murmur", category: "StoreKit")
    private let productIDs = ["com.murmur.tip.small"]

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case purchased
        case failed(String)
    }

    init() {
        Task {
            await loadProducts()
        }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
            purchaseState = .failed("Unable to load products")
        }
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    purchaseState = .purchased
                case .unverified:
                    purchaseState = .failed("Purchase verification failed")
                }
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func resetPurchaseState() {
        purchaseState = .idle
    }
}
