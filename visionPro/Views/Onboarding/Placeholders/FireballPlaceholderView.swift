import SwiftUI
import RealityKit

struct FireballPlaceholderView: View {
    var body: some View {
        RealityView { content in
            let mesh = MeshResource.generateSphere(radius: 0.20)
            var material = SimpleMaterial()
            material.color = .init(tint: .init(red: 0.12, green: 0.08, blue: 0.08, alpha: 1))
            material.roughness = 0.90
            let fireball = ModelEntity(mesh: mesh, materials: [material])
            fireball.position = [0, -0.06, -0.66]
            content.add(fireball)
        }
    }
}
