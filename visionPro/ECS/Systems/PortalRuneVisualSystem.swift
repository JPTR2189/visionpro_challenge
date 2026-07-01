//
//  PortalRuneVisualSystem.swift
//  visionPro
//
//  Created by Jean Pierre on 29/06/26.
//

import RealityKit
import SwiftUI

struct PortalRuneVisualSystem: System {
    private static let runeQuery = EntityQuery(where: .has(PortalRuneComponent.self))
    private static let portalSurfaceQuery = EntityQuery(where: .has(PortalSurfaceComponent.self))

    init(scene: RealityKit.Scene) {}

    static func registerRealityKitContent() {
        PortalRuneComponent.registerComponent()
        PortalProgressSlotComponent.registerComponent()
        PortalSurfaceComponent.registerComponent()
        PortalRuneVisualSystem.registerSystem()
    }

    func update(context: SceneUpdateContext) {
        let currentTime = CACurrentMediaTime()

        for entity in context.entities(matching: Self.runeQuery, updatingSystemWhen: .rendering) {
            guard var rune = entity.components[PortalRuneComponent.self] else { continue }

            if rune.stateStartedAt == 0 {
                rune.stateStartedAt = currentTime
                entity.components.set(rune)
            }

            let elapsed = Float(currentTime - rune.stateStartedAt)
            let pulse = sin(elapsed * 7) * 0.025
            let targetScale: Float

            switch rune.visualState {
            case .normal:
                targetScale = rune.baseScale
                applyRuneMaterial(to: entity, red: rune.red, green: rune.green, blue: rune.blue, opacity: 0.88, roughness: 0.36)
                applyRuneGlow(to: entity, opacity: 0.0, scale: 0.001)
            case .focused:
                let glowPulse = 1.0 + sin(elapsed * 4.4) * 0.10
                targetScale = rune.baseScale * (1.09 + pulse)
                applyRuneMaterial(to: entity, red: rune.red, green: rune.green, blue: rune.blue, opacity: 1.0, roughness: 0.12)
                applyRuneGlow(to: entity, opacity: 0.58, scale: 1.0 * glowPulse)
            case .selected:
                targetScale = rune.baseScale
                applyRuneMaterial(to: entity, red: rune.red, green: rune.green, blue: rune.blue, opacity: 0.88, roughness: 0.36)
                applyRuneGlow(to: entity, opacity: 0.0, scale: 0.001)
            case .error:
                targetScale = rune.baseScale * 1.12
                applyRuneMaterial(to: entity, red: 1.0, green: 0.12, blue: 0.10, opacity: 0.96, roughness: 0.2)
                applyRuneGlow(to: entity, opacity: 0.28, scale: 0.82)
            }

            entity.scale = [targetScale, targetScale, targetScale]
        }

        for entity in context.entities(matching: Self.portalSurfaceQuery, updatingSystemWhen: .rendering) {
            guard let surface = entity.components[PortalSurfaceComponent.self] else { continue }

            let time = Float(currentTime)
            let slowWave = sin(time * 1.7 + surface.phase)
            let detailWave = sin(time * 2.6 + surface.phase * 0.7)
            entity.scale = [
                surface.baseScaleX * (1.0 + slowWave * 0.018),
                surface.baseScaleY * (1.0 + detailWave * 0.014),
                surface.baseScaleZ
            ]
            entity.position.z = surface.basePositionZ + slowWave * 0.012

            if let modelEntity = entity as? ModelEntity {
                applyPortalSurfaceMaterial(to: modelEntity, pulse: slowWave)
            }
        }
    }

    private func applyRuneMaterial(to entity: Entity, red: Double, green: Double, blue: Double, opacity: Double, roughness: Float) {
        if let modelEntity = entity.findEntity(named: "RuneDisc") as? ModelEntity {
            applyMaterial(to: modelEntity, red: red, green: green, blue: blue, opacity: opacity, roughness: roughness)
        } else if let modelEntity = entity as? ModelEntity {
            applyMaterial(to: modelEntity, red: red, green: green, blue: blue, opacity: opacity, roughness: roughness)
        }
    }

    private func applyMaterial(to modelEntity: ModelEntity, red: Double, green: Double, blue: Double, opacity: Double, roughness: Float) {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(red: red, green: green, blue: blue, alpha: opacity))
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: 0.0)
        modelEntity.model?.materials = [material]
    }

    private func applyRuneGlow(to entity: Entity, opacity: Double, scale: Float) {
        guard let glow = entity.findEntity(named: "RuneGlow") as? ModelEntity else { return }

        var material = UnlitMaterial()
        material.color = .init(tint: .init(red: 1.0, green: 0.88, blue: 0.22, alpha: opacity))
        glow.model?.materials = [material]
        glow.scale = [scale, scale, scale]
    }

    private func applyPortalSurfaceMaterial(to modelEntity: ModelEntity, pulse: Float) {
        let glow = Double(0.54 + pulse * 0.08)

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(red: 0.70, green: 0.52, blue: 1.0, alpha: 0.44))
        material.roughness = .init(floatLiteral: 0.08)
        material.metallic = .init(floatLiteral: 0.0)
        material.emissiveColor = .init(color: .init(red: glow, green: 0.38, blue: 1.0, alpha: 0.62))
        material.emissiveIntensity = .init(floatLiteral: 0.85)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.46))
        modelEntity.model?.materials = [material]
    }
}
