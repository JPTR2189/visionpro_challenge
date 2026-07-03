import RealityKit
import RealityKitContent

@MainActor
enum PortalTemplateFactory {

    /// Carrega o modelo do portal do bundle do RealityKitContent.
    static func makeTemplate(targetHeight: Float?, attachingTo sceneRoot: Entity) async -> Entity? {
        guard let portal = try? await Entity(named: "Portal", in: realityKitContentBundle) else {
            print("""
            ❌ Não foi possível carregar a entity 'Portal'.
               Verifique no Reality Composer Pro se a cena se chama exatamente 'Portal'
               (Portal.usda) dentro do pacote RealityKitContent.
            """)
            return nil
        }

        print("✅ Template 'Portal' carregado com sucesso.")

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
