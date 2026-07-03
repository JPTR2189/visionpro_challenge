import SwiftUI
import RealityKit

struct HeroView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(white: 0.26, opacity: 1), Color(white: 0.10, opacity: 1)],
                center: UnitPoint(x: 0.70, y: 0.25),
                startRadius: 40,
                endRadius: 480
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                textPanel
                    .frame(width: 320)

                PortalPlaceholderView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 820, height: 520)
    }

    private var textPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()

            Text("Rune Stone")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)

            Text("A portal opens before you, carved in ancient stone. Explore runes at true scale, trace every mark, and uncover the secrets etched into the rock.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            startButton
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 40)
    }

    private var startButton: some View {
        Button {
            appModel.onboardingState = .tutorial(step: .runeInteraction)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                Text("Start immersion")
                    .font(.callout.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }
}

#Preview(windowStyle: .automatic) {
    HeroView()
        .environment(AppModel())
}
