import SwiftUI
import RealityKit
import RealityKitContent

struct PortalExperienceView: View {

    @Environment(AppModel.self) private var appModel

    @State private var sceneRoot = Entity()

    /// Tracking das mãos
    @State private var handModel = HandTrackingModel()

    /// Entidades bola de fogo
    @State private var rightSphereEntity: Entity?
    @State private var leftSphereEntity: Entity?

    /// Controlador de áudio
    @State private var rightAudioController: AudioPlaybackController?
    @State private var leftAudioController: AudioPlaybackController?

    /// Tasks pendentes de mostrar/esconder a bola de fogo.
    /// Precisam ser canceladas ao alternar o estado — senão uma Task
    /// atrasada desabilita a entidade depois que ela já reapareceu.
    @State private var rightVisibilityTask: Task<Void, Never>?
    @State private var leftVisibilityTask: Task<Void, Never>?

    /// Entidade do áudio das bolas de fogo
    @State private var rightAudioEntity: Entity?
    @State private var leftAudioEntity: Entity?

    /// Bola de fogo de DEBUG: fixa no mundo, controlada pelo ToggleDebugButton
    @State private var debugSphereEntity: Entity?
    @State private var debugAudioEntity: Entity?
    @State private var debugAudioController: AudioPlaybackController?
    @State private var debugVisibilityTask: Task<Void, Never>?

    /// Som contínuo de fogo (loop) e som de surgimento (uma vez por spawn)
    @State private var sharedAudioResource: AudioFileResource?
    @State private var spawnAudioResource: AudioFileResource?

    private let targetScale: Float = 0.05
    private let palmOffset: SIMD3<Float> = [0, 0.1, 0]
    private let animationDuration: UInt64 = 350_000_000

    var body: some View {
        RealityView { content in
            content.add(sceneRoot)

            /// Áudio compartilhado para as bolas de fogos
            /// (o USDA renomeou "fireSound" → "fire_sound" na branch de áudio)
            if let resource = try? await AudioFileResource(
                named: "/Root/Sphere/FireSpatialAudio/fire_sound",
                from: "FireBall.usda",
                in: realityKitContentBundle
            ) {
                sharedAudioResource = resource
            } else {
                print("⚠️ Não consegui carregar o áudio da FireBall.")
            }

            /// Áudio espacial do surgimento da bola (feat/spatial-audio)
            if let resource = try? await AudioFileResource(
                named: "/Root/Sphere/FireSpawnSpatialAudio/spawn_fire",
                from: "FireBall.usda",
                in: realityKitContentBundle
            ) {
                spawnAudioResource = resource
            } else {
                print("⚠️ Não consegui carregar o áudio de spawn da FireBall.")
            }

            // ── Bola de fogo: mão DIREITA (rotação horária) ──
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

            // ── Bola de fogo: mão ESQUERDA (rotação anti-horária) ──
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

            // ── Bola de fogo de DEBUG: fixa à frente do usuário ──
            if let debugFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let worldAnchor = AnchorEntity(world: [0, 1.2, -0.5])
                debugFireBall.scale = [0.001, 0.001, 0.001]
                debugFireBall.components.set(RotationComponent(angularSpeed: RotationComponent.clockwise))
                debugFireBall.isEnabled = false
                worldAnchor.addChild(debugFireBall)
                content.add(worldAnchor)
                debugSphereEntity = debugFireBall
                debugAudioEntity = debugFireBall.findEntity(named: "Sphere")

                if appModel.debugForceShow {
                    showFireball(debugSphereEntity, audioEntity: debugAudioEntity,
                                 audioController: &debugAudioController,
                                 visibilityTask: &debugVisibilityTask,
                                 show: true, translation: [0, 0, 0])
                }
            } else {
                print("❌ FireBall (debug) não carregou.")
            }
        }
        .task {
            /// Fornece a direção do olhar (projetada no plano horizontal)
            /// para o model validar se o arremesso é mesmo "para frente"
            _ = await HeadTracker.shared.start()
            handModel.deviceForwardProvider = {
                guard let transform = HeadTracker.shared.currentHeadTransform() else { return nil }
                let forward = -SIMD3<Float>(
                    transform.columns.2.x,
                    transform.columns.2.y,
                    transform.columns.2.z
                )
                let horizontal = SIMD3<Float>(forward.x, 0, forward.z)
                guard length(horizontal) > 0.001 else { return nil }
                return normalize(horizontal)
            }
        }
        .task { await handModel.start() }
        // ── Gestos: bola aparece/some na mão ──
        .onChange(of: handModel.rightSphereShouldAppear) { _, shouldAppear in
            showFireball(rightSphereEntity, audioEntity: rightAudioEntity,
                         audioController: &rightAudioController,
                         visibilityTask: &rightVisibilityTask,
                         show: shouldAppear, translation: palmOffset)
        }
        .onChange(of: handModel.leftSphereShouldAppear) { _, shouldAppear in
            showFireball(leftSphereEntity, audioEntity: leftAudioEntity,
                         audioController: &leftAudioController,
                         visibilityTask: &leftVisibilityTask,
                         show: shouldAppear, translation: palmOffset)
        }
        // ── Debug: bola fixa à frente do usuário ──
        .onChange(of: appModel.debugForceShow) { _, shouldAppear in
            showFireball(debugSphereEntity, audioEntity: debugAudioEntity,
                         audioController: &debugAudioController,
                         visibilityTask: &debugVisibilityTask,
                         show: shouldAppear, translation: [0, 0, 0])
        }
        // ── Gestos: arremesso ──
        .onChange(of: handModel.rightThrowTriggered) { _, triggered in
            guard triggered else { return }
            throwFireball(from: rightSphereEntity,
                          at: handModel.rightPalmWorldPosition,
                          direction: handModel.rightThrowDirection)
            handModel.resetThrowTrigger(isRight: true)
        }
        .onChange(of: handModel.leftThrowTriggered) { _, triggered in
            guard triggered else { return }
            throwFireball(from: leftSphereEntity,
                          at: handModel.leftPalmWorldPosition,
                          direction: handModel.leftThrowDirection)
            handModel.resetThrowTrigger(isRight: false)
        }
    }

    // MARK: - Bola de fogo na mão

    private func showFireball(_ entity: Entity?,
                              audioEntity: Entity?,
                              audioController: inout AudioPlaybackController?,
                              visibilityTask: inout Task<Void, Never>?,
                              show: Bool,
                              translation: SIMD3<Float>) {
        visibilityTask?.cancel()

        if show {
            entity?.isEnabled = true
            animate(entity, show: true, translation: translation)

            /// Som de spawn imediato, a cada aparição
            if let audioEntity, let spawnResource = spawnAudioResource {
                audioEntity.playAudio(spawnResource)
            }

            /// Loop de fogo preparado agora, disparado 1s após o spawn
            var fireController: AudioPlaybackController?
            if let audioEntity, let resource = sharedAudioResource {
                fireController = audioEntity.prepareAudio(resource)
            }
            audioController = fireController

            visibilityTask = Task { [fireController] in
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
            animate(entity, show: false, translation: translation)

            visibilityTask = Task {
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
            to: Transform(
                scale: [scale, scale, scale],
                rotation: entity.transform.rotation, // preserva a rotação atual
                translation: translation
            ),
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

    // MARK: - Arremesso

    /// Clona a bola no ponto atual da mão e entrega ao ProjectileSystem (movimento + 6s de vida).
    private func throwFireball(from handEntity: Entity?,
                               at palmWorldPosition: SIMD3<Float>,
                               direction: SIMD3<Float>) {
        guard let handEntity else { return }

        guard length(direction) > 0.001 else {
            print("⚠️ throwFireball: direção inválida.")
            return
        }

        guard length(palmWorldPosition) > 0.001 else {
            print("⚠️ throwFireball: posição da palma ainda não rastreada.")
            return
        }

        let launchDirection = normalize(direction)
        /// palmOffset: nasce na mesma altura em que a bola flutua na mão
        let spawnPosition = palmWorldPosition + palmOffset + launchDirection * 0.12

        let projectile = handEntity.clone(recursive: true)

        projectile.components.remove(RotationComponent.self)
        projectile.components.set(ProjectileComponent(direction: launchDirection))

        projectile.position = spawnPosition
        projectile.scale = [targetScale, targetScale, targetScale]
        projectile.isEnabled = true

        sceneRoot.addChild(projectile)

        if let audioEntity = projectile.findEntity(named: "Sphere"),
           let resource = sharedAudioResource {
            audioEntity.playAudio(resource)
        }
    }
}

#Preview(immersionStyle: .mixed) {
    PortalExperienceView()
        .environment(AppModel())
}
