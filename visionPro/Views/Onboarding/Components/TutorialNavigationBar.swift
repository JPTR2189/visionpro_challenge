import SwiftUI

struct TutorialNavigationBar: View {
    @Environment(AppModel.self) private var appModel
    let step: AppModel.TutorialStep

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Skip") { appModel.onboardingState = .done }
                    .buttonStyle(OnboardingPillButtonStyle())
            }

            Spacer()

            HStack {
                Spacer()
                if step.isLast {
                    Button("Finish") { appModel.onboardingState = .done }
                        .buttonStyle(OnboardingPillButtonStyle())
                } else {
                    Button("Next") {
                        if let next = step.next {
                            appModel.onboardingState = .tutorial(step: next)
                        }
                    }
                    .buttonStyle(OnboardingPillButtonStyle())
                }
            }
        }
        .padding(24)
    }
}

struct OnboardingPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
