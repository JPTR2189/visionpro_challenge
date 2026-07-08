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

    static func playOpeningAnimation(in root: Entity) async {
        guard let portal = root.findEntity(named: "MagicPortal") else { return }

        resetPortalLights(in: root)

        var floatingStones: [Entity] = []
        collectFloatingStones(from: portal, into: &floatingStones)
        let orderedStones = sortedOpeningStones(floatingStones)

        let originalPortalTransform = portal.transform
        let originalStoneTransforms = orderedStones.map { stone in
            (stone: stone, transform: stone.transform)
        }
        let center = portalCenterRunePosition(in: portal)

        let collapsedPortalTransform = scaledTransform(
            for: portal,
            keepingLocalPoint: center,
            scaleFactor: openingInitialScale
        )
        portal.transform = collapsedPortalTransform

        for (index, item) in originalStoneTransforms.enumerated() {
            let startOffset = openingRuneCenterOffset(index: index, count: originalStoneTransforms.count)
            item.stone.transform = Transform(
                scale: item.transform.scale * openingRuneCenterScale,
                rotation: item.transform.rotation,
                translation: center + startOffset
            )
        }

        portal.move(
            to: originalPortalTransform,
            relativeTo: portal.parent,
            duration: openingPortalDuration,
            timingFunction: .easeInOut
        )

        try? await Task.sleep(nanoseconds: openingRuneRevealDelay)

        for item in originalStoneTransforms {
            item.stone.move(
                to: item.transform,
                relativeTo: item.stone.parent,
                duration: openingRuneMoveDuration,
                timingFunction: .easeInOut
            )

            try? await Task.sleep(nanoseconds: openingRuneStaggerDuration)
        }

        try? await Task.sleep(nanoseconds: openingFinalSettleDuration)

        portal.transform = originalPortalTransform
        for item in originalStoneTransforms {
            item.stone.transform = item.transform
        }

        resetPortalLights(in: root)
    }

    static func playClosingAnimation(in root: Entity) async {
        guard let portal = root.findEntity(named: "MagicPortal") else { return }

        resetPortalLights(in: root)

        var floatingStones: [Entity] = []
        collectFloatingStones(from: portal, into: &floatingStones)
        let orderedStones = sortedOpeningStones(floatingStones)
        let center = portalCenterRunePosition(in: portal)
        let closingCenter = center + closingSmokeOffset

        if let smoke = makePortalSmoke(targetSize: closingSmokeTargetSize) {
            let smokePosition = portal.convert(
                position: closingCenter,
                to: portal.parent
            )
            smoke.position = smokePosition
            smoke.scale *= closingSmokeInitialScale
            portal.parent?.addChild(smoke)

            for animation in smoke.availableAnimations {
                let controller = smoke.playAnimation(animation.repeat())
                controller.speed = closingSmokeAnimationSpeed
            }

            animateFastSmokeSpin(smoke)

            smoke.move(
                to: Transform(
                    scale: smoke.scale * closingSmokeFinalScale,
                    rotation: smoke.orientation,
                    translation: smokePosition
                ),
                relativeTo: smoke.parent,
                duration: closingSmokeDuration,
                timingFunction: .easeInOut
            )
        }

        try? await Task.sleep(nanoseconds: closingSmokeLeadDuration)

        for (index, stone) in orderedStones.enumerated() {
            stone.components.remove(InputTargetComponent.self)
            stone.components.remove(HoverEffectComponent.self)
            stone.components.remove(CollisionComponent.self)

            let offset = openingRuneCenterOffset(index: index, count: orderedStones.count)
            stone.move(
                to: Transform(
                    scale: stone.scale * closingRuneCenterScale,
                    rotation: stone.orientation,
                    translation: center + offset
                ),
                relativeTo: stone.parent,
                duration: closingRuneMoveDuration,
                timingFunction: .easeInOut
            )
        }

        let collapsedPortalTransform = scaledTransform(
            for: portal,
            keepingLocalPoint: closingCenter,
            scaleFactor: closingPortalFinalScale
        )
        portal.move(
            to: collapsedPortalTransform,
            relativeTo: portal.parent,
            duration: closingPortalDuration,
            timingFunction: .easeInOut
        )

        try? await Task.sleep(nanoseconds: UInt64(closingPortalDuration * 1_000_000_000))
        portal.isEnabled = false

        try? await Task.sleep(nanoseconds: closingSettleDuration)
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

    static func makeRandomRuneSequence(length: Int) -> [String] {
        makeRandomRuneSequenceBindings(length: length).map(\.rockName)
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

    static func setClosingHitTargetEnabled(_ isEnabled: Bool, in root: Entity) {
        root.findEntity(named: closingHitTargetName)?.isEnabled = isEnabled
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
        configureClosingHitTarget(in: portal)
        configureRuntimePortalLights(in: portal)
        resetPortalLights(in: portal)

        return portal
    }

    private static func addPortalInterior(to portal: Entity) {
        guard let interior = makePortalInterior() else { return }

        interior.name = "PortalInterior"
        interior.position = portalCenterRunePosition(in: portal) + portalInteriorOffset
        interior.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 1, 0])
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
            let normalizedScale = portalInteriorTargetSize / largestExtent
            interior.scale = [normalizedScale, normalizedScale, normalizedScale]
            interior.position -= bounds.center * normalizedScale
        }

        container.addChild(interior)
        return container
    }

    private static func makePortalSmoke(targetSize: Float) -> Entity? {
        let smokeEntity = Entity()
        smokeEntity.name = "PortalClosingSmoke"

        var emitter = ParticleEmitterComponent()
        // .local: particles live in entity space so the fast spin creates a vortex
        emitter.fieldSimulationSpace = .local
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = SIMD3<Float>(repeating: targetSize * 0.35)
        emitter.speed = 0.10
        emitter.speedVariation = 0.05

        emitter.mainEmitter.birthRate = 65
        emitter.mainEmitter.lifeSpan = 1.5
        emitter.mainEmitter.lifeSpanVariation = 0.5
        emitter.mainEmitter.size = targetSize * 0.075
        emitter.mainEmitter.sizeVariation = targetSize * 0.025
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 1.8
        emitter.mainEmitter.color = .constant(.single(
            UIColor(white: 0.05, alpha: 0.28)
        ))
        emitter.mainEmitter.blendMode = .alpha
        emitter.mainEmitter.dampingFactor = 0.90
        emitter.mainEmitter.spreadingAngle = .pi

        smokeEntity.components.set(emitter)
        return smokeEntity
    }

    private static func animateFastSmokeSpin(_ smoke: Entity) {
        let baseTransform = smoke.transform
        let spinTransform = Transform(
            scale: baseTransform.scale,
            rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0]) * baseTransform.rotation,
            translation: baseTransform.translation
        )

        smoke.move(
            to: spinTransform,
            relativeTo: smoke.parent,
            duration: closingSmokeSpinDuration,
            timingFunction: .linear
        )

        Task { @MainActor in
            while smoke.parent != nil, smoke.isEnabled {
                try? await Task.sleep(nanoseconds: UInt64(closingSmokeSpinDuration * 1_000_000_000))
                smoke.transform = baseTransform
                smoke.move(
                    to: spinTransform,
                    relativeTo: smoke.parent,
                    duration: closingSmokeSpinDuration,
                    timingFunction: .linear
                )
            }
        }
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
    private static let portalInteriorTargetSize: Float = 3.22
    private static let portalInteriorOffset = SIMD3<Float>(0, 0, -0.10)
    private static let openingInitialScale: Float = 0.02
    private static let openingPortalDuration: TimeInterval = 0.56
    private static let openingRuneMoveDuration: TimeInterval = 0.16
    private static let openingRuneCenterScale: Float = 0.18
    private static let openingRuneCenterRadius: Float = 0.16
    private static let openingRuneCenterDepthOffset: Float = 0.10
    private static let openingRuneRevealDelay: UInt64 = 40_000_000
    private static let openingRuneStaggerDuration: UInt64 = 40_000_000
    private static let openingFinalSettleDuration: UInt64 = 180_000_000
    private static let closingSmokeTargetSize: Float = 2.15
    private static let closingSmokeInitialScale: Float = 0.35
    private static let closingSmokeFinalScale: Float = 1.35
    private static let closingSmokeOffset = SIMD3<Float>(0, 0, 0.46)
    private static let closingSmokeAnimationSpeed: Float = 42.0
    private static let closingSmokeSpinDuration: TimeInterval = 0.16
    private static let closingSmokeDuration: TimeInterval = 1.05
    private static let closingSmokeLeadDuration: UInt64 = 120_000_000
    private static let closingRuneMoveDuration: TimeInterval = 0.42
    private static let closingRuneCenterScale: Float = 0.16
    private static let closingPortalDuration: TimeInterval = 0.58
    private static let closingPortalFinalScale: Float = 0.001
    private static let closingSettleDuration: UInt64 = 360_000_000
    private static let closingHitTargetRadius: Float = 2.05
    private static let closingHitTargetOffset = SIMD3<Float>(0, 0, 0.30)
    private static let closingHitTargetName = "PortalClosingHitTarget"

    private static func sortedOpeningStones(_ stones: [Entity]) -> [Entity] {
        let runeOrder = Dictionary(
            uniqueKeysWithValues: runeLightBindings.enumerated().map { index, rune in
                (rune.rockName, index)
            }
        )

        return stones.sorted {
            (runeOrder[$0.name.uppercased()] ?? Int.max) < (runeOrder[$1.name.uppercased()] ?? Int.max)
        }
    }

    private static func openingRuneCenterOffset(
        index: Int,
        count: Int
    ) -> SIMD3<Float> {
        guard count > 0 else { return [0, 0, openingRuneCenterDepthOffset] }

        let angle = (Float(index) / Float(count)) * .pi * 2
        return [
            cos(angle) * openingRuneCenterRadius,
            sin(angle) * openingRuneCenterRadius,
            openingRuneCenterDepthOffset
        ]
    }

    private static func scaledTransform(
        for entity: Entity,
        keepingLocalPoint localPoint: SIMD3<Float>,
        scaleFactor: Float
    ) -> Transform {
        let transform = entity.transform
        let targetScale = transform.scale * scaleFactor
        let targetPoint = transformedPoint(
            localPoint,
            scale: transform.scale,
            rotation: transform.rotation,
            translation: transform.translation
        )
        let scaledPointOffset = transform.rotation.act([
            localPoint.x * targetScale.x,
            localPoint.y * targetScale.y,
            localPoint.z * targetScale.z
        ])

        return Transform(
            scale: targetScale,
            rotation: transform.rotation,
            translation: targetPoint - scaledPointOffset
        )
    }

    private static func transformedPoint(
        _ point: SIMD3<Float>,
        scale: SIMD3<Float>,
        rotation: simd_quatf,
        translation: SIMD3<Float>
    ) -> SIMD3<Float> {
        translation + rotation.act([
            point.x * scale.x,
            point.y * scale.y,
            point.z * scale.z
        ])
    }

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

    private static func configureClosingHitTarget(in portal: Entity) {
        let target = Entity()
        target.name = closingHitTargetName
        target.position = portalCenterRunePosition(in: portal) + closingHitTargetOffset
        target.isEnabled = false
        target.components.set(InputTargetComponent(allowedInputTypes: .indirect))
        target.components.set(
            CollisionComponent(
                shapes: [.generateSphere(radius: closingHitTargetRadius)]
            )
        )

        portal.addChild(target)
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
