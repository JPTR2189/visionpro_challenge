//
//  ImmersiveView.swift
//  visionPro
//
//  Created by Jean Pierre on 23/06/26.
//

import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        RealityView { content in
            let scene = PortalExperience.makeScene()
            content.add(scene)
            PortalExperience.startFloatingStoneMotion(in: scene)
            PortalExperience.startGeniusLightSequence(in: scene)
        }
        .onDisappear {
            openWindow(id: "MainWindow")
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView().environment(AppModel())
}
