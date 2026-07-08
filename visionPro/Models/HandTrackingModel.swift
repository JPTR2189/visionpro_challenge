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

    /// Máquina de estados do gesto de arremesso (uma por mão).
   
    private struct ThrowGestureState {
        var forwardFrames = 0
        var exitFrames = 0
        var isArmed = true
        var lastFireTime: TimeInterval = 0
    }

    /// Classificação da pose com histerese: os limiares de entrada
    /// (forward) e de saída (exited) são afastados de propósito —
    /// ruído na fronteira cai em "ambiguous" e não conta para nenhum lado.
    private enum ThrowPose {
        case forward
        case ambiguous
        case exited
    }

    private var rightThrowState = ThrowGestureState()
    private var leftThrowState = ThrowGestureState()

    /// Gesto de arremesso (palma virando pra frente)
    var rightThrowTriggered = false
    var leftThrowTriggered = false
    var rightThrowDirection: SIMD3<Float> = [0, 0, -1]
    var leftThrowDirection: SIMD3<Float> = [0, 0, -1]

    /// Posição da palma no espaço do mundo
    var rightPalmWorldPosition: SIMD3<Float> = .zero
    var leftPalmWorldPosition: SIMD3<Float> = .zero

    /// Limite de frames com ruído tolerados antes de esconder a esfera
    private let toleratedBadFrames = 5
    /// Frames corretos necessários para exibir a esfera (visual)
    private let framesToConfirm = 10
    /// Frames para confirmar o arremesso (~33ms a 90Hz)
    private let framesToConfirmThrow = 3
    /// Confirmação rápida quando a bola estava visível na mão há pouco:
    /// no gesto combinado (palma p/ cima → p/ frente) a intenção é
    /// inequívoca, então o disparo responde no mínimo de frames
    private let framesToConfirmThrowQuick = 2
    /// Janela em que a bola "recém-visível" habilita a confirmação rápida
    private let sphereVisibleGrace: TimeInterval = 1.0
    /// Frames claramente FORA da pose necessários para re-armar o arremesso
    private let framesToRearm = 8
    /// Intervalo mínimo entre dois arremessos da mesma mão (segundos)
    private let throwCooldown: TimeInterval = 0.5

    /// Última vez em que a bola esteve visível em cada mão
    private var rightSphereLastVisibleAt: TimeInterval = 0
    private var leftSphereLastVisibleAt: TimeInterval = 0

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

        /// Cálculo posição normal da palma (direção que a palma aponta).
        let toIndex = indexPosition - wristPosition
        let toLittle = littlePosition - wristPosition
        let palmNormal = handAnchor.chirality == .right
            ? cross(toIndex, toLittle)
            : cross(toLittle, toIndex)
        guard length(palmNormal) > 0.0001 else { return }
        let normalizedPalm = normalize(palmNormal)

        let worldUp = SIMD3<Float>(0, 1, 0)
        let upAlignment = dot(normalizedPalm, worldUp)
        let isUp = upAlignment > 0.75

        /// Sinal 1 — normal da palma: projeção horizontal
        let horizontalComponent = SIMD3<Float>(
            normalizedPalm.x,
            0,
            normalizedPalm.z
        )
        let horizontalMagnitude = length(horizontalComponent)
        let palmHorizontalDirection: SIMD3<Float> = horizontalMagnitude > 0.001
            ? horizontalComponent / horizontalMagnitude
            : .zero

        /// Sinal 2 — direção dos DEDOS (pulso → nó do dedo médio).
        /// Cobre a pose de "empurrão"/arremesso real, em que a palma
        /// termina inclinada para baixo mas os dedos apontam ao alvo —
        /// pose muito semelhante que o sinal 1 sozinho não reconhece.
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        var fingersDirection: SIMD3<Float> = .zero
        var fingersHorizontalRatio: Float = 0
        if middleKnuckle.isTracked {
            let knucklePosition = jointWorldPosition(middleKnuckle, in: handAnchor)
            let toKnuckle = knucklePosition - wristPosition
            let fingersHorizontal = SIMD3<Float>(toKnuckle.x, 0, toKnuckle.z)
            let horizontalLength = length(fingersHorizontal)
            let totalLength = length(toKnuckle)
            if totalLength > 0.0001, horizontalLength > 0.0001 {
                fingersDirection = fingersHorizontal / horizontalLength
                fingersHorizontalRatio = horizontalLength / totalLength
            }
        }

        let palmWorldPosition = wristPosition

        await MainActor.run {
            /// Alinhamento de cada sinal com o olhar
            /// (sem referência do device, os gates não bloqueiam)
            let deviceForward = deviceForwardProvider?()

            let palmGaze: Float
            if let deviceForward, palmHorizontalDirection != .zero {
                palmGaze = dot(palmHorizontalDirection, deviceForward)
            } else {
                palmGaze = palmHorizontalDirection != .zero ? 1.0 : -1.0
            }

            let fingersGaze: Float
            if let deviceForward, fingersDirection != .zero {
                fingersGaze = dot(fingersDirection, deviceForward)
            } else {
                fingersGaze = fingersDirection != .zero ? 1.0 : -1.0
            }

            /// Pose de arremesso: qualquer um dos dois sinais basta.
            /// Sinal 1: palma virada para frente (até ~30° acima ou
            /// qualquer inclinação para baixo com componente horizontal).
            /// Sinal 2: dedos apontando ao alvo com a palma não-para-cima.
            let palmSignal = upAlignment < 0.55
                && horizontalMagnitude > 0.5
                && palmGaze > 0.15
            let pushSignal = upAlignment < 0.35
                && fingersHorizontalRatio > 0.5
                && fingersGaze > 0.4

            let throwPose: ThrowPose
            if isUp || upAlignment > 0.7 {
                throwPose = .exited
            } else if palmSignal || pushSignal {
                throwPose = .forward
            } else if palmGaze < 0.05 && fingersGaze < 0.05 {
                /// Nenhum sinal aponta nem vagamente para frente
                throwPose = .exited
            } else {
                throwPose = .ambiguous
            }

            /// Direção do arremesso: a direção da MÃO (palma quando
            /// confiável, senão dedos), estabilizada pela média com o
            /// olhar — os logs mostraram a normal da palma sozinha
            /// desviando até ~74° do alvo em empurrões reais.
            let handDirection: SIMD3<Float>
            if horizontalMagnitude > 0.5 {
                handDirection = palmHorizontalDirection
            } else if fingersDirection != .zero {
                handDirection = fingersDirection
            } else {
                handDirection = palmHorizontalDirection
            }

            let throwDirection: SIMD3<Float>
            if let deviceForward, handDirection != .zero {
                throwDirection = normalize(handDirection + deviceForward)
            } else if handDirection != .zero {
                throwDirection = handDirection
            } else {
                throwDirection = deviceForward ?? .zero
            }

            let now = Date().timeIntervalSince1970

            switch handAnchor.chirality {
            case .right:
                rightPalmIsFacingUp = isUp
                rightPalmWorldPosition = palmWorldPosition

                /// Gesto 1 (palma para cima exibe a bola)
                updateDebounced(isUp, consecutiveFrames: &rightConsecutiveFramesUp) { rightSphereShouldAppear = $0 }
                if rightSphereShouldAppear { rightSphereLastVisibleAt = now }

                /// Gesto 2 (palma para frente arremessa).
                /// Bola recém-visível na mão = gesto combinado em curso:
                /// confirma no mínimo de frames para máxima resposta.
                let rightFramesNeeded = now - rightSphereLastVisibleAt < sphereVisibleGrace
                    ? framesToConfirmThrowQuick
                    : framesToConfirmThrow

                updateThrowDetection(
                    pose: throwPose,
                    direction: throwDirection,
                    framesNeeded: rightFramesNeeded,
                    state: &rightThrowState
                ) { direction in
                    print("🧭 [DIREITA] throwDirection detectado")
                    print("   x=\(direction.x)  y=\(direction.y)  z=\(direction.z)")
                    print("   up=\(upAlignment)  palmGaze=\(palmGaze)  fingersGaze=\(fingersGaze)")
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
                if leftSphereShouldAppear { leftSphereLastVisibleAt = now }

                let leftFramesNeeded = now - leftSphereLastVisibleAt < sphereVisibleGrace
                    ? framesToConfirmThrowQuick
                    : framesToConfirmThrow

                updateThrowDetection(
                    pose: throwPose,
                    direction: throwDirection,
                    framesNeeded: leftFramesNeeded,
                    state: &leftThrowState
                ) { direction in
                    print("🧭 [ESQUERDA] throwDirection detectado")
                    print("   x=\(direction.x)  y=\(direction.y)  z=\(direction.z)")
                    print("   up=\(upAlignment)  palmGaze=\(palmGaze)  fingersGaze=\(fingersGaze)")
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
   
    private func updateThrowDetection(pose: ThrowPose,
                                      direction: SIMD3<Float>,
                                      framesNeeded: Int,
                                      state: inout ThrowGestureState,
                                      onThrow: (SIMD3<Float>) -> Void) {
        let now = Date().timeIntervalSince1970

        switch pose {
        case .forward:
            state.exitFrames = 0
            state.forwardFrames = min(
                state.forwardFrames + 1,
                framesToConfirmThrow + toleratedBadFrames
            )
            if state.isArmed,
               state.forwardFrames >= framesNeeded,
               now - state.lastFireTime >= throwCooldown {
                state.isArmed = false
                state.lastFireTime = now
                onThrow(direction)
            }

        case .exited:
            state.forwardFrames = 0
            state.exitFrames += 1
            if state.exitFrames >= framesToRearm {
                state.isArmed = true
            }

        case .ambiguous:
            state.forwardFrames = max(state.forwardFrames - 1, 0)
            state.exitFrames = 0
        }
    }
}
