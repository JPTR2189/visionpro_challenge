import SwiftUI

struct TogglePortalSpaceButton: View {

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow)         private var dismissWindow
    @Environment(\.openImmersiveSpace)    private var openImmersiveSpace

    var body: some View {
        Button {
            Task { @MainActor in
                switch appModel.portalSpaceState {
                case .open:
                    appModel.portalSpaceState = .inTransition
                    await dismissImmersiveSpace()

                case .closed:
                    appModel.portalSpaceState = .inTransition
                    switch await openImmersiveSpace(id: appModel.portalSpaceID) {
                    case .opened:
                        dismissWindow(id: "MainWindow")
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
                appModel.portalSpaceState == .open ? "Close Portal Experience" : "Open Portal Experience",
                systemImage: appModel.portalSpaceState == .open ? "xmark.circle" : "circle.hexagongrid"
            )
        }
        .disabled(appModel.portalSpaceState == .inTransition)
        .fontWeight(.semibold)
    }
}
