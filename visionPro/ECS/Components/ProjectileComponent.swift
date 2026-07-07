import RealityKit
import Foundation

/// Componente que marca uma entidade como projétil em voo.
struct ProjectileComponent: Component {

    /// Direção do movimento (vetor normalizado, definido no arremesso)
    var direction: SIMD3<Float>

    /// Velocidade constante em metros por segundo
    var speed: Float = 2.5

    /// Momento em que o projétil foi lançado (usado para calcular quando destruí-lo)
    var launchTime: TimeInterval = Date().timeIntervalSince1970

    /// Tempo de vida em segundos antes de ser destruído
    var lifetime: TimeInterval = 6.0
}
