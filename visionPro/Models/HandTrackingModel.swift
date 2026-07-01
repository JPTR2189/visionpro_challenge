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

    /// Limite de frames seguidos com ruído que podem ser tolerados
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

        // 🔧 Bug 3 corrigido: o sistema de coordenadas do punho é ESPELHADO
        // entre mão direita e esquerda no ARKit.
        // Direita: precisamos inverter o sinal (-) pra "palma pra cima" bater com worldUp
        // Esquerda: o sinal original (+) já funciona corretamente
        let sign: Float = handAnchor.chirality == .right ? -1 : 1
        let palmNormal = sign * SIMD3<Float>(
            wristTransform.columns.1.x,
            wristTransform.columns.1.y,
            wristTransform.columns.1.z
        )

        let worldUp = SIMD3<Float>(0, 1, 0) /// Mão apontada para cima no mundo real
        let alignment = dot(normalize(palmNormal), worldUp) /// Compara com a prova real

        let isUp = alignment > 0.75 /// Resultado "cru" desse frame específico

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
