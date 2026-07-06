//
//  PortalRuneVisualSystem.swift
//  visionPro
//
//  Created by Jean Pierre on 29/06/26.
//

import RealityKit

struct PortalRuneVisualSystem: System {
    init(scene: RealityKit.Scene) {}

    static func registerRealityKitContent() {
        PortalRuneComponent.registerComponent()
        PortalProgressSlotComponent.registerComponent()
        PortalFloatingStoneComponent.registerComponent()
        PortalRuneVisualSystem.registerSystem()
    }

    func update(context: SceneUpdateContext) {}
}

