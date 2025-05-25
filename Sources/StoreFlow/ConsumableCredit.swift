//
//  ConsumableCredit.swift
//  StoreFlow
//
//  Created by Gerard Gomez on 4/27/25.
//

import Foundation
import SwiftData

@Model
public final class ConsumableCredit {
    @Attribute(.unique) public var id: String
    public var quantity: Int
    
    public init(id: String, quantity: Int) {
        self.id = id
        self.quantity = quantity
    }
}
