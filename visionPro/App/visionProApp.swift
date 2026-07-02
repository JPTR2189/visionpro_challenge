import SwiftUI
import RealityKit

@main
struct visionProApp: App {
    @State private var appModel = AppModel()

    init() {
        PortalSpawnerComponent.registerComponent()
        PortalSpawnerSystem.registerSystem()
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
