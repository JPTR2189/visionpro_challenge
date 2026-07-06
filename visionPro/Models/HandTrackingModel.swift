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

    /// Estado da bola de fogo na mão
    private var rightSphereIsHeld = false
    private var leftSphereIsHeld = false
    private var rightFramesSinceUp = 0
    private var leftFramesSinceUp = 0

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
    /// Tolerância para movimento de lançar bola de fogo (~1s a 90Hz)
    private let framesToAbandonHold = 90

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
        guard wristJoint.isTracked else { return }

        let wristTransform = handAnchor.originFromAnchorTransform * wristJoint.anchorFromJointTransform

        let sign: Float = handAnchor.chirality == .right ? -1 : 1
        let palmNormal = sign * SIMD3<Float>(
            wristTransform.columns.1.x,
            wristTransform.columns.1.y,
            wristTransform.columns.1.z
        )
        let normalizedPalm = normalize(palmNormal)

        let worldUp = SIMD3<Float>(0, 1, 0)
        let upAlignment = dot(normalizedPalm, worldUp)
        let isUp = upAlignment > 0.75
        
        /// Direção do arremesso da bola de fogo
        let horizontalComponent = SIMD3<Float>(
        normalizedPalm.x,
        0,
        normalizedPalm.z
    )

        let horizontalMagnitude = length(horizontalComponent)
        let isForward = horizontalMagnitude > 0.8 && abs(upAlignment) < 0.4

        let throwDirection: SIMD3<Float> = isForward
            ? normalize(horizontalComponent)
            : .zero
        

        let palmWorldPosition = SIMD3<Float>(
            wristTransform.columns.3.x,
            wristTransform.columns.3.y,
            wristTransform.columns.3.z
        )

        await MainActor.run {
            /// Só aceita o arremesso se a palma aponta para onde o usuário olha
            let deviceForward = deviceForwardProvider?()
            let isThrowForward = isForward
                && (deviceForward.map { dot(throwDirection, $0) > 0.5 } ?? true)

            switch handAnchor.chirality {
            case .right:
                rightPalmIsFacingUp = isUp
                rightPalmWorldPosition = palmWorldPosition
                updateDebounced(isUp, consecutiveFrames: &rightConsecutiveFramesUp) { rightSphereShouldAppear = $0 }

                /// A bola só é "segurada" depois de confirmada visualmente,
                /// para o arremesso nunca disparar sem bola na mão

                if isUp {
                    rightFramesSinceUp = 0
                    if rightSphereShouldAppear {
                        rightSphereIsHeld = true
                    }
                } else {
                    rightFramesSinceUp += 1
                    if rightFramesSinceUp > framesToAbandonHold {
                        rightSphereIsHeld = false
                    }
                }

                updateThrowDetection(
                    isForward: isThrowForward,
                    sphereIsActive: rightSphereIsHeld,
                    direction: throwDirection,
                    consecutiveFrames: &rightConsecutiveFramesForward
                ) { direction in
                    print("🧭 [DIREITA] throwDirection detectado")
                    print("   x=\(direction.x)  y=\(direction.y)  z=\(direction.z)")
                    rightThrowDirection = direction
                    rightThrowTriggered = true
                    rightSphereShouldAppear = false
                    rightSphereIsHeld = false
                    rightConsecutiveFramesUp = 0
                }
            case .left:
                leftPalmIsFacingUp = isUp
                leftPalmWorldPosition = palmWorldPosition
                updateDebounced(isUp, consecutiveFrames: &leftConsecutiveFramesUp) { leftSphereShouldAppear = $0 }

                if isUp {
                    leftFramesSinceUp = 0
                    if leftSphereShouldAppear {
                        leftSphereIsHeld = true
                    }
                } else {
                    leftFramesSinceUp += 1
                    if leftFramesSinceUp > framesToAbandonHold {
                        leftSphereIsHeld = false
                    }
                }

                updateThrowDetection(
                    isForward: isThrowForward,
                    sphereIsActive: leftSphereIsHeld,
                    direction: throwDirection,
                    consecutiveFrames: &leftConsecutiveFramesForward
                ) { direction in
                    print("---DEBUG DIRECTION---")
                    print("🧭 [ESQUERDA] throwDirection detectado")
                    print("   x=\(direction.x)  y=\(direction.y)  z=\(direction.z)")
                    print("-------------------------")
                    leftThrowDirection = direction
                    leftThrowTriggered = true
                    leftSphereShouldAppear = false
                    leftSphereIsHeld = false
                    leftConsecutiveFramesUp = 0
                }
            @unknown default:
                break
            }
        }
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

    private func updateThrowDetection(isForward: Bool,
                                      sphereIsActive: Bool,
                                      direction: SIMD3<Float>,
                                      consecutiveFrames: inout Int,
                                      onThrow: (SIMD3<Float>) -> Void) {
        guard sphereIsActive else {
            consecutiveFrames = 0
            return
        }

        if isForward {
            consecutiveFrames += 1
            if consecutiveFrames == framesToConfirmThrow {
                onThrow(direction)
                consecutiveFrames = 0
            }
        } else {
            consecutiveFrames = max(consecutiveFrames - 1, 0)
        }
    }
}
