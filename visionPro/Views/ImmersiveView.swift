import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var rootEntity = Entity()

    var body: some View {
        RealityView { content in
            content.add(rootEntity)
        }
        .task {
            let started = await HeadTracker.shared.start()
            guard started else {
                print("Tracking não autorizado/disponível.")
                return
            }

            guard let referenceTransform = await HeadTracker.shared.captureReferenceTransform() else {
                print("❌ Não foi possível obter a posição inicial do usuário.")
                return
            }

            guard let template = await PortalTemplateFactory.makeTemplate(
                targetHeight: nil, // mantém igual ao que está funcionando — ajuste depois se precisar
                attachingTo: rootEntity
            ) else {
                print("❌ Não foi possível preparar o template do portal.")
                return
            }

            var spawner = PortalSpawnerComponent()
            spawner.portalTemplate = template
            spawner.referenceTransform = referenceTransform
            spawner.lastSpawnTime = 0

            rootEntity.components.set(spawner)
        }
    }
}
