import SceneKit
import UIKit

/// One-shot effects for `BikeWorld.react`.
enum BurstKind {
    case coin
    case goldenCoin
    case hitSplash
    case skid
    /// Streaks along one side of the bike (-1 left, 1 right).
    case nearMiss(side: Double)
    case pickup(ColorValue)
    case boostFlash
    case shieldBreak
    case debris
    case bigSplash
}

/// A ring of emitter nodes. Each burst replaces whatever the oldest node was showing,
/// so nothing piles up however many coins are taken.
@MainActor
final class BurstPool {
    private static let size = 14
    private static let emitSeconds: CGFloat = 0.06

    private var nodes: [SCNNode] = []
    private var next = 0
    var budget: CGFloat = 1

    init(parent: SCNNode) {
        for _ in 0..<Self.size {
            let node = SCNNode()
            parent.addChildNode(node)
            nodes.append(node)
        }
    }

    func fire(_ kind: BurstKind, at position: SCNVector3) {
        let node = nodes[next]
        next = (next + 1) % nodes.count
        node.removeAllParticleSystems()
        node.position = position
        for system in Self.systems(for: kind) {
            system.birthRate *= budget
            node.addParticleSystem(system)
        }
    }

    // MARK: - Recipes

    private static func oneShot(_ image: UIImage, color: UIColor, count: CGFloat, size: CGFloat, life: CGFloat, speed: CGFloat) -> SCNParticleSystem {
        let system = WorldParticles.base(image, color: color, size: size, life: life)
        system.loops = false
        system.emissionDuration = emitSeconds
        system.birthRate = count / emitSeconds
        system.particleVelocity = speed
        system.particleVelocityVariation = speed * 0.5
        system.spreadingAngle = 180
        system.emittingDirection = SCNVector3(0, 1, 0)
        system.isLocal = false
        return system
    }

    private static func systems(for kind: BurstKind) -> [SCNParticleSystem] {
        switch kind {
        case .coin: return [sparkle(count: 26, color: UIColor(red: 1, green: 0.82, blue: 0.3, alpha: 1), speed: 3)]
        case .goldenCoin:
            return [sparkle(count: 70, color: UIColor(red: 1, green: 0.95, blue: 0.5, alpha: 1), speed: 5), ring(ColorValue(hex: 0xFFD21E))]
        case .hitSplash: return [liquid(count: 90, color: WorldParticles.pissYellow), liquid(count: 40, color: WorldParticles.poopBrown)]
        case .skid: return [liquid(count: 50, color: WorldParticles.poopBrown)]
        case .nearMiss(let side): return [streaks(side: side)]
        case .pickup(let color): return [ring(color), sparkle(count: 40, color: color.ui, speed: 4)]
        case .boostFlash: return [flash()]
        case .shieldBreak: return [ring(ColorValue(hex: 0x4CFF6A)), sparkle(count: 60, color: UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1), speed: 6)]
        case .debris: return [debris(), liquid(count: 50, color: WorldParticles.poopBrown)]
        case .bigSplash: return [liquid(count: 180, color: WorldParticles.pissYellow), liquid(count: 90, color: WorldParticles.poopBrown)]
        }
    }

    private static func sparkle(count: CGFloat, color: UIColor, speed: CGFloat) -> SCNParticleSystem {
        let system = oneShot(SpriteTextures.spark, color: color, count: count, size: 0.12, life: 0.55, speed: speed)
        system.blendMode = .additive
        system.acceleration = SCNVector3(0, -3, 3)
        WorldParticles.shape(system, peak: 1, grow: (1.2, 0.2))
        return system
    }

    private static func liquid(count: CGFloat, color: UIColor) -> SCNParticleSystem {
        let system = oneShot(SpriteTextures.softDot, color: color, count: count, size: 0.16, life: 0.7, speed: 5)
        system.spreadingAngle = 65
        system.acceleration = SCNVector3(0, -15, 6)
        WorldParticles.shape(system, peak: 1, grow: (1, 0.7))
        return system
    }

    private static func ring(_ color: ColorValue) -> SCNParticleSystem {
        let system = oneShot(SpriteTextures.bubble, color: color.ui, count: 1, size: 0.6, life: 0.45, speed: 0)
        system.particleSizeVariation = 0
        system.blendMode = .additive
        WorldParticles.shape(system, peak: 1, grow: (1, 6))
        return system
    }

    private static func streaks(side: Double) -> SCNParticleSystem {
        let system = oneShot(SpriteTextures.spark, color: UIColor(red: 0.8, green: 0.95, blue: 1, alpha: 1), count: 24, size: 0.05, life: 0.3, speed: 30)
        system.emittingDirection = SCNVector3(Float(side) * 0.15, 0, 1)
        system.spreadingAngle = 6
        system.stretchFactor = 0.08
        system.blendMode = .additive
        system.emitterShape = SCNBox(width: 0.2, height: 1.4, length: 2, chamferRadius: 0)
        system.birthLocation = .volume
        return system
    }

    private static func flash() -> SCNParticleSystem {
        let system = oneShot(SpriteTextures.softDot, color: UIColor(red: 1, green: 0.7, blue: 0.3, alpha: 1), count: 30, size: 0.5, life: 0.45, speed: 6)
        system.emittingDirection = SCNVector3(0, 0.2, 1)
        system.spreadingAngle = 30
        system.blendMode = .additive
        WorldParticles.shape(system, peak: 1, grow: (0.6, 3))
        return system
    }

    private static func debris() -> SCNParticleSystem {
        let system = oneShot(SpriteTextures.paper, color: UIColor(white: 0.55, alpha: 1), count: 40, size: 0.22, life: 1.1, speed: 9)
        system.particleColorVariation = SCNVector4(0.1, 0.3, 0.4, 0)
        system.emittingDirection = SCNVector3(0, 1, 0.6)
        system.spreadingAngle = 60
        system.acceleration = SCNVector3(0, -14, 12)
        system.particleAngularVelocity = 400
        system.particleAngularVelocityVariation = 300
        return system
    }
}
