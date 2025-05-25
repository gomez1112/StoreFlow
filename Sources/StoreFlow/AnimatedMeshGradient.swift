//
//  AnimatedMeshGradient.swift
//  StoreFlow
//
//  Created by Gerard Gomez on 5/25/25.
//

import SwiftUI

public struct AnimatedMeshGradient: View {
    private let amplitude: Float  = 0.008
    private let frequency: Double = 0.2
    private let basePoints: [SIMD2<Float>] = [
        .init(0.00, 0.00), .init(0.50, 0.05), .init(1.00, 0.00),
        .init(0.00, 0.50), .init(0.95, 0.35), .init(1.00, 0.50),
        .init(0.00, 1.00), .init(0.50, 0.95), .init(1.00, 1.00)
    ]
    private let palette: [Color] = [
        .pink,  .purple, .cyan,
        .mint,  .yellow, .orange,
        .indigo, .teal,  .blue
    ]
    
    public var body: some View {
        Group {
            if #available(iOS 18, macOS 15, visionOS 2, *) {
                TimelineView(.animation) { context in
                    let t        = context.date.timeIntervalSinceReferenceDate
                    let points   = animatedPoints(at: t)
                    let hueShift = Angle.degrees((t.truncatingRemainder(dividingBy: 40)) / 40 * 360)
                    MeshGradient(
                        width: 3, height: 3,
                        points: points,
                        colors: palette
                    )
                    .hueRotation(hueShift)
                    .ignoresSafeArea()
                }
            } else {
                LinearGradient(colors: [.cyan, .purple],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                .ignoresSafeArea()
            }
        }
    }
    private func animatedPoints(at t: TimeInterval) -> [SIMD2<Float>] {
        basePoints.enumerated().map { index, base in
            let phase = Double(index) * .pi / 4
            let dx = amplitude * Float(sin(2 * .pi * frequency * t + phase))
            let dy = amplitude * Float(cos(2 * .pi * frequency * t + phase))
            return SIMD2<Float>(base.x + dx, base.y + dy)
        }
    }
}

#Preview {
    AnimatedMeshGradient()
}
