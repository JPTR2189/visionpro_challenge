import SwiftUI
import RealityKit

struct TutorialStepView: View {
    let step: AppModel.TutorialStep

    var body: some View {
        ZStack {
            Color(white: 0.14)
                .ignoresSafeArea()

            stepPlaceholder

            VStack(spacing: 0) {
                Text("Tutorial")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.top, 36)

                Spacer()

                VStack(spacing: 18) {
                    Text(step.instruction)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)

                    HStack(spacing: 14) {
                        Image(systemName: step.leadingIcon)
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.55))

                        Text("+")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.55))

                        Image(systemName: step.trailingIcon)
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.bottom, 72)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var stepPlaceholder: some View {
        switch step {
        case .runeInteraction:       RunePlaceholderView()
        case .fireballInteraction:   FireballPlaceholderView()
        case .scanningExplanation:   ScanningPlaceholderView()
        }
    }
}

private extension AppModel.TutorialStep {
    var instruction: String {
        switch self {
        case .runeInteraction:
            return "Look at each rune and click to activate it,\nfollowing the order shown by the lights."
        case .fireballInteraction:
            return "Extend your arm until your hand comes into view.\nOpen your palm, turn it upward, and watch the\nfireball come to life."
        case .scanningExplanation:
            return "Take a moment to look around. Mapping your space\nunlocks a more immersive experience."
        }
    }

    var leadingIcon: String {
        switch self {
        case .runeInteraction:       return "eye"
        case .fireballInteraction:   return "hand.point.up.left"
        case .scanningExplanation:   return "person.and.arrow.left.and.arrow.right"
        }
    }

    var trailingIcon: String {
        switch self {
        case .runeInteraction:       return "hand.tap"
        case .fireballInteraction:   return "hand.raised"
        case .scanningExplanation:   return "move.3d"
        }
    }
}
