import SwiftUI

struct RoomScanningDoneView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("Scanned Room")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("Everything is ready to start the\nexperience.")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }

            Button {
                appModel.shouldRevealEnvironment = true
                dismissWindow(id: "MainWindow")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "visionpro")
                        .fontWeight(.semibold)
                    Text("Start Now")
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
    RoomScanningDoneView()
        .environment(AppModel())
}
