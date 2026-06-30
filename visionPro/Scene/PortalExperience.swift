//
//  PortalExperience.swift
//  visionPro
//
//  Created by Jean Pierre on 29/06/26.
//

import RealityKit
import SwiftUI

struct RuneDefinition: Identifiable {
    let id: String
    let symbol: String
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

@MainActor
enum PortalExperience {
    static let runeDefinitions: [RuneDefinition] = [
        .init(id: "ignis", symbol: "I", red: 0.92, green: 0.18, blue: 0.16),
        .init(id: "aqua", symbol: "A", red: 0.10, green: 0.68, blue: 0.92),
        .init(id: "terra", symbol: "T", red: 0.18, green: 0.78, blue: 0.34),
        .init(id: "lux", symbol: "L", red: 0.96, green: 0.82, blue: 0.20),
        .init(id: "umbra", symbol: "U", red: 0.54, green: 0.30, blue: 0.88),
        .init(id: "ventus", symbol: "V", red: 0.35, green: 0.92, blue: 0.74),
        .init(id: "ordo", symbol: "O", red: 0.96, green: 0.46, blue: 0.14),
        .init(id: "nox", symbol: "N", red: 0.30, green: 0.38, blue: 0.88)
    ]

    static func makeScene(selectedRuneIDs: [String]) -> Entity {
        let root = Entity()
        root.name = "PortalExperience"

        let frontAnchor = AnchorEntity(.world(transform: matrix_identity_float4x4))
        frontAnchor.name = "PortalWorldAnchor"
        frontAnchor.position = [0, 1.15, -1.45]
        frontAnchor.scale = [0.72, 0.72, 0.72]

        addLighting(to: frontAnchor)
        addPortalPlaceholder(to: frontAnchor)
        addRunes(to: frontAnchor)
        updateProgress(in: frontAnchor, selectedRuneIDs: selectedRuneIDs)

        root.addChild(frontAnchor)
        return root
    }

    static func updateProgress(in root: Entity, selectedRuneIDs: [String]) {
        root.findEntity(named: "PortalProgress")?.removeFromParent()

        let progressRoot = Entity()
        progressRoot.name = "PortalProgress"
        progressRoot.position = [0, -0.02, 0.05]

        let spacing: Float = 0.12
        let visibleIDs = Array(selectedRuneIDs.suffix(5))
        let startX = -Float(max(visibleIDs.count - 1, 0)) * spacing / 2

        for (index, runeID) in visibleIDs.enumerated() {
            guard let definition = runeDefinitions.first(where: { $0.id == runeID }) else { continue }

            let marker = makeRune(definition: definition, radius: 0.036, depth: 0.01)
            marker.name = "ProgressRune-\(definition.id)"
            marker.position = [startX + Float(index) * spacing, 0, 0.02]
            marker.components.set(PortalProgressSlotComponent(index: index))
            progressRoot.addChild(marker)
        }

        root.addChild(progressRoot)
    }

    static func setRuneState(in root: Entity, runeID: String, state: PortalRuneVisualState) {
        guard let rune = root.findEntity(named: "Rune-\(runeID)"),
              var component = rune.components[PortalRuneComponent.self] else {
            return
        }

        component.visualState = state
        component.stateStartedAt = CACurrentMediaTime()
        rune.components.set(component)
    }

    static func resetTransientRuneStates(in root: Entity, selectedRuneIDs: [String]) {
        for definition in runeDefinitions {
            guard let rune = root.findEntity(named: "Rune-\(definition.id)"),
                  var component = rune.components[PortalRuneComponent.self] else {
                continue
            }

            component.visualState = selectedRuneIDs.contains(definition.id) ? .selected : .normal
            component.stateStartedAt = CACurrentMediaTime()
            rune.components.set(component)
        }
    }

    private static func addLighting(to root: Entity) {
        let keyLight = DirectionalLight()
        keyLight.name = "PortalKeyLight"
        keyLight.light.intensity = 1800
        keyLight.light.color = .init(red: 0.70, green: 0.86, blue: 1.0, alpha: 1.0)
        keyLight.orientation =
            simd_quatf(angle: -.pi / 7, axis: [1, 0, 0]) *
            simd_quatf(angle: -.pi / 9, axis: [0, 1, 0])
        root.addChild(keyLight)

        let glow = PointLight()
        glow.name = "PortalCenterGlow"
        glow.light.intensity = 2200
        glow.light.color = .init(red: 0.38, green: 0.72, blue: 1.0, alpha: 1.0)
        glow.light.attenuationRadius = 3
        glow.position = [0, 0, 0.18]
        root.addChild(glow)
    }

    private static func addPortalPlaceholder(to root: Entity) {
        var centerMaterial = UnlitMaterial()
        centerMaterial.color = .init(tint: .init(red: 0.03, green: 0.08, blue: 0.15, alpha: 0.78))

        let center = ModelEntity(
            mesh: .generateCylinder(height: 0.014, radius: 0.42),
            materials: [centerMaterial]
        )
        center.name = "PortalCenter"
        center.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        root.addChild(center)

        var ringMaterial = PhysicallyBasedMaterial()
        ringMaterial.baseColor = .init(tint: .init(red: 0.18, green: 0.52, blue: 1.0, alpha: 0.92))
        ringMaterial.roughness = .init(floatLiteral: 0.24)

        let segmentCount = 28
        let ringRadius: Float = 0.50

        for index in 0..<segmentCount {
            let angle = Float(index) / Float(segmentCount) * 2 * .pi
            let segment = ModelEntity(
                mesh: .generateSphere(radius: 0.018),
                materials: [ringMaterial]
            )
            segment.name = "PortalRingSegment"
            segment.position = [cos(angle) * ringRadius, sin(angle) * ringRadius, 0]
            root.addChild(segment)
        }
    }

    private static func addRunes(to root: Entity) {
        let radius: Float = 0.70

        for (index, definition) in runeDefinitions.enumerated() {
            let angle = Float(index) / Float(runeDefinitions.count) * 2 * .pi + .pi / 2
            let rune = makeRune(definition: definition, radius: 0.052, depth: 0.018)
            rune.name = "Rune-\(definition.id)"
            rune.position = [cos(angle) * radius, sin(angle) * radius, 0.055]
            rune.components.set(
                PortalRuneComponent(
                    id: definition.id,
                    symbol: definition.symbol,
                    red: definition.red,
                    green: definition.green,
                    blue: definition.blue,
                    baseScale: 1.0
                )
            )
            rune.components.set(InputTargetComponent())
            rune.components.set(HoverEffectComponent())
            rune.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.068)]))
            root.addChild(rune)
        }
    }

    private static func makeRune(definition: RuneDefinition, radius: Float, depth: Float) -> Entity {
        let runeRoot = Entity()
        runeRoot.name = "RuneRoot-\(definition.id)"

        var runeMaterial = PhysicallyBasedMaterial()
        runeMaterial.baseColor = .init(tint: .init(
            red: definition.red,
            green: definition.green,
            blue: definition.blue,
            alpha: 0.82
        ))
        runeMaterial.roughness = .init(floatLiteral: 0.32)

        let disc = ModelEntity(
            mesh: .generateCylinder(height: depth, radius: radius),
            materials: [runeMaterial]
        )
        disc.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        disc.name = "RuneDisc"

        let symbol = makeRuneSymbol(definition.symbol, radius: radius)
        symbol.position = [-radius * 0.30, -radius * 0.34, depth * 1.05]

        runeRoot.addChild(disc)
        runeRoot.addChild(symbol)
        return runeRoot
    }

    private static func makeRuneSymbol(_ text: String, radius: Float) -> ModelEntity {
        let fontSize = CGFloat(radius * 1.25)
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.004,
            font: .systemFont(ofSize: fontSize, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byClipping
        )

        var material = UnlitMaterial()
        material.color = .init(tint: .white)

        let symbol = ModelEntity(mesh: mesh, materials: [material])
        symbol.name = "RuneSymbol-\(text)"
        return symbol
    }
}
