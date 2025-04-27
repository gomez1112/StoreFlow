//
//  File.swift
//  StoreFlow
//
//  Created by Gerard Gomez on 4/27/25.
//

import Foundation

public protocol StoreProductID: RawRepresentable<String>, CaseIterable, Hashable, Sendable, Codable { }
public enum AccessLevel: Int, Codable, Sendable, Comparable {
    case free, pro, lifetime
    public static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }
}

/// Conform on your ProductID enum to map SKUs → tier.
public protocol AccessLevelMappable {
    var accessLevel: AccessLevel { get }
}
