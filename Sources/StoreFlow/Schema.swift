//
//  File.swift
//  StoreFlow
//
//  Created by Gerard Gomez on 4/27/25.
//

import Foundation
import SwiftData

// ───────────────────────────────────────────────────────────────────────────
// MARK: – SwiftData schema
// ───────────────────────────────────────────────────────────────────────────

@Model public final class EntitlementRecord {
    @Attribute(.unique) public var productID: String
    
    public init(productID: String) {
        self.productID = productID
    }
}

@Model public final class ConsumableRecord {
    @Attribute(.unique) public var productID: String
    public var quantity: Int
    
    public init(productID: String, quantity: Int = 0) {
        self.productID = productID
        self.quantity  = quantity
    }
}

@Model public final class RenewalRecord {
    @Attribute(.unique) public var productID: String
    public var renewalDate: Date?
    public var willAutoRenew = false
    public var isInBillingRetry = false
    
    public init(productID: String) {
        self.productID = productID
    }
}
