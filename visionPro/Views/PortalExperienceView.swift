import SwiftUI
import RealityKit
import ARKit

struct PortalExperienceView: View {

    @State private var arSession  = ARKitSessionManager()
    @State private var sceneRoot  = Entity()
    @State private var wallMaterial: (any RealityKit.Material)?

    var body: some View {
        RealityView { content in
            content.add(sceneRoot)
        }
        .task {
            wallMaterial = await TextureMaterialLoader.loadWallMaterial()
        }
        .task {
            await arSession.run()
        }
        .task {
            await processPlaneUpdates()
        }
        .overlay(alignment: .bottom) {
            if arSession.authorizationDenied {
                authorizationDeniedBanner
            }
        }
    }

    // MARK: - Processamento de Anchors

    @MainActor
    private func processPlaneUpdates() async {
        for await update in arSession.planeUpdates {
            switch update.event {
            case .added, .updated:
                replacePlaneEntity(for: update.anchor)
            case .removed:
                sceneRoot.findEntity(named: update.anchor.id.uuidString)?.removeFromParent()
            }
        }
    }

    @MainActor
    private func replacePlaneEntity(for anchor: PlaneAnchor) {
        sceneRoot.findEntity(named: anchor.id.uuidString)?.removeFromParent()

        guard let entity = EnvironmentMappingBuilder.makePlaneEntity(
            for: anchor,
            wallOpacity: arSession.wallOpacity,
            floorOpacity: arSession.floorOpacity,
            wallMaterial: wallMaterial
        ) else { return }

        sceneRoot.addChild(entity)
    }

    // MARK: - UI de Erro

    private var authorizationDeniedBanner: some View {
        Text("World sensing permission denied. Enable it in Settings to use the portal experience.")
            .font(.caption)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 32)
    }
}

#Preview(immersionStyle: .mixed) {
    PortalExperienceView()
        .environment(AppModel())
}
