import RealityKit
import RealityKitContent
import UIKit

@MainActor
enum TextureMaterialLoader {

    static func loadWallMaterial() async -> (any RealityKit.Material)? {
        guard let url = realityKitContentBundle.url(forResource: "stoneTexture", withExtension: "usdz"),
              let entity = try? await Entity(contentsOf: url) else {
            return nil
        }
        return extractFirstMaterial(from: entity)
    }

    static func loadFloorMaterial() async -> (any RealityKit.Material)? {
        guard let url = realityKitContentBundle.url(forResource: "grassTexture", withExtension: "usdz"),
              let entity = try? await Entity(contentsOf: url) else {
            return nil
        }
        return extractFirstMaterial(from: entity)
    }

    static func createScanningMaterial() -> any RealityKit.Material {
        let size = CGSize(width: 128, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            UIColor.systemCyan.setFill()
            let dotRect = CGRect(x: 56, y: 56, width: 16, height: 16)
            ctx.cgContext.fillEllipse(in: dotRect)
        }
        
        guard let cgImage = image.cgImage,
              let texture = try? TextureResource(image: cgImage, options: .init(semantic: .color)) else {
            var mat = UnlitMaterial()
            mat.color = .init(tint: UIColor.systemCyan.withAlphaComponent(0.25))
            return mat
        }
        
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: 0.8)
        return material
    }

    private static func extractFirstMaterial(from entity: Entity) -> (any RealityKit.Material)? {
        if let model = entity as? ModelEntity,
           let material = model.model?.materials.first {
            return material
        }
        for child in entity.children {
            if let material = extractFirstMaterial(from: child) {
                return material
            }
        }
        return nil
    }
}
