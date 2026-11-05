import SceneKit
import UIKit

/// What the bike needs from the ride this frame.
struct BikeFrame {
    var x = 0.0
    var distance = 0.0
    var speed = 0.0
    var rev = 0.0
    var boosting = false
    var blinking = false
    var shield = 0.0
    var magnet = 0.0
    var doubler = 0.0
    var skidding = false
    var crashed = false
    var live = true
    var clock = 0.0
}

/// The bike and everything attached to it: lean, wheels, rider tuck, fart clouds, boost trail,
/// shield bubble, magnet ring, coin glitter, headlight and the rut it leaves.
@MainActor
final class BikeEffects {
    private static let maxLean = 0.42
    private static let crashRoll = 1.3

    let holder = SCNNode()
    private let library: MaterialLibrary
    private let headlight: SCNNode
    private let fart = WorldParticles.fartCloud()
    private let glitter = WorldParticles.glitter()
    private var trail: TrailParticles.Trail?
    private let shield: SCNNode
    private let magnetRing: SCNNode
    private let ruts: RutTrail
    private var rig: BikeRig?
    private var riderBase = SCNVector3(0, 0, 0)
    private var bikeStyle: BikeStyle?
    private var riderStyle: RiderStyle?
    private var trailStyle: TrailStyle?
    private var lastX = 0.0
    private var lean = 0.0
    private var yaw = 0.0
    private var crash = 0.0
    /// Shows the shield, magnet ring, glitter and trail while the world warms up behind the loading screen.
    var warming = false
    var budget: CGFloat = 1

    init(parent: SCNNode, library: MaterialLibrary, headlight: SCNNode) {
        self.library = library
        self.headlight = headlight
        shield = Self.makeShield()
        let ring = library.shared("magnetRing", bend: false) {
            let material = WorldMaterials.decal(SpriteTextures.bubble, additive: true)
            material.multiply.contents = PickupIcons.color(.magnet).ui
            return material
        }
        magnetRing = Shapes.decal(3.2, 3.2, ring, at: Shapes.v(0, 0.05, 0))
        magnetRing.castsShadow = false
        ruts = RutTrail(parent: parent, library: library)
        parent.addChildNode(holder)
        holder.addChildNode(shield)
        holder.addChildNode(magnetRing)
        let glitterNode = SCNNode()
        glitterNode.position = Shapes.v(0, 1, 0)
        glitterNode.addParticleSystem(glitter)
        holder.addChildNode(glitterNode)
    }

    private static func makeShield() -> SCNNode {
        let sphere = SCNSphere(radius: 1.2)
        sphere.segmentCount = 32
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.blendMode = .add
        material.writesToDepthBuffer = false
        material.shaderModifiers = [.fragment: """
        #pragma transparent
        #pragma body
        float facing = saturate(dot(normalize(_surface.normal), normalize(_surface.view)));
        float rim = pow(1.0 - facing, 2.5);
        _output.color = float4(float3(0.3, 1.0, 0.45) * (0.05 + rim * 1.7), 1.0);
        """]
        sphere.firstMaterial = material
        let node = SCNNode(geometry: sphere)
        node.position = Shapes.v(0, 0.95, 0)
        node.scale = SCNVector3(0.9, 1.05, 1.45)
        node.castsShadow = false
        node.isHidden = true
        return node
    }

    // MARK: - Dressing

    func dress(bike: BikeStyle, rider: RiderStyle, trail style: TrailStyle) {
        if bike != bikeStyle || rider != riderStyle || rig == nil {
            bikeStyle = bike
            riderStyle = rider
            rig?.exhaust.removeParticleSystem(fart)
            rig?.root.removeFromParentNode()
            let fresh = BikeModels.makeRig(bike: bike, rider: rider)
            holder.addChildNode(fresh.root)
            riderBase = fresh.rider.eulerAngles
            headlight.removeFromParentNode()
            headlight.position = SCNVector3(0, 0, 0)
            fresh.headlight.addChildNode(headlight)
            fresh.exhaust.addParticleSystem(fart)
            rig = fresh
            trailStyle = nil
        }
        guard style != trailStyle, let rig else { return }
        trailStyle = style
        if let old = trail { rig.exhaust.removeParticleSystem(old.system) }
        let made = TrailParticles.make(style)
        made.system.birthRate = 0
        rig.exhaust.addParticleSystem(made.system)
        trail = made
    }

    func resetRuts() {
        ruts.reset()
    }

    // MARK: - Per frame

    func update(_ frame: BikeFrame, dt: Double) {
        steer(frame, dt: dt)
        spinWheels(frame)
        emit(frame)
        showPowerUps(frame)
        ruts.update(distance: frame.distance, x: frame.x, record: frame.live && !frame.crashed)
    }

    private func steer(_ frame: BikeFrame, dt: Double) {
        let rate = dt > 0 ? (frame.x - lastX) / dt : 0
        lastX = frame.x
        let follow = dt > 0 ? 1 - exp(-dt * 7) : 0
        let wobble = frame.skidding ? 0.22 * sin(frame.clock * 24) : 0
        lean += (max(-Self.maxLean, min(Self.maxLean, -rate * 0.055)) - lean) * follow
        yaw += (-rate * 0.02 + wobble - yaw) * follow
        let crashTarget = frame.crashed ? 1.0 : 0.0
        crash += (crashTarget - crash) * (frame.crashed ? min(1, dt * 3) : 1)
        let bounce = frame.live ? 0.012 * sin(frame.clock * 31) * min(1, frame.rev + 0.3) : 0
        holder.position = SCNVector3(Float(frame.x), Float(bounce - crash * 0.25), 0)
        holder.eulerAngles = SCNVector3(0, Float(yaw + crash * 0.5), Float(lean + crash * Self.crashRoll))
        holder.opacity = frame.blinking && sin(frame.clock * 34) > 0 ? 0.35 : 1
        if let rider = rig?.rider {
            let tuck: Float = frame.boosting ? -0.22 : 0
            rider.eulerAngles = SCNVector3(riderBase.x + tuck, riderBase.y, riderBase.z + Float(lean * 0.35))
        }
    }

    private func spinWheels(_ frame: BikeFrame) {
        guard let rig else { return }
        let front = Double(max(0.05, rig.frontWheelRadius))
        let rear = Double(max(0.05, rig.rearWheelRadius))
        let turn = 2 * Double.pi
        rig.frontWheel.eulerAngles.x = Float(-(frame.distance / front).truncatingRemainder(dividingBy: turn))
        rig.rearWheel.eulerAngles.x = Float(-(frame.distance / rear).truncatingRemainder(dividingBy: turn))
    }

    /// Farts come in puffs, faster with speed; the trail only flows under gas.
    private func emit(_ frame: BikeFrame) {
        let running = frame.live && !frame.crashed
        let rev = min(1.5, max(0, frame.rev))
        let puff = pow(max(0, sin(frame.clock * (5 + 7 * rev))), 2)
        let rate = (5 + 20 * rev) * (0.25 + 1.5 * puff)
        fart.birthRate = running ? CGFloat(rate) * budget : 0
        fart.particleVelocity = CGFloat(1.5 + frame.speed * 0.05)
        let sweep = Float(frame.speed * 0.45)
        fart.acceleration = SCNVector3(0, 0.6, sweep)
        if let trail {
            trail.system.birthRate = (running && frame.boosting) || warming ? trail.fullRate * budget : 0
            trail.system.acceleration = SCNVector3(trail.system.acceleration.x, trail.system.acceleration.y, sweep * 1.4)
        }
        glitter.birthRate = (running && frame.doubler > 0) || warming ? 30 * budget : 0
    }

    private func showPowerUps(_ frame: BikeFrame) {
        let shieldOn = frame.shield > 0 && !frame.crashed
        let fading = frame.shield < 1.5 && sin(frame.clock * 20) > 0
        shield.isHidden = warming ? false : !shieldOn || fading
        let breathe = Float(1 + 0.04 * sin(frame.clock * 5))
        shield.scale = SCNVector3(0.9 * breathe, 1.05 * breathe, 1.45 * breathe)
        magnetRing.isHidden = warming ? false : frame.magnet <= 0 || frame.crashed
        let ringScale = Float(1 + 0.12 * sin(frame.clock * 6))
        magnetRing.scale = SCNVector3(ringScale, ringScale, ringScale)
    }

    /// The bike and rider last dressed, if any.
    var dressedStyles: (bike: BikeStyle, rider: RiderStyle)? {
        guard let bikeStyle, let riderStyle else { return nil }
        return (bikeStyle, riderStyle)
    }

    /// Where the exhaust tip is in the scene, for boost flashes.
    var exhaustPosition: SCNVector3 {
        rig?.exhaust.worldPosition ?? holder.worldPosition
    }
}
