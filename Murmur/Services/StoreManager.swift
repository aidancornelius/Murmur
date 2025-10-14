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

    // Task references for cleanup
    private var transactionUpdatesTask: Task<Void, Never>?

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

        // Listen for transaction updates to handle purchases that complete
        // when the app is backgrounded or killed
        // Store task reference for cleanup
        transactionUpdatesTask = Task {
            for await result in Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
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

    /// Silently checks purchase history in the background without affecting UI state
    /// Runs off the main actor to avoid blocking the main thread
    /// Returns true if a purchase was found, false otherwise
    nonisolated func silentRestorePurchases() async -> Bool {
        let productIDsToCheck = productIDs
        var foundPurchase = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIDsToCheck.contains(transaction.productID) {
                    foundPurchase = true
                    break
                }
            }
        }

        // Only update hasTipped on main actor if we found a purchase
        if foundPurchase {
            await MainActor.run { [weak self] in
                self?.hasTipped = true
            }
        }

        return foundPurchase
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

// MARK: - ResourceManageable conformance

extension StoreManager: ResourceManageable {
    nonisolated func start() async throws {
        // Initialisation happens in init, products are loaded there
    }

    nonisolated func cleanup() {
        // Assume we're on the main actor (safe in tests and normal app usage)
        // This avoids creating an unstructured Task that completes asynchronously
        MainActor.assumeIsolated {
            _cleanup()
        }
    }

    @MainActor
    private func _cleanup() {
        // Cancel transaction observation
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = nil

        // Clear cached products
        products.removeAll()

        // Reset purchase state
        purchaseState = .idle
    }
}
