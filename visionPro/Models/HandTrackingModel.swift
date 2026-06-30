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

    /// Limite de frames seguidos com rúido que podem ser tolerados ( antes de zerar a contagem)
    private let toleratedBadFrames = 5
    /// Quantidade de frames corretos para exibir a esfera
    private let framesToConfirm = 10

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
        let palmNormal = -SIMD3<Float>(wristTransform.columns.1.x, wristTransform.columns.1.y, wristTransform.columns.1.z)
        let worldUp = SIMD3<Float>(0, 1, 0)
        let alignment = dot(normalize(palmNormal), worldUp)

        let isUp = alignment > 0.75

        await MainActor.run {
            switch handAnchor.chirality {
            case .right:
                rightPalmIsFacingUp = isUp
                updateDebounced(isUp, consecutiveFrames: &rightConsecutiveFramesUp) { rightSphereShouldAppear = $0 }
            case .left:
                leftPalmIsFacingUp = isUp
                updateDebounced(isUp, consecutiveFrames: &leftConsecutiveFramesUp) { leftSphereShouldAppear = $0 }
            @unknown default:
                break
            }
        }
    }

    /// Faz a contagem de frames quando a mão está na posição correta para exibir a esfera
    private func updateDebounced(_ isUp: Bool, consecutiveFrames: inout Int, apply: (Bool) -> Void) {
        if isUp {
            consecutiveFrames = min(consecutiveFrames + 1, framesToConfirm + toleratedBadFrames)
        } else {
            consecutiveFrames = max(consecutiveFrames - toleratedBadFrames, 0)
        }

        apply(consecutiveFrames > framesToConfirm)
    }
}
