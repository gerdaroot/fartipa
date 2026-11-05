import SceneKit
import UIKit

/// Particle systems of one piss stream. All are local, so they ride along with the stream's node
/// as the road scrolls, and start with a birth rate of 0; the stream only changes `birthRate`.
enum PissParticles {
    static let paleYellow = UIColor(red: 1, green: 0.93, blue: 0.45, alpha: 1)
    static let sprayRate: CGFloat = 80
    static let hopRate: CGFloat = 14
    static let dripRate: CGFloat = 34
    private static let gravity: Float = -14

    /// Fine spray thrown up and out where the stream hits the road.
    static func spray() -> SCNParticleSystem {
        let system = WorldParticles.base(SpriteTextures.spark, color: paleYellow, size: 0.09, life: 0.42)
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.spreadingAngle = 62
        system.particleVelocity = 4.2
        system.particleVelocityVariation = 1.8
        system.acceleration = SCNVector3(0, gravity, 0)
        system.emitterShape = SCNTorus(ringRadius: 0.22, pipeRadius: 0.04)
        system.birthLocation = .surface
        system.isLocal = true
        WorldParticles.shape(system, peak: 0.95, grow: (1, 0.5))
        return system
    }

    /// A few fat drops that hop away from the puddle and fall back.
    static func hops() -> SCNParticleSystem {
        let system = WorldParticles.base(SpriteTextures.softDot, color: WorldParticles.pissYellow, size: 0.15, life: 0.75)
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.spreadingAngle = 48
        system.particleVelocity = 3.4
        system.particleVelocityVariation = 1.2
        system.acceleration = SCNVector3(0, gravity, 0)
        system.stretchFactor = 0.03
        system.isLocal = true
        WorldParticles.shape(system, peak: 0.9, grow: (1, 0.7))
        return system
    }

    /// Loose drops falling beside the lower stream, or ahead of the stream's front while it arrives.
    /// The stream points `emittingDirection` along the arc every frame.
    static func drips() -> SCNParticleSystem {
        let system = WorldParticles.base(SpriteTextures.spark, color: WorldParticles.pissYellow, size: 0.1, life: 0.55)
        system.emittingDirection = SCNVector3(0, -1, 0)
        system.spreadingAngle = 9
        system.particleVelocity = 13
        system.particleVelocityVariation = 3
        system.acceleration = SCNVector3(0, gravity, 0)
        system.stretchFactor = 0.035
        system.emitterShape = SCNSphere(radius: 0.4)
        system.birthLocation = .volume
        system.isLocal = true
        WorldParticles.shape(system, peak: 0.85, grow: (1, 0.6))
        return system
    }
}
