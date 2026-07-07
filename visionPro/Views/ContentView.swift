import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        switch appModel.onboardingState {
        case .hero:
            HomeView()
        case .tutorial(let step):
            TutorialContainerView(currentStep: step)
        case .roomScanning(let step):
            RoomScanningContainerView(currentStep: step)
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
