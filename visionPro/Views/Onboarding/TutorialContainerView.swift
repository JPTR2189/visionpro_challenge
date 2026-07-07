import SwiftUI

struct TutorialContainerView: View {
    @Environment(AppModel.self) private var appModel
    let currentStep: AppModel.TutorialStep

    var body: some View {
        Group {
            switch currentStep {
            case .runeInteraction:
                TutorialRuneView()
            case .fireballInteraction:
                TutorialFireballView()
            case .scanningExplanation:
                TutorialScanningView()
            }
        }
        .transition(.opacity)
    }
}
