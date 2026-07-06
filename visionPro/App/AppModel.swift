//
//  AppModel.swift
//  visionPro
//

import SwiftUI

@MainActor
@Observable
class AppModel {
    let portalSpaceID = "PortalExperienceSpace"

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    var portalSpaceState: ImmersiveSpaceState = .closed
}
