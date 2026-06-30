import ARKit
import QuartzCore
import simd

@MainActor
final class HeadTracker {
    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()

    private var isRunningSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func start() async -> Bool {
        print("🔍 WorldTrackingProvider.isSupported =", WorldTrackingProvider.isSupported)

        guard WorldTrackingProvider.isSupported else {
            print("❌ Este dispositivo/simulador não suporta WorldTrackingProvider.")
            return false
        }

        if isRunningSimulator {
            print("⚠️ Rodando no Simulator — autorização não resolve, pulando checagem e tentando iniciar a sessão direto.")
        } else {
            let result = await session.requestAuthorization(for: [.worldSensing])
            print("🔍 Resultado da autorização:", result)

            guard result[.worldSensing] == .allowed else {
                print("❌ World sensing NÃO autorizado. Status:", result[.worldSensing] as Any)
                return false
            }
        }

        do {
            try await session.run([worldTracking])
            print("✅ ARKitSession rodando com sucesso.")
            return true
        } catch {
            print("❌ Erro ao rodar a sessão:", error)
            return false
        }
    }

    func currentHeadTransform() -> simd_float4x4? {
        if let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
            return anchor.originFromAnchorTransform
        }

        // Fallback só pra testes visuais no Simulator, quando o anchor real não vem
        if isRunningSimulator {
            print("⚠️ queryDeviceAnchor nil no Simulator — usando transform fixa de fallback (identity, olhando para -Z).")
            return matrix_identity_float4x4
        }

        print("⚠️ queryDeviceAnchor retornou nil")
        return nil
    }
}
