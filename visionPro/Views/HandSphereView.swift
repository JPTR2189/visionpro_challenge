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

    private let targetScale: Float = 0.05
    private let palmOffset: SIMD3<Float> = [0, 0.1, 0]

    /// Duração da animação de aparecimento (em nanosegundos)
    /// Deve ser ligeiramente maior que a duration do entity.move() (0.3s)
    private let animationDuration: UInt64 = 350_000_000

    var body: some View {
        RealityView { content in
            RotationSystem.registerSystem()

            // Mão direita — rotação HORÁRIA
            if let rightFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let rightAnchor = AnchorEntity(.hand(.right, location: .palm))
                rightFireBall.scale = [0.001, 0.001, 0.001]
                rightFireBall.position = palmOffset
                rightFireBall.components.set(RotationComponent(angularSpeed: RotationComponent.clockwise))
                rightAnchor.addChild(rightFireBall)
                content.add(rightAnchor)
                rightSphereEntity = rightFireBall
            } else {
                print("FireBall (direita) não carregou.")
            }

            // Mão esquerda — rotação ANTI-HORÁRIA
            if let leftFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let leftAnchor = AnchorEntity(.hand(.left, location: .palm))
                leftFireBall.scale = [0.001, 0.001, 0.001]
                leftFireBall.position = palmOffset
                leftFireBall.components.set(RotationComponent(angularSpeed: RotationComponent.counterClockwise))
                leftAnchor.addChild(leftFireBall)
                content.add(leftAnchor)
                leftSphereEntity = leftFireBall
            } else {
                print("FireBall (esquerda) não carregou.")
            }

            // Ponto fixo [DEBUG]
            if let debugFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let worldAnchor = AnchorEntity(world: [0, 1.2, -0.5])
                debugFireBall.scale = [0.001, 0.001, 0.001]
                debugFireBall.components.set(RotationComponent(angularSpeed: RotationComponent.clockwise))
                worldAnchor.addChild(debugFireBall)
                content.add(worldAnchor)
                debugSphereEntity = debugFireBall
            } else {
                print("FireBall (debug) não carregou.")
            }
        }
        .onChange(of: handModel.rightSphereShouldAppear) { _, shouldAppear in
            showSphere(rightSphereEntity, show: shouldAppear, translation: palmOffset,
                       audioController: &rightAudioController)
        }
        .onChange(of: handModel.leftSphereShouldAppear) { _, shouldAppear in
            showSphere(leftSphereEntity, show: shouldAppear, translation: palmOffset,
                       audioController: &leftAudioController)
        }
        .onChange(of: appModel.debugForceShow) { _, shouldAppear in
            // Debug usa [0,0,0] — posição já definida pelo worldAnchor
            showSphere(debugSphereEntity, show: shouldAppear, translation: [0, 0, 0],
                       audioController: &debugAudioController)
        }
        .task {
            await handModel.start()
        }
    }

    // MARK: - Helpers

    /// Controla aparecimento, rotação e áudio de uma esfera.
    /// A rotação só é ativada DEPOIS da animação de scale completar,
    /// evitando que o RotationSystem cancele o entity.move() em andamento.
    private func showSphere(_ entity: Entity?, show: Bool,
                            translation: SIMD3<Float>,
                            audioController: inout AudioPlaybackController?) {
        animate(entity, show: show, translation: translation)

        if show {
            // Áudio: imediatamente, não conflita com a animação visual
            audioController = playFireAudio(on: entity)

            // Rotação: espera a animação de scale terminar (0.3s + margem)
            // antes de deixar o RotationSystem começar a escrever no transform
            Task {
                try? await Task.sleep(nanoseconds: animationDuration)
                setRotation(on: entity, active: true)
            }
        } else {
            // Ao esconder: para rotação PRIMEIRO, depois anima o desaparecimento
            setRotation(on: entity, active: false)
            audioController?.stop()
            audioController = nil
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

    @discardableResult
    private func playFireAudio(on rootEntity: Entity?) -> AudioPlaybackController? {
        guard let rootEntity else { return nil }

        guard let sphereEntity = rootEntity.findEntity(named: "Sphere") else {
            print("Não encontrei 'Sphere' dentro do FireBall.")
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
                    sphereEntity.playAudio(resource)
                    return
                }
            }
            print("⚠️ Áudio não encontrado.")
        }
        return nil
    }
}

#Preview {
    HandSphereView()
}
