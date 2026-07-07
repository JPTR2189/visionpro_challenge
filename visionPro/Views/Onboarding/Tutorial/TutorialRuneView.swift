import SwiftUI
import RealityKit

struct TutorialRuneView: View {
    @Environment(AppModel.self) private var appModel

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

                        Image(systemName: "hand.tap")
                            .font(.extraLargeTitle.bold())
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                }
            }
            .padding(.top, 40)

            Image(uiImage: .tutorialRunes)
        }
        .frame(width: 1300, height: 700)
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
