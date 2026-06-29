import ARKit
import RealityKit
import UIKit

@MainActor
enum EnvironmentMappingBuilder {

    // MARK: - API Pública

    static func makePlaneEntity(
        for anchor: PlaneAnchor,
        wallOpacity: Float,
        floorOpacity: Float,
        wallMaterial: (any RealityKit.Material)? = nil
    ) -> ModelEntity? {
        switch anchor.classification {
        case .wall:
            return makeWallEntity(for: anchor, opacity: wallOpacity, customMaterial: wallMaterial)
        case .floor:
            return makeColoredEntity(for: anchor, color: .systemRed, opacity: floorOpacity, tag: FloorPlaneComponent())
        default:
            return nil
        }
    }

    // MARK: - Construção de Parede

    private static func makeWallEntity(
        for anchor: PlaneAnchor,
        opacity: Float,
        customMaterial: (any RealityKit.Material)?
    ) -> ModelEntity {
        let extent = anchor.geometry.extent
        let mesh   = MeshResource.generatePlane(width: extent.width, depth: extent.height)

        let material: any RealityKit.Material = customMaterial ?? fallbackWallMaterial(opacity: opacity)

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name      = anchor.id.uuidString
        entity.transform = Transform(
            matrix: anchor.originFromAnchorTransform * extent.anchorFromExtentTransform
        )
        entity.components.set(WallPlaneComponent())
        return entity
    }

    // MARK: - Construção de Chão (colorido)

    private static func makeColoredEntity<Tag: Component>(
        for anchor: PlaneAnchor,
        color: UIColor,
        opacity: Float,
        tag: Tag
    ) -> ModelEntity {
        let extent = anchor.geometry.extent
        let mesh   = MeshResource.generatePlane(width: extent.width, depth: extent.height)

        var material = UnlitMaterial()
        material.color = .init(tint: color.withAlphaComponent(CGFloat(opacity)))

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name      = anchor.id.uuidString
        entity.transform = Transform(
            matrix: anchor.originFromAnchorTransform * extent.anchorFromExtentTransform
        )
        entity.components.set(tag)
        return entity
    }

    // MARK: - Fallback (sem USDZ carregado)

    private static func fallbackWallMaterial(opacity: Float) -> any RealityKit.Material {
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor.systemBlue.withAlphaComponent(CGFloat(opacity)))
        return material
    }
}
