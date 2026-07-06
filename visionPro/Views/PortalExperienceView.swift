import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct PortalExperienceView: View {

    //
    @State private var arSession  = ARKitSessionManager()
    @State private var sceneRoot  = Entity()
    @State private var wallMaterial: (any RealityKit.Material)?
    @State private var floorMaterial: (any RealityKit.Material)?
    @State private var scanningMaterial: (any RealityKit.Material)?
    @State private var meshEntities = [UUID: Entity]()
    @State private var wallEntities = [UUID: Entity]()
    @State private var portalTemplate: Entity?

    /// Tracking das mãos
    @State private var handModel = HandTrackingModel()
    
    /// Entidades bola de fogo
    @State private var rightSphereEntity: Entity?
    @State private var leftSphereEntity: Entity?
    
    /// Controlador de áudio
    @State private var rightAudioController: AudioPlaybackController?
    @State private var leftAudioController: AudioPlaybackController?

    /// Tasks pendentes de mostrar/esconder a bola de fogo.
    /// Precisam ser canceladas ao alternar o estado — senão uma Task
    /// atrasada desabilita a entidade depois que ela já reapareceu.
    @State private var rightVisibilityTask: Task<Void, Never>?
    @State private var leftVisibilityTask: Task<Void, Never>?
    
    /// Entidade do áudio das bolas de fogo
    @State private var rightAudioEntity: Entity?
    @State private var leftAudioEntity: Entity?
    
    @State private var sharedAudioResource: AudioFileResource?

    /// Adiciona o handler de colisão das bolas de fogo
    @State private var collisionHandler = CollisionHandler()
    
    /// Aramzena o conteúdo da cena do RealityKit
    @State private var sceneContent: RealityViewContent?

    private let targetScale: Float = 0.05
    private let palmOffset: SIMD3<Float> = [0, 0.1, 0]
    private let animationDuration: UInt64 = 350_000_000

    var body: some View {
        RealityView { content, attachments in
            sceneContent = content
            content.add(sceneRoot)

            /// Observador das colisões
            collisionHandler.subscribe(to: content)

            if let uiEntity = attachments.entity(for: "MappingUI") {
                // Ancorado ao content (não ao sceneRoot) para aparecer
                // à frente do usuário no momento de entrada
                uiEntity.position = [0, 1.6, -1.0]
                content.add(uiEntity)
            }

            /// Áudio compartilhado para as bolas de fogos
            if let resource = try? await AudioFileResource(
                named: "/Root/Sphere/FireSpatialAudio/fireSound",
                from: "FireBall.usda",
                in: realityKitContentBundle
            ) {
                sharedAudioResource = resource
            } else {
                print("⚠️ Não consegui carregar o áudio da FireBall.")
            }

            // ── Bola de fogo: mão DIREITA (rotação horária) ──
            if let rightFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let rightAnchor = AnchorEntity(.hand(.right, location: .palm))
                rightFireBall.scale = [0.001, 0.001, 0.001]
                rightFireBall.position = palmOffset
                rightFireBall.components.set(RotationComponent(angularSpeed: RotationComponent.clockwise))
                rightFireBall.isEnabled = false
                rightAnchor.addChild(rightFireBall)
                content.add(rightAnchor)
                rightSphereEntity = rightFireBall
                rightAudioEntity = rightFireBall.findEntity(named: "Sphere")
            } else {
                print("❌ FireBall (direita) não carregou.")
            }

            // ── Bola de fogo: mão ESQUERDA (rotação anti-horária) ──
            if let leftFireBall = try? await Entity(named: "FireBall", in: realityKitContentBundle) {
                let leftAnchor = AnchorEntity(.hand(.left, location: .palm))
                leftFireBall.scale = [0.001, 0.001, 0.001]
                leftFireBall.position = palmOffset
                leftFireBall.components.set(RotationComponent(angularSpeed: RotationComponent.counterClockwise))
                leftFireBall.isEnabled = false
                leftAnchor.addChild(leftFireBall)
                content.add(leftAnchor)
                leftSphereEntity = leftFireBall
                leftAudioEntity = leftFireBall.findEntity(named: "Sphere")
            } else {
                print("❌ FireBall (esquerda) não carregou.")
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
        .task {
            /// Fornece a direção do olhar (projetada no plano horizontal)
            /// para o model validar se o arremesso é mesmo "para frente"
            handModel.deviceForwardProvider = {
                guard let transform = arSession.currentDeviceTransform() else { return nil }
                let forward = -SIMD3<Float>(
                    transform.columns.2.x,
                    transform.columns.2.y,
                    transform.columns.2.z
                )
                let horizontal = SIMD3<Float>(forward.x, 0, forward.z)
                guard length(horizontal) > 0.001 else { return nil }
                return normalize(horizontal)
            }
            await handModel.start()
        }
        // ── Gestos: bola aparece/some na mão ──
        .onChange(of: handModel.rightSphereShouldAppear) { _, shouldAppear in
            showFireball(rightSphereEntity, audioEntity: rightAudioEntity,
                         audioController: &rightAudioController,
                         visibilityTask: &rightVisibilityTask, show: shouldAppear)
        }
        .onChange(of: handModel.leftSphereShouldAppear) { _, shouldAppear in
            showFireball(leftSphereEntity, audioEntity: leftAudioEntity,
                         audioController: &leftAudioController,
                         visibilityTask: &leftVisibilityTask, show: shouldAppear)
        }
        // ── Gestos: arremesso ──
        .onChange(of: handModel.rightThrowTriggered) { _, triggered in
            guard triggered else { return }
            throwFireball(from: rightSphereEntity,
                          at: handModel.rightPalmWorldPosition,
                          direction: handModel.rightThrowDirection)
            handModel.resetThrowTrigger(isRight: true)
        }
        .onChange(of: handModel.leftThrowTriggered) { _, triggered in
            guard triggered else { return }
            throwFireball(from: leftSphereEntity,
                          at: handModel.leftPalmWorldPosition,
                          direction: handModel.leftThrowDirection)
            handModel.resetThrowTrigger(isRight: false)
        }
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
                    await refreshMeshEntity(for: update.anchor)
                }
            case .removed:
                arSession.removeMeshAnchor(id: update.anchor.id)
                meshEntities[update.anchor.id]?.removeFromParent()
                meshEntities.removeValue(forKey: update.anchor.id)
            }
        }
    }

    // MARK: - Plane Tracking: cria superfícies ECS apenas para paredes

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
            // Durante o refinamento a classificação pode ficar temporariamente
            // indisponível. Mantém uma parede que já foi reconhecida.
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
        guard let portalTemplate else {
            print("❌ enablePortalSpawning abortado: portalTemplate é nil.")
            return
        }

        var referenceTransform: simd_float4x4?

        for _ in 0..<30 {
            if let transform = arSession.currentDeviceTransform() {
                referenceTransform = transform
                break
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        guard let referenceTransform else {
            print("❌ Não foi possível obter a pose do Vision Pro para iniciar os portais.")
            return
        }

        var spawner = PortalSpawnerComponent()
        spawner.portalTemplate = portalTemplate
        spawner.referenceTransform = referenceTransform
        spawner.lastSpawnTime = 0

        
        let bounds = portalTemplate.visualBounds(relativeTo: nil)
        if bounds.extents.x > 0.001, bounds.extents.y > 0.001 {
            let maxPortalWidth: Float = 1.2
            let maxPortalHeight: Float = 1.8
            spawner.portalSize = SIMD2<Float>(
                min(bounds.extents.x, maxPortalWidth),
                min(bounds.extents.y, maxPortalHeight)
            )
            print("📐 portalSize configurado: \(spawner.portalSize) " +
                  "(medido: \(bounds.extents.x)×\(bounds.extents.y))")
        }

        sceneRoot.components.set(spawner)
        print("🌀 Spawner de portais ativado. Aguardando paredes válidas...")
    }

    // MARK: - Reveal: instância todos os anchors coletados de uma vez

    @MainActor
    private func revealEnvironment() {
        arSession.reveal()

        Task {
            for anchor in arSession.scannedMeshAnchors.values {
                await refreshMeshEntity(for: anchor)
            }
            await enablePortalSpawning()
        }
    }

    @MainActor
    private func refreshMeshEntity(for anchor: MeshAnchor) async {
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

        
        if isFinal {
            entity.components.set(EnvironmentMeshComponent())

            if let shape = try? await ShapeResource.generateStaticMesh(from: anchor) {
                entity.components.set(CollisionComponent(
                    shapes: [shape],
                    mode: .trigger   // detecta contato, sem física de empurrão
                ))
            } else {
                print("⚠️ Não consegui gerar forma de colisão para o anchor \(anchor.id).")
            }
        }
    }

    // MARK: - Bola de fogo na mão

    private func showFireball(_ entity: Entity?,
                              audioEntity: Entity?,
                              audioController: inout AudioPlaybackController?,
                              visibilityTask: inout Task<Void, Never>?,
                              show: Bool) {
        visibilityTask?.cancel()

        if show {
            entity?.isEnabled = true
            animate(entity, show: true)

            if let audioEntity, let resource = sharedAudioResource {
                audioController = audioEntity.playAudio(resource)
            }

            visibilityTask = Task {
                try? await Task.sleep(nanoseconds: animationDuration)
                guard !Task.isCancelled else { return }
                setRotation(on: entity, active: true)
            }
        } else {
            setRotation(on: entity, active: false)
            audioController?.stop()
            audioController = nil
            animate(entity, show: false)

            visibilityTask = Task {
                try? await Task.sleep(nanoseconds: animationDuration)
                guard !Task.isCancelled else { return }
                entity?.isEnabled = false
            }
        }
    }

    private func animate(_ entity: Entity?, show: Bool) {
        guard let entity else { return }
        let scale = show ? targetScale : Float(0.001)
        entity.move(
            to: Transform(
                scale: [scale, scale, scale],
                rotation: entity.transform.rotation, // preserva a rotação atual
                translation: palmOffset
            ),
            relativeTo: entity.parent,
            duration: 0.3,
            timingFunction: .easeInOut
        )
    }

    private func setRotation(on entity: Entity?, active: Bool) {
        guard let entity else { return }
        if var component = entity.components[RotationComponent.self] {
            component.isActive = active
            entity.components.set(component)
        }
    }

    // MARK: - Arremesso

    /// Clona a bola no ponto atual da mão e entrega ao ProjectileSystem (movimento + 6s de vida).
    private func throwFireball(from handEntity: Entity?,
                               at palmWorldPosition: SIMD3<Float>,
                               direction: SIMD3<Float>) {
        print("---DEBUG FIREBALL CALLER---")
        print("   direction recebida: x=\(direction.x)  y=\(direction.y)  z=\(direction.z)")
        print("   worldPos da palma:  \(palmWorldPosition)")
        guard let handEntity, let content = sceneContent else { return }

        guard length(direction) > 0.001 else {
            print("⚠️ throwFireball: direção inválida.")
            return
        }

        guard length(palmWorldPosition) > 0.001 else {
            print("⚠️ throwFireball: posição da palma ainda não rastreada.")
            return
        }

        let launchDirection = normalize(direction)
        /// palmOffset: nasce na mesma altura em que a bola flutua na mão
        let spawnPosition = palmWorldPosition + palmOffset + launchDirection * 0.12


        let projectile = handEntity.clone(recursive: true)

        projectile.components.remove(RotationComponent.self)

        projectile.components.set(ProjectileComponent(direction: launchDirection))

        projectile.components.set(
            CollisionComponent(
                shapes: [.generateSphere(radius: 0.05)],
                mode: .trigger
            )
        )

        let worldAnchor = AnchorEntity(world: spawnPosition)
        projectile.position = [0, 0, 0]
        projectile.scale = [targetScale, targetScale, targetScale]
        projectile.isEnabled = true

        worldAnchor.addChild(projectile)
        content.add(worldAnchor)

        if let audioEntity = projectile.findEntity(named: "Sphere"),
           let resource = sharedAudioResource {
            audioEntity.playAudio(resource)
        }
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
