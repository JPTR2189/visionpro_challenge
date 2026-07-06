import ARKit
import QuartzCore
import simd

@MainActor
final class HeadTracker {
    static let shared = HeadTracker()
    private init() {}

    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()

    /// Permite realizar certas ações apenas no visionPro
    private var isRunningSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func start() async -> Bool {
        
        guard WorldTrackingProvider.isSupported else {
            print("Este dispositivo NÃO SUPORTA WorldTrackingProvider.")
            return false
        }

        // MARK: Autorização para usar o sensor
        if isRunningSimulator {
            /// Caso esteja rodando no simulador, não irá pedir autorização para acesso do sensor
            print("Rodando no Simulador...")
        } else {
            let result = await session.requestAuthorization(for: [.worldSensing])
            print("Resultado da autorização:", result)

            guard result[.worldSensing] == .allowed else {
                print("World sensing NÃO autorizado. Status:", result[.worldSensing] as Any)
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
        if isRunningSimulator {
            return matrix_identity_float4x4
        }
        print("⚠️ queryDeviceAnchor retornou nil")
        return nil
    }
}
