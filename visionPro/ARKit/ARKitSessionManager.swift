import ARKit
import RealityKit

@MainActor
@Observable
final class ARKitSessionManager {

    // MARK: - Estado de Mapeamento

    enum MappingState {
        case idle
        case scanning
        case ready
        case active
    }

    private(set) var mappingState: MappingState = .idle
    private(set) var authorizationDenied = false
    private(set) var scannedMeshAnchors: [UUID: MeshAnchor] = [:]
    
    private(set) var currentRoomAnchor: RoomAnchor?
    private(set) var canFinishScanning = false
    private(set) var meshAnchorCount = 0

    private static let minAnchorsToFinish = 5

    // MARK: - Configuração

    var floorOpacity: Float = 0.4

    // MARK: - Providers

    private let session             = ARKitSession()
    private let roomTracking        = RoomTrackingProvider()
    private let sceneReconstruction = SceneReconstructionProvider(modes: [.classification])

    // MARK: - Streams

    var meshAnchorUpdates: AnchorUpdateSequence<MeshAnchor> {
        sceneReconstruction.anchorUpdates
    }

    var roomAnchorUpdates: AnchorUpdateSequence<RoomAnchor> {
        roomTracking.anchorUpdates
    }

    // MARK: - Ciclo de Vida

    func run() async {
        guard RoomTrackingProvider.isSupported,
              SceneReconstructionProvider.isSupported else { return }

        let authResults = await session.requestAuthorization(for: [.worldSensing])
        guard authResults[.worldSensing] == .allowed else {
            authorizationDenied = true
            return
        }

        do {
            try await session.run([roomTracking, sceneReconstruction])
            mappingState = .scanning
        } catch {
            mappingState = .idle
        }
    }

    func stop() {
        session.stop()
        mappingState = .idle
    }

    // MARK: - Controle de Estado

    func updateCurrentRoom(_ anchor: RoomAnchor) {
        guard mappingState == .scanning else { return }
        if anchor.isCurrentRoom {
            currentRoomAnchor = anchor
            canFinishScanning = true
        }
    }

    func finishScanning() {
        guard mappingState == .scanning && canFinishScanning else { return }
        mappingState = .ready
    }

    func reveal() {
        guard mappingState == .ready else { return }
        mappingState = .active
    }

    // MARK: - Coleta de Mesh Anchors

    func updateMeshAnchor(_ anchor: MeshAnchor) {
        scannedMeshAnchors[anchor.id] = anchor
        meshAnchorCount = scannedMeshAnchors.count
        if mappingState == .scanning && meshAnchorCount >= ARKitSessionManager.minAnchorsToFinish {
            canFinishScanning = true
        }
    }

    func removeMeshAnchor(id: UUID) {
        scannedMeshAnchors.removeValue(forKey: id)
    }
}
