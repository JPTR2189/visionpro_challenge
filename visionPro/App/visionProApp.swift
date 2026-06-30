//
//  visionProApp.swift
//  visionPro
//
//  Created by Jean Pierre on 23/06/26.
//

import SwiftUI

@main
struct visionProApp: App {

    @State private var appModel = AppModel()

    init() {
        PortalRuneVisualSystem.registerRealityKitContent()
    }

    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environment(appModel)
        }
        .windowStyle(.volumetric)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
