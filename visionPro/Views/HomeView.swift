import RealityKit
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 80) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Portal Runes")
                        .font(.extraLargeTitle.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("A portal opens before you, carved in ancient stone.\nExplore runes at true scale, trace every mark, and\nuncover the secrets etched into the rock.")
                    .font(.body)
                    .foregroundStyle(.primary)
                }

                Button {
                    appModel.onboardingState = .tutorial(step: .runeInteraction)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        
                        Text("Start immersion")
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.thinMaterial, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(80)
            .opacity(appeared ? 1 : 0)

        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.35)) { appeared = true }
        }
        .frame(width: 1200, height: 660, alignment: .bottomLeading)
        .glassBackgroundEffect()
        .overlay(alignment: .trailing) {
            PortalPlaceholderView()
                .frame(width: 760, height: 760)
                .offset(x: 76)
//                .offset(y: -28)
                .allowsHitTesting(false)
        }
        .frame(width: 1300, height: 700, alignment: .leading)
    }
}

#Preview(windowStyle: .automatic) {
    HomeView()
        .environment(AppModel())
}
