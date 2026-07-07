import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        if appModel.isGameOver {
            gameOverPanel
        } else if appModel.isRitualComplete {
            ritualCompletePanel
        } else {
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

    private var gameOverPanel: some View {
        ritualResultPanel(
            title: "Ritual Over",
            iconName: "xmark.octagon",
            iconSize: 78,
            message: "The sequence was broken. The stone did not respond.",
            primaryTitle: "Try Again",
            primaryWidth: 133,
            primaryAction: tryAgain
        )
    }

    private var ritualCompletePanel: some View {
        ritualResultPanel(
            title: "Ritual Complete",
            iconName: "wand.and.stars",
            iconSize: 72,
            message: "Every rune answered your call.\nThe stone remembers your name.",
            primaryTitle: "Play Again",
            primaryWidth: 143,
            primaryAction: tryAgain
        )
    }

    private func ritualResultPanel(
        title: String,
        iconName: String,
        iconSize: CGFloat,
        message: String,
        primaryTitle: String,
        primaryWidth: CGFloat,
        primaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 70) {
            Text(title)
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(.white)

            Image(systemName: iconName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 100, height: 100)

            Text(message)
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(width: 446, height: 76)

            HStack(spacing: 60) {
                gameOverButton(
                    title: primaryTitle,
                    width: primaryWidth,
                    isPrimary: true,
                    action: primaryAction
                )

                gameOverButton(
                    title: "Exit Ritual",
                    width: 141,
                    isPrimary: false,
                    action: exitRitual
                )
            }
        }
        .padding(40)
        .frame(width: 526, height: 546)
        .glassBackgroundEffect()
    }

    private func gameOverButton(
        title: String,
        width: CGFloat,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(isPrimary ? .white : .white.opacity(0.92))
                .frame(width: width, height: 52)
                .background {
                    if isPrimary {
                        Capsule()
                            .fill(Color(red: 0.0, green: 0.57, blue: 1.0))
                    } else {
                        Capsule()
                            .fill(.white.opacity(0.16))
                            .background(.thinMaterial, in: Capsule())
                    }
                }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }

    private func tryAgain() {
        appModel.isGameOver = false
        appModel.isRitualComplete = false
        appModel.shouldRevealEnvironment = false
        appModel.onboardingState = .roomScanning(step: .done)
    }

    private func exitRitual() {
        appModel.isGameOver = false
        appModel.isRitualComplete = false
        appModel.onboardingState = .hero
        Task { await dismissImmersiveSpace() }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
