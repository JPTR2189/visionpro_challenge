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

    /// Tamanho visual do portal em metros (largura e altura).
    var portalSize = SIMD2<Float>(0.8, 1.5)

    /// Espaco minimo entre as bordas do portal e as bordas da parede.
    var wallMargin: Float = 0.10

    var spawnInterval: TimeInterval = 3.0
    var lastSpawnTime: TimeInterval = 0

    /// Evita consultar todas as paredes a cada frame enquanto nenhuma e valida.
    var placementRetryInterval: TimeInterval = 0.25
    var lastPlacementAttemptTime: TimeInterval = 0

    var isReady: Bool {
        portalTemplate != nil && referenceTransform != nil
    }
}
