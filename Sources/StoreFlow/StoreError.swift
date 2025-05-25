//
//  File.swift
//  StoreFlow
//
//  Created by Gerard Gomez on 4/27/25.
//

import Foundation

// ───────────────────────────────────────────────────────────────────────────
// MARK: – Error taxonomy
// ───────────────────────────────────────────────────────────────────────────

public enum StoreError: LocalizedError, Sendable, Identifiable, Equatable {
    
    public var id: String { localizedDescription }
    
    case failedVerification, insufficientBalance
    case productRequestFailed(Error)
    case swiftDataSaveFailed(Error), swiftDataFetchFailed(Error)
    case subscriptionStatusFailed(Error)
    case unsupportedProductType, unknownProduct
    case purchasePending
    case invalidAmount
    case syncFailed(Error)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
            case .failedVerification:      "The App Store couldn’t verify this purchase."
            case .insufficientBalance:     "Not enough credits remaining."
            case .unsupportedProductType:  "Unsupported product type."
            case .unknownProduct:          "Unrecognised product identifier."
            case .purchasePending: "Purchase pending"
            case .invalidAmount: "The amount is invalid"
            case .productRequestFailed(let e),
                    .swiftDataSaveFailed(let e),
                    .swiftDataFetchFailed(let e),
                    .subscriptionStatusFailed(let e),
                    .syncFailed(let e),
                    .unknown(let e):          e.localizedDescription
        }
    }
    
    public static func == (lhs: StoreError, rhs: StoreError) -> Bool {
        lhs.id == rhs.id
    }
}
