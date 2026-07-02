import SwiftUI
import RealityKit
import ARKit

struct PortalExperienceView: View {

    @State private var arSession  = ARKitSessionManager()
    @State private var sceneRoot  = Entity()
    @State private var wallMaterial: (any RealityKit.Material)?
    @State private var floorMaterial: (any RealityKit.Material)?
    @State private var scanningMaterial: (any RealityKit.Material)?
    @State private var meshEntities = [UUID: Entity]()
    @State private var wallEntities = [UUID: Entity]()
    @State private var portalTemplate: Entity?

    var body: some View {
        RealityView { content, attachments in
            content.add(sceneRoot)
            if let uiEntity = attachments.entity(for: "MappingUI") {
                // Ancorado ao content (espaço imersivo) e não ao sceneRoot
                // para que apareça à frente do usuário no momento de entrada
                uiEntity.position = [0, 1.6, -1.0]
                content.add(uiEntity)
            }
        } attachments: {
            Attachment(id: "MappingUI") {
                mappingOverlay
            }
        }
        .task { scanningMaterial = TextureMaterialLoader.createScanningMaterial() }
        .task { wallMaterial = await TextureMaterialLoader.loadWallMaterial() }
        .task { floorMaterial = await TextureMaterialLoader.loadFloorMaterial() }
        .task { await arSession.run() }
        .task { await processRoomUpdates() }
        .task { await processMeshUpdates() }
        .task { await processWallUpdates() }
        .task { await preparePortalTemplate() }
        .onDisappear {
            arSession.stop()
        }
    }

    // MARK: - Room Tracking: aguarda cômodo completo

    @MainActor
    private func processRoomUpdates() async {
        for await update in arSession.roomAnchorUpdates {
            arSession.updateCurrentRoom(update.anchor)
        }
    }

    // MARK: - Mesh Tracking: coleta silenciosa + instância após reveal

    @MainActor
    private func processMeshUpdates() async {
        for await update in arSession.meshAnchorUpdates {
            switch update.event {
            case .added, .updated:
                arSession.updateMeshAnchor(update.anchor)
                // Só (re)cria a entidade se ainda não aplicamos as texturas finais,
                // evitando sobrescrever o material definitivo com o de escaneamento.
                if arSession.mappingState != .active {
                    refreshMeshEntity(for: update.anchor)
                }
            case .removed:
                arSession.removeMeshAnchor(id: update.anchor.id)
                meshEntities[update.anchor.id]?.removeFromParent()
                meshEntities.removeValue(forKey: update.anchor.id)
            }
        }
    }

    // MARK: - Plane Tracking: cria superficies ECS apenas para paredes

    @MainActor
    private func processWallUpdates() async {
        for await update in arSession.wallAnchorUpdates {
            switch update.event {
            case .added, .updated:
                refreshWallEntity(for: update.anchor)

            case .removed:
                removeWallEntity(id: update.anchor.id)
            }
        }
    }

    @MainActor
    private func refreshWallEntity(for anchor: PlaneAnchor) {
        switch anchor.surfaceClassification {
        case .wall:
            break

        case .none:
            // Durante o refinamento a classificacao pode ficar temporariamente
            // indisponivel. Mantem uma parede que ja foi reconhecida.
            return

        default:
            removeWallEntity(id: anchor.id)
            return
        }

        let wallEntity: Entity

        if let existingEntity = wallEntities[anchor.id] {
            wallEntity = existingEntity
        } else {
            wallEntity = Entity()
            wallEntity.name = "MappedWall-\(anchor.id)"
            wallEntities[anchor.id] = wallEntity
            sceneRoot.addChild(wallEntity)
        }

        let extent = anchor.geometry.extent
        let worldFromExtent = anchor.originFromAnchorTransform
            * extent.anchorFromExtentTransform

        wallEntity.setTransformMatrix(worldFromExtent, relativeTo: nil)
        wallEntity.components.set(
            WallSurfaceComponent(
                width: extent.width,
                height: extent.height
            )
        )
    }

    @MainActor
    private func removeWallEntity(id: UUID) {
        wallEntities[id]?.removeFromParent()
        wallEntities[id] = nil
    }

    // MARK: - Portal Spawner

    @MainActor
    private func preparePortalTemplate() async {
        portalTemplate = await PortalTemplateFactory.makeTemplate(
            targetHeight: nil,
            attachingTo: sceneRoot
        )

        if arSession.mappingState == .active {
            await enablePortalSpawning()
        }
    }

    @MainActor
    private func enablePortalSpawning() async {
        guard let portalTemplate else { return }

        var referenceTransform: simd_float4x4?

        for _ in 0..<30 {
            if let transform = arSession.currentDeviceTransform() {
                referenceTransform = transform
                break
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        guard let referenceTransform else {
            print("❌ Nao foi possivel obter a pose do Vision Pro para iniciar os portais.")
            return
        }

        var spawner = PortalSpawnerComponent()
        spawner.portalTemplate = portalTemplate
        spawner.referenceTransform = referenceTransform
        spawner.lastSpawnTime = 0

        let bounds = portalTemplate.visualBounds(relativeTo: nil)
        if bounds.extents.x > 0.001, bounds.extents.y > 0.001 {
            spawner.portalSize = SIMD2<Float>(
                bounds.extents.x,
                bounds.extents.y
            )
        }

        sceneRoot.components.set(spawner)
    }

    // MARK: - Reveal: instância todos os anchors coletados de uma vez

    @MainActor
    private func revealEnvironment() {
        arSession.reveal()

        for anchor in arSession.scannedMeshAnchors.values {
            refreshMeshEntity(for: anchor)
        }

        Task {
            await enablePortalSpawning()
        }
    }

    @MainActor
    private func refreshMeshEntity(for anchor: MeshAnchor) {
        meshEntities[anchor.id]?.removeFromParent()

        let isFinal = (arSession.mappingState == .active)
        let wMat = isFinal ? wallMaterial : scanningMaterial
        let fMat = isFinal ? floorMaterial : scanningMaterial

        guard let entity = EnvironmentMappingBuilder.makeRoomEntity(
            from: anchor,
            wallMaterial: wMat,
            floorMaterial: fMat,
            floorOpacity: arSession.floorOpacity
        ) else { return }

        sceneRoot.addChild(entity)
        meshEntities[anchor.id] = entity
    }

    // MARK: - UI

    @ViewBuilder
    private var mappingOverlay: some View {
        switch arSession.mappingState {
        case .idle:
            EmptyView()
        case .scanning:
            scanningPanel
        case .ready:
            readyPanel
        case .active:
            EmptyView()
        }
    }

    private var scanningPanel: some View {
        VStack(spacing: 20) {
            ScanningIndicator()

            VStack(spacing: 6) {
                Text("Scanning your room...")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Move your head slowly to scan walls and floor")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if arSession.canFinishScanning {
                Button("Finish Scanning") {
                    arSession.finishScanning()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else if arSession.authorizationDenied {
                Text("Permission denied — enable in Settings")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: 320)
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.bottom, 40)
    }

    private var readyPanel: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating)

            VStack(spacing: 6) {
                Text("Room mapped!")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Your environment is ready. Apply textures when you're set.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                revealEnvironment()
            } label: {
                Label("Apply Textures", systemImage: "sparkles")
                    .fontWeight(.semibold)
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .frame(maxWidth: 320)
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.bottom, 40)
    }
}

#Preview(immersionStyle: .mixed) {
    PortalExperienceView()
        .environment(AppModel())
}
