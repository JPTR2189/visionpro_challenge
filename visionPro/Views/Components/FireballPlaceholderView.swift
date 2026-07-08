import SwiftUI
import RealityKit

struct FireBallPlaceholderView: View {
    var resourceName: String = "Fireball"
    var bundle: Bundle = .main
    private var portalURL: URL? {
           bundle.url(forResource: resourceName, withExtension: "usdz", subdirectory: "Resources")
               ?? bundle.url(forResource: resourceName, withExtension: "usdz")
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


