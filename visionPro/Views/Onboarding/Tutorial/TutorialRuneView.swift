import SwiftUI
import RealityKit
import RealityKitContent

struct TutorialRuneView: View {
    @Environment(AppModel.self) private var appModel

    private let portalWidthRatio: CGFloat = 2.3
    private let portalHeightRatio: CGFloat = 1.8

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            VStack(alignment: .center, spacing: 80) {
                Text("Tutorial")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                
                VStack(alignment: .center, spacing: 24) {
                    Text("Look at each rune and click to activate it,\nfollowing the order shown by the lights.")
                        .font(.largeTitle)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "eye")
                            .font(.extraLargeTitle.bold())
                            .foregroundStyle(.primary.opacity(0.5))

                        Image(systemName: "plus")
                            .font(.extraLargeTitle.bold())
                            .foregroundStyle(.primary.opacity(0.5))

                        Image(systemName: "hand.pinch")
                            .font(.extraLargeTitle.bold())
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                }
                Spacer()
            }
            .padding(.top, 48)
        }
        .frame(width: 1300, height: 700)
        .overlay(alignment: .bottom) {
            PortalPlaceholderView()
                .containerRelativeFrame([.horizontal, .vertical]) { length, axis in
                    axis == .horizontal ? length * portalWidthRatio : length * portalHeightRatio
                }
                .offset(y: 930)
                .offset(z: -150)
                .rotation3DEffect(.degrees(-15), axis: (x:1, y:0, z:0), anchor: .bottom)
                .allowsHitTesting(false)
                
        }
        .overlay(alignment: .topTrailing) {
            Button {
                appModel.onboardingState = .roomScanning(step: .start)
            } label: {
                Text("Skip")
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(40)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                appModel.onboardingState = .tutorial(step: .fireballInteraction)
            } label: {
                Text("Next")
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(40)
        }
        .glassBackgroundEffect()
    }
}

#Preview(windowStyle: .automatic) {
    TutorialRuneView()
        .environment(AppModel())
}
