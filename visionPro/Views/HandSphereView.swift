//
//  HandSphereView.swift
//  visionPro
//
//  Created by Jean Pierre on 29/06/26.
//

import SwiftUI
import RealityKit

//struct HandSphereView: View {
//    @State private var handModel = HandTrackingModel()
//    @State private var sphereEntity: ModelEntity?
//
//    var body: some View {
//        RealityView { content in
//            let sphere = ModelEntity(
//                mesh: .generateSphere(radius: 0.03),
//                materials: [SimpleMaterial(color: .orange, isMetallic: true)]
//            )
//            sphere.name = "fireBall"
//            sphere.transform.scale = [0.001, 0.001, 0.001] /// começa "invisível" por tamanho
//
//            let handAnchor = AnchorEntity(.hand(.right, location: .palm)) /// Coloca a âncora na palma da mão
//
//            handAnchor.addChild(sphere) /// Coloca a esfera sempre em cima da mão
//            content.add(handAnchor)
//
//            sphereEntity = sphere /// guarda a referência pra usar no onChange
//        }
//        .onChange(of: handModel.sphereShouldAppear) { _, shouldAppear in
//            print("onChange disparou! shouldAppear =", shouldAppear, "| sphereEntity existe?", sphereEntity != nil)
//
//            guard let sphereEntity else { return }
//
//            let targetScale: Float = shouldAppear ? 1.0 : 0.001
//            sphereEntity.move(
//                to: Transform(scale: [targetScale, targetScale, targetScale]),
//                relativeTo: sphereEntity.parent,
//                duration: 0.3,
//                timingFunction: .easeInOut
//            )
//        }
//        .task {
//            await handModel.start()
//        }
//    }
//}


// DEBUG



struct HandSphereView: View {
    @Environment(AppModel.self) private var appModel
    @State private var handModel = HandTrackingModel()
    @State private var sphereEntity: ModelEntity?

    // 🧪 Entidade separada, só para testes — não depende de rastreamento
    // de mão, porque está ancorada num ponto fixo do mundo.
    @State private var debugSphereEntity: ModelEntity?

    var body: some View {
        RealityView { content in
            // Esfera de produção — ancorada na palma da mão real.
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.03),
                materials: [SimpleMaterial(color: .orange, isMetallic: true)]
            )
            sphere.name = "fireBall"
            sphere.transform.scale = [0.001, 0.001, 0.001] /// começa "invisível" por tamanho

            let handAnchor = AnchorEntity(.hand(.right, location: .palm)) /// Coloca a âncora na palma da mão
            handAnchor.addChild(sphere) /// Coloca a esfera sempre em cima da mão
            content.add(handAnchor)
            sphereEntity = sphere /// guarda a referência pra usar no onChange

            // 🧪 Esfera de debug — ancorada num ponto fixo do espaço,
            // não depende de nenhum sensor de mão.
            let debugSphere = ModelEntity(
                mesh: .generateSphere(radius: 0.03),
                materials: [SimpleMaterial(color: .cyan, isMetallic: true)]
            )
            debugSphere.name = "debugBall"
            debugSphere.transform.scale = [0.001, 0.001, 0.001]

            let worldAnchor = AnchorEntity(world: [0, 1.2, -0.5])
            worldAnchor.addChild(debugSphere)
            content.add(worldAnchor)
            debugSphereEntity = debugSphere
        }
        .onChange(of: handModel.sphereShouldAppear) { _, shouldAppear in
            animate(sphereEntity, show: shouldAppear)
        }
        .onChange(of: appModel.debugForceShow) { _, shouldAppear in
            // 🧪 Anima a esfera de DEBUG, não a de produção.
            animate(debugSphereEntity, show: shouldAppear)
        }
        .task {
            await handModel.start()
        }
    }

    private func animate(_ entity: ModelEntity?, show: Bool) {
        guard let entity else { return }

        let targetScale: Float = show ? 1.0 : 0.001
        entity.move(
            to: Transform(scale: [targetScale, targetScale, targetScale]),
            relativeTo: entity.parent,
            duration: 0.3,
            timingFunction: .easeInOut
        )
    }
}
#Preview {
    HandSphereView()
}
