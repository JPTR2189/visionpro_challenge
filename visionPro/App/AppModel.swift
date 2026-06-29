//
//  AppModel.swift
//  visionPro
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    // 🧪 Temporário, só para testar a animação da esfera sem depender da mão.
    // Remover esta propriedade quando o app estiver validado por completo.
    var debugForceShow = false
}
