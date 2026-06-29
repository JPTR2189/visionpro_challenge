import ARKit
import RealityKit

@MainActor
@Observable
final class ARKitSessionManager {

    // MARK: - Estado de Mapeamento

    enum MappingState {
        case idle
        case scanning
        case active
    }

    private(set) var mappingState: MappingState = .idle
    private(set) var scannedAnchors: [UUID: PlaneAnchor] = [:]

    var detectedSurfaceCount: Int { scannedAnchors.count }

    // MARK: - Configuração de Opacidade e Debug

    var wallOpacity:  Float = 0.4
    var floorOpacity: Float = 0.4
    var debugMode:    Bool  = false

    // MARK: - Estado da Sessão

    private(set) var isRunning           = false
    private(set) var authorizationDenied = false

    // MARK: - Providers ARKit

    private let session             = ARKitSession()
    private let planeDetector       = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
    private let sceneReconstruction = SceneReconstructionProvider()

    // MARK: - Streams

    var planeUpdates: AnchorUpdateSequence<PlaneAnchor> {
        planeDetector.anchorUpdates
    }

    var meshUpdates: AnchorUpdateSequence<MeshAnchor> {
        sceneReconstruction.anchorUpdates
    }

    // MARK: - Ciclo de Vida

    func run() async {
        guard PlaneDetectionProvider.isSupported,
              SceneReconstructionProvider.isSupported else { return }

        let authResults = await session.requestAuthorization(for: [.worldSensing])
        guard authResults[.worldSensing] == .allowed else {
            authorizationDenied = true
            return
        }

        do {
            try await session.run([planeDetector, sceneReconstruction])
            isRunning = true
            mappingState = .scanning
        } catch {
            isRunning = false
        }
    }

    func stop() {
        session.stop()
        isRunning = false
        mappingState = .idle
    }

    // MARK: - Controle de Mapeamento

    func reveal() {
        guard mappingState == .scanning else { return }
        mappingState = .active
    }

    func resetScan() {
        scannedAnchors.removeAll()
        mappingState = .idle
    }

    // MARK: - Coleta de Anchors (chamado pela View durante scanning)

    func collectAnchor(_ anchor: PlaneAnchor) {
        scannedAnchors[anchor.id] = anchor
    }

    func discardAnchor(id: UUID) {
        scannedAnchors.removeValue(forKey: id)
    }
}
