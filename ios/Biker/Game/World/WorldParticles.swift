import SceneKit
import UIKit

/// Particle systems of the world. Continuous ones get their birth rate set every frame;
/// one-shot bursts come from `burst` and are fired by `BurstPool`.
enum WorldParticles {
    static let pissYellow = UIColor(red: 1, green: 0.84, blue: 0.16, alpha: 1)
    static let poopBrown = UIColor(red: 0.36, green: 0.2, blue: 0.08, alpha: 1)
    static let fartGreen = UIColor(red: 0.62, green: 0.68, blue: 0.3, alpha: 1)

    // MARK: - Building blocks

    static func base(_ image: UIImage, color: UIColor, size: CGFloat, life: CGFloat) -> SCNParticleSystem {
        let system = SCNParticleSystem()
        system.particleImage = image
        system.particleColor = color
        system.particleSize = size
        system.particleSizeVariation = size * 0.4
        system.particleLifeSpan = life
        system.particleLifeSpanVariation = life * 0.3
        system.isLightingEnabled = false
        system.blendMode = .alpha
        system.sortingMode = .none
        system.birthRate = 0
        return system
    }

    static func ramp(_ values: [Any]) -> SCNParticlePropertyController {
        let animation = CAKeyframeAnimation()
        animation.values = values
        animation.duration = 1
        return SCNParticlePropertyController(animation: animation)
    }

    /// Opacity from `peak` to nothing, and size scaled from `grow.0` to `grow.1` over a particle's life.
    static func shape(_ system: SCNParticleSystem, peak: Double, grow: (Double, Double), colors: [UIColor]? = nil) {
        var controllers: [SCNParticleSystem.ParticleProperty: SCNParticlePropertyController] = [
            .opacity: ramp([NSNumber(value: peak), NSNumber(value: peak * 0.8), NSNumber(value: 0)]),
            .size: ramp([NSNumber(value: Double(system.particleSize) * grow.0), NSNumber(value: Double(system.particleSize) * grow.1)]),
        ]
        if let colors, colors.count > 1 { controllers[.color] = ramp(colors) }
        system.propertyControllers = controllers
    }

    // MARK: - Continuous

    /// Fart clouds from the exhaust. World space, so they hang in the air and fall behind.
    static func fartCloud() -> SCNParticleSystem {
        let system = base(SpriteTextures.softDot, color: fartGreen, size: 0.32, life: 1.1)
        system.emittingDirection = SCNVector3(0, 0.25, 1)
        system.spreadingAngle = 22
        system.particleVelocity = 2
        system.particleVelocityVariation = 0.8
        system.acceleration = SCNVector3(0, 0.6, 0)
        system.particleAngleVariation = 180
        system.particleAngularVelocityVariation = 60
        system.isLocal = false
        shape(system, peak: 0.6, grow: (0.5, 3.2), colors: [fartGreen, UIColor(red: 0.5, green: 0.46, blue: 0.3, alpha: 1)])
        return system
    }

    static func splash() -> SCNParticleSystem {
        let system = base(SpriteTextures.spark, color: pissYellow, size: 0.11, life: 0.5)
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.spreadingAngle = 75
        system.particleVelocity = 4.5
        system.particleVelocityVariation = 2
        system.acceleration = SCNVector3(0, -14, 0)
        system.blendMode = .additive
        system.isLocal = true
        shape(system, peak: 1, grow: (1, 0.6))
        return system
    }

    static func drips() -> SCNParticleSystem {
        let system = base(SpriteTextures.spark, color: pissYellow, size: 0.07, life: 0.7)
        system.emittingDirection = SCNVector3(0, -1, 0)
        system.spreadingAngle = 30
        system.particleVelocity = 3
        system.acceleration = SCNVector3(0, -12, 0)
        system.stretchFactor = 0.05
        system.blendMode = .additive
        system.isLocal = true
        let emitter = SCNCylinder(radius: 0.45, height: 10)
        system.emitterShape = emitter
        system.birthLocation = .surface
        return system
    }

    /// Faint green wisps rising off a poop pile.
    static func stink() -> SCNParticleSystem {
        let system = base(SpriteTextures.softDot, color: UIColor(red: 0.55, green: 0.8, blue: 0.25, alpha: 1), size: 0.5, life: 1.6)
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.spreadingAngle = 25
        system.particleVelocity = 0.8
        system.isLocal = true
        system.birthRate = 3
        shape(system, peak: 0.22, grow: (0.6, 2))
        return system
    }

    /// Black smoke from a wrecked vehicle.
    static func smoke() -> SCNParticleSystem {
        let system = base(SpriteTextures.softDot, color: UIColor(white: 0.12, alpha: 1), size: 0.8, life: 2)
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.spreadingAngle = 18
        system.particleVelocity = 2.2
        system.acceleration = SCNVector3(0, 0.5, 0)
        system.isLocal = true
        shape(system, peak: 0.7, grow: (0.6, 3))
        return system
    }

    /// Streaks rushing past the camera while boosting. Local to an emitter node turned by +pi/2
    /// around x in front of the camera, so the ring circles the view and local +y points back at it.
    static func speedLines() -> SCNParticleSystem {
        let system = base(SpriteTextures.spark, color: UIColor(white: 1, alpha: 1), size: 0.035, life: 0.35)
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.spreadingAngle = 0
        system.particleVelocity = 40
        system.stretchFactor = 0.06
        system.blendMode = .additive
        system.isLocal = true
        let emitter = SCNTorus(ringRadius: 2.6, pipeRadius: 0.8)
        system.emitterShape = emitter
        system.birthLocation = .volume
        shape(system, peak: 0.8, grow: (1, 1))
        return system
    }

    /// Golden glitter around the bike while coins are doubled.
    static func glitter() -> SCNParticleSystem {
        let system = base(SpriteTextures.spark, color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 0.08, life: 0.6)
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.spreadingAngle = 180
        system.particleVelocity = 0.8
        system.blendMode = .additive
        system.isLocal = false
        system.emitterShape = SCNSphere(radius: 0.9)
        system.birthLocation = .surface
        return system
    }
}
