//
//  PortalRuneComponent.swift
//  visionPro
//
//  Created by Jean Pierre on 29/06/26.
//

import RealityKit
import SwiftUI

enum PortalRuneVisualState: String, Codable {
    case normal
    case focused
    case selected
    case error
}

struct PortalRuneComponent: Component, Codable {
    var id: String
    var symbol: String
    var red: Double
    var green: Double
    var blue: Double
    var baseScale: Float
    var visualState: PortalRuneVisualState = .normal
    var stateStartedAt: TimeInterval = 0

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

struct PortalProgressSlotComponent: Component, Codable {
    var index: Int
}

struct PortalFloatingStoneComponent: Component {
    var runeID: String?
    var basePosition: SIMD3<Float>
    var baseOrientation: simd_quatf
    var baseScale: SIMD3<Float>
    var phase: Float
    var amplitude: Float
    var speed: Float
    var tilt: Float
}
