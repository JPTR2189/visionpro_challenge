//
//  HandSphereView.swift
//  visionPro
//

import SwiftUI
import RealityKit
import RealityKitContent

struct HandSphereView: View {
    @Environment(AppModel.self) private var appModel
    @State private var handModel = HandTrackingModel()

    @State private var rightSphereEntity: Entity?
    @State private var leftSphereEntity: Entity?
    @State private var debugSphereEntity: Entity?

    var body: some View {
        RealityView { content in
            // Mão direita
            if let rightFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let rightAnchor = AnchorEntity(.hand(.right, location: .palm))
                rightFireBall.scale = [0.001, 0.001, 0.001]
                rightFireBall.position = [0, 0.05, 0]
                rightAnchor.addChild(rightFireBall)
                content.add(rightAnchor)
                rightSphereEntity = rightFireBall
            } else {
                print("Não consegui carregar a cena 'FireBall' (mão direita).")
            }

            // Mão esquerda
            if let leftFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let leftAnchor = AnchorEntity(.hand(.left, location: .palm))
                leftFireBall.scale = [0.001, 0.001, 0.001]
                leftFireBall.position = [0, 0.05, 0]
                leftAnchor.addChild(leftFireBall)
                content.add(leftAnchor)
                leftSphereEntity = leftFireBall
            } else {
                print("Não consegui carregar a cena 'FireBall' (mão esquerda).")
            }

            // 🧪 Debug — ancorada em ponto fixo do mundo, sem depender da mão
            if let debugFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let worldAnchor = AnchorEntity(world: [0, 1.2, -0.5])
                debugFireBall.scale = [0.001, 0.001, 0.001]
                worldAnchor.addChild(debugFireBall)
                content.add(worldAnchor)
                debugSphereEntity = debugFireBall
            } else {
                print("Não consegui carregar a cena 'FireBall' (debug).")
            }
        }
        .onChange(of: handModel.rightSphereShouldAppear) { _, shouldAppear in
            animate(rightSphereEntity, show: shouldAppear)
            if shouldAppear { playFireAudio(on: rightSphereEntity) }
        }
        .onChange(of: handModel.leftSphereShouldAppear) { _, shouldAppear in
            animate(leftSphereEntity, show: shouldAppear)
            if shouldAppear { playFireAudio(on: leftSphereEntity) }
        }
        .onChange(of: appModel.debugForceShow) { _, shouldAppear in
            animate(debugSphereEntity, show: shouldAppear)
            if shouldAppear { playFireAudio(on: debugSphereEntity) }
        }
        .task {
            await handModel.start()
        }
    }

    private func animate(_ entity: Entity?, show: Bool) {
        guard let entity else { return }

        let targetScale: Float = show ? 1.0 : 0.001
        entity.move(
            to: Transform(scale: [targetScale, targetScale, targetScale]),
            relativeTo: entity.parent,
            duration: 0.3,
            timingFunction: .easeInOut
        )
    }

    /// Carrega o áudio "fireSound" diretamente da cena "FireBall.usda"
    private func playFireAudio(on rootEntity: Entity?) {
        guard let rootEntity else { return }

        guard let sphereEntity = rootEntity.findEntity(named: "Sphere") else {
            print("Não foi encotrado a entidade 'Sphere' dentro do FireBall.")
            return
        }

        Task {
            /// Caminhos possíveis para o acessar o áudio:
            let attempts = [
                "/Root/Sphere/FireSpatialAudio/fireSound",
                "/Root/FireSpatialAudio/fireSound",
                "Sphere/FireSpatialAudio/fireSound",
                "FireSpatialAudio/fireSound",
                "fireSound"
            ]

            for path in attempts {
                if let resource = try? await AudioFileResource(
                    named: path,
                    from: "FireBall.usda",
                    in: realityKitContentBundle
                ) {
                    print("✅ Carregou o áudio usando o caminho:", path)
                    sphereEntity.playAudio(resource)
                    return
                } else {
                    print("❌ Falhou com o caminho:", path)
                }
            }

            print("Nenhum caminho funcionou. Pode ser necessário ajustar o nome exato da cena/entidade.")
        }
    }
}

#Preview {
    HandSphereView()
}
