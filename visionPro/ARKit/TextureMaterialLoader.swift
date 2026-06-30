import RealityKit
import RealityKitContent

@MainActor
enum TextureMaterialLoader {

    static func loadWallMaterial() async -> (any RealityKit.Material)? {
        guard let entity = try? await Entity(named: "stoneTexture", in: realityKitContentBundle) else {
            return nil
        }
        return extractFirstMaterial(from: entity)
    }
    static func loadFloorMaterial() async -> (any RealityKit.Material)? {
        guard let entity = try? await Entity(named: "grassTexture", in: realityKitContentBundle) else {
            return nil
        }
        return extractFirstMaterial(from: entity)
    }

    private static func extractFirstMaterial(from entity: Entity) -> (any RealityKit.Material)? {
        if let model = entity as? ModelEntity,
           let material = model.model?.materials.first {
            return material
        }
        for child in entity.children {
            if let material = extractFirstMaterial(from: child) {
                return material
            }
        }
        return nil
    }
}
