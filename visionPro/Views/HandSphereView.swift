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

    /// Entidades vísiveis das bolas de fogo
    @State private var rightSphereEntity: Entity?
    @State private var leftSphereEntity: Entity?
    @State private var debugSphereEntity: Entity?

    /// Controlador de áudio
    @State private var rightAudioController: AudioPlaybackController?
    @State private var leftAudioController: AudioPlaybackController?
    @State private var debugAudioController: AudioPlaybackController?

    /// Entidades para configura áudio espacial das bolas de fogo
    @State private var rightAudioEntity: Entity?
    @State private var leftAudioEntity: Entity?
    @State private var debugAudioEntity: Entity?
    
    /// Gerenciador de colisões
    @State private var collisionHandler = CollisionHandler()

    
    @State private var sharedAudioResource: AudioFileResource?

    /// Referência ao contéudo do RealityView
    @State private var sceneContent: RealityViewContent?

    private let targetScale: Float = 0.05
    private let palmOffset: SIMD3<Float> = [0, 0.1, 0]
    private let animationDuration: UInt64 = 350_000_000

    var body: some View {
        RealityView { content in
            RotationSystem.registerSystem()
            ProjectileSystem.registerSystem()
            collisionHandler.subscribe(to: content)

            /// Guarda o content para  criar as bolas de fogo (projéteis)
            sceneContent = content

            if let resource = try? await AudioFileResource(
                named: "/Root/Sphere/FireSpatialAudio/fireSound",
                from: "FireBall.usda",
                in: realityKitContentBundle
            ) {
                sharedAudioResource = resource
            }

            /// Mão direita - rotação horária
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
            }

            /// Mão esquerda rotação anti-horária
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
            }

            // Debug
            if let debugFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let worldAnchor = AnchorEntity(world: [0, 1.2, -0.5])
                debugFireBall.scale = [0.001, 0.001, 0.001]
                debugFireBall.components.set(RotationComponent(angularSpeed: RotationComponent.clockwise))
                debugFireBall.isEnabled = false
                worldAnchor.addChild(debugFireBall)
                content.add(worldAnchor)
                debugSphereEntity = debugFireBall
                debugAudioEntity = debugFireBall.findEntity(named: "Sphere")
            }
        }
        .onChange(of: handModel.rightSphereShouldAppear) { _, shouldAppear in
            showSphere(rightSphereEntity, audioEntity: rightAudioEntity,
                       audioController: &rightAudioController,
                       show: shouldAppear, translation: palmOffset)
        }
        .onChange(of: handModel.leftSphereShouldAppear) { _, shouldAppear in
            showSphere(leftSphereEntity, audioEntity: leftAudioEntity,
                       audioController: &leftAudioController,
                       show: shouldAppear, translation: palmOffset)
        }
        .onChange(of: appModel.debugForceShow) { _, shouldAppear in
            showSphere(debugSphereEntity, audioEntity: debugAudioEntity,
                       audioController: &debugAudioController,
                       show: shouldAppear, translation: [0, 0, 0])
        }
        .onChange(of: handModel.rightThrowTriggered) { _, triggered in
            guard triggered else { return }
            throwFireball(from: rightSphereEntity, direction: handModel.rightThrowDirection)
            handModel.resetThrowTrigger(isRight: true)
        }
        .onChange(of: handModel.leftThrowTriggered) { _, triggered in
            guard triggered else { return }
            throwFireball(from: leftSphereEntity, direction: handModel.leftThrowDirection)
            handModel.resetThrowTrigger(isRight: false)
        }
        .task {
            await handModel.start()
        }
    }

    // MARK: - Arremesso

    /// Cria um clone da bola no ponto atual da mão
    private func throwFireball(from handEntity: Entity?, direction: SIMD3<Float>) {
        guard let handEntity, let content = sceneContent else { return }

  
        let worldPosition = handEntity.position(relativeTo: nil)

       
        let projectile = handEntity.clone(recursive: true)

        projectile.components.remove(RotationComponent.self)

        projectile.components.set(ProjectileComponent(direction: direction))
        
        /// Adiciona componente de colisão na bola de fogo
        projectile.components.set(CollisionComponent(
                shapes: [.generateSphere(radius: 0.05)],
                mode: .trigger
            ))

        let worldAnchor = AnchorEntity(world: worldPosition)
        projectile.position = [0, 0, 0]  // zero relativo ao anchor
        projectile.scale = [targetScale, targetScale, targetScale]
        projectile.isEnabled = true
        worldAnchor.addChild(projectile)
        content.add(worldAnchor)

        if let audioEntity = projectile.findEntity(named: "Sphere"),
           let resource = sharedAudioResource {
            audioEntity.playAudio(resource)
        }

        Task {
            try? await Task.sleep(nanoseconds: 6_500_000_000)
            worldAnchor.removeFromParent()
        }
    }

    // MARK: - Helpers

    private func showSphere(_ entity: Entity?,
                            audioEntity: Entity?,
                            audioController: inout AudioPlaybackController?,
                            show: Bool,
                            translation: SIMD3<Float>) {
        if show {
            entity?.isEnabled = true
            animate(entity, show: true, translation: translation)

            if let audioEntity, let resource = sharedAudioResource {
                audioController = audioEntity.playAudio(resource)
            }

            Task {
                try? await Task.sleep(nanoseconds: animationDuration)
                setRotation(on: entity, active: true)
            }
        } else {
            setRotation(on: entity, active: false)
            audioController?.stop()
            audioController = nil
            animate(entity, show: false, translation: translation)

            Task {
                try? await Task.sleep(nanoseconds: animationDuration)
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
