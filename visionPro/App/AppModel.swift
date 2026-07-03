import SwiftUI

@MainActor
@Observable
final class AppModel {
    let portalSpaceID = "PortalExperienceSpace"
    let immersiveSpaceID = "ImmersiveSpace"


    enum ImmersiveSpaceState {
        case closed, inTransition, open
    }

    var portalSpaceState: ImmersiveSpaceState = .closed
    var immersiveSpaceState = ImmersiveSpaceState.closed

    var isPlaying: Bool {
        immersiveSpaceState == .open
    }

    // 🧪 Temporário, só para testar a animação da esfera sem depender da mão.
    // Remover esta propriedade quando o app estiver validado por completo.
    var debugForceShow = false
}
