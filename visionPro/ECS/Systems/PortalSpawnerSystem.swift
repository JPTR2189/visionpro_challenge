import RealityKit
import Foundation
import simd

struct PortalSpawnerSystem: System {

    static let query = EntityQuery(where: .has(PortalSpawnerComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let now = Date().timeIntervalSinceReferenceDate

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var spawner = entity.components[PortalSpawnerComponent.self] else { continue }
            guard spawner.isReady else { continue }
            guard now - spawner.lastSpawnTime >= spawner.spawnInterval else { continue }
            guard let referenceTransform = spawner.referenceTransform else { continue }

            spawner.lastSpawnTime = now
            entity.components[PortalSpawnerComponent.self] = spawner

            spawnPortal(on: entity, template: spawner.portalTemplate!, headTransform: referenceTransform, spawner: spawner)
        }
    }

    private func spawnPortal(
        on parent: Entity,
        template: Entity,
        headTransform: simd_float4x4,
        spawner: PortalSpawnerComponent
    ) {
        let portal = template.clone(recursive: true)

        let position = Self.randomPosition(
            relativeTo: headTransform,
            spawner: spawner
        )

        portal.position = position

        let headPosition = SIMD3<Float>(
            headTransform.columns.3.x,
            headTransform.columns.3.y,
            headTransform.columns.3.z
        )

        portal.look(
            at: headPosition,
            from: position,
            relativeTo: nil
        )

        let finalTransform = portal.transform

        var initialTransform = finalTransform
        initialTransform.scale = finalTransform.scale * 0.001

        portal.transform = initialTransform

        parent.addChild(portal)

        portal.move(
            to: finalTransform,
            relativeTo: parent,
            duration: 0.65,
            timingFunction: .easeInOut
        )
    }

    static func randomPosition(relativeTo headTransform: simd_float4x4,
                                spawner: PortalSpawnerComponent) -> SIMD3<Float> {

        let headPosition = SIMD3<Float>(headTransform.columns.3.x,
                                         headTransform.columns.3.y,
                                         headTransform.columns.3.z)

        let rawForward = -normalize(SIMD3<Float>(headTransform.columns.2.x,
                                                   headTransform.columns.2.y,
                                                   headTransform.columns.2.z))

        var forward = SIMD3<Float>(rawForward.x, 0, rawForward.z)
        if simd_length(forward) < 0.0001 {
            forward = SIMD3<Float>(0, 0, -1)
        }
        forward = normalize(forward)

        let worldUp = SIMD3<Float>(0, 1, 0)
        let azimuthDeg = Float.random(in: -spawner.halfFieldDegrees...spawner.halfFieldDegrees)
        let azimuthRad = azimuthDeg * .pi / 180
        let distance = Float.random(in: spawner.minDistance...spawner.maxDistance)

        let yawRotation = simd_quatf(angle: azimuthRad, axis: worldUp)
        let direction = normalize(yawRotation.act(forward))

        let rawPosition = headPosition + direction * distance
        return SIMD3<Float>(rawPosition.x, headPosition.y, rawPosition.z)
    }
}
