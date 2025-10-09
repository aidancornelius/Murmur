//
//  StoreManager.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import StoreKit
import SwiftUI
import os.log

@MainActor
class StoreManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var hasTipped: Bool = false

    private let logger = Logger(subsystem: "app.murmur", category: "StoreKit")
    private let productIDs = ["com.murmur.tip.small", "com.murmur.tip.generous"]

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case purchased
        case failed(String)
    }

    init() {
        Task {
            await loadProducts()
            await checkPurchaseHistory()
        }

        // Listen for transaction updates to handle purchases that complete
        // when the app is backgrounded or killed
        Task {
            for await result in Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }
    }

    func checkPurchaseHistory() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIDs.contains(transaction.productID) {
                    logger.info("Found previous tip purchase: \(transaction.productID)")
                    hasTipped = true
                    return
                }
            }
        }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
            logger.debug("Loaded \(self.products.count) products")
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
                    logger.info("Purchase successful - Product: \(product.id), Price: \(product.displayPrice)")
                    logger.info("Transaction ID: \(transaction.id), Date: \(transaction.purchaseDate)")
                    await transaction.finish()
                    hasTipped = true
                    purchaseState = .purchased
                case .unverified:
                    logger.error("Purchase verification failed")
                    purchaseState = .failed("Purchase verification failed")
                }
            case .userCancelled:
                logger.info("Purchase cancelled by user")
                purchaseState = .idle
            case .pending:
                logger.info("Purchase pending")
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

    private func handleTransactionUpdate(_ result: VerificationResult<StoreKit.Transaction>) async {
        switch result {
        case .verified(let transaction):
            // Only process transactions for our products
            guard productIDs.contains(transaction.productID) else {
                return
            }

            logger.info("Transaction update received - Product: \(transaction.productID), Transaction ID: \(transaction.id)")

            // Finish the transaction
            await transaction.finish()

            // Update state
            hasTipped = true
            purchaseState = .purchased

        case .unverified(let transaction, let error):
            logger.error("Unverified transaction for \(transaction.productID): \(error.localizedDescription)")
            // Still finish unverified transactions to prevent them from appearing again
            await transaction.finish()
        }
    }
}
