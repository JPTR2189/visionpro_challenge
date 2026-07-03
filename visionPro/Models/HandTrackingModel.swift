//
//  HandTrackingModel.swift
//  visionPro
//

import ARKit

@Observable
final class HandTrackingModel {
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()

    /// Estado da mão DIREITA
    var rightPalmIsFacingUp = false
    var rightSphereShouldAppear = false
    private var rightConsecutiveFramesUp = 0

    /// Estado da mão ESQUERDA
    var leftPalmIsFacingUp = false
    var leftSphereShouldAppear = false
    private var leftConsecutiveFramesUp = 0

    // Gesto de arremesso
    var rightThrowTriggered = false
    var leftThrowTriggered = false

    /// Direção para lançar a bola de fogo
    var rightThrowDirection: SIMD3<Float> = [0, 0, -1]
    var leftThrowDirection: SIMD3<Float> = [0, 0, -1]

    private var rightConsecutiveFramesForward = 0
    private var leftConsecutiveFramesForward = 0

    /// Limite de frames seguidos com ruído que podem ser tolerados
    private let toleratedBadFrames = 5
    /// Quantidade de frames corretos para exibir a esfera
    private let framesToConfirm = 10
    /// Frames para confirmar o gesto de arremesso (menor que framesToConfirm)
    private let framesToConfirmThrow = 5

    func start() async {
        guard HandTrackingProvider.isSupported else {
            print("Hand tracking não é suportado neste ambiente (provavelmente o Simulador).")
            return
        }

        do {
            try await session.run([handTracking])
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

        // MARK: Surgimento da bola de fogo (palma para cima)
        let worldUp = SIMD3<Float>(0, 1, 0)
        let upAlignment = dot(normalizedPalm, worldUp)
        let isUp = upAlignment > 0.75

        // MARK: Arremesso da bola de fogo (palma para frente)
        let horizontalComponent = SIMD3<Float>(normalizedPalm.x, 0, normalizedPalm.z)
        let horizontalMagnitude = length(horizontalComponent)
        let isForward = horizontalMagnitude > 0.8 && upAlignment < 0.4

        await MainActor.run {
            switch handAnchor.chirality {
            case .right:
                rightPalmIsFacingUp = isUp
                updateDebounced(isUp, consecutiveFrames: &rightConsecutiveFramesUp) { rightSphereShouldAppear = $0 }
                updateThrowDetection(
                    isForward: isForward,
                    sphereIsActive: rightSphereShouldAppear,
                    direction: normalize(horizontalComponent),
                    consecutiveFrames: &rightConsecutiveFramesForward
                ) { direction in
                    rightThrowDirection = direction
                    rightThrowTriggered = true
                    // Esconde a esfera da mão (ela virou projétil)
                    rightSphereShouldAppear = false
                    rightConsecutiveFramesUp = 0
                }
            case .left:
                leftPalmIsFacingUp = isUp
                updateDebounced(isUp, consecutiveFrames: &leftConsecutiveFramesUp) { leftSphereShouldAppear = $0 }
                updateThrowDetection(
                    isForward: isForward,
                    sphereIsActive: leftSphereShouldAppear,
                    direction: normalize(horizontalComponent),
                    consecutiveFrames: &leftConsecutiveFramesForward
                ) { direction in
                    leftThrowDirection = direction
                    leftThrowTriggered = true
                    leftSphereShouldAppear = false
                    leftConsecutiveFramesUp = 0
                }
            @unknown default:
                break
            }
        }
    }

    /// Reseta o gatilho de arremesso depois de processar o lançamento, para permitir novos arremessos.
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

    /// Detecção do gesto de arremesso (garante que a bola já está na mão)
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
