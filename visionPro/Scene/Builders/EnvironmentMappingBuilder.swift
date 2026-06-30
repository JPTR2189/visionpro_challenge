import ARKit
import RealityKit
import UIKit

@MainActor
enum EnvironmentMappingBuilder {

    // MARK: - API Pública

    static func makeRoomEntity(
        from anchor: MeshAnchor,
        wallMaterial: (any RealityKit.Material)?,
        floorMaterial: (any RealityKit.Material)?,
        floorOpacity: Float
    ) -> Entity? {
        let geometry        = anchor.geometry
        let allVertices     = geometry.vertexPositions()
        let allIndices      = geometry.triangleIndices()
        let classifications = geometry.faceClassifications()

        let root = Entity()
        root.name = anchor.id.uuidString
        root.transform = Transform(matrix: anchor.originFromAnchorTransform)

        if let wallEntity = makeSubEntity(
            vertices: allVertices,
            indices: allIndices,
            classifications: classifications,
            condition: { $0 == .wall },
            material: wallMaterial ?? fallbackWallMaterial()
        ) {
            root.addChild(wallEntity)
        }

        if let floorEntity = makeSubEntity(
            vertices: allVertices,
            indices: allIndices,
            classifications: classifications,
            condition: { $0 == .floor },
            material: floorMaterial ?? fallbackFloorMaterial(opacity: floorOpacity)
        ) {
            root.addChild(floorEntity)
        }
        
        if let occlusionEntity = makeSubEntity(
            vertices: allVertices,
            indices: allIndices,
            classifications: classifications,
            condition: { $0 != .wall && $0 != .floor },
            material: OcclusionMaterial()
        ) {
            root.addChild(occlusionEntity)
        }

        return root.children.isEmpty ? nil : root
    }

    // MARK: - Submesh por Classificação

    private static func makeSubEntity(
        vertices: [SIMD3<Float>],
        indices: [UInt32],
        classifications: [MeshSurfaceClass],
        condition: (MeshSurfaceClass) -> Bool,
        material: any RealityKit.Material
    ) -> ModelEntity? {
        var vertexMap   = [UInt32: UInt32]()
        var newVertices = [SIMD3<Float>]()
        var newIndices  = [UInt32]()

        for faceIndex in 0..<classifications.count {
            guard condition(classifications[faceIndex]) else { continue }

            let base = faceIndex * 3
            for k in 0..<3 {
                let oldIndex = indices[base + k]
                if vertexMap[oldIndex] == nil {
                    vertexMap[oldIndex] = UInt32(newVertices.count)
                    newVertices.append(vertices[Int(oldIndex)])
                }
                newIndices.append(vertexMap[oldIndex]!)
            }
        }

        guard !newVertices.isEmpty else { return nil }

        var descriptor = MeshDescriptor()
        descriptor.positions  = MeshBuffers.Positions(newVertices)
        descriptor.primitives = .triangles(newIndices)

        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
        return ModelEntity(mesh: mesh, materials: [material])
    }

    // MARK: - Materiais

    private static func fallbackWallMaterial() -> any RealityKit.Material {
        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor.systemBlue.withAlphaComponent(0.5))
        return mat
    }

    private static func fallbackFloorMaterial(opacity: Float) -> any RealityKit.Material {
        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor.systemRed.withAlphaComponent(CGFloat(opacity)))
        return mat
    }
}
