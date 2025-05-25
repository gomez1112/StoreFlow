//
//  AccessLevel.swift
//  StoreFlow
//
//  Created by Gerard Gomez on 5/25/25.
//

import Foundation

public enum AccessLevel: Int, Codable, Comparable, Sendable {
    case notSubscribed, individual, family, premium
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
