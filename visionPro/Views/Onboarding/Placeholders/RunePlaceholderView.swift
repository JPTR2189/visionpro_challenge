import SwiftUI
import RealityKit

struct RunePlaceholderView: View {
    var body: some View {
        RealityView { content in
            for entity in makeRuneStones() {
                content.add(entity)
            }
        }
    }

    private func makeRuneStones() -> [Entity] {
        let configs: [(SIMD3<Float>, SIMD3<Float>)] = [
            ([-0.28,  0.02, -0.62], [0.07, 0.06, 0.045]),
            ([ 0.00,  0.14, -0.55], [0.08, 0.065, 0.05]),
            ([ 0.28,  0.02, -0.62], [0.07, 0.06, 0.045]),
            ([ 0.00, -0.10, -0.68], [0.10, 0.08, 0.055]),
        ]

        return configs.map { (pos, size) in
            let mesh = MeshResource.generateBox(size: size, cornerRadius: 0.015)
            var material = SimpleMaterial()
            material.color = .init(tint: .init(red: 0.50, green: 0.30, blue: 0.72, alpha: 1))
            material.roughness = 0.80
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = pos
            entity.transform.rotation = simd_quatf(
                angle: Float.random(in: -0.2...0.2),
                axis: normalize(SIMD3<Float>(0.2, 1, 0.1))
            )
            return entity
        }
    }
}
