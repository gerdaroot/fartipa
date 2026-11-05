import SceneKit
import UIKit
import simd

/// The toilet on wheels and the bike made of one giant poop.
@MainActor
enum BikeBodiesPotty {
    private static var chrome: SCNMaterial { ModelMaterials.chrome }
    private static let oval = RigVec(1, 1, 1.25)

    // MARK: - Toilet: bowl seat, cistern backrest, paper roll on the bars

    static func toilet(_ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        let node = SCNNode()
        let porcelain = ModelMaterials.porcelain(palette.style.primary)
        BikeParts.forkAndBars(node, layout)
        BikeParts.pegs(node, peg: layout.peg)
        ModelKit.add(ModelKit.cone(0.15, 0.2, 0.3), porcelain, to: node, at: RigVec(0, 0.45, 0.16), scale: oval)
        ModelKit.add(ModelKit.box(0.44, 0.04, 0.54, chamfer: 0.015), palette.trim, to: node, at: RigVec(0, 0.3, 0.16))
        ModelKit.add(ModelKit.cone(0.27, 0.15, 0.32), porcelain, to: node, at: RigVec(0, 0.74, 0.14), scale: oval)
        ModelKit.add(ModelKit.torus(0.25, 0.04), porcelain, to: node, at: RigVec(0, 0.9, 0.14), scale: oval)
        ModelKit.add(ModelKit.cylinder(0.22, 0.01), ModelMaterials.glow(palette.style.glow, strength: 0.6), to: node,
                     at: RigVec(0, 0.86, 0.14), scale: oval)
        ModelKit.add(ModelKit.torus(0.235, 0.034), palette.secondary, to: node, at: RigVec(0, 0.935, 0.14), scale: oval)
        ModelKit.add(ModelKit.cylinder(0.25, 0.03), palette.secondary, to: node, at: RigVec(0, 1.18, 0.4),
                     euler: RigVec(.pi / 2 - 0.25, 0, 0), scale: RigVec(1, 1, 1.25))
        ModelKit.add(ModelKit.box(0.48, 0.42, 0.2, chamfer: 0.04), porcelain, to: node, at: RigVec(0, 1.12, 0.56))
        ModelKit.add(ModelKit.box(0.52, 0.05, 0.24, chamfer: 0.02), porcelain, to: node, at: RigVec(0, 1.355, 0.56))
        ModelKit.rod(RigVec(0.17, 1.26, 0.45), RigVec(0.27, 1.26, 0.43), radius: 0.012, chrome, to: node)
        ModelKit.add(ModelKit.sphere(0.025), chrome, to: node, at: RigVec(0.17, 1.26, 0.45))
        ModelKit.rod(RigVec(0, 0.94, 0.5), RigVec(0, 0.8, 0.36), radius: 0.025, chrome, to: node)
        toiletFrame(node, palette, layout)
        toiletExtras(node, palette, layout)
        return node
    }

    private static func toiletFrame(_ node: SCNNode, _ palette: BikePalette, _ layout: BikeLayout) {
        ModelKit.pipe([RigVec(0, 0.34, -0.08), RigVec(0, 0.6, -0.32), layout.forkTop + RigVec(0, -0.08, 0.03)],
                      radius: 0.035, palette.trim, to: node)
        BikeParts.swingarm(node, pivot: RigVec(0, 0.34, 0.3), axle: layout.rearAxle, gap: 0.12, material: palette.trim)
        for side: Float in [-1, 1] {
            ModelKit.rod(RigVec(side * 0.12, 0.92, 0.6), layout.rearAxle + RigVec(side * 0.12, 0, 0),
                         radius: 0.025, palette.trim, to: node)
        }
        BikeParts.headlight(node, front: layout.headlight, radius: 0.09, bucket: palette.trim)
        BikeParts.taillight(node, at: RigVec(0, 1.14, 0.665), width: 0.22, height: 0.04)
        BikeParts.exhaust(node, points: [RigVec(0, 0.5, 0.3), RigVec(0.12, 0.42, 0.5), RigVec(0.18, 0.4, 0.66),
                                         layout.exhaust], mufflerLength: 0.24, radius: 0.05)
    }

    private static func toiletExtras(_ node: SCNNode, _ palette: BikePalette, _ layout: BikeLayout) {
        let rollCenter = RigVec(0, layout.grip.y + 0.065, layout.grip.z)
        ModelKit.add(ModelKit.tube(0.025, 0.065, 0.12), ModelMaterials.paper, to: node, at: rollCenter,
                     euler: RigVec(0, 0, .pi / 2))
        ModelKit.add(ModelKit.tube(0.02, 0.026, 0.124), ModelMaterials.cardboard, to: node, at: rollCenter,
                     euler: RigVec(0, 0, .pi / 2))
        ModelKit.add(ModelKit.box(0.1, 0.2, 0.004), ModelMaterials.paper, to: node,
                     at: rollCenter + RigVec(0, -0.1, -0.066))
        let cup = ModelMaterials.pbr("plungerCup", diffuse: UIColor(red: 0.75, green: 0.08, blue: 0.08, alpha: 1),
                                     metal: 0, rough: 0.35, clearCoat: 0.6)
        ModelKit.rod(RigVec(-0.27, 0.52, 0.0), RigVec(-0.27, 0.98, 0.24), radius: 0.016, ModelMaterials.wood, to: node)
        ModelKit.add(ModelKit.cone(0.025, 0.07, 0.08), cup, to: node, at: RigVec(-0.27, 0.49, -0.015),
                     euler: RigVec(0.48, 0, 0))
    }

    // MARK: - Turd: a giant poop log with a swirl backrest, googly eyes and flies

    private struct Knot {
        let z: Float
        let y: Float
        let radius: Float
    }

    private static let spine: [Knot] = [
        Knot(z: 0.98, y: 0.6, radius: 0.13), Knot(z: 0.7, y: 0.66, radius: 0.22), Knot(z: 0.36, y: 0.74, radius: 0.27),
        Knot(z: 0.0, y: 0.76, radius: 0.27), Knot(z: -0.34, y: 0.8, radius: 0.23), Knot(z: -0.6, y: 0.86, radius: 0.17),
    ]

    static func turd(_ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        let node = SCNNode()
        let poop = ModelMaterials.poop(palette.style.primary)
        let ridge = ModelMaterials.poop(palette.style.secondary)
        BikeParts.forkAndBars(node, layout)
        BikeParts.pegs(node, peg: layout.peg)
        BikeParts.swingarm(node, pivot: RigVec(0, 0.5, 0.3), axle: layout.rearAxle, gap: 0.12, material: ModelMaterials.darkMetal)
        for (index, knot) in spine.enumerated() {
            let center = RigVec(0, knot.y, knot.z)
            ModelKit.add(ModelKit.sphere(knot.radius), poop, to: node, at: center)
            guard index > 0 else { continue }
            let previous = spine[index - 1]
            let start = RigVec(0, previous.y, previous.z)
            let radius = min(previous.radius, knot.radius) * 0.96
            ModelKit.rod(start, center, radius: radius, poop, to: node)
            let ring = ModelKit.add(ModelKit.torus(radius * 0.97, 0.045), ridge, to: node, at: (start + center) * 0.5)
            ring.simdOrientation = ModelKit.orientation(alongY: simd_normalize(center - start))
        }
        let swirl: [(Float, Float, Float)] = [(0.17, 0.08, 0.94), (0.11, 0.07, 1.06), (0.06, 0.055, 1.16)]
        for (ringRadius, pipe, height) in swirl {
            ModelKit.add(ModelKit.torus(ringRadius, pipe), poop, to: node, at: RigVec(0, height, 0.64))
        }
        ModelKit.add(ModelKit.cone(0, 0.07, 0.14), poop, to: node, at: RigVec(0, 1.25, 0.66), euler: RigVec(0.3, 0, 0))
        turdFace(node, palette, layout, poop: poop)
        return node
    }

    private static func turdFace(_ node: SCNNode, _ palette: BikePalette, _ layout: BikeLayout, poop: SCNMaterial) {
        for side: Float in [-1, 1] {
            ModelKit.add(ModelKit.sphere(0.07), ModelMaterials.eyeWhite, to: node, at: RigVec(side * 0.09, 0.99, -0.6))
            ModelKit.add(ModelKit.sphere(0.033), palette.glow, to: node, at: RigVec(side * 0.09, 0.99, -0.66))
        }
        BikeParts.headlight(node, front: layout.headlight, radius: 0.07, bucket: poop)
        let corn = ModelMaterials.plastic(RGB(r: 0.98, g: 0.84, b: 0.22))
        let kernels: [RigVec] = [RigVec(0.2, 0.92, 0.42), RigVec(-0.22, 0.86, 0.1), RigVec(0.16, 0.72, -0.44)]
        for kernel in kernels {
            ModelKit.add(ModelKit.capsule(0.024, 0.07), corn, to: node, at: kernel, euler: RigVec(0.6, 0.4, 0.9))
        }
        let flyBody = ModelMaterials.blackPlastic
        let flyWing = ModelMaterials.pbr("flyWing", diffuse: UIColor(white: 0.8, alpha: 1), metal: 0.3, rough: 0.2,
                                         doubleSided: true)
        let flies: [RigVec] = [RigVec(0.26, 1.32, 0.74), RigVec(-0.22, 1.42, 0.52), RigVec(0.04, 1.52, 0.86)]
        for fly in flies {
            ModelKit.add(ModelKit.sphere(0.022), flyBody, to: node, at: fly)
            ModelKit.add(ModelKit.box(0.07, 0.003, 0.03), flyWing, to: node, at: fly + RigVec(0, 0.02, 0), euler: RigVec(0, 0.4, 0))
        }
        ModelKit.add(ModelKit.torus(0.06, 0.015), chrome, to: node, at: layout.exhaust + RigVec(0, 0, -0.02),
                     euler: RigVec(.pi / 2, 0, 0))
        BikeParts.taillight(node, at: RigVec(0, 0.735, 0.97), width: 0.1, height: 0.03)
    }
}
