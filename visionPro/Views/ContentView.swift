//
//  ContentView.swift
//  visionPro
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Esfera na Mão")
                .font(.largeTitle)
                .bold()

            Text("Toque no botão abaixo para entrar no modo imersivo. Depois, vire a palma da mão direita para cima para fazer a esfera aparecer.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            ToggleImmersiveSpaceButton()

            // Botão de DEBUB
            Button("🧪 Forçar esfera aparecer (debug)") {
                appModel.debugForceShow.toggle()
            }
            .font(.caption)
        }
        .padding(40)
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
