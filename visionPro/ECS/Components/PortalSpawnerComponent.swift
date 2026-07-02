import RealityKit
import Foundation
import simd

struct PortalSpawnerComponent: Component {
    var portalTemplate: Entity?

    /// Referência fixa de posição/orientação, capturada uma vez no início
    var referenceTransform: simd_float4x4?

    var minDistance: Float = 1.5
    var maxDistance: Float = 3.5
    var halfFieldDegrees: Float = 90

    var spawnInterval: TimeInterval = 3.0
    var lastSpawnTime: TimeInterval = 0

    var isReady: Bool {
        portalTemplate != nil && referenceTransform != nil
    }
}
