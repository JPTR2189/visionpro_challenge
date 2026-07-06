import ARKit
import RealityKit

enum MeshSurfaceClass: UInt8 {
    case none    = 0
    case wall    = 1
    case floor   = 2
    case ceiling = 3
    case table   = 4
    case seat    = 5
    case window  = 6
    case door    = 7
}

extension MeshAnchor.Geometry {

    func vertexPositions() -> [SIMD3<Float>] {
        let src = vertices
        let ptr = src.buffer.contents().advanced(by: src.offset)
        return (0..<src.count).map { i in
            ptr.loadUnaligned(fromByteOffset: i * src.stride, as: SIMD3<Float>.self)
        }
    }

    func triangleIndices() -> [UInt32] {
        let elem  = faces
        let ptr   = elem.buffer.contents()
        let total = elem.count * 3
        if elem.bytesPerIndex == 2 {
            return (0..<total).map { i in
                UInt32(ptr.loadUnaligned(fromByteOffset: i * 2, as: UInt16.self))
            }
        } else {
            return (0..<total).map { i in
                ptr.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self)
            }
        }
    }

    func faceClassifications() -> [MeshSurfaceClass] {
        guard let src = classifications else { return [] }
        let ptr = src.buffer.contents().advanced(by: src.offset)
        return (0..<faces.count).map { i in
            let raw = ptr.loadUnaligned(fromByteOffset: i * src.stride, as: UInt8.self)
            return MeshSurfaceClass(rawValue: raw) ?? .none
        }
    }
}
