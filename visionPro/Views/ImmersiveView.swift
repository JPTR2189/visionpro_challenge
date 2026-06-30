//
//  ImmersiveView.swift
//  visionPro
//
//  Created by Jean Pierre on 23/06/26.
//

import SwiftUI
import RealityKit

struct ImmersiveView: View {
    private static let sequenceLength = 6

    @Environment(\.openWindow) private var openWindow

    @State private var sceneRoot: Entity?
    @State private var targetRuneIDs = PortalExperience.makeRandomSequence(length: sequenceLength)
    @State private var selectedRuneIDs: [String] = []
    @State private var lastSelectionTime: Date = .distantPast

    private var activeRuneID: String? {
        guard selectedRuneIDs.count < targetRuneIDs.count else { return nil }
        return targetRuneIDs[selectedRuneIDs.count]
    }

    var body: some View {
        RealityView { content in
            let root = PortalExperience.makeScene(
                selectedRuneIDs: selectedRuneIDs,
                activeRuneID: activeRuneID
            )
            sceneRoot = root
            content.add(root)
        } update: { _ in
            guard let sceneRoot else { return }
            PortalExperience.updateProgress(in: sceneRoot, selectedRuneIDs: selectedRuneIDs)
            PortalExperience.updateRuneStates(
                in: sceneRoot,
                selectedRuneIDs: selectedRuneIDs,
                activeRuneID: activeRuneID
            )
        }
        .gesture(
            TapGesture()
                .targetedToEntity(where: .has(PortalRuneComponent.self))
                .onEnded { value in
                    handleSelection(from: value.entity)
                }
        )
        .onDisappear {
            openWindow(id: "MainWindow")
        }
    }

    private func handleSelection(from entity: Entity) {
        guard Date().timeIntervalSince(lastSelectionTime) > 0.35,
              let runeEntity = entity.runeEntity,
              let rune = runeEntity.components[PortalRuneComponent.self],
              let sceneRoot else {
            return
        }

        lastSelectionTime = Date()

        guard rune.id == activeRuneID else {
            PortalExperience.setRuneState(in: sceneRoot, runeID: rune.id, state: .error)
            return
        }

        selectedRuneIDs.append(rune.id)
        PortalExperience.updateProgress(in: sceneRoot, selectedRuneIDs: selectedRuneIDs)
        PortalExperience.updateRuneStates(
            in: sceneRoot,
            selectedRuneIDs: selectedRuneIDs,
            activeRuneID: activeRuneID
        )
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}

private extension Entity {
    var runeEntity: Entity? {
        if components[PortalRuneComponent.self] != nil {
            return self
        }

        return parent?.runeEntity
    }
}
