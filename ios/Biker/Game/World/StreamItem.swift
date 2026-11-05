import SceneKit
import UIKit

/// One piss stream, pissed onto the road by a giant butt in a cloud off to the side.
///
/// While the warning climbs, a pulsing target and a growing shadow mark the road, the cloud gathers,
/// and in the last part of the warning the stream's front travels down its parabola so it lands
/// exactly when the stream starts to hurt. While it pours: a rippling translucent arc that thins and
/// breaks into drops, loose drops beside it, a splash crown with spray and hopping drops, and a
/// spreading puddle with ripples. If it ever stops, the tail falls after the front and the puddle
/// fades. Every node and particle system is made once in `init`; `update` only changes transforms,
/// opacity, visibility and birth rates.
@MainActor
final class StreamItem: PooledItem {
    static let columnHeight = PissArc.height
    /// Share of the warning the stream spends falling, within these limits in seconds.
    private static let fallShare = 0.55
    private static let shortestFall = 0.45
    private static let longestFall = 1.0
    private static let puddleGrowSeconds = 1.1
    private static let puddleLingerSeconds = 1.6
    private static let rippleSeconds = 0.85
    private static let sideThreshold = 0.25
    /// The cloud fades in over this share of the warning.
    private static let cloudFadeShare = 0.35

    let root = SCNNode()
    private let marker: SCNNode
    private let shadow: SCNNode
    private let puddle: SCNNode
    private let ripples: [SCNNode]
    private let crown: SCNNode
    private let body: PissBody
    private let spray = PissParticles.spray()
    private let hops = PissParticles.hops()
    private let warningMaterials: [SCNMaterial]
    private var markerStep = -1
    private var pourAge = 0.0
    private var drainAge = 0.0
    private var hasPoured = false
    private var isAimed = false
    private var rippleClock = 0.0
    var budget: CGFloat = 1

    init(kit: StreamKit) {
        warningMaterials = kit.warning
        marker = Shapes.decal(2.8, 2.8, kit.warning[0], at: Shapes.v(0, 0.05, 0))
        shadow = Shapes.decal(3.2, 3.2, kit.shadow, at: Shapes.v(0, 0.04, 0))
        puddle = Shapes.decal(3.4, 3.4, kit.puddle, at: Shapes.v(0, 0.035, 0))
        let rippleA = Shapes.decal(1.6, 1.6, kit.ripple, at: Shapes.v(0, 0.045, 0))
        let rippleB = Shapes.decal(1.6, 1.6, kit.ripple, at: Shapes.v(0, 0.046, 0))
        ripples = [rippleA, rippleB]
        crown = SCNNode(geometry: kit.crownMesh)
        crown.position = Shapes.v(0, 0.02, 0)
        body = PissBody(kit: kit)
        for node in [shadow, puddle, rippleA, rippleB, marker, crown, body.lean] { root.addChildNode(node) }
        let splashNode = SCNNode()
        splashNode.position = Shapes.v(0, 0.08, 0)
        splashNode.addParticleSystem(spray)
        splashNode.addParticleSystem(hops)
        root.addChildNode(splashNode)
        root.disableShadows()
        recycle()
    }

    func recycle() {
        pourAge = 0
        drainAge = 0
        rippleClock = 0
        hasPoured = false
        isAimed = false
        markerStep = -1
        for system in [spray, hops] {
            system.birthRate = 0
            system.reset()
        }
        puddle.isHidden = true
        crown.isHidden = true
        for ripple in ripples { ripple.isHidden = true }
        body.reset()
    }

    /// `clock` drives the pulse and splash; `dt` is 0 while paused. The root is already placed.
    func update(_ stream: PissStream, clock: Double, dt: Double) {
        if !isAimed {
            body.aim(side: StreamItem.side(of: stream), phase: stream.phase)
            isAimed = true
        }
        let warning = stream.isPouring ? 1 : max(0, min(1, stream.isVisible ? stream.warning : 0))
        updateMarker(warning: warning, pouring: stream.isPouring, clock: clock)
        body.follow(landingX: Double(root.position.x), dt: dt)
        if stream.isPouring {
            hasPoured = true
            drainAge = 0
            pourAge += dt
        } else if hasPoured {
            drainAge += dt
        }
        let fall = StreamItem.fallSeconds(stream)
        let front = hasPoured ? 1 : StreamItem.front(warning: warning, fall: fall, warningSeconds: stream.warningSeconds)
        let draining = hasPoured && !stream.isPouring
        let tail = draining ? min(1, drainAge / fall) : 0
        let live = dt > 0
        let cloud = draining ? 1 - tail : warning / StreamItem.cloudFadeShare
        body.show(front: front, tail: tail, cloudOpacity: cloud, dripRate: live ? PissParticles.dripRate * budget : 0)
        updateSplash(pouring: stream.isPouring, live: live, clock: clock, phase: stream.phase)
        updatePuddle(pouring: stream.isPouring, draining: draining, dt: dt)
    }

    /// Streams in the right half come from the right, in the left half from the left.
    private static func side(of stream: PissStream) -> Double {
        if stream.baseX > sideThreshold { return 1 }
        if stream.baseX < -sideThreshold { return -1 }
        return stream.id % 2 == 0 ? 1 : -1
    }

    /// How long the front takes from the cloud to the road for this stream.
    private static func fallSeconds(_ stream: PissStream) -> Double {
        max(shortestFall, min(longestFall, stream.warningSeconds * fallShare))
    }

    /// How far down the arc the arriving front is: it leaves the cloud `fall` seconds before the
    /// warning ends and, moving at constant sideways speed, reaches the road exactly at warning 1.
    private static func front(warning: Double, fall: Double, warningSeconds: Double) -> Double {
        let seconds = max(0.01, warningSeconds)
        let secondsLeft = (1 - warning) * seconds
        return max(0, min(1, 1 - secondsLeft / fall))
    }

    private func updateMarker(warning: Double, pouring: Bool, clock: Double) {
        let index = min(StreamKit.warningSteps - 1, Int(warning * Double(StreamKit.warningSteps)))
        if index != markerStep, index < warningMaterials.count {
            marker.geometry?.firstMaterial = warningMaterials[index]
            markerStep = index
        }
        let pulse = 0.5 + 0.5 * sin(clock * (8 + warning * 14))
        let markerScale = Float(0.45 + 0.75 * warning)
        marker.scale = SCNVector3(markerScale, markerScale, markerScale)
        marker.opacity = pouring ? 0.2 : CGFloat(0.45 + 0.55 * pulse)
        let shadowScale = Float(0.25 + warning)
        shadow.scale = SCNVector3(shadowScale, shadowScale, shadowScale)
        shadow.opacity = CGFloat(0.2 + 0.6 * warning)
    }

    private func updateSplash(pouring: Bool, live: Bool, clock: Double, phase: Double) {
        crown.isHidden = !pouring
        if pouring {
            let rise = Float(0.85 + 0.3 * sin(clock * 23 + phase) + 0.12 * sin(clock * 37))
            let spread = Float(1 + 0.08 * sin(clock * 17 + phase))
            crown.scale = SCNVector3(spread, rise, spread)
            crown.eulerAngles = SCNVector3(0, Float((clock * 1.3).truncatingRemainder(dividingBy: 2 * Double.pi)), 0)
        }
        let active = pouring && live
        spray.birthRate = active ? PissParticles.sprayRate * budget : 0
        hops.birthRate = active ? PissParticles.hopRate * budget : 0
    }

    private func updatePuddle(pouring: Bool, draining: Bool, dt: Double) {
        puddle.isHidden = !(pouring || draining)
        if pouring {
            let size = Float(0.3 + 0.75 * min(1, pourAge / StreamItem.puddleGrowSeconds))
            puddle.scale = SCNVector3(size, size, size)
            puddle.opacity = 1
        } else if draining {
            puddle.opacity = CGFloat(max(0, 1 - drainAge / StreamItem.puddleLingerSeconds))
        }
        rippleClock += pouring ? dt : 0
        for (index, ripple) in ripples.enumerated() {
            ripple.isHidden = !pouring
            guard pouring else { continue }
            let age = (rippleClock / StreamItem.rippleSeconds + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
            let size = Float(0.35 + 2.1 * age)
            ripple.scale = SCNVector3(size, size, size)
            ripple.opacity = CGFloat(0.7 * (1 - age))
        }
    }
}
