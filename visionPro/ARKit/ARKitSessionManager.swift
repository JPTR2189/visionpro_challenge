import ARKit
import RealityKit

@MainActor
@Observable
final class ARKitSessionManager {

    // MARK: - Configuração de Opacidade (ajustável em runtime)
    var wallOpacity:  Float = 0.4
    var floorOpacity: Float = 0.4

    // MARK: - Estado da Sessão
    private(set) var isRunning           = false
    private(set) var authorizationDenied = false

    // MARK: - Providers ARKit
    private let session              = ARKitSession()
    private let planeDetector        = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
    private let sceneReconstruction  = SceneReconstructionProvider()

    // MARK: - Stream de Anchors

    var planeUpdates: AnchorUpdateSequence<PlaneAnchor> {
        planeDetector.anchorUpdates
    }

    var meshUpdates: AnchorUpdateSequence<MeshAnchor> {
        sceneReconstruction.anchorUpdates
    }

    // MARK: - Ciclo de Vida

    func run() async {
        guard PlaneDetectionProvider.isSupported,
              SceneReconstructionProvider.isSupported else {
            return
        }

        let authResults = await session.requestAuthorization(for: [.worldSensing])

        guard authResults[.worldSensing] == .allowed else {
            authorizationDenied = true
            return
        }

        do {
            try await session.run([planeDetector, sceneReconstruction])
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func stop() {
        session.stop()
        isRunning = false
    }
}
