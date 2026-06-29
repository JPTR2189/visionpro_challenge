//
//  HandTrackingModel.swift
//  visionPro
//

import ARKit

@Observable
final class HandTrackingModel {
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    var palmIsFacingUp = false
    private var consecutiveFramesUp = 0
    var sphereShouldAppear = false

    func start() async {
        // Evita tentar rodar hand tracking em ambientes que não suportam
        // (como o Simulador) — sem isso, cairia direto no catch abaixo.
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

        /// Lê os valores em tempo real de acordo com as atualizações do sensor
        for await update in handTracking.anchorUpdates {
            await processUpdate(update.anchor)
        }
    }

    func processUpdate(_ handAnchor: HandAnchor) async {

        guard handAnchor.chirality == .right,
              let skeleton = handAnchor.handSkeleton else { return }

        let wristJoint = skeleton.joint(.wrist)
        guard wristJoint.isTracked else { return }

        // Transform do punho, em coordenadas de mundo
        let wristTransform = handAnchor.originFromAnchorTransform * wristJoint.anchorFromJointTransform

        // Testando columns.2 agora (columns.1 foi a primeira tentativa)
        let palmNormal = SIMD3<Float>(wristTransform.columns.2.x, wristTransform.columns.2.y, wristTransform.columns.2.z)

        let worldUp = SIMD3<Float>(0, 1, 0) /// Mão apontada para cima no mundo real (prova real)

        let alignment = dot(normalize(palmNormal), worldUp) /// Normaliza a posição da mão no vision e compara com a prova real (worldUp)

        print("alignment:", alignment) // 🧪 temporário, ajuda a calibrar o threshold certo

        let isUp = alignment > 0.75 /// Resultado "cru" desse frame específico

        await MainActor.run {
            palmIsFacingUp = isUp     /// Mantém o sinal cru, útil pra debug
            updateDebounced(isUp)     /// Alimenta o debounce, que decide sphereShouldAppear
        }
    }

    private func updateDebounced(_ isUp: Bool) {
        consecutiveFramesUp = isUp ? consecutiveFramesUp + 1 : 0
        sphereShouldAppear = consecutiveFramesUp > 10
    }
}
