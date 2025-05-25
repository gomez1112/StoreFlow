//
//  StoreKitPlus.swift
//  Core StoreKit 2 + SwiftData engine
//  Requires: iOS 17.4 / macOS 14.4 / visionOS 1.2 or later
//

import Foundation
import StoreKit
import SwiftData
import SwiftUI



@MainActor
@Observable
public final class StoreFlow: Sendable {
    private let config: StoreConfiguration
    private let modelContext: ModelContext
    
    public private(set) var currentAccess: AccessLevel = .notSubscribed
    public private(set) var availableProducts: [Product] = []
    public private(set) var purchasedProductIDs: Set<String> = []
    public var error: StoreError?
    
    public init(configuration: StoreConfiguration, modelContext: ModelContext) {
        self.config = configuration
        self.modelContext = modelContext
        Task { await reloadProducts() }
        Task { await observeTransactions() }
    }
    
    public func reloadProducts() async {
        do {
            let products = try await Product.products(for: config.productIDs)
            await MainActor.run {
                self.availableProducts = products
            }
        } catch {
            await MainActor.run {
                self.error = .productRequestFailed(error)
            }
        }
    }
    
    // MARK: - Purchase
    
    @discardableResult
    public func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        do {
            let result = try await product.purchase()
            switch result {
                case .success(let verification):
                    let transaction = try verification.payloadValue
                    try await handleTransaction(transaction)
                    return transaction
                case .userCancelled:
                    return nil
                default:
                    throw StoreError.failedVerification
            }
        } catch let err as StoreError {
            await MainActor.run { self.error = err }
            throw err
        } catch {
            let storeError = StoreError.unknown(error)
            await MainActor.run { self.error = storeError }
            throw storeError
        }
    }
    
    private func handleTransaction(_ transaction: StoreKit.Transaction) async throws {
        let productID = transaction.productID
        purchasedProductIDs.insert(productID)
        if config.consumableIDs.contains(productID) {
            do {
                try await incrementConsumable(id: productID)
            } catch {
                throw StoreError.swiftDataSaveFailed(error)
            }
        }
        let access = config.productAccess[productID] ?? .notSubscribed
        if access > currentAccess {
            currentAccess = access
        }
    }
    
    private func observeTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try result.payloadValue
                try await handleTransaction(transaction)
                await transaction.finish()
            } catch let err as StoreError {
                await MainActor.run { self.error = err }
            } catch {
                let storeError = StoreError.unknown(error)
                await MainActor.run { self.error = storeError }
            }
        }
    }
    
    // MARK: - Consumables
    
    public func consumableQuantity(for id: String) -> Int {
        do {
            let fetch = FetchDescriptor<ConsumableCredit>(predicate: #Predicate { $0.id == id })
            let credits = try modelContext.fetch(fetch)
            return credits.first?.quantity ?? 0
        } catch {
            self.error = .swiftDataFetchFailed(error)
            return 0
        }
    }
    
    public func useConsumable(id: String, amount: Int = 1) throws {
        do {
            let fetch = FetchDescriptor<ConsumableCredit>(predicate: #Predicate { $0.id == id })
            if let credit = try modelContext.fetch(fetch).first {
                if credit.quantity >= amount {
                    credit.quantity -= amount
                } else {
                    throw StoreError.insufficientBalance
                }
            } else {
                throw StoreError.insufficientBalance
            }
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
        do {
            let fetch = FetchDescriptor<ConsumableCredit>(predicate: #Predicate { $0.id == id })
            if let credit = try modelContext.fetch(fetch).first {
                credit.quantity += amount
            } else {
                let new = ConsumableCredit(id: id, quantity: amount)
                modelContext.insert(new)
            }
        } catch {
            throw StoreError.swiftDataSaveFailed(error)
        }
    }
    
    // MARK: - Restore/Sync
    
    public func sync() async {
        do {
            try await AppStore.sync()
            await reloadProducts()
        } catch {
            self.error = .unknown(error)
        }
    }
    
    public func restorePurchases() async {
        await sync()
    }
}

