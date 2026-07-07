import SwiftUI

struct RoomScanningProgressView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("Scanning Your Room")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("Move your head slowly to scan the\nenvironment")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }

            Button {
                if appModel.arSession.canFinishScanning {
                    appModel.arSession.finishScanning()
                } else {
                    appModel.arSession.finishScanningManually()
                }
                appModel.onboardingState = .roomScanning(step: .done)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .fontWeight(.bold)
                    Text("Finish Scanning")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Color(red: 0.0, green: 0.55, blue: 1.0), in: Capsule())
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
        }
        .padding(40)
        .frame(width: 440)
        .glassBackgroundEffect()
    }
}

#Preview {
    RoomScanningProgressView()
        .environment(AppModel())
}
