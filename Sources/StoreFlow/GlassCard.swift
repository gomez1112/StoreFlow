//
//  GlassCard.swift
//  StoreFlow
//
//  Created by Gerard Gomez on 5/25/25.
//

import Foundation
import SwiftUI

public struct GlassCard<Content: View>: View {
    let content: Content
    public init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    public var body: some View {
        content
            .padding(24)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }
}
