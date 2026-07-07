import SwiftUI

struct ToggleDebugButton: View {

    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        Button {
            Task { @MainActor in
                switch appModel.portalSpaceState {
                case .open:
                    appModel.debugForceShow.toggle()

                case .closed:
                  
                    appModel.portalSpaceState = .inTransition
                    switch await openImmersiveSpace(id: appModel.portalSpaceID) {
                    case .opened:
                        appModel.debugForceShow = true
                    case .userCancelled, .error:
                        fallthrough
                    @unknown default:
                        appModel.portalSpaceState = .closed
                    }

                case .inTransition:
                    break
                }
            }
        } label: {
            Label(
                appModel.debugForceShow ? "Disable debug mode" : "Enable debug mode",
                systemImage: appModel.debugForceShow ? "xmark.circle" : "ladybug"
            )
        }
        .disabled(appModel.portalSpaceState == .inTransition)
        .fontWeight(.semibold)
    }
}
