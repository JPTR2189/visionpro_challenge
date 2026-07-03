import SwiftUI

@MainActor
@Observable
final class AppModel {
    let portalSpaceID = "PortalExperienceSpace"

    enum ImmersiveSpaceState {
        case closed, inTransition, open
    }

    var portalSpaceState: ImmersiveSpaceState = .closed

    var isPlaying: Bool {
        portalSpaceState == .open
    }

    
    var debugForceShow = false
}
