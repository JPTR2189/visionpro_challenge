//
//  RotationSystem.swift
//  visionPro
//

import RealityKit

/// System responsável por rotacionar todas as entidades que têm um RotationComponent (ativo).
class RotationSystem: System {

    static let query = EntityQuery(where: .has(RotationComponent.self))

    required init(scene: RealityKit.Scene) { }

    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let component = entity.components[RotationComponent.self],
                  component.isActive else { continue }

            /// Calcula o incremento de rotação desse frame:
            let angleThisFrame = component.angularSpeed * deltaTime

            /// Cria um quaternion de rotação incremental em torno do eixo Y
            let deltaRotation = simd_quatf(angle: angleThisFrame, axis: [0, 1, 0])

            /// Aplica a rotação acumulando sobre a rotação atual
            entity.transform.rotation = deltaRotation * entity.transform.rotation
        }
    }
}
