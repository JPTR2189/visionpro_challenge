import SwiftUI
import RealityKit

@main
struct visionProApp: App {
    @State private var appModel = AppModel()

    init() {
        WallSurfaceComponent.registerComponent()
        PortalSpawnerComponent.registerComponent()
        PortalSpawnerSystem.registerSystem()
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.portalSpaceID) {
            PortalExperienceView()
                .environment(appModel)
                .onAppear   { appModel.portalSpaceState = .open   }
                .onDisappear { appModel.portalSpaceState = .closed }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
