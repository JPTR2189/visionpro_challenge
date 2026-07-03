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

            /// Destrói o a bola de fogo quando o tempo expirou
            if now - projectile.launchTime >= projectile.lifetime {
                entity.removeFromParent()
                continue
            }

            /// Movimento constante na direção do arremesso
            /// deslocamento = direção × velocidade × tempo do frame
            let displacement = projectile.direction * projectile.speed * deltaTime
            entity.position += displacement
        }
    }
}
