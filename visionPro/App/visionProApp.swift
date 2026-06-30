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

    var body: some Scene {
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

