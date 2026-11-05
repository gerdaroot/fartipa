import SceneKit
import UIKit

/// The bike's jump this frame, handed from `ObjectsLayer` (which sees the whole run) to
/// `BikeEffects` (which only gets a `BikeFrame`). Written before the bike updates in the same
/// frame; reset when the road objects are dropped.
@MainActor
enum PlayAirPose {
    /// Metres above the road.
    private(set) static var height = 0.0
    /// Flips in this jump: 1.0 is a whole turn.
    private(set) static var turns = 0.0
    private(set) static var isAirborne = false
    /// Counts hops that took off, so the bike can puff a fart cloud once per hop.
    private(set) static var hopCount = 0

    static func write(height newHeight: Double, turns newTurns: Double, airborne: Bool, hopped: Bool) {
        height = max(0, newHeight)
        turns = max(0, newTurns)
        isAirborne = airborne
        if hopped { hopCount &+= 1 }
    }

    static func reset() {
        height = 0
        turns = 0
        isAirborne = false
    }
}

/// Ramps and manholes.
@MainActor
enum PlayModels {
    private static let deckThickness = 0.16
    private static let stripeWidth = 0.18

    /// A wooden kicker with hazard stripes along its edges. The lip is at the node's origin; the
    /// ramp runs towards the camera (+z) for `RoadRamp.length` metres.
    static func ramp(library: MaterialLibrary) -> SimpleItem {
        let wood = library.shared("playRampWood", bend: false) {
            WorldMaterials.pbr(UIColor(red: 0.55, green: 0.36, blue: 0.18, alpha: 1), roughness: 0.7)
        }
        let stripe = library.shared("playRampStripe", bend: false) {
            WorldMaterials.glow(UIColor(red: 1, green: 0.78, blue: 0.1, alpha: 1), boost: 0.5)
        }
        let length = RoadRamp.length
        let rise = RoadRamp.lipHeight
        let width = RoadRamp.width
        let slant = (length * length + rise * rise).squareRoot()
        let pitch = atan2(rise, length)
        let deck = SCNNode()
        deck.addChildNode(Shapes.box(width, deckThickness, slant, wood, at: Shapes.v(0, 0, 0)))
        let edge = width / 2 - stripeWidth / 2
        for side in [-1.0, 1.0] {
            deck.addChildNode(Shapes.box(stripeWidth, deckThickness * 1.3, slant, stripe, at: Shapes.v(side * edge, 0.02, 0)))
        }
        deck.position = Shapes.v(0, rise / 2, length / 2)
        deck.eulerAngles.x = Float(pitch)
        let shape = SCNNode()
        shape.addChildNode(deck)
        shape.addChildNode(Shapes.box(width, rise, deckThickness, wood, at: Shapes.v(0, rise / 2, 0)))
        shape.addChildNode(Shapes.box(width, deckThickness, deckThickness * 1.4, stripe, at: Shapes.v(0, rise, 0)))
        let root = SCNNode()
        root.addChildNode(library.flatten(shape))
        return SimpleItem(root: root)
    }
}

/// A geyser manhole (iron ring, warning glow, sewage spout) or a manhole cover rolling on its edge.
@MainActor
final class PlayManholeItem: PooledItem {
    private static let lidRadius = 0.62
    private static let lidThickness = 0.12
    private static let sprayRate: CGFloat = 160
    private static let columnHeight = 2.6
    /// The glow ring brightens over this last share of a geyser's rest, as a warning.
    private static let warnShare = 0.3

    let root = SCNNode()
    let kind: ManholeKind
    private let spinner = SCNNode()
    private let column: SCNNode?
    private let glow: SCNNode?
    private let spray: SCNParticleSystem?

    init(kind: ManholeKind, library: MaterialLibrary) {
        self.kind = kind
        let iron = library.shared("playManholeIron", bend: false) {
            WorldMaterials.pbr(UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1), metalness: 0.8, roughness: 0.45)
        }
        guard kind == .geyser else {
            column = nil
            glow = nil
            spray = nil
            let disc = Shapes.cylinder(Self.lidRadius, Self.lidThickness, iron, at: Shapes.v(0, 0, 0))
            disc.eulerAngles.x = .pi / 2
            spinner.addChildNode(disc)
            spinner.position = Shapes.v(0, Self.lidRadius, 0)
            root.addChildNode(spinner)
            return
        }
        let made = Self.makeGeyser(library: library)
        column = made.column
        glow = made.glow
        spray = made.spray
        root.addChildNode(Shapes.cylinder(Self.lidRadius + 0.12, 0.06, iron, at: Shapes.v(0, 0.03, 0)))
        root.addChildNode(made.glow)
        root.addChildNode(made.column)
        let sprayNode = SCNNode()
        sprayNode.position = Shapes.v(0, 0.2, 0)
        sprayNode.addParticleSystem(made.spray)
        root.addChildNode(sprayNode)
    }

    private static func makeGeyser(library: MaterialLibrary) -> (column: SCNNode, glow: SCNNode, spray: SCNParticleSystem) {
        let sewage = library.shared("playGeyserSewage", bend: false) {
            WorldMaterials.pbr(UIColor(red: 0.42, green: 0.27, blue: 0.1, alpha: 1), roughness: 0.15)
        }
        let ring = library.shared("playGeyserRing", bend: false) {
            let material = WorldMaterials.decal(SpriteTextures.warningRing, additive: true)
            material.multiply.contents = UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 1)
            return material
        }
        let column = Shapes.cylinder(0.32, columnHeight, sewage, at: Shapes.v(0, columnHeight / 2, 0))
        column.isHidden = true
        let glow = Shapes.decal(2.6, 2.6, ring, at: Shapes.v(0, 0.07, 0))
        glow.opacity = 0
        let spray = WorldParticles.base(SpriteTextures.softDot, color: WorldParticles.poopBrown, size: 0.22, life: 0.7)
        spray.emittingDirection = SCNVector3(0, 1, 0)
        spray.spreadingAngle = 14
        spray.particleVelocity = 9
        spray.particleVelocityVariation = 2.5
        spray.acceleration = SCNVector3(0, -16, 0)
        spray.isLocal = true
        WorldParticles.shape(spray, peak: 0.9, grow: (0.8, 1.6))
        return (column, glow, spray)
    }

    func recycle() {
        spray?.birthRate = 0
        column?.isHidden = true
        glow?.opacity = 0
        spinner.eulerAngles = SCNVector3(0, 0, 0)
    }

    /// `x` is where the hazard is now: the lid spins by how far it has rolled.
    func update(_ hole: Manhole, time: Double, clock: Double, live: Bool, budget: CGFloat) {
        switch kind {
        case .rollingLid:
            let roll = -(hole.x(atTime: time) - hole.baseX) / Self.lidRadius
            spinner.perfSetEuler(SCNVector3(0, 0, Float(roll)))
        case .geyser:
            let cycle = hole.cycle(atTime: time)
            let spouting = cycle < Manhole.sprayShare
            spray?.perfSetBirthRate(spouting && live ? Self.sprayRate * budget : 0)
            column?.perfSetHidden(!spouting)
            if spouting, let column {
                let pulse = 0.85 + 0.15 * sin(clock * 30)
                column.scale = SCNVector3(Float(pulse), Float(min(1, cycle / 0.08)), Float(pulse))
                column.position.y = Float(Self.columnHeight / 2 * min(1, cycle / 0.08))
            }
            let warn = max(0, (cycle - (1 - Self.warnShare)) / Self.warnShare)
            glow?.perfSetOpacity(CGFloat(spouting ? 1 : warn))
        }
    }
}
