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

            Button("🧪 Forçar esfera aparecer (debug)") {
                appModel.debugForceShow.toggle()
            }
            .font(.caption)
        }
        .frame(width: 380)
        .padding(32)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
