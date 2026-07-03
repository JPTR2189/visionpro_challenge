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

    enum OnboardingState: Equatable {
        case hero
        case tutorial(step: TutorialStep)
        case done
    }

    enum TutorialStep: Int, CaseIterable, Equatable {
        case runeInteraction
        case fireballInteraction
        case scanningExplanation

        var isLast: Bool { self == Self.allCases.last }

        var next: TutorialStep? {
            let nextIndex = rawValue + 1
            guard nextIndex < Self.allCases.count else { return nil }
            return Self.allCases[nextIndex]
        }
    }

    var portalSpaceState: ImmersiveSpaceState = .closed
    var onboardingState: OnboardingState = .hero
}
