//
//  HandSphereView.swift
//  visionPro
//

import SwiftUI
import RealityKit

struct HandSphereView: View {
    @Environment(AppModel.self) private var appModel
    @State private var handModel = HandTrackingModel()

    @State private var rightSphereEntity: ModelEntity?
    @State private var leftSphereEntity: ModelEntity?

    var body: some View {
        RealityView { content in
            let rightAnchor = AnchorEntity(.hand(.right, location: .palm))
            let rightSphere = makeSphere(name: "fireBallRight")
            rightAnchor.addChild(rightSphere)
            content.add(rightAnchor)
            rightSphereEntity = rightSphere

            let leftAnchor = AnchorEntity(.hand(.left, location: .palm))
            let leftSphere = makeSphere(name: "fireBallLeft")
            leftAnchor.addChild(leftSphere)
            content.add(leftAnchor)
            leftSphereEntity = leftSphere
        }
        .onChange(of: handModel.rightSphereShouldAppear) { _, shouldAppear in
                    animate(rightSphereEntity, show: shouldAppear)
                }
        .onChange(of: handModel.leftSphereShouldAppear) { _, shouldAppear in
            animate(leftSphereEntity, show: shouldAppear)
        }
        .onChange(of: appModel.debugForceShow) { _, shouldAppear in
            // Força as duas esferas ao mesmo tempo [TESTE]
            animate(rightSphereEntity, show: shouldAppear)
            animate(leftSphereEntity, show: shouldAppear)
        }
        .task {
            await handModel.start()
        }
    }

    private func makeSphere(name: String) -> ModelEntity {
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.03),
            materials: [SimpleMaterial(color: .orange, isMetallic: true)]
        )
        sphere.name = name
        sphere.transform.scale = [0.001, 0.001, 0.001] /// começa "invisível" por tamanho
        sphere.position = [0, 0.05, 0] /// eleva a esfera acima da palma
        return sphere
    }

    private func animate(_ entity: ModelEntity?, show: Bool) {
        guard let entity else { return }

        let targetScale: Float = show ? 1.0 : 0.001
        entity.move(
            to: Transform(scale: [targetScale, targetScale, targetScale], translation: [0, 0.05, 0]),
            relativeTo: entity.parent,
            duration: 0.3,
            timingFunction: .easeInOut
        )
    }
}

#Preview {
    HandSphereView()
}
