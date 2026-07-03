import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Runic Portals")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Open the portal experience to begin mapping your environment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TogglePortalSpaceButton()
        }
        .frame(width: 380)
        .padding(32)

        // VStack(spacing: 20) {
        //     Text("Esfera na Mão")
        //         .font(.largeTitle)
        //         .bold()

        //     Text("Toque no botão abaixo para entrar no modo imersivo. Depois, vire a palma da mão direita para cima para fazer a esfera aparecer.")
        //         .font(.body)
        //         .foregroundStyle(.secondary)
        //         .multilineTextAlignment(.center)
        //         .frame(maxWidth: 420)

        //     ToggleImmersiveSpaceButton()

        //     // Botão de DEBUG
        //     Button("🧪 Forçar esfera aparecer (debug)") {
        //         appModel.debugForceShow.toggle()
        //     }
        //     .font(.caption)
        // }
        // .padding(40)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
