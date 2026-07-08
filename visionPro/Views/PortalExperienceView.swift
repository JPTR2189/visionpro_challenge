import SwiftUI
import RealityKit
import ARKit
import RealityKitContent

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
    @State private var windAudioController: AudioPlaybackController?
    @State private var handModel = HandTrackingModel()
    @State private var rightFireballEntity: Entity?
    @State private var leftFireballEntity: Entity?
    @State private var rightFireballAudioEntity: Entity?
    @State private var leftFireballAudioEntity: Entity?
    @State private var rightFireballAudioController: AudioPlaybackController?
    @State private var leftFireballAudioController: AudioPlaybackController?
    @State private var rightFireballVisibilityTask: Task<Void, Never>?
    @State private var leftFireballVisibilityTask: Task<Void, Never>?
    @State private var fireballLoopResource: AudioFileResource?
    @State private var fireballSpawnResource: AudioFileResource?

    private let roundSequenceLengths = [4, 6, 8]
    private let fireballTargetScale: Float = 0.05
    private let fireballHiddenScale: Float = 0.001
    private let fireballPalmOffset = SIMD3<Float>(0, 0.1, 0)
    private let fireballAnimationDuration: UInt64 = 350_000_000
    private let fireballProjectileSpeed: Float = 2.5
    private let fireballPortalImpactPadding: UInt64 = 120_000_000

    var body: some View {
        RealityView { content in
            content.add(sceneRoot)
            await loadFireballContent(into: content)
        }
        .task { scanningMaterial = TextureMaterialLoader.createScanningMaterial() }
        .task { wallMaterial = await TextureMaterialLoader.loadWallMaterial() }
        .task { floorMaterial = await TextureMaterialLoader.loadFloorMaterial() }
        .task { await appModel.arSession.run() }
        .task { await processRoomUpdates() }
        .task { await processMeshUpdates() }
        .task { await configureFireballTracking() }
        .task { await handModel.start() }
        .onChange(of: appModel.shouldRevealEnvironment) { _, shouldReveal in
            if shouldReveal {
                revealEnvironment()
            }
        }
        .onChange(of: handModel.rightSphereShouldAppear) { _, shouldAppear in
            updateFireballVisibility(
                rightFireballEntity,
                audioEntity: rightFireballAudioEntity,
                audioController: &rightFireballAudioController,
                visibilityTask: &rightFireballVisibilityTask,
                show: shouldAppear && isWaitingForClosingTap,
                translation: fireballPalmOffset
            )
        }
        .onChange(of: handModel.leftSphereShouldAppear) { _, shouldAppear in
            updateFireballVisibility(
                leftFireballEntity,
                audioEntity: leftFireballAudioEntity,
                audioController: &leftFireballAudioController,
                visibilityTask: &leftFireballVisibilityTask,
                show: shouldAppear && isWaitingForClosingTap,
                translation: fireballPalmOffset
            )
        }
        .onChange(of: handModel.rightThrowTriggered) { _, triggered in
            guard triggered else { return }
            throwFireball(
                from: rightFireballEntity,
                at: handModel.rightPalmWorldPosition,
                direction: handModel.rightThrowDirection
            )
            handModel.resetThrowTrigger(isRight: true)
        }
        .onChange(of: handModel.leftThrowTriggered) { _, triggered in
            guard triggered else { return }
            throwFireball(
                from: leftFireballEntity,
                at: handModel.leftPalmWorldPosition,
                direction: handModel.leftThrowDirection
            )
            handModel.resetThrowTrigger(isRight: false)
        }
        .onDisappear {
            windAudioController?.stop()
            rightFireballAudioController?.stop()
            leftFireballAudioController?.stop()
            rightFireballVisibilityTask?.cancel()
            leftFireballVisibilityTask?.cancel()
            AudioManager.shared.playClosePortal()
            if appModel.shouldOpenMainWindowOnImmersiveDisappear {
                openWindow(id: "MainWindow")
            } else {
                appModel.shouldOpenMainWindowOnImmersiveDisappear = true
            }
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
    private func loadFireballContent(into content: RealityViewContent) async {
        await loadFireballAudioResources()
        await addFireballAnchor(
            to: content,
            chirality: .right,
            angularSpeed: RotationComponent.clockwise,
            fireballEntity: $rightFireballEntity,
            audioEntity: $rightFireballAudioEntity
        )
        await addFireballAnchor(
            to: content,
            chirality: .left,
            angularSpeed: RotationComponent.counterClockwise,
            fireballEntity: $leftFireballEntity,
            audioEntity: $leftFireballAudioEntity
        )
    }

    @MainActor
    private func loadFireballAudioResources() async {
        if fireballLoopResource == nil {
            fireballLoopResource = try? await AudioFileResource(
                named: "/Root/Sphere/FireSpatialAudio/fire_sound",
                from: "FireBall.usda",
                in: realityKitContentBundle
            )
        }

        if fireballSpawnResource == nil {
            fireballSpawnResource = try? await AudioFileResource(
                named: "/Root/Sphere/FireSpawnSpatialAudio/spawn_fire",
                from: "FireBall.usda",
                in: realityKitContentBundle
            )
        }
    }

    @MainActor
    private func addFireballAnchor(
        to content: RealityViewContent,
        chirality: AnchoringComponent.Target.Chirality,
        angularSpeed: Float,
        fireballEntity: Binding<Entity?>,
        audioEntity: Binding<Entity?>
    ) async {
        guard fireballEntity.wrappedValue == nil,
              let fireball = try? await Entity(named: "FireBall", in: realityKitContentBundle) else {
            return
        }

        let anchor = AnchorEntity(.hand(chirality, location: .palm))
        fireball.scale = SIMD3<Float>(repeating: fireballHiddenScale)
        fireball.position = fireballPalmOffset
        fireball.components.set(RotationComponent(angularSpeed: angularSpeed))
        fireball.isEnabled = false

        anchor.addChild(fireball)
        content.add(anchor)

        fireballEntity.wrappedValue = fireball
        audioEntity.wrappedValue = fireball.findEntity(named: "Sphere")
    }

    @MainActor
    private func configureFireballTracking() async {
        _ = await HeadTracker.shared.start()
        handModel.deviceForwardProvider = {
            guard let transform = HeadTracker.shared.currentHeadTransform() else { return nil }
            let forward = -SIMD3<Float>(
                transform.columns.2.x,
                transform.columns.2.y,
                transform.columns.2.z
            )
            let horizontal = SIMD3<Float>(forward.x, 0, forward.z)
            guard length(horizontal) > 0.001 else { return nil }
            return normalize(horizontal)
        }
    }

    @MainActor
    private func updateFireballVisibility(
        _ entity: Entity?,
        audioEntity: Entity?,
        audioController: inout AudioPlaybackController?,
        visibilityTask: inout Task<Void, Never>?,
        show: Bool,
        translation: SIMD3<Float>
    ) {
        visibilityTask?.cancel()

        if show {
            entity?.isEnabled = true
            animateFireball(entity, show: true, translation: translation)

            if let audioEntity, let fireballSpawnResource {
                audioEntity.playAudio(fireballSpawnResource)
            }

            var fireController: AudioPlaybackController?
            if let audioEntity, let fireballLoopResource {
                fireController = audioEntity.prepareAudio(fireballLoopResource)
            }
            audioController = fireController

            visibilityTask = Task { [fireController] in
                try? await Task.sleep(nanoseconds: fireballAnimationDuration)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    setFireballRotation(on: entity, active: true)
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000 - fireballAnimationDuration)
                guard !Task.isCancelled else { return }
                fireController?.play()
            }
        } else {
            setFireballRotation(on: entity, active: false)
            audioController?.stop()
            audioController = nil
            animateFireball(entity, show: false, translation: translation)

            visibilityTask = Task {
                try? await Task.sleep(nanoseconds: fireballAnimationDuration)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    entity?.isEnabled = false
                }
            }
        }
    }

    @MainActor
    private func animateFireball(_ entity: Entity?, show: Bool, translation: SIMD3<Float>) {
        guard let entity else { return }
        let scale = show ? fireballTargetScale : fireballHiddenScale
        entity.move(
            to: Transform(
                scale: SIMD3<Float>(repeating: scale),
                rotation: entity.transform.rotation,
                translation: translation
            ),
            relativeTo: entity.parent,
            duration: 0.3,
            timingFunction: .easeInOut
        )
    }

    @MainActor
    private func setFireballRotation(on entity: Entity?, active: Bool) {
        guard let entity,
              var component = entity.components[RotationComponent.self] else {
            return
        }

        component.isActive = active
        entity.components.set(component)
    }

    @MainActor
    private func throwFireball(
        from handEntity: Entity?,
        at palmWorldPosition: SIMD3<Float>,
        direction: SIMD3<Float>
    ) {
        guard isWaitingForClosingTap,
              let handEntity,
              length(direction) > 0.001,
              length(palmWorldPosition) > 0.001 else {
            return
        }

        let fallbackDirection = normalize(direction)
        let preliminarySpawnPosition = palmWorldPosition + fireballPalmOffset + fallbackDirection * 0.12
        let targetPosition = portalFireballTargetPosition()
        let launchDirection: SIMD3<Float>

        if let targetPosition {
            let targetDirection = targetPosition - preliminarySpawnPosition
            launchDirection = length(targetDirection) > 0.001
                ? normalize(targetDirection)
                : fallbackDirection
        } else {
            launchDirection = fallbackDirection
        }

        let spawnPosition = palmWorldPosition + fireballPalmOffset + launchDirection * 0.12
        let projectile = handEntity.clone(recursive: true)

        projectile.components.remove(RotationComponent.self)
        projectile.components.set(
            ProjectileComponent(
                direction: launchDirection,
                speed: fireballProjectileSpeed
            )
        )
        projectile.position = spawnPosition
        projectile.scale = SIMD3<Float>(repeating: fireballTargetScale)
        projectile.isEnabled = true

        sceneRoot.addChild(projectile)

        if let audioEntity = projectile.findEntity(named: "Sphere"),
           let fireballLoopResource {
            audioEntity.playAudio(fireballLoopResource)
        }

        rightFireballAudioController?.stop()
        leftFireballAudioController?.stop()
        updateFireballVisibility(
            rightFireballEntity,
            audioEntity: rightFireballAudioEntity,
            audioController: &rightFireballAudioController,
            visibilityTask: &rightFireballVisibilityTask,
            show: false,
            translation: fireballPalmOffset
        )
        updateFireballVisibility(
            leftFireballEntity,
            audioEntity: leftFireballAudioEntity,
            audioController: &leftFireballAudioController,
            visibilityTask: &leftFireballVisibilityTask,
            show: false,
            translation: fireballPalmOffset
        )

        isWaitingForClosingTap = false
        isAcceptingRuneInput = false
        if let portalScene {
            PortalExperience.setClosingHitTargetEnabled(false, in: portalScene)
        }

        Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: fireballImpactDelay(
                    from: spawnPosition,
                    to: targetPosition
                )
            )
            closePortalAfterFinalTap()
        }
    }

    @MainActor
    private func portalFireballTargetPosition() -> SIMD3<Float>? {
        guard let portalScene,
              let portal = portalScene.findEntity(named: "MagicPortal") else {
            return nil
        }

        return portal.visualBounds(relativeTo: nil).center
    }

    private func fireballImpactDelay(
        from spawnPosition: SIMD3<Float>,
        to targetPosition: SIMD3<Float>?
    ) -> UInt64 {
        guard let targetPosition else {
            return 420_000_000
        }

        let distance = max(length(targetPosition - spawnPosition), 0.25)
        let seconds = min(max(distance / fireballProjectileSpeed, 0.25), 0.85)
        return UInt64(seconds * 1_000_000_000) + fireballPortalImpactPadding
    }

    @MainActor
    private func addPortalExperienceIfNeeded() {
        guard portalScene == nil else { return }

        let portal = PortalExperience.makeScene()
        portalScene = portal

        Task { @MainActor in
            if let windController = await playSpatialAudio(named: "Wind.flac", on: portal, loop: true) {
                windAudioController = windController
                windAudioController?.gain = 8.0
                windAudioController?.play()
            }
            if let openController = await playSpatialAudio(named: "Open Portal.wav", on: portal) {
                openController.gain = 10.0
                openController.play()
            }

            sceneRoot.addChild(portal)

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
        
        let soundName = isCorrect ? "Rune Correct.flac" : "Rune Error.wav"

        Task { @MainActor in
            if let runeController = await playSpatialAudio(named: soundName, on: entity) {
                runeController.gain = isCorrect ? 10.0 : -12.0
                runeController.play()
            }

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
                showGameOver()
            }
        }
    }

    @MainActor
    private func showGameOver() {
        isAcceptingRuneInput = false
        isWaitingForClosingTap = false
        isClosingPortal = false
        currentSequence = []
        selectedIndex = 0
        currentRoundIndex = 0
        appModel.isRitualComplete = false

        if let portalScene {
            PortalExperience.resetLights(in: portalScene)
            PortalExperience.setClosingHitTargetEnabled(false, in: portalScene)
            portalScene.removeFromParent()
            self.portalScene = nil
        }

        appModel.isGameOver = true
        openWindow(id: "MainWindow")
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
            AudioManager.shared.playClosePortal()
            windAudioController?.stop()
            
            await PortalExperience.playClosingAnimation(in: portalScene)
            portalScene.removeFromParent()
            self.portalScene = nil

            currentRoundIndex += 1
            guard currentRoundIndex < roundSequenceLengths.count else {
                showRitualComplete()
                return
            }

            try? await Task.sleep(nanoseconds: 850_000_000)
            addPortalExperienceIfNeeded()
        }
    }

    @MainActor
    private func showRitualComplete() {
        isAcceptingRuneInput = false
        isWaitingForClosingTap = false
        isClosingPortal = false
        currentSequence = []
        selectedIndex = 0
        currentRoundIndex = 0

        appModel.isGameOver = false
        appModel.isRitualComplete = true
        openWindow(id: "MainWindow")
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

    private func playSpatialAudio(named name: String, on entity: Entity, loop: Bool = false) async -> AudioPlaybackController? {
        var config = AudioFileResource.Configuration()
        config.shouldLoop = loop
        
        guard let resource = try? await AudioFileResource(named: name, configuration: config) else {
            print("Failed to load audio resource: \(name)")
            return nil
        }
        return entity.prepareAudio(resource)
    }
}

#Preview(immersionStyle: .mixed) {
    PortalExperienceView()
        .environment(AppModel())
}
