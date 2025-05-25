//
//  StoreConfiguration.swift
//  StoreFlow
//
//  Created by Gerard Gomez on 4/27/25.
//

import Foundation

public protocol StoreConfiguration {
    var groupID: String { get }
    var productIDs: [String] { get }
    var productAccess: [String: AccessLevel] { get }
    var consumableIDs: [String] { get }
}

public struct DefaultStoreConfiguration: StoreConfiguration {
    public let groupID: String
    public let productIDs: [String]
    public let productAccess: [String: AccessLevel]
    public let consumableIDs: [String]
    public init(groupID: String, productIDs: [String], productAccess: [String: AccessLevel], consumableIDs: [String]) {
        self.groupID = groupID
        self.productIDs = productIDs
        self.productAccess = productAccess
        self.consumableIDs = consumableIDs
    }
}


