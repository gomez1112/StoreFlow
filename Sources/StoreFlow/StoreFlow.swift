//
//  StoreKitPlus.swift
//  Core StoreKit 2 + SwiftData engine
//  Requires: iOS 17.4 / macOS 14.4 / visionOS 1.2 or later
//

import Foundation
import StoreKit
import SwiftData
import SwiftUI


typealias Transaction = StoreKit.Transaction


// ───────────────────────────────────────────────────────────────────────────
// MARK: – Store actor (StoreKit + persistence)
// ───────────────────────────────────────────────────────────────────────────

@MainActor
@Observable
public final class Store<ID: StoreProductID> {

    public private(set) var products: [ID: Product] = [:]
    public private(set) var actives: Set<ID> = []
    public private(set) var balances: [ID: Int] = [:]
    public private(set) var renewals: [ID: RenewalRecord] = [:]
    public private(set) var lastError: StoreError? = nil
    
    // Internals ────────────────────────────────────────────────────────────
    private let context: ModelContext
    private var updatesTask: Task<Void, Never>? = nil
    
    // init / deinit ────────────────────────────────────────────────────────
    public init(context: ModelContext) {
        self.context = context
        bootstrapFromDisk()
        updatesTask = listenForTransactions()
        Task { await requestProducts() }
        Task { await syncPastTransactions() }
        Task { await refreshSubscriptionStatus() }
    }
    
    // Convenience look-ups ─────────────────────────────────────────────────
    public func owns(_ id: ID) -> Bool {
        actives.contains(id)
    }
    public func balance(of id: ID) -> Int {
        balances[id, default: 0]
    }
    
    // MARK: – StoreKit interaction ––––––––––––––––––––––––––––––––––––––––
    
    private func requestProducts() async {
        do {
            let fetched = try await Product.products(for: ID.allCases.map(\.rawValue))
            for p in fetched where ID(rawValue: p.id) != nil {
                products[ID(rawValue: p.id)!] = p
            }
        } catch { lastError = .productRequestFailed(error) }
    }
    
    private func listenForTransactions() -> Task<Void,Never> {
        Task.detached(priority: .background) { [weak self] in          // 🔑 weak
            guard let self else { return }                             // stop if gone
            for await result in Transaction.updates {
                await self.handle(result)
            }
        }
    }

    
    private func syncPastTransactions() async {
        for await result in Transaction.all { await handle(result) }
    }
    
    private func handle(_ result: VerificationResult<Transaction>) async {
        do {
            let txn = try verified(result)
            try await apply(txn)
            await txn.finish()
        } catch { lastError = error as? StoreError ?? .unknown(error) }
    }
    
    // MARK: – Verification helpers ––––––––––––––––––––––––––––––––––––––––
    
    private func verified(_ r: VerificationResult<Transaction>) throws -> Transaction {
        guard case .verified(let t) = r else { throw StoreError.failedVerification }
        return t
    }
    
    private func verified( _ r: VerificationResult<Product.SubscriptionInfo.RenewalInfo>) throws -> Product.SubscriptionInfo.RenewalInfo {
        guard case .verified(let info) = r else { throw StoreError.failedVerification }
        return info
    }
    
    // MARK: – Apply transaction ––––––––––––––––––––––––––––––––––––––––––––
    
    private func apply(_ txn: Transaction) async throws {
        guard let id = ID(rawValue: txn.productID) else { throw StoreError.unknownProduct }
        
        switch txn.productType {
            case .autoRenewable, .nonRenewable, .nonConsumable:
                txn.revocationDate == nil ? grant(id) : revoke(id)
                
            case .consumable:
                try addUnits(id, qty: txn.purchasedQuantity)
                
            default: throw StoreError.unsupportedProductType
        }
        
        try context.save()
        refreshCaches()
        if txn.productType == .autoRenewable { await refreshSubscriptionStatus() }
    }
    
    // MARK: – Entitlements & consumables helpers -------------------------------
    @_spi(Testing) public func grant(_ id: ID) {
        guard !owns(id) else { return }
        context.insert(EntitlementRecord(productID: id.rawValue))
        try? context.save()
        refreshCaches()                       // ← added
    }
    
    @_spi(Testing) public func revoke(_ id: ID) {
        if let e = fetchEnt(id) {
            context.delete(e)
            try? context.save()
            refreshCaches()                   // ← added
        }
    }
    
    @_spi(Testing) public func addUnits(_ id: ID, qty: Int) throws {
        let rec = fetchCons(id) ?? {
            let r = ConsumableRecord(productID: id.rawValue)
            context.insert(r); return r
        }()
        rec.quantity += qty
        try context.save()
        refreshCaches()                       // ← added
    }
    
    public func consume(_ id: ID, qty: Int = 1) throws {
        guard let rec = fetchCons(id), rec.quantity >= qty
        else { throw StoreError.insufficientBalance }
        rec.quantity -= qty
        try context.save()
        refreshCaches()
    }
    
    // MARK: – Subscription status (iOS 17.4+) –––––––––––––––––––––––––––––
    
    public func refreshSubscriptionStatus() async {
        
        for id in ID.allCases where products[id]?.type == .autoRenewable {
            do {
                if let status = try await Product.SubscriptionInfo
                    .status(for: id.rawValue).first {
                    
                    let info = try verified(status.renewalInfo)
                    try upsertRenewal(id,
                                      date:  info.renewalDate,
                                      auto:  info.willAutoRenew,
                                      retry: info.isInBillingRetry)       // ← correct name
                }
            } catch { lastError = .subscriptionStatusFailed(error) }
        }
        refreshCaches()
    }
    
    // MARK: – SwiftData fetch helpers ––––––––––––––––––––––––––––––––––––––
    
    private func fetchEnt(_ id: ID) -> EntitlementRecord? {
        try? context.fetch(
            FetchDescriptor<EntitlementRecord>(
                predicate: #Predicate { $0.productID == id.rawValue })
        ).first
    }
    
    private func fetchCons(_ id: ID) -> ConsumableRecord? {
        try? context.fetch(
            FetchDescriptor<ConsumableRecord>(
                predicate: #Predicate { $0.productID == id.rawValue })
        ).first
    }
    
    private func fetchRen(_ id: ID) -> RenewalRecord? {
        try? context.fetch(
            FetchDescriptor<RenewalRecord>(
                predicate: #Predicate { $0.productID == id.rawValue })
        ).first
    }
    
    private func upsertRenewal(_ id: ID, date: Date?, auto: Bool, retry: Bool) throws {
        let rec = fetchRen(id) ?? {
            let r = RenewalRecord(productID: id.rawValue)
            context.insert(r)
            return r
        }()
        rec.renewalDate      = date
        rec.willAutoRenew    = auto
        rec.isInBillingRetry = retry
        try context.save()
    }
    
    // MARK: – Cache bootstrap / refresh –––––––––––––––––––––––––──────────–
    
    private func bootstrapFromDisk() {
        do {
            actives = Set(try context.fetch(FetchDescriptor<EntitlementRecord>())
                    .compactMap { ID(rawValue: $0.productID) }
            )
            
            balances = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<ConsumableRecord>())
                .compactMap { rec -> (ID, Int)? in
                    guard let id = ID(rawValue: rec.productID) else { return nil }
                    return (id, rec.quantity)
                }
            )
            
            renewals = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<RenewalRecord>())
                .compactMap { rec -> (ID, RenewalRecord)? in
                    guard let id = ID(rawValue: rec.productID) else { return nil }
                    return (id, rec)
                }
            )
        } catch { lastError = .swiftDataFetchFailed(error) }
    }
    
    private func refreshCaches() { bootstrapFromDisk() }
    
}

// ───────────────────────────────────────────────────────────────────────────
// MARK: – Access-level helpers (when ID : AccessLevelMappable)
// ───────────────────────────────────────────────────────────────────────────

public extension Store where ID: AccessLevelMappable {
    /// Highest tier unlocked by the currently-verified entitlements.
    var accessLevel: AccessLevel {
        actives
            .map(\.accessLevel)
            .max() ?? .free
    }
}

// ───────────────────────────────────────────────────────────────────────────
// MARK: – accessLevel @Environment entry
// ───────────────────────────────────────────────────────────────────────────

extension EnvironmentValues {
    @Entry public var accessLevel: AccessLevel = .free
    
    public var hasPro: Bool      { accessLevel == .pro || accessLevel == .lifetime }
    public var hasLifetime: Bool { accessLevel == .lifetime }
}

