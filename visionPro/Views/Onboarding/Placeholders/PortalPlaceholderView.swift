import SwiftUI
import RealityKit

struct PortalPlaceholderView: View {
    var body: some View {
        RealityView { content in
            content.add(makePortalRing())
            for entity in makeFloatingRunes() {
                content.add(entity)
            }
        }
    }

    private func makePortalRing() -> Entity {
        let root = Entity()
        let segmentCount = 14
        let ringRadius: Float = 0.17

        for i in 0..<segmentCount {
            let angle = Float(i) / Float(segmentCount) * 2 * .pi
            let x = ringRadius * cos(angle)
            let y = ringRadius * sin(angle)

            let mesh = MeshResource.generateBox(size: [0.045, 0.045, 0.038], cornerRadius: 0.01)
            var material = SimpleMaterial()
            material.color = .init(tint: .init(red: 0.42, green: 0.52, blue: 0.30, alpha: 1))
            material.roughness = 0.85
            let segment = ModelEntity(mesh: mesh, materials: [material])
            segment.position = SIMD3(x, y, -0.60)
            segment.transform.rotation = simd_quatf(angle: angle, axis: [0, 0, 1])
            root.addChild(segment)
        }
        return root
    }

    private func makeFloatingRunes() -> [Entity] {
        let positions: [(SIMD3<Float>, Float)] = [
            ([-0.30,  0.20, -0.52], 0.12),
            ([ 0.28,  0.26, -0.50], 0.15),
            ([-0.32,  0.02, -0.58], 0.10),
            ([ 0.32, -0.10, -0.54], 0.11),
            ([-0.10, -0.30, -0.50], 0.09),
            ([ 0.15, -0.28, -0.52], 0.13),
            ([ 0.38,  0.08, -0.56], 0.10),
        ]

        return positions.map { (pos, scale) in
            let mesh = MeshResource.generateBox(
                size: [0.055 * scale / 0.12, 0.048 * scale / 0.12, 0.038 * scale / 0.12],
                cornerRadius: 0.013
            )
            var material = SimpleMaterial()
            material.color = .init(tint: .init(red: 0.50, green: 0.30, blue: 0.72, alpha: 1))
            material.roughness = 0.80
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = pos
            return entity
        }
    }
}
