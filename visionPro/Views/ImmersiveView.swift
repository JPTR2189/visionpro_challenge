//
//  ImmersiveView.swift
//  visionPro
//
//  Created by Jean Pierre on 23/06/26.
//

import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var portalScene: Entity?
    @State private var currentSequence: [String] = []
    @State private var selectedIndex = 0
    @State private var isAcceptingRuneInput = false

    var body: some View {
        RealityView { content in
            let scene = PortalExperience.makeScene()
            portalScene = scene
            content.add(scene)
            PortalExperience.startFloatingStoneMotion(in: scene)
            startNewRound(in: scene)
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleRuneTap(value.entity)
                }
        )
        .onDisappear {
            openWindow(id: "MainWindow")
        }
    }

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
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView().environment(AppModel())
}
