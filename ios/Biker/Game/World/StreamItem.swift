import SceneKit
import UIKit

/// One piss stream: first a pulsing target and a growing shadow on the road, then a glowing column
/// that falls from the sky and lands exactly when the stream starts to hurt, with drips, a splash
/// and a spreading puddle.
@MainActor
final class StreamItem: PooledItem {
    static let columnHeight = 60.0
    private static let warningSteps = 8
    private static let fallStart = 0.55
    private static let puddleSeconds = 0.9
    private static let splashRate: CGFloat = 140
    private static let dripRate: CGFloat = 40

    let root = SCNNode()
    private let marker: SCNNode
    private let shadow: SCNNode
    private let pivot = SCNNode()
    private let column: SCNNode
    private let puddle: SCNNode
    private let glow: SCNNode
    private let splash = WorldParticles.splash()
    private let drips = WorldParticles.drips()
    private let warningMaterials: [SCNMaterial]
    private var pourAge = 0.0
    var budget: CGFloat = 1

    init(kit: StreamKit) {
        warningMaterials = kit.warning
        marker = Shapes.decal(2.8, 2.8, kit.warning[0], at: Shapes.v(0, 0.05, 0))
        shadow = Shapes.decal(3.2, 3.2, kit.shadow, at: Shapes.v(0, 0.04, 0))
        puddle = Shapes.decal(3.4, 3.4, kit.puddle, at: Shapes.v(0, 0.035, 0))
        glow = Shapes.decal(6, 6, kit.glow, at: Shapes.v(0, 0.06, 0))
        column = SCNNode()
        let outer = SCNCylinder(radius: 0.34, height: CGFloat(Self.columnHeight))
        outer.radialSegmentCount = 14
        outer.firstMaterial = kit.column
        column.addChildNode(SCNNode(geometry: outer))
        let inner = SCNCylinder(radius: 0.13, height: CGFloat(Self.columnHeight))
        inner.radialSegmentCount = 8
        inner.firstMaterial = kit.core
        column.addChildNode(SCNNode(geometry: inner))
        column.position = Shapes.v(0, -Self.columnHeight / 2, 0)
        pivot.position = Shapes.v(0, Self.columnHeight, 0)
        pivot.addChildNode(column)
        for node in [shadow, puddle, marker, glow, pivot] { root.addChildNode(node) }
        let splashNode = SCNNode()
        splashNode.position = Shapes.v(0, 0.1, 0)
        splashNode.addParticleSystem(splash)
        root.addChildNode(splashNode)
        let dripNode = SCNNode()
        dripNode.position = Shapes.v(0, 6, 0)
        dripNode.addParticleSystem(drips)
        root.addChildNode(dripNode)
        root.disableShadows()
    }

    func recycle() {
        pourAge = 0
        splash.birthRate = 0
        drips.birthRate = 0
        puddle.isHidden = true
        glow.isHidden = true
        pivot.isHidden = true
    }

    /// `clock` drives the pulse and wobble; `dt` is 0 while paused.
    func update(_ stream: PissStream, clock: Double, dt: Double) {
        let warning = stream.isPouring ? 1 : max(0, min(1, (stream.isVisible ? stream.warning : 0)))
        let index = min(Self.warningSteps - 1, Int(warning * Double(Self.warningSteps)))
        marker.geometry?.firstMaterial = warningMaterials[index]
        let pulse = 0.5 + 0.5 * sin(clock * (8 + warning * 14))
        let markerScale = Float(0.45 + 0.75 * warning)
        marker.scale = SCNVector3(markerScale, markerScale, markerScale)
        marker.opacity = stream.isPouring ? 0.25 : CGFloat(0.45 + 0.55 * pulse)
        let shadowScale = Float(0.25 + warning)
        shadow.scale = SCNVector3(shadowScale, shadowScale, shadowScale)
        shadow.opacity = CGFloat(0.2 + 0.6 * warning)
        let fall = max(0, min(1, (warning - Self.fallStart) / (1 - Self.fallStart)))
        pivot.isHidden = fall <= 0
        let wobble = Float(1 + 0.12 * sin(clock * 17 + stream.phase))
        pivot.scale = SCNVector3(wobble, Float(max(0.001, fall * fall)), wobble)
        updatePour(stream.isPouring, dt: dt)
    }

    private func updatePour(_ pouring: Bool, dt: Double) {
        if pouring { pourAge += dt }
        let grown = Float(min(1, pourAge / Self.puddleSeconds))
        puddle.isHidden = !pouring
        glow.isHidden = !pouring
        let size = 0.3 + 0.7 * grown
        puddle.scale = SCNVector3(size, size, size)
        glow.scale = SCNVector3(size, size, size)
        let active = pouring && dt > 0
        splash.birthRate = active ? Self.splashRate * budget : 0
        drips.birthRate = active ? Self.dripRate * budget : 0
    }
}

/// Materials shared by every stream.
@MainActor
final class StreamKit {
    let warning: [SCNMaterial]
    let shadow: SCNMaterial
    let puddle: SCNMaterial
    let glow: SCNMaterial
    let column: SCNMaterial
    let core: SCNMaterial

    init(library: MaterialLibrary) {
        var steps: [SCNMaterial] = []
        let yellow = ColorValue(1, 0.9, 0.15)
        let red = ColorValue(1, 0.08, 0.05)
        for index in 0..<8 {
            let color = yellow.mixed(with: red, Double(index) / 7)
            steps.append(library.shared("warning-\(index)", bend: false) {
                let material = WorldMaterials.decal(SpriteTextures.warningRing, additive: true)
                material.multiply.contents = color.ui
                return material
            })
        }
        warning = steps
        shadow = library.shared("streamShadow", bend: false) { WorldMaterials.decal(SpriteTextures.shadowDisc, additive: false) }
        puddle = library.shared("puddle", bend: false) { WorldMaterials.decal(SpriteTextures.puddle, additive: false, lit: true) }
        glow = library.shared("splashGlow", bend: false) {
            let material = WorldMaterials.decal(SpriteTextures.lightPool, additive: true)
            material.multiply.contents = UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1)
            return material
        }
        column = library.shared("streamColumn", bend: false) {
            let material = WorldMaterials.decal(SpriteTextures.streamFlow, additive: false)
            material.emission.contents = SpriteTextures.streamFlow
            material.emission.intensity = 0.9
            material.cullMode = .back
            return material
        }
        core = library.shared("streamCore", bend: false) {
            WorldMaterials.glow(UIColor(red: 1, green: 0.88, blue: 0.3, alpha: 1), boost: 1.4)
        }
        WorldMaterials.repeating(column.diffuse, scaleX: 2, scaleY: 8)
        WorldMaterials.repeating(column.emission, scaleX: 2, scaleY: 8)
    }

    /// Runs the streaks down every column.
    func flow(clock: Double) {
        let shift = Float((clock * 2.2).truncatingRemainder(dividingBy: 1))
        let transform = SCNMatrix4Mult(SCNMatrix4MakeScale(2, 8, 1), SCNMatrix4MakeTranslation(0, shift, 0))
        column.diffuse.contentsTransform = transform
        column.emission.contentsTransform = transform
    }
}
