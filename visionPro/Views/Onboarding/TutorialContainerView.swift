import SwiftUI

struct TutorialContainerView: View {
    let currentStep: AppModel.TutorialStep

    var body: some View {
        TutorialStepView(step: currentStep)
            .overlay {
                TutorialNavigationBar(step: currentStep)
            }
            .transition(.opacity)
    }
}
