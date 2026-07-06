import RealityKit
import Foundation

/// Sistema que move projéteis em linha reta com velocidade constante,
/// e os destrói quando o tempo de vida (6s) expira.
class ProjectileSystem: System {

    static let query = EntityQuery(where: .has(ProjectileComponent.self))

    required init(scene: RealityKit.Scene) { }

    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        let now = Date().timeIntervalSince1970

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let projectile = entity.components[ProjectileComponent.self] else { continue }

            /// Destrói a bola de fogo e a âncora de mundo quando o tempo expirou

            if now - projectile.launchTime >= projectile.lifetime {
                if let anchor = entity.parent as? AnchorEntity {
                    anchor.removeFromParent()
                } else {
                    entity.removeFromParent()
                }
                continue
            }

            /// Movimento constante na direção do arremesso
            /// deslocamento = direção × velocidade × tempo do frame
            let direction = normalize(projectile.direction)
            let displacement = direction * projectile.speed * deltaTime

            let currentWorldPosition = entity.position(relativeTo: nil)
            entity.setPosition(
                currentWorldPosition + displacement,
                relativeTo: nil
            )
        }
    }
}
