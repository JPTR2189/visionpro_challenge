import RealityKit
import Foundation
import simd

struct PortalSpawnerComponent: Component {
    var portalTemplate: Entity?

    /// Referência fixa de posição/orientação, capturada uma vez no início
    var referenceTransform: simd_float4x4?

    ///  Condições para spawnar os portais nas paredes
    var minDistance: Float = 1.0      // era 1.5
    var maxDistance: Float = 4.5      // era 3.5
    var halfFieldDegrees: Float = 90

    /// Tamanho visual do portal em metros (largura e altura).
    var portalSize = SIMD2<Float>(0.8, 1.5)

    /// Espaço mínimo entre as bordas do portal e as bordas da parede.
    var wallMargin: Float = 0.05

    var spawnInterval: TimeInterval = 3.0
    var lastSpawnTime: TimeInterval = 0

    /// Evita consultar todas as paredes a cada frame enquanto nenhuma é válida.
    var placementRetryInterval: TimeInterval = 0.25
    var lastPlacementAttemptTime: TimeInterval = 0

    /// Contador de tentativas falhas seguidas.
    /// Garante que os portais eventualmente apareçam mesmo em ambientes pequenos/apertados.
    var failedAttempts: Int = 0

    /// Limite de falhas permitidas antes de diminuir os filtros.
    static let attemptsBeforeRelaxingFilter = 12       /// ~3 segundos
    static let attemptsBeforeRelaxingDistance = 24  /// ~6 segundos

    var isReady: Bool {
        portalTemplate != nil && referenceTransform != nil
    }
}
