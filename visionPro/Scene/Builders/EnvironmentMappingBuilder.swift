import ARKit
import RealityKit
import UIKit

@MainActor
enum EnvironmentMappingBuilder {

    enum Projection {
        case horizontal
        case vertical
        case none
    }

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
            material: wallMaterial ?? fallbackWallMaterial(),
            projection: .vertical
        ) {
            root.addChild(wallEntity)
        }

        if let floorEntity = makeSubEntity(
            vertices: allVertices,
            indices: allIndices,
            classifications: classifications,
            condition: { $0 == .floor },
            material: floorMaterial ?? fallbackFloorMaterial(opacity: floorOpacity),
            projection: .horizontal
        ) {
            root.addChild(floorEntity)
        }


        if let occlusionEntity = makeSubEntity(
            vertices: allVertices,
            indices: allIndices,
            classifications: classifications,
            condition: { $0 != .floor && $0 != .wall },
            material: OcclusionMaterial(),
            projection: .none
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
        material: any RealityKit.Material,
        projection: Projection
    ) -> ModelEntity? {
        var vertexMap   = [UInt32: UInt32]()
        var newVertices = [SIMD3<Float>]()
        var newUVs      = [SIMD2<Float>]()
        var newIndices  = [UInt32]()

        for faceIndex in 0..<classifications.count {
            guard condition(classifications[faceIndex]) else { continue }

            let base = faceIndex * 3
            for k in 0..<3 {
                let oldIndex = indices[base + k]
                if vertexMap[oldIndex] == nil {
                    vertexMap[oldIndex] = UInt32(newVertices.count)
                    let v = vertices[Int(oldIndex)]
                    newVertices.append(v)

                    switch projection {
                    case .horizontal:
                        newUVs.append(SIMD2<Float>(v.x, v.z))
                    case .vertical:
                        newUVs.append(SIMD2<Float>(v.x, v.y))
                    case .none:
                        newUVs.append(.zero)
                    }
                }
                newIndices.append(vertexMap[oldIndex]!)
            }
        }

        guard !newVertices.isEmpty else { return nil }

        var descriptor = MeshDescriptor()
        descriptor.positions  = MeshBuffers.Positions(newVertices)
        descriptor.primitives = .triangles(newIndices)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(newUVs)

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
