import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    @State private var headTracker = HeadTracker()
    @State private var spawner = PortalSpawner()
    @State private var rootEntity = Entity()
    @State private var spawnTimer: Timer?

    var body: some View {
        RealityView { content in
            content.add(rootEntity)
        }
        .task {
            let started = await headTracker.start()
            guard started else {
                print("Tracking não autorizado/disponível.")
                return
            }

            spawnTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                Task { @MainActor in
                    await spawnPortal()
                }
            }

            await spawnPortal()
        }
        .onDisappear {
            spawnTimer?.invalidate()
            spawnTimer = nil
        }
    }

    @MainActor
    private func spawnPortal() async {
        guard let headTransform = headTracker.currentHeadTransform() else { return }

        let position = spawner.randomPosition(relativeTo: headTransform)

        guard let portal = await spawner.makePortalEntity() else { return }
        portal.position = position

        let headPos = SIMD3<Float>(headTransform.columns.3.x,
                                    headTransform.columns.3.y,
                                    headTransform.columns.3.z)
        portal.look(at: headPos, from: position, relativeTo: nil)

        rootEntity.addChild(portal)
    }
}
