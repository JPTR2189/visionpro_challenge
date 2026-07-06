//
//  HandTrackingModel.swift
//  visionPro
//

import ARKit

@Observable
final class HandTrackingModel {
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()

    /// Estado visual da mão DIREITA
    var rightPalmIsFacingUp = false
    var rightSphereShouldAppear = false
    private var rightConsecutiveFramesUp = 0

    /// Estado visual da mão ESQUERDA
    var leftPalmIsFacingUp = false
    var leftSphereShouldAppear = false
    private var leftConsecutiveFramesUp = 0

    /// Permite que usuário dispare uma bola de fogo por vez
    private var rightThrowFired = false
    private var leftThrowFired = false

    /// Gesto de arremesso (palma virando pra frente)
    var rightThrowTriggered = false
    var leftThrowTriggered = false
    var rightThrowDirection: SIMD3<Float> = [0, 0, -1]
    var leftThrowDirection: SIMD3<Float> = [0, 0, -1]

    /// Posição da palma no espaço do mundo
    var rightPalmWorldPosition: SIMD3<Float> = .zero
    var leftPalmWorldPosition: SIMD3<Float> = .zero
    private var rightConsecutiveFramesForward = 0
    private var leftConsecutiveFramesForward = 0

    /// Limite de frames com ruído tolerados antes de esconder a esfera
    private let toleratedBadFrames = 5
    /// Frames corretos necessários para exibir a esfera (visual)
    private let framesToConfirm = 10
    /// Frames para confirmar o arremesso
    private let framesToConfirmThrow = 5

    /// Usada para aceitar só arremessos para frente 
    @ObservationIgnored
    var deviceForwardProvider: (@MainActor () -> SIMD3<Float>?)?

    func start() async {
        guard HandTrackingProvider.isSupported else {
            print("Hand tracking não é suportado neste ambiente (provavelmente o Simulador).")
            return
        }

        do {
            try await session.run([handTracking]) /// Liga o sensor de tracking
        } catch {
            print("Erro ao iniciar hand tracking: \(error)")
            return
        }

        for await update in handTracking.anchorUpdates {
            await processUpdate(update.anchor)
        }
    }

    func processUpdate(_ handAnchor: HandAnchor) async {

        guard let skeleton = handAnchor.handSkeleton else { return }

        let wristJoint = skeleton.joint(.wrist)
        let indexMetacarpal = skeleton.joint(.indexFingerMetacarpal)
        let littleMetacarpal = skeleton.joint(.littleFingerMetacarpal)
        guard wristJoint.isTracked,
              indexMetacarpal.isTracked,
              littleMetacarpal.isTracked else { return }

        let wristPosition = jointWorldPosition(wristJoint, in: handAnchor)
        let indexPosition = jointWorldPosition(indexMetacarpal, in: handAnchor)
        let littlePosition = jointWorldPosition(littleMetacarpal, in: handAnchor)

        /// Cálculo posição normal da palma (direção que a palma aponta)
        let toIndex = indexPosition - wristPosition
        let toLittle = littlePosition - wristPosition
        let palmNormal = handAnchor.chirality == .right
            ? cross(toLittle, toIndex)
            : cross(toIndex, toLittle)
        guard length(palmNormal) > 0.0001 else { return }
        let normalizedPalm = normalize(palmNormal)

        let worldUp = SIMD3<Float>(0, 1, 0)
        let upAlignment = dot(normalizedPalm, worldUp)
        let isUp = upAlignment > 0.75

        /// Direção do arremesso da bola de fogo.
        let horizontalComponent = SIMD3<Float>(
            normalizedPalm.x,
            0,
            normalizedPalm.z
        )

        let isForward = abs(upAlignment) < 0.5
            && length(horizontalComponent) > 0.001

        let throwDirection: SIMD3<Float> = isForward
            ? normalize(horizontalComponent)
            : .zero

        let palmWorldPosition = wristPosition

        await MainActor.run {
            /// Só aceita o arremesso se a palma aponta para onde o usuário olha
            let deviceForward = deviceForwardProvider?()
            let isThrowForward = isForward
                && (deviceForward.map { dot(throwDirection, $0) > 0.4 } ?? true)

            switch handAnchor.chirality {
            case .right:
                rightPalmIsFacingUp = isUp
                rightPalmWorldPosition = palmWorldPosition

                /// Gesto 1 (palma para cima exibe a bola)
                updateDebounced(isUp, consecutiveFrames: &rightConsecutiveFramesUp) { rightSphereShouldAppear = $0 }

                /// Gesto 2 (palma para frente arremessa)
                updateThrowDetection(
                    isForward: isThrowForward,
                    direction: throwDirection,
                    consecutiveFrames: &rightConsecutiveFramesForward,
                    hasFired: &rightThrowFired
                ) { direction in
                    print("🧭 [DIREITA] throwDirection detectado")
                    print("   x=\(direction.x)  y=\(direction.y)  z=\(direction.z)")
                    rightThrowDirection = direction
                    rightThrowTriggered = true
                    /// Esconde a bola da mão
                    rightSphereShouldAppear = false
                    rightConsecutiveFramesUp = 0
                }
            case .left:
                leftPalmIsFacingUp = isUp
                leftPalmWorldPosition = palmWorldPosition

                updateDebounced(isUp, consecutiveFrames: &leftConsecutiveFramesUp) { leftSphereShouldAppear = $0 }

                updateThrowDetection(
                    isForward: isThrowForward,
                    direction: throwDirection,
                    consecutiveFrames: &leftConsecutiveFramesForward,
                    hasFired: &leftThrowFired
                ) { direction in
                    print("🧭 [ESQUERDA] throwDirection detectado")
                    print("   x=\(direction.x)  y=\(direction.y)  z=\(direction.z)")
                    leftThrowDirection = direction
                    leftThrowTriggered = true
                    /// Esconde a bola da mão: uma nova instância é arremessada
                    leftSphereShouldAppear = false
                    leftConsecutiveFramesUp = 0
                }
            @unknown default:
                break
            }
        }
    }

    /// Posição de referência da mão no mundo físico
    private func jointWorldPosition(_ joint: HandSkeleton.Joint,
                                    in handAnchor: HandAnchor) -> SIMD3<Float> {
        let transform = handAnchor.originFromAnchorTransform * joint.anchorFromJointTransform
        return SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }

    func resetThrowTrigger(isRight: Bool) {
        if isRight {
            rightThrowTriggered = false
        } else {
            leftThrowTriggered = false
        }
    }

    private func updateDebounced(_ isUp: Bool, consecutiveFrames: inout Int, apply: (Bool) -> Void) {
        if isUp {
            consecutiveFrames = min(consecutiveFrames + 1, framesToConfirm + toleratedBadFrames)
        } else {
            /// Decrementa 1 quando tiver frames ruins na utilização do gesto
            consecutiveFrames = max(consecutiveFrames - 1, 0)
        }

        apply(consecutiveFrames > framesToConfirm)
    }

    /// Detecção do arremesso
    private func updateThrowDetection(isForward: Bool,
                                      direction: SIMD3<Float>,
                                      consecutiveFrames: inout Int,
                                      hasFired: inout Bool,
                                      onThrow: (SIMD3<Float>) -> Void) {
        if isForward {
            consecutiveFrames += 1
            if !hasFired && consecutiveFrames >= framesToConfirmThrow {
                hasFired = true
                onThrow(direction)
            }
        } else {
            consecutiveFrames = max(consecutiveFrames - 1, 0)
            if consecutiveFrames == 0 {
                hasFired = false
            }
        }
    }
}
