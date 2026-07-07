import SwiftUI
import RealityKit
import ARKit

struct PortalExperienceView: View {

    @Environment(\.openWindow) private var openWindow
    @Environment(AppModel.self) private var appModel

    @State private var sceneRoot  = Entity()
    @State private var wallMaterial: (any RealityKit.Material)?
    @State private var floorMaterial: (any RealityKit.Material)?
    @State private var scanningMaterial: (any RealityKit.Material)?
    @State private var meshEntities = [UUID: Entity]()
    @State private var portalScene: Entity?
    @State private var currentSequence: [String] = []
    @State private var selectedIndex = 0
    @State private var isAcceptingRuneInput = false

    var body: some View {
        RealityView { content in
            content.add(sceneRoot)
        }
        .task { scanningMaterial = TextureMaterialLoader.createScanningMaterial() }
        .task { wallMaterial = await TextureMaterialLoader.loadWallMaterial() }
        .task { floorMaterial = await TextureMaterialLoader.loadFloorMaterial() }
        .task { await appModel.arSession.run() }
        .task { await processRoomUpdates() }
        .task { await processMeshUpdates() }
        .onChange(of: appModel.shouldRevealEnvironment) { _, shouldReveal in
            if shouldReveal {
                revealEnvironment()
            }
        }
        .onDisappear {
            openWindow(id: "MainWindow")
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleRuneTap(value.entity)
                }
        )
    }

    @MainActor
    private func addPortalExperienceIfNeeded() {
        guard portalScene == nil else { return }

        let portal = PortalExperience.makeScene()
        portalScene = portal
        sceneRoot.addChild(portal)
        PortalExperience.startFloatingStoneMotion(in: portal)
        startNewRound(in: portal)
    }

    @MainActor
    private func startNewRound(in scene: Entity) {
        isAcceptingRuneInput = false
        selectedIndex = 0
        currentSequence = PortalExperience.makeRandomRuneSequence()

        Task { @MainActor in
            PortalExperience.resetLights(in: scene)
            try? await Task.sleep(nanoseconds: 650_000_000)
            await PortalExperience.playRuneSequence(currentSequence, in: scene)
            isAcceptingRuneInput = true
        }
    }

    @MainActor
    private func handleRuneTap(_ entity: Entity) {
        guard isAcceptingRuneInput,
              let portalScene,
              selectedIndex < currentSequence.count,
              let selectedRockName = PortalExperience.rockName(containing: entity) else {
            return
        }

        let expectedRockName = currentSequence[selectedIndex]
        let isCorrect = selectedRockName == expectedRockName
        isAcceptingRuneInput = false

        Task { @MainActor in
            await PortalExperience.flashSelection(
                for: selectedRockName,
                in: portalScene,
                isCorrect: isCorrect
            )

            if isCorrect {
                selectedIndex += 1
                if selectedIndex < currentSequence.count {
                    isAcceptingRuneInput = true
                } else {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    startNewRound(in: portalScene)
                }
            } else {
                try? await Task.sleep(nanoseconds: 500_000_000)
                startNewRound(in: portalScene)
            }
        }
    }

    // MARK: - Room Tracking: aguarda cômodo completo

    @MainActor
    private func processRoomUpdates() async {
        for await update in appModel.arSession.roomAnchorUpdates {
            appModel.arSession.updateCurrentRoom(update.anchor)
        }
    }

    // MARK: - Mesh Tracking: coleta silenciosa + instância após reveal

    @MainActor
    private func processMeshUpdates() async {
        for await update in appModel.arSession.meshAnchorUpdates {
            switch update.event {
            case .added, .updated:
                appModel.arSession.updateMeshAnchor(update.anchor)
                
                if appModel.arSession.mappingState != .active {
                    refreshMeshEntity(for: update.anchor)
                }
            case .removed:
                appModel.arSession.removeMeshAnchor(id: update.anchor.id)
                meshEntities[update.anchor.id]?.removeFromParent()
                meshEntities.removeValue(forKey: update.anchor.id)
            }
        }
    }

    // MARK: - Reveal: instância todos os anchors coletados de uma vez

    @MainActor
    private func revealEnvironment() {
        appModel.arSession.reveal()
        
        for anchor in appModel.arSession.scannedMeshAnchors.values {
            refreshMeshEntity(for: anchor)
        }

        addPortalExperienceIfNeeded()
    }

    @MainActor
    private func refreshMeshEntity(for anchor: MeshAnchor) {
        meshEntities[anchor.id]?.removeFromParent()
        
        let isFinal = (appModel.arSession.mappingState == .active)
        let wMat = isFinal ? wallMaterial : scanningMaterial
        let fMat = isFinal ? floorMaterial : scanningMaterial

        guard let entity = EnvironmentMappingBuilder.makeRoomEntity(
            from: anchor,
            wallMaterial: wMat,
            floorMaterial: fMat,
            floorOpacity: appModel.arSession.floorOpacity
        ) else { return }

        sceneRoot.addChild(entity)
        meshEntities[anchor.id] = entity
    }
}

#Preview(immersionStyle: .mixed) {
    PortalExperienceView()
        .environment(AppModel())
}
