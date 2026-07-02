//
//  visionProApp.swift
//  visionPro
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
            HandSphereView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
                // 🔧 Reduz a visibilidade e intrusividade do botão de Home
                // do visionOS durante a experiência imersiva.
                // IMPORTANTE: não suprime completamente (requisito de segurança
                // da Apple) — mas diminui muito a chance de ativação acidental
                // durante o gesto de palma pra cima.
                .persistentSystemOverlays(.hidden)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
