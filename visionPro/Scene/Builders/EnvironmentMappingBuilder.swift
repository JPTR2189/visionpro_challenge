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
        wallMaterial: (any RealityKit.Material)? = nil,
        debugMode: Bool = false
    ) -> ModelEntity? {
        if debugMode {
            return makeDebugEntity(for: anchor)
        }

        switch anchor.classification {
        case .wall:
            return makeWallEntity(for: anchor, opacity: wallOpacity, customMaterial: wallMaterial)
        case .floor:
            return makeColoredEntity(for: anchor, color: .systemRed, opacity: floorOpacity, tag: FloorPlaneComponent())
        default:
            return nil
        }
    }

    // MARK: - Debug: Todas as classificações visíveis com cores únicas

    private static func makeDebugEntity(for anchor: PlaneAnchor) -> ModelEntity {
        let color = debugColor(for: anchor.classification)
        let entity = makeColoredEntity(for: anchor, color: color, opacity: 0.55, tag: WallPlaneComponent())
        return entity
    }

    private static func debugColor(for classification: PlaneAnchor.Classification) -> UIColor {
        switch classification {
        case .wall:     return .systemBlue
        case .floor:    return .systemRed
        case .ceiling:  return .systemGreen
        case .table:    return .systemYellow
        case .seat:     return .systemOrange
        case .window:   return .cyan
        case .door:     return .systemPurple
        default:        return .white
        }
    }

    // MARK: - Construção de Parede (com textura ou fallback)

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

    // MARK: - Construção de Plano Colorido (chão e debug)

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

    // MARK: - Fallback

    private static func fallbackWallMaterial(opacity: Float) -> any RealityKit.Material {
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor.systemBlue.withAlphaComponent(CGFloat(opacity)))
        return material
    }
}
