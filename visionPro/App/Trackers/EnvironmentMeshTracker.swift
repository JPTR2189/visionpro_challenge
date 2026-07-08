import ARKit
import RealityKit

/// Reconstrói a malha do ambiente físico (paredes, chão, móveis) como
/// entidades de colisão INVISÍVEIS na cena, para a bola de fogo poder
/// explodir ao atingir objetos do mundo real.
@MainActor
final class EnvironmentMeshTracker {

    private let session = ARKitSession()
    private let sceneReconstruction = SceneReconstructionProvider()

    /// Entidade de colisão de cada anchor de malha do ARKit
    private var meshEntities = [UUID: Entity]()

    func start(attachingTo root: Entity) async {
        guard SceneReconstructionProvider.isSupported else {
            print("Scene reconstruction não é suportada neste ambiente (provavelmente o Simulador).")
            return
        }

        let authResults = await session.requestAuthorization(for: [.worldSensing])
        guard authResults[.worldSensing] == .allowed else {
            print("⚠️ World sensing não autorizado — a bola de fogo não colidirá com o ambiente.")
            return
        }

        do {
            try await session.run([sceneReconstruction])
        } catch {
            print("❌ Erro ao iniciar scene reconstruction: \(error)")
            return
        }

        for await update in sceneReconstruction.anchorUpdates {
            switch update.event {
            case .added, .updated:
                await refreshCollisionEntity(for: update.anchor, in: root)
            case .removed:
                meshEntities[update.anchor.id]?.removeFromParent()
                meshEntities[update.anchor.id] = nil
            }
        }
    }

    private func refreshCollisionEntity(for anchor: MeshAnchor, in root: Entity) async {
        guard let shape = try? await ShapeResource.generateStaticMesh(from: anchor) else {
            return
        }

        let entity: Entity
        if let existing = meshEntities[anchor.id] {
            entity = existing
        } else {
            entity = Entity()
            entity.name = "EnvironmentMesh-\(anchor.id)"
            entity.components.set(EnvironmentMeshComponent())
            meshEntities[anchor.id] = entity
            root.addChild(entity)
        }

        entity.setTransformMatrix(anchor.originFromAnchorTransform, relativeTo: nil)

        /// Colisor estático (.default): o PhysX não suporta triangle mesh
        /// como trigger — o papel de trigger é do projétil.
        entity.components.set(
            CollisionComponent(
                shapes: [shape],
                mode: .default
            )
        )
    }
}
