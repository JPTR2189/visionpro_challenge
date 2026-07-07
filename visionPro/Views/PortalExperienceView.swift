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
    @State private var isWaitingForClosingTap = false
    @State private var isClosingPortal = false
    @State private var currentRoundIndex = 0

    private let roundSequenceLengths = [4, 6, 8]

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

        Task { @MainActor in
            await PortalExperience.playOpeningAnimation(in: portal)
            PortalExperience.startFloatingStoneMotion(in: portal)
            startCurrentRound(in: portal)
        }
    }

    @MainActor
    private func startCurrentRound(in scene: Entity) {
        guard currentRoundIndex < roundSequenceLengths.count else { return }

        isAcceptingRuneInput = false
        isWaitingForClosingTap = false
        isClosingPortal = false
        PortalExperience.setClosingHitTargetEnabled(false, in: scene)
        selectedIndex = 0
        currentSequence = PortalExperience.makeRandomRuneSequence(
            length: roundSequenceLengths[currentRoundIndex]
        )

        Task { @MainActor in
            PortalExperience.resetLights(in: scene)
            try? await Task.sleep(nanoseconds: 650_000_000)
            await PortalExperience.playRuneSequence(currentSequence, in: scene)
            isAcceptingRuneInput = true
        }
    }

    @MainActor
    private func handleRuneTap(_ entity: Entity) {
        if isWaitingForClosingTap {
            closePortalAfterFinalTap()
            return
        }

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
                await PortalExperience.moveCorrectRuneToPortalCenter(
                    for: selectedRockName,
                    in: portalScene
                )

                selectedIndex += 1
                if selectedIndex < currentSequence.count {
                    isAcceptingRuneInput = true
                } else {
                    isWaitingForClosingTap = true
                    PortalExperience.setClosingHitTargetEnabled(true, in: portalScene)
                }
            } else {
                try? await Task.sleep(nanoseconds: 500_000_000)
                startCurrentRound(in: portalScene)
            }
        }
    }

    @MainActor
    private func closePortalAfterFinalTap() {
        guard !isClosingPortal,
              let portalScene else {
            return
        }

        isClosingPortal = true
        isWaitingForClosingTap = false
        isAcceptingRuneInput = false
        PortalExperience.setClosingHitTargetEnabled(false, in: portalScene)

        Task { @MainActor in
            await PortalExperience.playClosingAnimation(in: portalScene)
            portalScene.removeFromParent()
            self.portalScene = nil

            currentRoundIndex += 1
            guard currentRoundIndex < roundSequenceLengths.count else {
                return
            }

            try? await Task.sleep(nanoseconds: 850_000_000)
            addPortalExperienceIfNeeded()
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
