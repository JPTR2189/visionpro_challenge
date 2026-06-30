//
//  AppModel.swift
//  visionPro
//
//  Created by Jean Pierre on 23/06/26.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
final class AppModel {
    let immersiveSpaceID = "PortalImmersiveSpace"

    enum ImmersiveSpaceState {
        case closed, inTransition, open
    }
    var immersiveSpaceState: ImmersiveSpaceState = .closed
}

