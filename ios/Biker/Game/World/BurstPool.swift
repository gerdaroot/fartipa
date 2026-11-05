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

/// A ring of emitter nodes fed from particle systems built once at load. Each burst replaces whatever
/// the oldest node was showing, so nothing piles up however many coins are taken, and no particle
/// system, image or property controller is created during a ride.
@MainActor
final class BurstPool {
    private static let size = 14
    private static let emitSeconds: CGFloat = 0.06
    /// Copies of each recipe, so back-to-back bursts of one kind do not share a system.
    private static let copies = 2
    /// Bursts of this many particles or fewer are never thinned by the budget.
    private static let fewParticles: CGFloat = 2

    private final class Prepared {
        let systems: [SCNParticleSystem]
        let rates: [CGFloat]
        /// The ring node these systems were last shown on.
        weak var host: SCNNode?

        init(systems: [SCNParticleSystem]) {
            self.systems = systems
            rates = systems.map { $0.birthRate }
        }
    }

    private var nodes: [SCNNode] = []
    private var next = 0
    private var prepared: [Int: [Prepared]] = [:]
    private var turn: [Int: Int] = [:]
    var budget: CGFloat = 1

    init(parent: SCNNode) {
        for _ in 0..<Self.size {
            let node = SCNNode()
            node.castsShadow = false
            parent.addChildNode(node)
            nodes.append(node)
        }
        for kind in Self.everyKind { prebuild(kind) }
    }

    /// Every burst the game can fire, one per distinct look. Pickup colours come from the catalog of pickups.
    static var everyKind: [BurstKind] {
        var kinds: [BurstKind] = [
            .coin, .goldenCoin, .hitSplash, .skid, .nearMiss(side: -1), .nearMiss(side: 1),
            .boostFlash, .shieldBreak, .debris, .bigSplash,
        ]
        for kind in PickupKind.allCases { kinds.append(.pickup(PickupIcons.color(kind))) }
        return kinds
    }

    private func prebuild(_ kind: BurstKind) {
        let key = Self.key(kind)
        guard prepared[key] == nil else { return }
        var made: [Prepared] = []
        for _ in 0..<Self.copies {
            let systems = Self.systems(for: kind)
            made.append(Prepared(systems: systems))
        }
        prepared[key] = made
    }

    func fire(_ kind: BurstKind, at position: SCNVector3) {
        let key = Self.key(kind)
        if prepared[key] == nil { prebuild(kind) }
        guard let options = prepared[key], !options.isEmpty else { return }
        let index = (turn[key] ?? 0) % options.count
        turn[key] = index + 1
        let chosen = options[index]
        let node = nodes[next]
        next = (next + 1) % nodes.count
        if let host = chosen.host {
            for system in chosen.systems { host.removeParticleSystem(system) }
        }
        node.removeAllParticleSystems()
        node.position = position
        for (offset, system) in chosen.systems.enumerated() {
            let rate = chosen.rates[offset]
            // Single-particle rings keep their rate: a budget below 1 would emit nothing at all.
            system.birthRate = rate * Self.emitSeconds <= Self.fewParticles ? rate : rate * budget
            system.reset()
            node.addParticleSystem(system)
        }
        chosen.host = node
    }

    /// Fires every copy of every recipe at `position`, so their particle pipelines compile while hidden
    /// behind the loading screen.
    func warmUp(at position: SCNVector3) {
        for kind in Self.everyKind {
            for _ in 0..<Self.copies { fire(kind, at: position) }
        }
    }

    /// A number per distinct look; no string is built when a burst fires.
    private static func key(_ kind: BurstKind) -> Int {
        switch kind {
        case .coin: return 0
        case .goldenCoin: return 1
        case .hitSplash: return 2
        case .skid: return 3
        case .nearMiss(let side): return side < 0 ? 4 : 5
        case .pickup(let color): return pickupKey(color)
        case .boostFlash: return 6
        case .shieldBreak: return 7
        case .debris: return 8
        case .bigSplash: return 9
        }
    }

    /// Pickup colours packed into one number above the fixed kinds.
    private static func pickupKey(_ color: ColorValue) -> Int {
        let red = channel(color.r) << 16
        let green = channel(color.g) << 8
        return 1_000 + red + green + channel(color.b)
    }

    private static func channel(_ value: Double) -> Int {
        Int((max(0, min(1, value)) * 255).rounded())
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
