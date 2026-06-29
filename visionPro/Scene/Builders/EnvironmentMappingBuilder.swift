import ARKit
import RealityKit
import UIKit

@MainActor
enum EnvironmentMappingBuilder {

    // MARK: - API Pública

    static func makePlaneEntity(
        for anchor: PlaneAnchor,
        wallOpacity: Float,
        floorOpacity: Float
    ) -> ModelEntity? {
        switch anchor.classification {
        case .wall:
            return makeEntity(for: anchor, color: .systemBlue, opacity: wallOpacity, tag: WallPlaneComponent())
        case .floor:
            return makeEntity(for: anchor, color: .systemRed, opacity: floorOpacity, tag: FloorPlaneComponent())
        default:
            return nil
        }
    }

    // MARK: - Construção da Entidade

    private static func makeEntity<Tag: Component>(
        for anchor: PlaneAnchor,
        color: UIColor,
        opacity: Float,
        tag: Tag
    ) -> ModelEntity {
        let extent = anchor.geometry.extent
        let mesh   = MeshResource.generatePlane(
            width: extent.width,
            depth: extent.height
        )

        var material = UnlitMaterial()
        material.color = .init(tint: color.withAlphaComponent(CGFloat(opacity)))

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = anchor.id.uuidString
        entity.transform = Transform(
            matrix: anchor.originFromAnchorTransform * extent.anchorFromExtentTransform
        )
        entity.components.set(tag)

        return entity
    }
}
