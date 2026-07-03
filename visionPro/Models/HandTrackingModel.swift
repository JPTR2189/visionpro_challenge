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
    private var rightConsecutiveFramesForward = 0
    private var leftConsecutiveFramesForward = 0

    /// Limite de frames com ruído tolerados antes de esconder a esfera
    private let toleratedBadFrames = 5
    /// Frames corretos necessários para exibir a esfera (visual)
    private let framesToConfirm = 10
    /// Frames para confirmar o arremesso
    private let framesToConfirmThrow = 5
    /// Tolerância para movimento de lançar bola de fogo
    private let framesToAbandonHold = 30

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

        let horizontalComponent = SIMD3<Float>(normalizedPalm.x, 0, normalizedPalm.z)
        let horizontalMagnitude = length(horizontalComponent)
        let isForward = horizontalMagnitude > 0.8 && upAlignment < 0.4

        await MainActor.run {
            switch handAnchor.chirality {
            case .right:
                rightPalmIsFacingUp = isUp
                updateDebounced(isUp, consecutiveFrames: &rightConsecutiveFramesUp) { rightSphereShouldAppear = $0 }

                /// Sobe instantaneamente ao ver a palma pra cima, detectando o arremesso

                if isUp {
                    rightFramesSinceUp = 0
                    rightSphereIsHeld = true
                } else {
                    rightFramesSinceUp += 1
                    if rightFramesSinceUp > framesToAbandonHold {
                        rightSphereIsHeld = false
                    }
                }

                updateThrowDetection(
                    isForward: isForward,
                    sphereIsActive: rightSphereIsHeld,
                    direction: normalize(horizontalComponent),
                    consecutiveFrames: &rightConsecutiveFramesForward
                ) { direction in
                    rightThrowDirection = direction
                    rightThrowTriggered = true
                    rightSphereShouldAppear = false
                    rightSphereIsHeld = false
                    rightConsecutiveFramesUp = 0
                }
            case .left:
                leftPalmIsFacingUp = isUp
                updateDebounced(isUp, consecutiveFrames: &leftConsecutiveFramesUp) { leftSphereShouldAppear = $0 }

                if isUp {
                    leftFramesSinceUp = 0
                    leftSphereIsHeld = true
                } else {
                    leftFramesSinceUp += 1
                    if leftFramesSinceUp > framesToAbandonHold {
                        leftSphereIsHeld = false
                    }
                }

                updateThrowDetection(
                    isForward: isForward,
                    sphereIsActive: leftSphereIsHeld,
                    direction: normalize(horizontalComponent),
                    consecutiveFrames: &leftConsecutiveFramesForward
                ) { direction in
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
            consecutiveFrames = max(consecutiveFrames - toleratedBadFrames, 0)
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
