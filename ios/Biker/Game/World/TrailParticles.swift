import SceneKit
import UIKit

/// The boost exhaust in the selected trail skin. World space: it streams back from the bike.
/// `fullRate` is the birth rate while boosting; the world sets 0 otherwise.
enum TrailParticles {
    struct Trail {
        let system: SCNParticleSystem
        let fullRate: CGFloat
    }

    static func make(_ style: TrailStyle) -> Trail {
        let primary = ColorValue(style.primary).ui
        let secondary = ColorValue(style.secondary).ui
        let recipe = recipe(style.pattern)
        let system = WorldParticles.base(recipe.image, color: primary, size: recipe.size, life: recipe.life)
        system.emittingDirection = SCNVector3(0, recipe.lift, 1)
        system.spreadingAngle = recipe.spread
        system.particleVelocity = recipe.speed
        system.particleVelocityVariation = recipe.speed * 0.35
        system.acceleration = SCNVector3(0, Float(recipe.gravity), 0)
        system.blendMode = recipe.additive ? .additive : .alpha
        system.stretchFactor = recipe.stretch
        system.particleAngleVariation = 180
        system.particleAngularVelocityVariation = recipe.spin
        system.isLocal = false
        if recipe.rainbow {
            system.particleColorVariation = SCNVector4(1, 0.2, 0, 0)
        }
        WorldParticles.shape(system, peak: recipe.opacity, grow: recipe.grow, colors: recipe.rainbow ? nil : [primary, secondary])
        return Trail(system: system, fullRate: recipe.rate)
    }

    private struct Recipe {
        var image: UIImage = SpriteTextures.softDot
        var size: CGFloat = 0.4
        var life: CGFloat = 0.9
        var speed: CGFloat = 6
        var spread: CGFloat = 14
        var lift: Float = 0.15
        var gravity: Double = 0
        var rate: CGFloat = 70
        var additive = false
        var stretch: CGFloat = 0
        var spin: CGFloat = 0
        var opacity = 0.9
        var grow: (Double, Double) = (0.6, 2.6)
        var rainbow = false
    }

    private static func recipe(_ pattern: TrailPattern) -> Recipe {
        var recipe = Recipe()
        switch pattern {
        case .cloud:
            recipe.size = 0.55
            recipe.grow = (0.6, 3.4)
        case .smoke:
            recipe.life = 1.3
            recipe.gravity = 1.2
            recipe.opacity = 0.75
        case .rainbow:
            recipe.rainbow = true
            recipe.additive = true
            recipe.size = 0.35
            recipe.spread = 4
            recipe.rate = 120
            recipe.grow = (1, 1.6)
        case .fire, .plasma, .sparks, .lightning:
            energetic(pattern, &recipe)
        case .bubbles:
            recipe.image = SpriteTextures.bubble
            recipe.size = 0.22
            recipe.life = 1.4
            recipe.speed = 4
            recipe.gravity = 1.6
            recipe.grow = (0.6, 1.6)
        case .confetti, .toiletPaper:
            recipe.image = SpriteTextures.paper
            recipe.size = pattern == .toiletPaper ? 0.32 : 0.16
            recipe.life = 1.5
            recipe.spread = 40
            recipe.gravity = -3
            recipe.spin = 360
            recipe.grow = (1, 1)
            recipe.rainbow = pattern == .confetti
        case .flies:
            recipe.image = SpriteTextures.fly
            recipe.size = 0.12
            recipe.life = 1.2
            recipe.speed = 3
            recipe.spread = 70
            recipe.grow = (1, 1)
        case .coins:
            recipe.image = BikeTextures.coinImage
            recipe.size = 0.22
            recipe.life = 1.1
            recipe.spread = 35
            recipe.gravity = -8
            recipe.spin = 300
            recipe.grow = (1, 1)
            recipe.lift = 0.6
        }
        return recipe
    }

    private static func energetic(_ pattern: TrailPattern, _ recipe: inout Recipe) {
        recipe.additive = true
        switch pattern {
        case .fire, .plasma:
            recipe.size = 0.45
            recipe.life = 0.45
            recipe.speed = 9
            recipe.gravity = 2
            recipe.rate = 140
            recipe.grow = (1.1, 0.2)
        case .sparks, .lightning:
            recipe.image = SpriteTextures.spark
            recipe.size = 0.09
            recipe.life = 0.5
            recipe.speed = 12
            recipe.spread = pattern == .lightning ? 8 : 28
            recipe.gravity = pattern == .sparks ? -9 : 0
            recipe.stretch = 0.05
            recipe.rate = 160
            recipe.grow = (1, 0.4)
        default:
            break
        }
    }
}
