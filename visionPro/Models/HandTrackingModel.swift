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
    /// Frames para confirmar o arremesso
    private let framesToConfirmThrow = 5
    /// Frames claramente FORA da pose necessários para re-armar o arremesso
    private let framesToRearm = 12
    /// Intervalo mínimo entre dois arremessos da mesma mão (segundos)
    private let throwCooldown: TimeInterval = 0.7

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

        /// Direção do arremesso: projeção horizontal da normal da palma
        let horizontalComponent = SIMD3<Float>(
            normalizedPalm.x,
            0,
            normalizedPalm.z
        )
        let horizontalMagnitude = length(horizontalComponent)
        let throwDirection: SIMD3<Float> = horizontalMagnitude > 0.001
            ? horizontalComponent / horizontalMagnitude
            : .zero

        let palmWorldPosition = wristPosition

        await MainActor.run {
            /// Alinhamento da palma com o olhar
            let deviceForward = deviceForwardProvider?()
            let gazeAlignment: Float
            if let deviceForward, throwDirection != .zero {
                gazeAlignment = dot(throwDirection, deviceForward)
            } else {
                gazeAlignment = 1.0
            }

          
            let throwPose: ThrowPose
            if isUp || upAlignment > 0.7 || gazeAlignment < 0.1 || horizontalMagnitude < 0.25 {
                throwPose = .exited
            } else if upAlignment < 0.55 && horizontalMagnitude > 0.5 && gazeAlignment > 0.25 {
                throwPose = .forward
            } else {
                throwPose = .ambiguous
            }

            switch handAnchor.chirality {
            case .right:
                rightPalmIsFacingUp = isUp
                rightPalmWorldPosition = palmWorldPosition

                /// Gesto 1 (palma para cima exibe a bola)
                updateDebounced(isUp, consecutiveFrames: &rightConsecutiveFramesUp) { rightSphereShouldAppear = $0 }

                /// Gesto 2 (palma para frente arremessa)
                updateThrowDetection(
                    pose: throwPose,
                    direction: throwDirection,
                    state: &rightThrowState
                ) { direction in
                    print("🧭 [DIREITA] throwDirection detectado")
                    print("   x=\(direction.x)  y=\(direction.y)  z=\(direction.z)")
                    print("   up=\(upAlignment)  gaze=\(gazeAlignment)")
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
                    pose: throwPose,
                    direction: throwDirection,
                    state: &leftThrowState
                ) { direction in
                    print("🧭 [ESQUERDA] throwDirection detectado")
                    print("   x=\(direction.x)  y=\(direction.y)  z=\(direction.z)")
                    print("   up=\(upAlignment)  gaze=\(gazeAlignment)")
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
               state.forwardFrames >= framesToConfirmThrow,
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
