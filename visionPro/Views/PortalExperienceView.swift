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
            await collectPlaneUpdates()
        }
        .overlay(alignment: .bottom) {
            mappingOverlay
        }
    }

    // MARK: - Coleta Silenciosa de Anchors

    @MainActor
    private func collectPlaneUpdates() async {
        for await update in arSession.planeUpdates {
            switch update.event {
            case .added, .updated:
                arSession.collectAnchor(update.anchor)
                if arSession.mappingState == .active {
                    replacePlaneEntity(for: update.anchor)
                }
            case .removed:
                arSession.discardAnchor(id: update.anchor.id)
                sceneRoot.findEntity(named: update.anchor.id.uuidString)?.removeFromParent()
            }
        }
    }

    // MARK: - Reveal: instancia tudo de uma vez

    @MainActor
    private func revealEnvironment() {
        arSession.reveal()
        for anchor in arSession.scannedAnchors.values {
            replacePlaneEntity(for: anchor)
        }
    }

    @MainActor
    private func replacePlaneEntity(for anchor: PlaneAnchor) {
        sceneRoot.findEntity(named: anchor.id.uuidString)?.removeFromParent()

        guard let entity = EnvironmentMappingBuilder.makePlaneEntity(
            for: anchor,
            wallOpacity: arSession.wallOpacity,
            floorOpacity: arSession.floorOpacity,
            wallMaterial: arSession.debugMode ? nil : wallMaterial,
            debugMode: arSession.debugMode
        ) else { return }

        sceneRoot.addChild(entity)
    }

    // MARK: - UI de Mapeamento

    @ViewBuilder
    private var mappingOverlay: some View {
        switch arSession.mappingState {
        case .idle:
            EmptyView()
        case .scanning:
            scanningPanel
        case .active:
            if arSession.debugMode {
                debugControls
            }
        }
    }

    private var scanningPanel: some View {
        VStack(spacing: 20) {
            ScanningIndicator()

            VStack(spacing: 6) {
                Text("Scanning Environment")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("\(arSession.detectedSurfaceCount) surfaces detected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.default, value: arSession.detectedSurfaceCount)
            }

            Button {
                revealEnvironment()
            } label: {
                Label("Reveal!", systemImage: "sparkles")
                    .fontWeight(.semibold)
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(arSession.detectedSurfaceCount == 0)

            if arSession.authorizationDenied {
                Text("Permission denied — enable in Settings")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.bottom, 40)
    }

    private var debugControls: some View {
        VStack(spacing: 8) {
            debugLegend

            Toggle("Debug Mode", isOn: Binding(
                get: { arSession.debugMode },
                set: { newValue in
                    arSession.debugMode = newValue
                    sceneRoot.children.forEach { $0.removeFromParent() }
                    for anchor in arSession.scannedAnchors.values {
                        replacePlaneEntity(for: anchor)
                    }
                }
            ))
            .toggleStyle(.button)
            .tint(.orange)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.bottom, 32)
    }

    private var debugLegend: some View {
        HStack(spacing: 10) {
            legendItem(color: .blue,   label: "Wall")
            legendItem(color: .red,    label: "Floor")
            legendItem(color: .green,  label: "Ceiling")
            legendItem(color: .yellow, label: "Table")
            legendItem(color: .orange, label: "Seat")
            legendItem(color: .cyan,   label: "Window")
            legendItem(color: .purple, label: "Door")
            legendItem(color: .white,  label: "Unknown")
        }
        .font(.caption2)
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
        }
    }
}

#Preview(immersionStyle: .mixed) {
    PortalExperienceView()
        .environment(AppModel())
}
