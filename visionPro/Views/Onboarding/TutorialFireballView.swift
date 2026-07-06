import SwiftUI
import RealityKit

struct TutorialFireballView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            VStack(alignment: .center, spacing: 80) {
                Text("Tutorial")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                
                VStack(alignment: .center, spacing: 24) {
                    Text("Extend your arm until your hand comes into view.\nOpen your palm, turn it upward, and watch the\nfireball come to life.")
                        .font(.largeTitle)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "hand.point.up.left")
                            .font(.extraLargeTitle.bold())
                            .foregroundStyle(.primary.opacity(0.5))

                        Image(systemName: "plus")
                            .font(.extraLargeTitle.bold())
                            .foregroundStyle(.primary.opacity(0.5))

                        Image(systemName: "hand.raised")
                            .font(.extraLargeTitle.bold())
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                }
            }
            .padding(.top, 40)

            Image(uiImage: .tutorialFireball)
        }
        .frame(width: 1300, height: 700)
        .overlay(alignment: .topTrailing) {
            Button {
                appModel.onboardingState = .done
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
                appModel.onboardingState = .tutorial(step: .scanningExplanation)
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
        .overlay(alignment: .bottomLeading) {
            Button {
                appModel.onboardingState = .tutorial(step: .runeInteraction)
            } label: {
                Text("Back")
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(40)
        }
    }
}
