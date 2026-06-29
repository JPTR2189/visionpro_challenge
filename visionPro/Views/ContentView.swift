import SwiftUI

struct ContentView: View {

    var body: some View {
        VStack(spacing: 18) {
            Text("Runic Portals")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Divider()

            Text("Portal Experience")
                .font(.headline)
                .foregroundStyle(.secondary)

            TogglePortalSpaceButton()

            Divider()

            Text("Kayak Demo")
                .font(.headline)
                .foregroundStyle(.secondary)

            ToggleImmersiveSpaceButton()
        }
        .frame(width: 420)
        .padding(32)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
