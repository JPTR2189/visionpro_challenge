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

    @State private var rightAudioController: AudioPlaybackController?
    @State private var leftAudioController: AudioPlaybackController?
    @State private var debugAudioController: AudioPlaybackController?

    @State private var rightAudioEntity: Entity?
    @State private var leftAudioEntity: Entity?
    @State private var debugAudioEntity: Entity?

    /// Tarefas atrasadas (rotação, fogo, desativação) do ciclo atual de cada esfera.
    @State private var rightPendingTask: Task<Void, Never>?
    @State private var leftPendingTask: Task<Void, Never>?
    @State private var debugPendingTask: Task<Void, Never>?

    /// Áudios carregados UMA vez no make (async), podendo ser usados nas três esferas

    @State private var sharedAudioResource: AudioFileResource?
    @State private var spawnAudioResource: AudioFileResource?

    private let targetScale: Float = 0.05
    private let palmOffset: SIMD3<Float> = [0, 0.1, 0]
    private let animationDuration: UInt64 = 350_000_000

    var body: some View {
        RealityView { content in
            RotationSystem.registerSystem()

            
            if let resource = try? await AudioFileResource(
                named: "/Root/Sphere/FireSpatialAudio/fire_sound",
                from: "FireBall.usda",
                in: realityKitContentBundle
            ) {
                sharedAudioResource = resource
            } else {
                print("⚠️ Não conseguiu carregar o recurso de áudio.")
            }

            if let resource = try? await AudioFileResource(
                named: "/Root/Sphere/FireSpawnSpatialAudio/spawn_fire",
                from: "FireBall.usda",
                in: realityKitContentBundle
            ) {
                spawnAudioResource = resource
            } else {
                print("⚠️ Não conseguiu carregar o áudio de spawn.")
            }

            // Mão direita — rotação HORÁRIA
            if let rightFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let rightAnchor = AnchorEntity(.hand(.right, location: .palm))
                rightFireBall.scale = [0.001, 0.001, 0.001]
                rightFireBall.position = palmOffset
                rightFireBall.components.set(RotationComponent(angularSpeed: RotationComponent.clockwise))
                rightFireBall.isEnabled = false
                rightAnchor.addChild(rightFireBall)
                content.add(rightAnchor)
                rightSphereEntity = rightFireBall
                rightAudioEntity = rightFireBall.findEntity(named: "Sphere")
            } else {
                print("❌ FireBall (direita) não carregou.")
            }

            // Mão esquerda — rotação ANTI-HORÁRIA
            if let leftFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let leftAnchor = AnchorEntity(.hand(.left, location: .palm))
                leftFireBall.scale = [0.001, 0.001, 0.001]
                leftFireBall.position = palmOffset
                leftFireBall.components.set(RotationComponent(angularSpeed: RotationComponent.counterClockwise))
                leftFireBall.isEnabled = false
                leftAnchor.addChild(leftFireBall)
                content.add(leftAnchor)
                leftSphereEntity = leftFireBall
                leftAudioEntity = leftFireBall.findEntity(named: "Sphere")
            } else {
                print("❌ FireBall (esquerda) não carregou.")
            }

            // Debug 
            if let debugFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let worldAnchor = AnchorEntity(world: [0, 1.2, -0.5])
                debugFireBall.scale = [0.001, 0.001, 0.001]
                debugFireBall.components.set(RotationComponent(angularSpeed: RotationComponent.clockwise))
                debugFireBall.isEnabled = false  // 🔧 Bug 2
                worldAnchor.addChild(debugFireBall)
                content.add(worldAnchor)
                debugSphereEntity = debugFireBall
                debugAudioEntity = debugFireBall.findEntity(named: "Sphere")

                if appModel.debugForceShow {
                    showSphere(debugSphereEntity, audioEntity: debugAudioEntity,
                               audioController: &debugAudioController,
                               pendingTask: &debugPendingTask,
                               show: true, translation: [0, 0, 0])
                }
            } else {
                print("❌ FireBall (debug) não carregou.")
            }
        }
        .onChange(of: handModel.rightSphereShouldAppear) { _, shouldAppear in
            showSphere(rightSphereEntity, audioEntity: rightAudioEntity,
                       audioController: &rightAudioController,
                       pendingTask: &rightPendingTask,
                       show: shouldAppear, translation: palmOffset)
        }
        .onChange(of: handModel.leftSphereShouldAppear) { _, shouldAppear in
            showSphere(leftSphereEntity, audioEntity: leftAudioEntity,
                       audioController: &leftAudioController,
                       pendingTask: &leftPendingTask,
                       show: shouldAppear, translation: palmOffset)
        }
        .onChange(of: appModel.debugForceShow) { _, shouldAppear in
            showSphere(debugSphereEntity, audioEntity: debugAudioEntity,
                       audioController: &debugAudioController,
                       pendingTask: &debugPendingTask,
                       show: shouldAppear, translation: [0, 0, 0])
        }
        .task {
            await handModel.start()
        }
    }

    // MARK: - Helpers

    /// Coordena aparecimento, rotação, áudio e ocultação de uma esfera.
    private func showSphere(_ entity: Entity?,
                            audioEntity: Entity?,
                            audioController: inout AudioPlaybackController?,
                            pendingTask: inout Task<Void, Never>?,
                            show: Bool,
                            translation: SIMD3<Float>) {
        /// Cancela as tarefas atrasadas do ciclo anterior
        pendingTask?.cancel()

        if show {
            /// Ativa a entidade ANTES de animar
            entity?.isEnabled = true

            // Anima o crescimento
            animate(entity, show: true, translation: translation)

            /// Toca o som de spawn imediatamente, a cada aparição
            if let audioEntity, let spawnResource = spawnAudioResource {
                audioEntity.playAudio(spawnResource)
            }

            /// Prepara o som contínuo de fogo para iniciar 1s após o spawn
            var fireController: AudioPlaybackController?
            if let audioEntity, let resource = sharedAudioResource {
                fireController = audioEntity.prepareAudio(resource)
            }
            audioController = fireController

            /// Rotação após a animação de scale
            pendingTask = Task { [fireController] in
                try? await Task.sleep(nanoseconds: animationDuration)
                guard !Task.isCancelled else { return }
                setRotation(on: entity, active: true)

                try? await Task.sleep(nanoseconds: 1_000_000_000 - animationDuration)
                guard !Task.isCancelled else { return }
                fireController?.play()
            }

        } else {
            setRotation(on: entity, active: false)

            audioController?.stop()
            audioController = nil

            /// Anima o encolhimento
            animate(entity, show: false, translation: translation)

            /// Desativa a entidade APÓS a animação terminar
            pendingTask = Task {
                try? await Task.sleep(nanoseconds: animationDuration)
                guard !Task.isCancelled else { return }
                entity?.isEnabled = false
            }
        }
    }

    private func animate(_ entity: Entity?, show: Bool, translation: SIMD3<Float>) {
        guard let entity else { return }
        let scale = show ? targetScale : Float(0.001)
        entity.move(
            to: Transform(scale: [scale, scale, scale], translation: translation),
            relativeTo: entity.parent,
            duration: 0.3,
            timingFunction: .easeInOut
        )
    }

    private func setRotation(on entity: Entity?, active: Bool) {
        guard let entity else { return }
        if var component = entity.components[RotationComponent.self] {
            component.isActive = active
            entity.components.set(component)
        }
    }
}

#Preview {
    HandSphereView()
}
