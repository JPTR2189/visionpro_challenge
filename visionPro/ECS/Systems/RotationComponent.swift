import RealityKit

/// Define se uma entidade pode rotacionada pelo RotationSystem.
struct RotationComponent: Component {

    /// Positivo = sentido anti-horário (visto de cima)
    /// Negativo = sentido horário (visto de cima)
    var angularSpeed: Float

    /// Controla se a rotação está ativa ou pausada.
    var isActive: Bool = false

    /// Direções pré-definidas, pra facilitar o uso no HandSphereView
    
    static let clockwise = Float(-1.2)         /// 69 graus/s (horário)
    static let counterClockwise = Float(1.2)   /// 69 graus/s (anti-horário)
}
