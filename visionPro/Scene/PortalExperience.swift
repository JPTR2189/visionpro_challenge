//
//  PortalExperience.swift
//  visionPro
//
//  Created by Jean Pierre on 29/06/26.
//

import RealityKit
import SwiftUI

@MainActor
enum PortalExperience {
    private static let sequenceLength = 6
    private static var centeredStoneNames: Set<String> = []

    static func makeScene() -> Entity {
        let root = Entity()
        root.name = "PortalExperience"

        let frontAnchor = AnchorEntity(.world(transform: matrix_identity_float4x4))
        frontAnchor.name = "PortalWorldAnchor"
        frontAnchor.position = [0, 1.15, -1.45]
        frontAnchor.scale = [0.80, 0.80, 0.80]

        addLighting(to: frontAnchor)
        addPortal(to: frontAnchor)

        root.addChild(frontAnchor)
        return root
    }

    static func startFloatingStoneMotion(in root: Entity) {
        var floatingStones: [Entity] = []
        collectFloatingStones(from: root, into: &floatingStones)

        for (index, stone) in floatingStones.enumerated() {
            let phase = Float(index) * 0.72
            let amplitude: Float = 0.028
            let duration = 1.45 + Double(index % 3) * 0.18
            let tilt: Float = 0.045
            let basePosition = stone.position
            let baseOrientation = stone.orientation
            let baseScale = stone.scale

            Task { @MainActor in
                await animateFloatingStone(
                    stone,
                    basePosition: basePosition,
                    baseOrientation: baseOrientation,
                    baseScale: baseScale,
                    phase: phase,
                    amplitude: amplitude,
                    duration: duration,
                    tilt: tilt
                )
            }
        }
    }

    static func startGeniusLightSequence(in root: Entity) {
        Task { @MainActor in
            resetPortalLights(in: root)
            try? await Task.sleep(nanoseconds: 700_000_000)

            let sequence = makeRandomRuneSequenceBindings(length: sequenceLength)
            await playLightSequence(sequence, in: root)
        }
    }

    static func makeRandomRuneSequence() -> [String] {
        makeRandomRuneSequenceBindings(length: sequenceLength).map(\.rockName)
    }

    static func playRuneSequence(_ rockNames: [String], in root: Entity) async {
        let sequence = rockNames.compactMap(binding(forRockName:))
        await playLightSequence(sequence, in: root)
    }

    static func flashSelection(for rockName: String, in root: Entity, isCorrect: Bool) async {
        guard let rune = binding(forRockName: rockName) else { return }

        let lightName = isCorrect ? rune.purpleLightName : rune.redLightName
        setPortalLight(named: lightName, enabled: true, in: root)
        try? await Task.sleep(nanoseconds: 280_000_000)
        setPortalLight(named: lightName, enabled: false, in: root)
    }

    static func moveCorrectRuneToPortalCenter(for rockName: String, in root: Entity) async {
        guard let portal = root.findEntity(named: "MagicPortal"),
              let stone = portal.findEntity(named: rockName) else {
            return
        }

        centeredStoneNames.insert(stone.name.uppercased())

        let originalParent = stone.parent
        let originalTransform = stone.transform
        let originalInput = stone.components[InputTargetComponent.self]
        let originalHover = stone.components[HoverEffectComponent.self]
        let originalCollision = stone.components[CollisionComponent.self]
        stone.components.remove(InputTargetComponent.self)
        stone.components.remove(HoverEffectComponent.self)
        stone.components.remove(CollisionComponent.self)

        stone.setParent(portal, preservingWorldTransform: true)

        let targetScale = stone.scale * 0.72
        let targetRotation = stone.orientation
        let targetVisualCenter = referenceRuneVisualCenter(in: portal)
        let visualOffset = visualCenterOffset(
            for: stone,
            scale: targetScale,
            rotation: targetRotation
        )
        let targetTransform = Transform(
            scale: targetScale,
            rotation: targetRotation,
            translation: targetVisualCenter - visualOffset
        )

        stone.move(
            to: targetTransform,
            relativeTo: portal,
            duration: 0.42,
            timingFunction: .easeInOut
        )

        try? await Task.sleep(nanoseconds: 780_000_000)

        stone.setParent(originalParent, preservingWorldTransform: true)
        stone.move(
            to: originalTransform,
            relativeTo: originalParent,
            duration: 0.34,
            timingFunction: .easeInOut
        )

        try? await Task.sleep(nanoseconds: 360_000_000)
        if let originalInput {
            stone.components.set(originalInput)
        }
        if let originalHover {
            stone.components.set(originalHover)
        }
        if let originalCollision {
            stone.components.set(originalCollision)
        }
        centeredStoneNames.remove(stone.name.uppercased())
    }

    static func resetLights(in root: Entity) {
        resetPortalLights(in: root)
    }

    static func rockName(containing entity: Entity) -> String? {
        var current: Entity? = entity

        while let entity = current {
            let name = entity.name.uppercased()
            if floatingStoneNames.contains(name) {
                return name
            }

            current = entity.parent
        }

        return nil
    }

    private static func makeRandomRuneSequenceBindings(length: Int) -> [RuneLightBinding] {
        guard length > 0 else { return [] }

        var sequence: [RuneLightBinding] = []
        var previousRuneName: String?

        while sequence.count < length {
            let candidates = runeLightBindings.filter { $0.rockName != previousRuneName }
            guard let nextRune = candidates.randomElement() else { break }

            sequence.append(nextRune)
            previousRuneName = nextRune.rockName
        }

        return sequence
    }

    private static func binding(forRockName rockName: String) -> RuneLightBinding? {
        runeLightBindings.first { $0.rockName == rockName.uppercased() }
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
    }

    private static func animateFloatingStone(
        _ stone: Entity,
        basePosition: SIMD3<Float>,
        baseOrientation: simd_quatf,
        baseScale: SIMD3<Float>,
        phase: Float,
        amplitude: Float,
        duration: Double,
        tilt: Float
    ) async {
        var direction: Float = 1

        while !Task.isCancelled {
            if centeredStoneNames.contains(stone.name.uppercased()) {
                try? await Task.sleep(nanoseconds: 120_000_000)
                continue
            }

            let drift = sin(phase + direction * 0.9) * amplitude * 0.22
            let depth = cos(phase + direction * 1.2) * amplitude * 0.16
            let liftedPosition = basePosition + [
                drift,
                amplitude * direction,
                depth
            ]

            let rotation =
                baseOrientation *
                simd_quatf(angle: tilt * direction, axis: [1, 0, 0]) *
                simd_quatf(angle: tilt * 0.45 * sin(phase), axis: [0, 1, 0]) *
                simd_quatf(angle: tilt * 0.55 * direction, axis: [0, 0, 1])

            stone.move(
                to: Transform(
                    scale: baseScale,
                    rotation: rotation,
                    translation: liftedPosition
                ),
                relativeTo: stone.parent,
                duration: duration,
                timingFunction: .easeInOut
            )

            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            direction *= -1
        }
    }

    private static func addPortal(to root: Entity) {
        if let portal = makeOfficialPortal() {
            root.addChild(portal)
        } else {
            addPortalPlaceholder(to: root)
        }
    }

    private static func makeOfficialPortal() -> Entity? {
        let portalURL =
            Bundle.main.url(
                forResource: "Scene - Portal+Runes - Lights Purple and Red",
                withExtension: "usdz",
                subdirectory: "Resources"
            ) ?? Bundle.main.url(
                forResource: "Scene - Portal+Runes - Lights Purple and Red",
                withExtension: "usdz"
            )

        guard let portalURL,
              let portal = try? Entity.load(contentsOf: portalURL) else {
            return nil
        }

        portal.name = "MagicPortal"
        portal.position = [0, 0, 0]

        let bounds = portal.visualBounds(relativeTo: portal)
        let largestExtent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        if largestExtent > 0 {
            let targetSize: Float = 1.32
            let normalizedScale = targetSize / largestExtent
            portal.scale = [normalizedScale, normalizedScale, normalizedScale]
            portal.position -= bounds.center * normalizedScale
        }

        addPortalInterior(to: portal)
        configureFloatingStones(in: portal)
        configureRuntimePortalLights(in: portal)
        resetPortalLights(in: portal)

        return portal
    }

    private static func addPortalInterior(to portal: Entity) {
        guard let interior = makePortalInterior() else { return }

        interior.name = "PortalInterior"
        interior.position = [0, 0, -0.16]
        portal.addChild(interior)
    }

    private static func makePortalInterior() -> Entity? {
        let interiorURL =
            Bundle.main.url(
                forResource: "Dentro do portal",
                withExtension: "usdz",
                subdirectory: "Resources"
            ) ?? Bundle.main.url(
                forResource: "Dentro do portal",
                withExtension: "usdz"
            )

        guard let interiorURL,
              let interior = try? Entity.load(contentsOf: interiorURL) else {
            return nil
        }

        let container = Entity()
        let bounds = interior.visualBounds(relativeTo: interior)
        let largestExtent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        if largestExtent > 0 {
            let targetSize: Float = 0.88
            let normalizedScale = targetSize / largestExtent
            interior.scale = [normalizedScale, normalizedScale, normalizedScale]
            interior.position -= bounds.center * normalizedScale
        }

        container.addChild(interior)
        return container
    }

    private static func playLightSequence(_ sequence: [RuneLightBinding], in root: Entity) async {
        for rune in sequence {
            resetPortalLights(in: root)
            setPortalLight(named: rune.purpleLightName, enabled: true, in: root)
            try? await Task.sleep(nanoseconds: 650_000_000)

            setPortalLight(named: rune.purpleLightName, enabled: false, in: root)
            try? await Task.sleep(nanoseconds: 220_000_000)
        }

        resetPortalLights(in: root)
    }

    private static func resetPortalLights(in root: Entity) {
        for rune in runeLightBindings {
            setPortalLight(named: rune.purpleLightName, enabled: false, in: root)
            setPortalLight(named: rune.redLightName, enabled: false, in: root)
        }
    }

    private struct RuneLightBinding: Equatable {
        let rockName: String
        let purpleLightName: String
        let redLightName: String
        let lightPosition: SIMD3<Float>
    }

    private static let runeLightBindings: [RuneLightBinding] = [
        RuneLightBinding(
            rockName: "ROCK_A",
            purpleLightName: "PointLight_N",
            redLightName: "PointLight_N_red",
            lightPosition: [-0.41637206, 3.157634, -0.3517058]
        ),
        RuneLightBinding(
            rockName: "ROCK_B",
            purpleLightName: "PointLight_NE",
            redLightName: "PointLight_NE_red",
            lightPosition: [-1.8447664, 2.6147785, -0.3517058]
        ),
        RuneLightBinding(
            rockName: "ROCK_C",
            purpleLightName: "PointLight_E",
            redLightName: "PointLight_E_red",
            lightPosition: [-2.3906116, 1.2723978, -0.3517058]
        ),
        RuneLightBinding(
            rockName: "ROCK_D",
            purpleLightName: "PointLight_SE",
            redLightName: "PointLight_SE_red",
            lightPosition: [-1.8447664, -0.0069098473, -0.3517058]
        ),
        RuneLightBinding(
            rockName: "ROCK_E",
            purpleLightName: "PointLight_S",
            redLightName: "PointLight_S_red",
            lightPosition: [-0.41637206, -0.6560919, -0.3517058]
        ),
        RuneLightBinding(
            rockName: "ROCK_F",
            purpleLightName: "PointLight_SW",
            redLightName: "PointLight_SW_red",
            lightPosition: [0.906744, -0.0069098473, -0.3517058]
        ),
        RuneLightBinding(
            rockName: "ROCK_G",
            purpleLightName: "PointLight_W",
            redLightName: "PointLight_W_red",
            lightPosition: [1.4958928, 1.2723978, -0.3517058]
        ),
        RuneLightBinding(
            rockName: "ROCK_H",
            purpleLightName: "PointLight_NW",
            redLightName: "PointLight_NW_red",
            lightPosition: [0.906744, 2.6147785, -0.3517058]
        )
    ]

    private static func setPortalLight(named lightName: String, enabled: Bool, in root: Entity) {
        if let runtimeLight = root.findEntity(named: runtimeLightName(for: lightName)) {
            runtimeLight.isEnabled = enabled
            return
        }

        guard let light = root.findEntity(named: lightName) else {
            return
        }

        light.isEnabled = enabled
        setChildrenEnabled(of: light, enabled: enabled)
    }

    private static func setChildrenEnabled(of entity: Entity, enabled: Bool) {
        for child in entity.children {
            child.isEnabled = enabled
            setChildrenEnabled(of: child, enabled: enabled)
        }
    }

    private static func configureRuntimePortalLights(in portal: Entity) {
        for rune in runeLightBindings {
            let lightPosition = runtimeLightPosition(for: rune, in: portal)

            addRuntimePointLight(
                named: rune.purpleLightName,
                red: 0.58,
                green: 0.16,
                blue: 1.0,
                position: lightPosition,
                to: portal
            )
            addRuntimePointLight(
                named: rune.redLightName,
                red: 1.0,
                green: 0.08,
                blue: 0.04,
                position: lightPosition,
                to: portal
            )
        }
    }

    private static func runtimeLightPosition(for rune: RuneLightBinding, in portal: Entity) -> SIMD3<Float> {
        guard let stone = portal.findEntity(named: rune.rockName) else {
            return rune.lightPosition
        }

        return stone.visualBounds(relativeTo: portal).center
    }

    private static func addRuntimePointLight(
        named lightName: String,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        position: SIMD3<Float>,
        to portal: Entity
    ) {
        let light = PointLight()
        light.name = runtimeLightName(for: lightName)
        light.position = position + [0, 0, runtimeLightForwardOffset]
        light.light.color = .init(red: red, green: green, blue: blue, alpha: 1.0)
        light.light.intensity = 18_000
        light.light.attenuationRadius = runtimeLightAttenuationRadius
        light.isEnabled = false
        portal.addChild(light)
    }

    private static func runtimeLightName(for lightName: String) -> String {
        "Runtime_\(lightName)"
    }

    private static let runtimeLightForwardOffset: Float = 0.9
    private static let runtimeLightAttenuationRadius: Float = 0.38

    private static func portalCenterRunePosition(in portal: Entity) -> SIMD3<Float> {
        var center = runeLightBindings.reduce(SIMD3<Float>(repeating: 0)) { partialResult, rune in
            partialResult + rune.lightPosition
        } / Float(runeLightBindings.count)

        center.z = portalCenterDepth
        return center
    }

    private static let portalCenterDepth: Float = -0.22

    private static func referenceRuneVisualCenter(in portal: Entity) -> SIMD3<Float> {
        let pivotTarget = portalCenterRunePosition(in: portal)
        guard let referenceStone = portal.findEntity(named: "ROCK_C") else {
            return pivotTarget
        }

        let referenceScale = referenceStone.scale * 0.72
        let referenceRotation = referenceStone.orientation
        let referenceOffset = visualCenterOffset(
            for: referenceStone,
            scale: referenceScale,
            rotation: referenceRotation
        )

        return pivotTarget + referenceOffset + portalCenterVisualAdjustment
    }

    private static let portalCenterVisualAdjustment = SIMD3<Float>(0, -1.20, 0.10)

    private static func visualCenterOffset(
        for stone: Entity,
        scale: SIMD3<Float>,
        rotation: simd_quatf
    ) -> SIMD3<Float> {
        let localCenter = stone.visualBounds(relativeTo: stone).center
        let scaledCenter = SIMD3<Float>(
            localCenter.x * scale.x,
            localCenter.y * scale.y,
            localCenter.z * scale.z
        )

        return rotation.act(scaledCenter)
    }

    private static func configureFloatingStones(in portal: Entity) {
        var floatingStones: [Entity] = []
        collectFloatingStones(from: portal, into: &floatingStones)

        for (index, stone) in floatingStones.enumerated() {
            configureStoneInteraction(on: stone)

            stone.components.set(
                PortalFloatingStoneComponent(
                    runeID: nil,
                    basePosition: stone.position,
                    baseOrientation: stone.orientation,
                    baseScale: stone.scale,
                    phase: Float(index) * 0.78,
                    amplitude: 0.028,
                    speed: 0.82 + Float(index % 3) * 0.10,
                    tilt: 0.045
                )
            )
        }
    }

    private static func configureStoneInteraction(on stone: Entity) {
        let bounds = stone.visualBounds(relativeTo: stone)
        let radius = max(bounds.extents.x, bounds.extents.y, bounds.extents.z) * 0.62
        let shape = ShapeResource
            .generateSphere(radius: max(radius, 0.12))
            .offsetBy(translation: bounds.center)

        stone.components.set(InputTargetComponent(allowedInputTypes: .indirect))
        stone.components.set(HoverEffectComponent())
        stone.components.set(
            CollisionComponent(
                shapes: [shape]
            )
        )
    }

    private static func collectFloatingStones(from entity: Entity, into result: inout [Entity]) {
        let name = entity.name.uppercased()
        if Self.floatingStoneNames.contains(name) {
            result.append(entity)
            return
        }

        for child in entity.children {
            collectFloatingStones(from: child, into: &result)
        }
    }

    private static let floatingStoneNames: Set<String> = [
        "ROCK_A",
        "ROCK_B",
        "ROCK_C",
        "ROCK_D",
        "ROCK_E",
        "ROCK_F",
        "ROCK_G",
        "ROCK_H"
    ]

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
}
