import SwiftUI
import RealityKit
import RealityKitContent

struct FireballPlaceholderView: View {
    var body: some View {
        RealityView { content in
            guard let scene = try? await Entity(named: "SceneTutorial", in: realityKitContentBundle) else { return }

            let fireball = scene.findEntity(named: "FireBall") ?? scene

            fireball.position = [0, -0.08, -0.70]

            let scale: Float = 0.38
            fireball.scale = SIMD3(repeating: scale)

            content.add(fireball)
        }
    }
}
