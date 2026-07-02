import RealityKit
import RealityKitContent

@MainActor
enum PortalTemplateFactory {

    /// Carrega o modelo. Se quiser manter o comportamento 100% original (sem escala),
    /// comente o bloco de escala abaixo.
    static func makeTemplate(targetHeight: Float?, attachingTo sceneRoot: Entity) async -> Entity? {
        guard let portal = try? await Entity(named: "Portal", in: realityKitContentBundle) else {
            print("❌ Erro ao carregar entity 'Portal'.")
            return nil
        }

        if let targetHeight {
            sceneRoot.addChild(portal)

            let bounds = portal.visualBounds(relativeTo: sceneRoot)
            let currentHeight = bounds.extents.y
            print("📏 Bounds medidos: extents =", bounds.extents, "| currentHeight =", currentHeight)

            if currentHeight > 0.001 {
                let scaleFactor = targetHeight / currentHeight
                portal.scale = SIMD3<Float>(repeating: scaleFactor)
                print("📐 Escala aplicada: fator =", scaleFactor)
            } else {
                print("⚠️ Não foi possível medir o tamanho do portal — mantendo escala original.")
            }

            portal.removeFromParent()
        }

        return portal
    }
}
