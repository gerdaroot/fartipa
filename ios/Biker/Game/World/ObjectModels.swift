import SceneKit
import UIKit

/// Poop piles, coins and pickups.
@MainActor
enum ObjectModels {
    static let coinHeight = 1.0
    static let pickupHeight = 1.35
    /// One disc geometry per coin kind, shared by every pooled coin (one vertex buffer, same materials).
    private static var coinDiscs: [Bool: SCNGeometry] = [:]

    static func pile(library: MaterialLibrary, seed: UInt64) -> SimpleItem {
        var random = SplitMix(seed: seed)
        let brown = library.shared("pileBrown", bend: false) {
            WorldMaterials.pbr(UIColor(red: 0.3, green: 0.17, blue: 0.07, alpha: 1), roughness: 0.22)
        }
        let corn = library.shared("pileCorn", bend: false) {
            WorldMaterials.pbr(UIColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1), roughness: 0.4)
        }
        let shape = SCNNode()
        let tiers: [(radius: Double, y: Double)] = [(0.85, 0.36), (0.62, 0.9), (0.4, 1.32)]
        for tier in tiers {
            let sphere = SCNSphere(radius: CGFloat(tier.radius))
            sphere.segmentCount = 18
            sphere.firstMaterial = brown
            let node = SCNNode(geometry: sphere)
            node.position = Shapes.v(random.unit() * 0.1 - 0.05, tier.y, 0)
            node.scale = SCNVector3(1, 0.62, 1)
            shape.addChildNode(node)
        }
        let tip = SCNCone(topRadius: 0, bottomRadius: 0.22, height: 0.5)
        tip.firstMaterial = brown
        let tipNode = SCNNode(geometry: tip)
        tipNode.position = Shapes.v(0.05, 1.7, 0)
        tipNode.eulerAngles.z = -0.35
        shape.addChildNode(tipNode)
        for _ in 0..<5 {
            let bit = SCNCapsule(capRadius: 0.06, height: 0.2)
            bit.firstMaterial = corn
            let node = SCNNode(geometry: bit)
            let angle = random.unit() * 2 * .pi
            node.position = Shapes.v(cos(angle) * 0.7, 0.35 + random.unit() * 0.6, sin(angle) * 0.7)
            node.eulerAngles = Shapes.v(random.unit() * 3, 0, random.unit() * 3)
            shape.addChildNode(node)
        }
        let root = SCNNode()
        root.addChildNode(library.flatten(shape))
        let stinkNode = SCNNode()
        stinkNode.position = Shapes.v(0, 1.6, 0)
        stinkNode.addParticleSystem(WorldParticles.stink())
        root.addChildNode(stinkNode)
        return SimpleItem(root: root)
    }

    /// A spinning coin standing on its edge. Golden ones are bigger with a halo.
    static func coin(library: MaterialLibrary, golden: Bool) -> SimpleItem {
        let edge = library.shared("coinEdge", bend: false) {
            WorldMaterials.pbr(UIColor(red: 0.95, green: 0.66, blue: 0.16, alpha: 1), metalness: 1, roughness: 0.25)
        }
        let picture = golden ? BikeTextures.goldenCoinImage : BikeTextures.coinImage
        let face = library.shared(golden ? "goldenFace" : "coinFace", bend: false) {
            let material = WorldMaterials.pbr(.white, metalness: 0.75, roughness: 0.3)
            material.diffuse.contents = picture
            material.emission.contents = picture
            material.emission.intensity = golden ? 1 : 0.45
            WorldMaterials.mipmapped(material.diffuse)
            WorldMaterials.mipmapped(material.emission)
            return material
        }
        let disc: SCNGeometry
        if let cached = coinDiscs[golden] {
            disc = cached
        } else {
            let made = SCNCylinder(radius: golden ? 0.78 : 0.55, height: golden ? 0.14 : 0.1)
            made.radialSegmentCount = 20
            made.materials = [edge, face, face]
            coinDiscs[golden] = made
            disc = made
        }
        let discNode = SCNNode(geometry: disc)
        discNode.eulerAngles.x = .pi / 2
        let spinner = SCNNode()
        spinner.addChildNode(discNode)
        spinner.position = Shapes.v(0, coinHeight + (golden ? 0.3 : 0), 0)
        let root = SCNNode()
        root.addChildNode(spinner)
        if golden {
            let halo = library.shared("coinHalo", bend: false) {
                let material = WorldMaterials.decal(SpriteTextures.softDot, additive: true)
                material.multiply.contents = UIColor(red: 1, green: 0.8, blue: 0.25, alpha: 1)
                return material
            }
            root.addChildNode(Shapes.panel(3, 3, halo, at: Shapes.v(0, coinHeight + 0.3, -0.2)))
        }
        root.disableShadows()
        return SimpleItem(root: root, spinner: spinner)
    }

    /// A floating glowing badge with a light beam and a ring on the road.
    static func pickup(_ kind: PickupKind, library: MaterialLibrary) -> SimpleItem {
        let tint = PickupIcons.color(kind)
        let icon = library.shared("pickupIcon-\(kind.rawValue)", bend: false) {
            let material = WorldMaterials.screen(PickupIcons.image(kind), boost: 1.2)
            material.transparencyMode = .aOne
            material.writesToDepthBuffer = false
            return material
        }
        let ring = library.shared("pickupRing-\(kind.rawValue)", bend: false) {
            let material = WorldMaterials.decal(SpriteTextures.bubble, additive: true)
            material.multiply.contents = tint.ui
            return material
        }
        let beam = library.shared("pickupBeam-\(kind.rawValue)", bend: false) {
            let material = WorldMaterials.decal(SpriteTextures.lightPool, additive: true)
            material.multiply.contents = tint.ui
            material.isDoubleSided = true
            return material
        }
        let spinner = SCNNode()
        spinner.position = Shapes.v(0, pickupHeight, 0)
        let badge = Shapes.panel(1.5, 1.5, icon, at: Shapes.v(0, 0, 0))
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        badge.constraints = [billboard]
        spinner.addChildNode(badge)
        let root = SCNNode()
        root.addChildNode(spinner)
        root.addChildNode(Shapes.decal(2.6, 2.6, ring, at: Shapes.v(0, 0.04, 0)))
        let beamNode = Shapes.panel(1.4, 5, beam, at: Shapes.v(0, 2.5, 0))
        let beamBillboard = SCNBillboardConstraint()
        beamBillboard.freeAxes = .Y
        beamNode.constraints = [beamBillboard]
        root.addChildNode(beamNode)
        root.disableShadows()
        return SimpleItem(root: root, spinner: spinner)
    }
}
