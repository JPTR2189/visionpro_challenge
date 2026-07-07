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
        case roomScanning(step: RoomScanningStep)
    }

    enum RoomScanningStep: Int, CaseIterable, Equatable {
        case start
        case progress
        case done
    }

    enum TutorialStep: Int, CaseIterable, Equatable {
        case runeInteraction
        case fireballInteraction
        case scanningExplanation

        var isFirst: Bool { self == Self.allCases.first }
        var isLast: Bool { self == Self.allCases.last }

        var previous: TutorialStep? {
            let previousIndex = rawValue - 1
            guard previousIndex >= 0 else { return nil }
            return Self.allCases[previousIndex]
        }

        var next: TutorialStep? {
            let nextIndex = rawValue + 1
            guard nextIndex < Self.allCases.count else { return nil }
            return Self.allCases[nextIndex]
        }
    }

    var portalSpaceState: ImmersiveSpaceState = .closed
    var onboardingState: OnboardingState = .hero
    var isGameOver = false
    var isRitualComplete = false

    let arSession = ARKitSessionManager()
    var shouldRevealEnvironment = false
    var shouldOpenMainWindowOnImmersiveDisappear = true
}
