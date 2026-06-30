import RealityKit
import simd
import Foundation
internal import UIKit
import RealityKitContent

@MainActor
final class PortalSpawner {

    private let minDistance: Float = 1.5
    private let maxDistance: Float = 3.5
    private let halfFieldDegrees: Float = 90 // 90° pra cada lado = 180° total

    /// Calcula uma posição aleatória num arco horizontal de 180° na frente da cabeça,
    /// sempre na mesma altura (Y) da cabeça — sem variação vertical.
    func randomPosition(relativeTo headTransform: simd_float4x4) -> SIMD3<Float> {

        let headPosition = SIMD3<Float>(headTransform.columns.3.x,
                                         headTransform.columns.3.y,
                                         headTransform.columns.3.z)

        // Forward "bruto" da cabeça (pode estar inclinado se o usuário olhar pra cima/baixo)
        let rawForward = -normalize(SIMD3<Float>(headTransform.columns.2.x,
                                                   headTransform.columns.2.y,
                                                   headTransform.columns.2.z))

        // Projeta no plano horizontal (zera o componente Y) — ignora pitch da cabeça
        var forward = SIMD3<Float>(rawForward.x, 0, rawForward.z)

        // Caso o usuário esteja olhando quase reto pra cima/baixo, o forward projetado
        // pode ficar quase zero. Nesse caso, usa uma direção padrão como fallback.
        if simd_length(forward) < 0.0001 {
            forward = SIMD3<Float>(0, 0, -1)
        }
        forward = normalize(forward)

        // Usa o "up" absoluto do mundo (não o da cabeça) pra rotação de azimute,
        // assim mesmo que o usuário incline a cabeça de lado, o arco continua nivelado.
        let worldUp = SIMD3<Float>(0, 1, 0)

        let azimuthDeg = Float.random(in: -halfFieldDegrees...halfFieldDegrees)
        let azimuthRad = azimuthDeg * .pi / 180

        let distance = Float.random(in: minDistance...maxDistance)

        let yawRotation = simd_quatf(angle: azimuthRad, axis: worldUp)
        let direction = normalize(yawRotation.act(forward))

        let rawPosition = headPosition + direction * distance

        // Força o Y a ser igual ao da cabeça — elimina qualquer variação vertical
        return SIMD3<Float>(rawPosition.x, headPosition.y, rawPosition.z)
    }

    func makePortalEntity() async -> Entity? {
        do {
            let portal = try await Entity(named: "Portal", in: realityKitContentBundle)
            return portal
        } catch {
            print("❌ Erro ao carregar entity 'Portal':", error)
            return nil
        }
    }
}
