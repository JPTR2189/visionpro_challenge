import SwiftUI

struct MainMenuView: View {
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
    }
}

#Preview(windowStyle: .automatic) {
    MainMenuView()
        .environment(AppModel())
}
