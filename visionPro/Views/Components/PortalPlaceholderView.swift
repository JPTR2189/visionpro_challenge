import SwiftUI
import RealityKit

struct PortalPlaceholderView: View {
    var resourceName: String = "Portal+Runes"
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


