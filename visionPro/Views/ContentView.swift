import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 24) {
            Text("Portal Spawner Test")
                .font(.largeTitle)

            Toggle("Espaço Imersivo", isOn: Binding(
                get: { appModel.immersiveSpaceState == .open },
                set: { isOn in
                    Task {
                        if isOn {
                            appModel.immersiveSpaceState = .inTransition
                            switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                            case .opened:
                                appModel.immersiveSpaceState = .open
                            default:
                                appModel.immersiveSpaceState = .closed
                            }
                        } else {
                            appModel.immersiveSpaceState = .inTransition
                            await dismissImmersiveSpace()
                            appModel.immersiveSpaceState = .closed
                        }
                    }
                }
            ))
            .toggleStyle(.button)
            .padding()
        }
        .padding()
    }
}
