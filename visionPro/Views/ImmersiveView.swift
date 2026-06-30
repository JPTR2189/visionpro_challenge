//
//  ImmersiveView.swift
//  visionPro
//
//  Created by Jean Pierre on 23/06/26.
//

import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @State private var sceneRoot: Entity?
    @State private var selectedRuneIDs: [String] = []
    @State private var lastSelectionTime: Date = .distantPast

    var body: some View {
        RealityView { content in
            let root = PortalExperience.makeScene(selectedRuneIDs: selectedRuneIDs)
            sceneRoot = root
            content.add(root)
        } update: { _ in
            guard let sceneRoot else { return }
            PortalExperience.updateProgress(in: sceneRoot, selectedRuneIDs: selectedRuneIDs)
        }
        .gesture(
            TapGesture()
                .targetedToEntity(where: .has(PortalRuneComponent.self))
                .onEnded { value in
                    handleSelection(from: value.entity)
                }
        )
    }

    private func handleSelection(from entity: Entity) {
        guard Date().timeIntervalSince(lastSelectionTime) > 0.35,
              let runeEntity = entity.runeEntity,
              let rune = runeEntity.components[PortalRuneComponent.self],
              let sceneRoot else {
            return
        }

        lastSelectionTime = Date()

        PortalExperience.resetTransientRuneStates(in: sceneRoot, selectedRuneIDs: selectedRuneIDs)
        selectedRuneIDs.append(rune.id)
        PortalExperience.setRuneState(in: sceneRoot, runeID: rune.id, state: .selected)
        PortalExperience.updateProgress(in: sceneRoot, selectedRuneIDs: selectedRuneIDs)
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
