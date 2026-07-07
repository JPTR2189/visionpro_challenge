import SwiftUI
import RealityKit

struct TutorialScanningView: View {
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            VStack(alignment: .center, spacing: 80) {
                Text("Tutorial")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                
                VStack(alignment: .center, spacing: 24) {
                    Text("Take a moment to look around. Mapping your space\nunlocks a more immersive experience.")
                        .font(.largeTitle)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "person.and.arrow.left.and.arrow.right")
                            .font(.extraLargeTitle.bold())
                            .foregroundStyle(.primary.opacity(0.5))
                        
                        Image(systemName: "plus")
                            .font(.extraLargeTitle.bold())
                            .foregroundStyle(.primary.opacity(0.5))
                        
                        Image(systemName: "move.3d")
                            .font(.extraLargeTitle.bold())
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                }
            }
            .padding(.top, 40)
            
            Image(uiImage: .tutorialScanning)
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
                appModel.onboardingState = .roomScanning(step: .start)
            } label: {
                Text("Finish")
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
                appModel.onboardingState = .tutorial(step: .fireballInteraction)
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
        .glassBackgroundEffect()
    }
}
