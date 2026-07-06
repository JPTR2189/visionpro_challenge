import SwiftUI
import RealityKit

struct PortalPlaceholderView: View {
    private var portalURL: URL? {
        Bundle.main.url(
            forResource: "Scene - Portal+Runes - Lights Purple and Red",
            withExtension: "usdz",
            subdirectory: "Resources"
        ) ?? Bundle.main.url(
            forResource: "Scene - Portal+Runes - Lights Purple and Red",
            withExtension: "usdz"
        )
    }

    var body: some View {
        if let url = portalURL {
            Model3D(url: url) { model in
                model
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
        } else {
            ProgressView()
        }
    }
}


