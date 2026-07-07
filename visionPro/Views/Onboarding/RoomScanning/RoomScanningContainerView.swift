import SwiftUI

struct RoomScanningContainerView: View {
    @Environment(AppModel.self) private var appModel
    let currentStep: AppModel.RoomScanningStep

    var body: some View {
        Group {
            switch currentStep {
            case .start:
                RoomScanningStartView().id("start")
            case .progress:
                RoomScanningProgressView().id("progress")
            case .done:
                RoomScanningDoneView().id("done")
            }
        }
        .transition(.opacity)
    }
}
