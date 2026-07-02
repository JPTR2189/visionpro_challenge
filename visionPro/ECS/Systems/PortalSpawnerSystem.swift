import RealityKit
import Foundation
import simd

struct PortalSpawnerSystem: System {

    static let spawnerQuery = EntityQuery(where: .has(PortalSpawnerComponent.self))
    static let wallQuery = EntityQuery(where: .has(WallSurfaceComponent.self))

    private struct WallPlacement {
        let wall: Entity
        let localPosition: SIMD3<Float>
        let shouldFlipAroundY: Bool
    }

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let now = Date().timeIntervalSinceReferenceDate
        let walls = Array(
            context.entities(
                matching: Self.wallQuery,
                updatingSystemWhen: .rendering
            )
        )

        for entity in context.entities(
            matching: Self.spawnerQuery,
            updatingSystemWhen: .rendering
        ) {
            guard var spawner = entity.components[PortalSpawnerComponent.self] else { continue }
            guard spawner.isReady else { continue }
            guard now - spawner.lastSpawnTime >= spawner.spawnInterval else { continue }
            guard now - spawner.lastPlacementAttemptTime >= spawner.placementRetryInterval else { continue }
            guard let referenceTransform = spawner.referenceTransform else { continue }

            spawner.lastPlacementAttemptTime = now
            entity.components[PortalSpawnerComponent.self] = spawner

            guard let placement = Self.randomWallPlacement(
                among: walls,
                headTransform: referenceTransform,
                spawner: spawner
            ) else {
                continue
            }

            spawner.lastSpawnTime = now
            entity.components[PortalSpawnerComponent.self] = spawner

            spawnPortal(
                at: placement,
                template: spawner.portalTemplate!
            )
        }
    }

    private func spawnPortal(
        at placement: WallPlacement,
        template: Entity
    ) {
        let portal = template.clone(recursive: true)

        var finalTransform = portal.transform
        finalTransform.translation = placement.localPosition

        if placement.shouldFlipAroundY {
            finalTransform.rotation = simd_quatf(
                angle: .pi,
                axis: SIMD3<Float>(0, 1, 0)
            ) * finalTransform.rotation
        }

        var initialTransform = finalTransform
        initialTransform.scale = finalTransform.scale * 0.001
        portal.transform = initialTransform

        placement.wall.addChild(portal)

        portal.move(
            to: finalTransform,
            relativeTo: placement.wall,
            duration: 0.65,
            timingFunction: .easeInOut
        )
    }

    private static func randomWallPlacement(
        among walls: [Entity],
        headTransform: simd_float4x4,
        spawner: PortalSpawnerComponent
    ) -> WallPlacement? {
        let headPosition = SIMD3<Float>(
            headTransform.columns.3.x,
            headTransform.columns.3.y,
            headTransform.columns.3.z
        )

        let rawForward = -normalize(SIMD3<Float>(
            headTransform.columns.2.x,
            headTransform.columns.2.y,
            headTransform.columns.2.z
        ))

        var forward = SIMD3<Float>(rawForward.x, 0, rawForward.z)
        if simd_length(forward) < 0.0001 {
            forward = SIMD3<Float>(0, 0, -1)
        }
        forward = normalize(forward)

        let halfFieldRadians = spawner.halfFieldDegrees * .pi / 180
        let minimumFieldDot = cos(halfFieldRadians)

        for wall in walls.shuffled() {
            guard let surface = wall.components[WallSurfaceComponent.self] else {
                continue
            }

            let availableX = (surface.width - spawner.portalSize.x) / 2
                - spawner.wallMargin
            let availableY = (surface.height - spawner.portalSize.y) / 2
                - spawner.wallMargin

            guard availableX >= 0, availableY >= 0 else {
                continue
            }

            let localHeadPosition = wall.convert(position: headPosition, from: nil)
            let facesPositiveZ = localHeadPosition.z >= 0

            for _ in 0..<8 {
                let localPosition = SIMD3<Float>(
                    Float.random(in: -availableX...availableX),
                    Float.random(in: -availableY...availableY),
                    facesPositiveZ ? 0.01 : -0.01
                )

                let worldPosition = wall.convert(position: localPosition, to: nil)
                let offset = worldPosition - headPosition
                let distance = simd_length(offset)

                guard distance >= spawner.minDistance,
                      distance <= spawner.maxDistance else {
                    continue
                }

                var horizontalDirection = SIMD3<Float>(offset.x, 0, offset.z)
                guard simd_length(horizontalDirection) > 0.0001 else {
                    continue
                }
                horizontalDirection = normalize(horizontalDirection)

                guard dot(forward, horizontalDirection) >= minimumFieldDot else {
                    continue
                }

                return WallPlacement(
                    wall: wall,
                    localPosition: localPosition,
                    shouldFlipAroundY: facesPositiveZ
                )
            }
        }

        return nil
    }
}
