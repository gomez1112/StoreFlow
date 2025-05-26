//
//  StoreKitPlus.swift
//  Core StoreKit 2 + SwiftData engine
//  Requires: iOS 17.4 / macOS 14.4 / visionOS 1.2 or later
//

import Foundation
import StoreKit
import SwiftData
import SwiftUI
import OSLog




@MainActor
@Observable
public final class StoreFlow {
    private let config: StoreConfiguration
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "StoreFlow", category: "Store")
    private var updatesTask: Task<Void, Never>?
    
    public private(set) var currentAccess: AccessLevel = .notSubscribed
    public private(set) var availableProducts: [Product] = []
    public private(set) var purchasedProductIDs: Set<String> = []
    public private(set) var activeSubscriptions: Set<String> = []
    public var error: StoreError?
    var consumableTransactions: [StoreKit.Transaction] = []
    
    func loadConsumableTransactions() async {
            var transactions: [StoreKit.Transaction] = []
            for await result in StoreKit.Transaction.all {
                if let transaction = try? result.payloadValue, transaction.productType == .consumable {
                    transactions.append(transaction)
                }
            }
            consumableTransactions = transactions
    }
    public init(configuration: StoreConfiguration, modelContext: ModelContext) {
        self.config = configuration
        self.modelContext = modelContext
        
        Task {
            await reloadProducts()
            await updatePurchasedProducts()
        }
        
        // Start transaction observer
        updatesTask = Task { await observeTransactions() }
    }
   
    public func reloadProducts() async {
        do {
            let products = try await Product.products(for: config.productIDs)
            await MainActor.run {
                self.availableProducts = products.sorted { $0.price < $1.price }
            }
            logger.info("Loaded \(products.count) products")
        } catch {
            await MainActor.run {
                self.error = .productRequestFailed(error)
            }
            logger.error("Failed to load products: \(error)")
        }
    }
 
    public func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var activeSubs: Set<String> = []
        var highestAccess: AccessLevel = .notSubscribed
        
        // Check all current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Only add if transaction is not revoked
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                    
                    // Check if it's an active subscription
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        activeSubs.insert(transaction.productID)
                    } else if transaction.productType == .nonConsumable {
                        // Non-consumables are always active
                        activeSubs.insert(transaction.productID)
                    }
                    
                    // Update access level
                    if let access = config.productAccess[transaction.productID],
                       access > highestAccess {
                        highestAccess = access
                    }
                }
            } catch {
                logger.error("Failed to verify transaction: \(error)")
            }
        }
        
        await MainActor.run {
            self.purchasedProductIDs = purchased
            self.activeSubscriptions = activeSubs
            self.currentAccess = highestAccess
        }
    }
    
    @discardableResult
    public func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        do {
            let result = try await product.purchase()
            
            switch result {
                case .success(let verification):
                    let transaction = try checkVerified(verification)
                    try await handleTransaction(transaction)
                    await transaction.finish()
                    return transaction
                    
                case .userCancelled:
                    logger.info("User cancelled purchase")
                    return nil
                    
                case .pending:
                    logger.info("Purchase pending")
                    throw StoreError.purchasePending
                    
                @unknown default:
                    throw StoreError.unknown(NSError(domain: "StoreFlow", code: -1))
            }
        } catch let err as StoreError {
            self.error = err
            throw err
        } catch {
            let storeError = StoreError.unknown(error)
            self.error = storeError
            throw storeError
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
            case .unverified(_, let error):
                logger.error("Verification failed: \(error)")
                throw StoreError.failedVerification
            case .verified(let safe):
                return safe
        }
    }
   
    private func handleTransaction(_ transaction: StoreKit.Transaction) async throws {
        let productID = transaction.productID
        
        // Update purchased products
        purchasedProductIDs.insert(productID)
        
        // Handle consumables
        if config.consumableIDs.contains(productID) {
            try await incrementConsumable(id: productID)
        } else {
            // For non-consumables and subscriptions, update active status
            if transaction.revocationDate == nil {
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        activeSubscriptions.insert(productID)
                    }
                } else {
                    // Non-consumable or lifetime
                    activeSubscriptions.insert(productID)
                }
            }
        }
        
        // Update access level
        await updateAccessLevel()
        
        logger.info("Handled transaction for product: \(productID)")
    }
    
    private func updateAccessLevel() async {
        var highestAccess: AccessLevel = .notSubscribed
        
        for productID in activeSubscriptions {
            if let access = config.productAccess[productID],
               access > highestAccess {
                highestAccess = access
            }
        }
        
        currentAccess = highestAccess
    }
    
    private func observeTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                try await handleTransaction(transaction)
                await transaction.finish()
                
                // Update purchase state after handling transaction
                await updatePurchasedProducts()
            } catch {
                logger.error("Error handling transaction update: \(error)")
                self.error = .unknown(error)
            }
        }
    }
    public func consumableQuantity(for id: String) -> Int {
        do {
            let fetch = FetchDescriptor<ConsumableCredit>(
                predicate: #Predicate { $0.id == id }
            )
            let credits = try modelContext.fetch(fetch)
            return credits.first?.quantity ?? 0
        } catch {
            logger.error("Failed to fetch consumable quantity: \(error)")
            self.error = .swiftDataFetchFailed(error)
            return 0
        }
    }
    
    public func useConsumable(id: String, amount: Int = 1) throws {
        guard amount > 0 else {
            throw StoreError.invalidAmount
        }
        
        do {
            let fetch = FetchDescriptor<ConsumableCredit>(
                predicate: #Predicate { $0.id == id }
            )
            
            guard let credit = try modelContext.fetch(fetch).first else {
                throw StoreError.insufficientBalance
            }
            
            guard credit.quantity >= amount else {
                throw StoreError.insufficientBalance
            }
            
            credit.quantity -= amount
            try saveContext()
            
            logger.info("Used \(amount) of consumable: \(id)")
        } catch let err as StoreError {
            self.error = err
            throw err
        } catch {
            let storeError = StoreError.swiftDataFetchFailed(error)
            self.error = storeError
            throw storeError
        }
    }
 
    public func incrementConsumable(id: String, amount: Int = 1) async throws {
        guard amount > 0 else {
            throw StoreError.invalidAmount
        }
        
        do {
            let fetch = FetchDescriptor<ConsumableCredit>(
                predicate: #Predicate { $0.id == id }
            )
            
            if let credit = try modelContext.fetch(fetch).first {
                credit.quantity += amount
            } else {
                let new = ConsumableCredit(id: id, quantity: amount)
                modelContext.insert(new)
            }
            
            try saveContext()
            logger.info("Added \(amount) to consumable: \(id)")
        } catch {
            throw StoreError.swiftDataSaveFailed(error)
        }
    }
    
    private func saveContext() throws {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save context: \(error)")
            throw error
        }
    }
    
    // MARK: - Restore/Sync

    public func sync() async {
        do {
            try await AppStore.sync()
            await reloadProducts()
            await updatePurchasedProducts()
            logger.info("Store sync completed")
        } catch {
            self.error = .syncFailed(error)
            logger.error("Store sync failed: \(error)")
        }
    }

    public func restorePurchases() async {
        await sync()
    }
    
    // MARK: - Helpers
    
    public func isProductPurchased(_ productID: String) -> Bool {
        activeSubscriptions.contains(productID)
    }
    
    public func product(for id: String) -> Product? {
        availableProducts.first { $0.id == id }
    }
}

