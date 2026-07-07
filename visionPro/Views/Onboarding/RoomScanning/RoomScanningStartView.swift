import SwiftUI

struct RoomScanningStartView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

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
                Task { @MainActor in
                    appModel.portalSpaceState = .inTransition
                    switch await openImmersiveSpace(id: appModel.portalSpaceID) {
                    case .opened:
                        appModel.onboardingState = .roomScanning(step: .progress)
                    case .userCancelled, .error:
                        fallthrough
                    @unknown default:
                        appModel.portalSpaceState = .closed
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.right")
                        .fontWeight(.semibold)
                    Text("Start Scanning")
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
    RoomScanningStartView()
        .environment(AppModel())
}
