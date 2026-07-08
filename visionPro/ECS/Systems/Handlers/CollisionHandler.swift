import SwiftUI
import RealityKit

/// Observa as colisões da cena e dispara a explosão quando uma bola de
/// fogo atinge um objeto do mundo físico escaneado pelo ARKit.
@MainActor
final class CollisionHandler {

    /// A subscription precisa ser guardada — se for descartada,
    /// o RealityKit para de entregar os eventos.
    private var subscription: EventSubscription?

    func subscribe(to content: RealityViewContent) {
        subscription = content.subscribe(to: CollisionEvents.Began.self) { [weak self] event in
            Task { @MainActor in
                self?.handleCollision(event)
            }
        }
    }

    private func handleCollision(_ event: CollisionEvents.Began) {
        /// Identifica o projétil (a ordem entityA/entityB não é garantida)
        let projectile: Entity
        let other: Entity

        if event.entityA.components.has(ProjectileComponent.self) {
            projectile = event.entityA
            other = event.entityB
        } else if event.entityB.components.has(ProjectileComponent.self) {
            projectile = event.entityB
            other = event.entityA
        } else {
            return
        }

        guard hasEnvironmentAncestor(other) else { return }

        explode(projectile: projectile)
        print("💥 Bola de fogo explodiu no ambiente físico!")
    }

    private func hasEnvironmentAncestor(_ entity: Entity) -> Bool {
        var current: Entity? = entity
        while let entity = current {
            if entity.components.has(EnvironmentMeshComponent.self) {
                return true
            }
            current = entity.parent
        }
        return false
    }

    /// Animação de explosão:
    /// 1. Para o movimento e a colisão (remove os components)
    /// 2. Expande rápido ("estouro"), encolhe e remove da cena
    private func explode(projectile: Entity) {
        /// ProjectileSystem passa a ignorar a entidade, e novos eventos
        /// de colisão dela deixam de ser reconhecidos como projétil
        projectile.components.remove(ProjectileComponent.self)
        projectile.components.remove(CollisionComponent.self)
        projectile.components.remove(PhysicsBodyComponent.self)

        let currentScale = projectile.scale.x
        let explosionScale = currentScale * 3.0

        projectile.move(
            to: Transform(
                scale: [explosionScale, explosionScale, explosionScale],
                rotation: projectile.orientation,
                translation: projectile.position
            ),
            relativeTo: projectile.parent,
            duration: 0.15,
            timingFunction: .easeOut
        )

        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)

            projectile.move(
                to: Transform(
                    scale: [0.001, 0.001, 0.001],
                    rotation: projectile.orientation,
                    translation: projectile.position
                ),
                relativeTo: projectile.parent,
                duration: 0.25,
                timingFunction: .easeIn
            )

            try? await Task.sleep(nanoseconds: 300_000_000)
            /// Remove só o projétil: o pai é o sceneRoot —
            /// remover o pai apagaria a cena inteira.
            projectile.removeFromParent()
        }
    }
}
