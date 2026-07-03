import SwiftUI
import RealityKit

@main
struct visionProApp: App {

    @State private var appModel = AppModel()

    init() {
        PortalRuneVisualSystem.registerRealityKitContent()
    }

    var body: some SwiftUI.Scene {
        WindowGroup(id: "MainWindow") {
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
