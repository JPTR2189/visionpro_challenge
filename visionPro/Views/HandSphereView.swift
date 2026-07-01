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

    /// Controle o áudio das bolas de fogo
    @State private var rightAudioController: AudioPlaybackController?
    @State private var leftAudioController: AudioPlaybackController?
    @State private var debugAudioController: AudioPlaybackController?

    ///  Tamanho da bola de fogo
    private let targetScale: Float = 0.15

    /// Elevação da bola de fogo na mão
    private let palmOffset: SIMD3<Float> = [0, 0.1, 0]

    var body: some View {
        RealityView { content in
            
            /// Mão direita
            if let rightFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let rightAnchor = AnchorEntity(.hand(.right, location: .palm))
                rightFireBall.scale = [0.001, 0.001, 0.001]
                rightFireBall.position = palmOffset
                rightAnchor.addChild(rightFireBall)
                content.add(rightAnchor)
                rightSphereEntity = rightFireBall
            } else {
                print("Não consegui carregar a cena 'FireBall' (mão direita).")
            }

            /// Mão esquerda
            if let leftFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let leftAnchor = AnchorEntity(.hand(.left, location: .palm))
                leftFireBall.scale = [0.001, 0.001, 0.001]
                leftFireBall.position = palmOffset
                leftAnchor.addChild(leftFireBall)
                content.add(leftAnchor)
                leftSphereEntity = leftFireBall
            } else {
                print("Não consegui carregar a cena 'FireBall' (mão esquerda).")
            }

            // Usado para gerar a bola de fogo fixa [DEBUG]
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
            if shouldAppear {
                rightAudioController = playFireAudio(on: rightSphereEntity)
            } else {
                rightAudioController?.stop()
                rightAudioController = nil
            }
        }
        .onChange(of: handModel.leftSphereShouldAppear) { _, shouldAppear in
            animate(leftSphereEntity, show: shouldAppear)
            if shouldAppear {
                leftAudioController = playFireAudio(on: leftSphereEntity)
            } else {
                leftAudioController?.stop()
                leftAudioController = nil
            }
        }
        .onChange(of: appModel.debugForceShow) { _, shouldAppear in
            animate(debugSphereEntity, show: shouldAppear)
            if shouldAppear {
                debugAudioController = playFireAudio(on: debugSphereEntity)
            } else {
                debugAudioController?.stop()
                debugAudioController = nil
            }
        }
        .task {
            await handModel.start()
        }
    }

    private func animate(_ entity: Entity?, show: Bool) {
        guard let entity else { return }

        let scale = show ? targetScale : Float(0.001)
        entity.move(
            to: Transform(scale: [scale, scale, scale], translation: palmOffset),
            relativeTo: entity.parent,
            duration: 0.3,
            timingFunction: .easeInOut
        )
    }

    /// Toca o áudio da FireBall e retorna o AudioPlaybackController,
    /// que permite parar o som depois quando necessário.
    @discardableResult
    private func playFireAudio(on rootEntity: Entity?) -> AudioPlaybackController? {
        guard let rootEntity else { return nil }

        guard let sphereEntity = rootEntity.findEntity(named: "Sphere") else {
            print("Não encontrei a entidade 'Sphere' dentro do FireBall.")
            return nil
        }

        Task {
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
                }
            }

            print("⚠️ Áudio não encontrado — continuando sem som.")
        }

        return nil
    }
}

#Preview {
    HandSphereView()
}
