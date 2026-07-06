import RealityKit
import _RealityKit_SwiftUI
import Foundation

/// Gerencia as colisões das bolas de fogo
@MainActor
final class CollisionHandler {

    /// A subscription precisa ser guardada — se for descartada,
    /// o RealityKit para de entregar os eventos.
    private var subscription: EventSubscription?

    /// Registra o observador de colisões na cena.
    func subscribe(to content: RealityViewContent) {
        subscription = content.subscribe(to: CollisionEvents.Began.self) { [weak self] event in
            Task { @MainActor in
                self?.handleCollision(event)
            }
        }
    }

    private func handleCollision(_ event: CollisionEvents.Began) {
        let entityA = event.entityA
        let entityB = event.entityB

        // Identifica o projétil (a ordem entityA/entityB não é garantida)
        let projectile: Entity?
        let other: Entity?

        if entityA.components.has(ProjectileComponent.self) {
            projectile = entityA
            other = entityB
        } else if entityB.components.has(ProjectileComponent.self) {
            projectile = entityB
            other = entityA
        } else {
            return  // colisão sem projétil envolvido — ignora
        }

        guard let projectile, let other else { return }

        // ── Caso 1: atingiu um PORTAL → explode E destrói o portal ──
        if other.components.has(PortalComponent.self) {
            explode(projectile: projectile)
            other.removeFromParent()
            print("💥 Bola de fogo destruiu um portal!")
            return
        }

        // ── Caso 2: atingiu o AMBIENTE REAL → só explode ──
        // (a malha da parede/chão/móvel continua intacta, obviamente)
        if hasEnvironmentAncestor(other) {
            explode(projectile: projectile)
            print("💥 Bola de fogo explodiu no ambiente real!")
            return
        }

    }

    
    private func hasEnvironmentAncestor(_ entity: Entity) -> Bool {
        var current: Entity? = entity
        while let e = current {
            if e.components.has(EnvironmentMeshComponent.self) {
                return true
            }
            current = e.parent
        }
        return false
    }

    /// O efeito de explosão (compartilhado pelos dois casos):
    /// 1. Para o movimento (remove o ProjectileComponent)
    /// 2. Expande rápido ("estouro"), encolhe, e remove
    private func explode(projectile: Entity) {

        /// ProjectileSystem passa a ignorar a entidade

        projectile.components.remove(ProjectileComponent.self)

        /// Remove a colisão
        projectile.components.remove(CollisionComponent.self)

        /// Animação de explosão
        let currentScale = projectile.scale.x
        let explosionScale = currentScale * 3.0

        projectile.move(
            to: Transform(
                scale: [explosionScale, explosionScale, explosionScale],
                translation: projectile.position
            ),
            relativeTo: projectile.parent,
            duration: 0.15,
            timingFunction: .easeOut
        )

        /// Animação de sumir da cena
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)

            projectile.move(
                to: Transform(
                    scale: [0.001, 0.001, 0.001],
                    translation: projectile.position
                ),
                relativeTo: projectile.parent,
                duration: 0.25,
                timingFunction: .easeIn
            )

            try? await Task.sleep(nanoseconds: 300_000_000)
            /// Remove só o projétil: o pai agora é o sceneRoot —
            /// remover o pai apagaria a cena inteira.
            projectile.removeFromParent()
        }
    }
}
