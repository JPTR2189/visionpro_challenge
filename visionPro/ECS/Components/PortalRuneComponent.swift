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

struct PortalSurfaceComponent: Component, Codable {
    var baseScaleX: Float
    var baseScaleY: Float
    var baseScaleZ: Float
    var basePositionZ: Float
    var phase: Float
}
