import SceneKit
import UIKit
import simd

/// Dirt bike, scooter, tractor and rocket. Each builder returns an unflattened subtree in rig space.
@MainActor
enum BikeBodiesOdd {
    private static var chrome: SCNMaterial { ModelMaterials.chrome }
    private static var dark: SCNMaterial { ModelMaterials.darkMetal }

    // MARK: - Dirt: tall long-travel fork, high fenders, number plates

    static func dirt(_ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        let node = SCNNode()
        BikeParts.forkAndBars(node, layout, gap: 0.09)
        ModelKit.add(ModelKit.box(0.16, 0.045, 0.045, chamfer: 0.015), palette.seat, to: node, at: layout.grip * RigVec(0, 1, 1))
        BikeParts.pegs(node, peg: layout.peg)
        ModelKit.pipe([layout.forkTop + RigVec(0, -0.06, 0.03), RigVec(0, 0.98, -0.1), RigVec(0, 1.0, 0.3)],
                      radius: 0.03, palette.trim, to: node)
        ModelKit.pipe([layout.forkTop + RigVec(0, -0.16, 0.02), RigVec(0, 0.42, -0.22), RigVec(0, 0.36, 0.1),
                       RigVec(0, 0.56, 0.24)], radius: 0.03, palette.trim, to: node)
        BikeParts.swingarm(node, pivot: RigVec(0, 0.56, 0.24), axle: layout.rearAxle, gap: 0.11, material: ModelMaterials.brushed)
        BikeParts.shock(node, from: RigVec(0, 0.6, 0.36), to: RigVec(0, 0.98, 0.14), spring: palette.glow)
        BikeParts.engine(node, center: RigVec(0, 0.6, -0.04), palette: palette)
        ModelKit.add(ModelKit.box(0.2, 0.04, 0.4, chamfer: 0.015), dark, to: node, at: RigVec(0, 0.32, -0.06))
        BikeShapes.curved(node, "dirtShroud", width: 0.4, chamfer: 0.12, palette.primary, start: (0.52, 1.12), steps: [
            .quad(0.1, 1.14, controlX: 0.3, controlY: 1.2),
            .line(0.06, 0.98),
            .quad(0.42, 0.84, controlX: 0.3, controlY: 0.86),
        ])
        BikeShapes.panel(node, "dirtSide", points: [(-0.12, 0.98), (-0.5, 1.02), (-0.46, 0.78), (-0.16, 0.8)],
                         width: 0.34, chamfer: 0.04, palette.secondary)
        BikeShapes.seat(node, front: 0.16, back: -0.62, base: 1.0, height: 0.07, width: 0.24, palette.seat, rearRise: 0.1)
        BikeShapes.curved(node, "dirtRearFender", width: 0.2, chamfer: 0.05, palette.primary, start: (-0.4, 1.0), steps: [
            .line(-1.05, 1.1), .line(-1.05, 1.07), .line(-0.42, 0.95),
        ])
        BikeShapes.curved(node, "dirtFrontFender", width: 0.17, chamfer: 0.05, palette.primary, start: (0.5, 0.96), steps: [
            .quad(1.1, 0.9, controlX: 0.84, controlY: 1.0),
            .line(1.08, 0.87),
            .quad(0.5, 0.92, controlX: 0.82, controlY: 0.95),
        ])
        BikeShapes.panel(node, "dirtPlate", points: [(0.62, 0.95), (0.6, 1.24), (0.53, 1.26), (0.55, 0.95)],
                         width: 0.26, chamfer: 0.03, palette.secondary)
        BikeParts.headlight(node, front: layout.headlight, radius: 0.055, bucket: ModelMaterials.blackPlastic)
        BikeParts.taillight(node, at: RigVec(0, 1.08, 1.04), width: 0.07, height: 0.03)
        BikeParts.exhaust(node, points: [RigVec(0.08, 0.62, -0.24), RigVec(0.16, 0.5, -0.05), RigVec(0.18, 0.76, 0.3),
                                         layout.exhaust], mufflerLength: 0.4, radius: 0.055)
        return node
    }

    // MARK: - Scooter: leg shield, floorboard, round rear body, small wheels

    static func scooter(_ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        let node = SCNNode()
        BikeParts.fork(node, axle: layout.frontAxle, top: layout.forkTop, gap: 0.055)
        BikeParts.handlebar(node, clamp: layout.forkTop, grip: layout.grip)
        BikeParts.mirrors(node, grip: layout.grip)
        ModelKit.add(ModelKit.box(0.3, 0.14, 0.18, chamfer: 0.06), palette.primary, to: node, at: RigVec(0, 1.1, -0.37))
        BikeParts.headlight(node, front: layout.headlight, radius: 0.06, bucket: palette.primary)
        BikeParts.indicators(node, at: RigVec(0, 1.1, -0.44), spread: 0.17)
        BikeShapes.curved(node, "scooterShield", width: 0.5, chamfer: 0.1, palette.primary, start: (0.26, 0.3), steps: [
            .quad(0.5, 1.0, controlX: 0.48, controlY: 0.5),
            .line(0.42, 1.02),
            .quad(0.2, 0.36, controlX: 0.36, controlY: 0.5),
        ])
        BikeShapes.fender(node, axle: layout.frontAxle, radius: 0.29, from: 0, to: 150, width: 0.16, palette.primary)
        ModelKit.add(ModelKit.box(0.36, 0.04, 0.5, chamfer: 0.015), palette.secondary, to: node, at: RigVec(0, 0.3, -0.06))
        for index in 0..<3 {
            ModelKit.add(ModelKit.box(0.3, 0.012, 0.025), ModelMaterials.rubber, to: node,
                         at: RigVec(0, 0.325, -0.22 + Float(index) * 0.13))
        }
        BikeShapes.curved(node, "scooterBody", width: 0.46, chamfer: 0.17, palette.primary, start: (-0.06, 0.3), steps: [
            .quad(-0.12, 0.74, controlX: -0.02, controlY: 0.6),
            .line(-0.66, 0.76),
            .quad(-0.84, 0.5, controlX: -0.9, controlY: 0.72),
            .quad(-0.3, 0.38, controlX: -0.6, controlY: 0.4),
        ])
        ModelKit.add(ModelKit.box(0.47, 0.03, 0.4), palette.glow, to: node, at: RigVec(0, 0.42, 0.46))
        BikeShapes.seat(node, front: -0.06, back: -0.7, base: 0.74, height: 0.08, width: 0.3, palette.seat, rearRise: 0.15)
        for side: Float in [-1, 1] {
            ModelKit.pipe([RigVec(side * 0.12, 0.8, 0.7), RigVec(side * 0.12, 0.86, 0.9)], radius: 0.012, chrome, to: node)
        }
        ModelKit.rod(RigVec(-0.12, 0.86, 0.9), RigVec(0.12, 0.86, 0.9), radius: 0.012, chrome, to: node)
        BikeParts.taillight(node, at: RigVec(0, 0.68, 0.855), width: 0.12, height: 0.05)
        ModelKit.rod(RigVec(0.06, 0.32, 0.36), layout.rearAxle + RigVec(0.06, 0, 0), radius: 0.04, dark, to: node)
        BikeParts.exhaust(node, points: [RigVec(0.1, 0.3, 0.3), RigVec(0.18, 0.28, 0.45), layout.exhaust],
                          mufflerLength: 0.26, radius: 0.05)
        return node
    }

    // MARK: - Tractor: hood and grille, giant twin rear wheels, smoke stack, steering wheel

    static func tractor(_ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        let node = SCNNode()
        ModelKit.add(ModelKit.box(0.44, 0.4, 0.78, chamfer: 0.07), palette.primary, to: node, at: RigVec(0, 0.76, -0.62))
        ModelKit.add(ModelKit.box(0.46, 0.05, 0.8, chamfer: 0.02), palette.secondary, to: node, at: RigVec(0, 0.86, -0.62))
        ModelKit.add(ModelKit.box(0.36, 0.32, 0.04), dark, to: node, at: RigVec(0, 0.74, -1.02))
        for index in 0..<4 {
            ModelKit.add(ModelKit.box(0.34, 0.016, 0.02), chrome, to: node,
                         at: RigVec(0, 0.63 + Float(index) * 0.07, -1.045))
        }
        for side: Float in [-1, 1] {
            BikeParts.headlight(node, front: RigVec(side * 0.15, 0.98, -1.03), radius: 0.05, bucket: dark)
            ModelKit.rod(RigVec(side * 0.12, 0.58, -0.86), layout.frontAxle + RigVec(side * 0.12, 0, 0),
                         radius: 0.03, dark, to: node)
            BikeShapes.fender(node, axle: layout.rearAxle, radius: 0.52, from: 20, to: 175, width: 0.28,
                              palette.secondary, thickness: 0.03, x: side * 0.32)
            BikeParts.taillight(node, at: RigVec(side * 0.32, 0.86, 1.03), width: 0.06, height: 0.04)
        }
        ModelKit.rod(layout.frontAxle + RigVec(-0.14, 0, 0), layout.frontAxle + RigVec(0.14, 0, 0), radius: 0.025, chrome, to: node)
        BikeShapes.fender(node, axle: layout.frontAxle, radius: 0.31, from: 10, to: 140, width: 0.19, palette.secondary)
        ModelKit.add(ModelKit.box(0.3, 0.2, 0.32), dark, to: node, at: RigVec(0, 0.46, -0.34))
        ModelKit.add(ModelKit.box(0.2, 0.2, 0.7), dark, to: node, at: RigVec(0, 0.55, 0.12))
        ModelKit.rod(RigVec(-0.44, 0.48, 0.52), RigVec(0.44, 0.48, 0.52), radius: 0.05, dark, to: node, rounded: false)
        ModelKit.add(ModelKit.box(0.56, 0.03, 0.36), ModelMaterials.brushed, to: node, at: RigVec(0, 0.6, 0.12))
        ModelKit.add(ModelKit.box(0.12, 0.08, 0.2), dark, to: node, at: RigVec(0, 0.45, 0.98))
        BikeParts.exhaust(node, points: [RigVec(0.22, 0.94, -0.6), layout.exhaust], mufflerLength: 0.3, radius: 0.05)
        ModelKit.rod(RigVec(-0.18, 0.94, -0.76), RigVec(-0.18, 1.22, -0.76), radius: 0.03, chrome, to: node)
        tractorCab(node, palette, layout)
        return node
    }

    private static func tractorCab(_ node: SCNNode, _ palette: BikePalette, _ layout: BikeLayout) {
        let wheelCenter = RigVec(0, layout.grip.y, layout.grip.z)
        let columnBase = RigVec(0, 0.94, -0.3)
        let normal = simd_normalize(wheelCenter - columnBase)
        ModelKit.rod(columnBase, wheelCenter, radius: 0.022, dark, to: node)
        let ring = ModelKit.add(ModelKit.torus(layout.grip.x, 0.02), ModelMaterials.blackPlastic, to: node, at: wheelCenter)
        ring.simdOrientation = ModelKit.orientation(alongY: normal)
        ModelKit.rod(ModelKit.mirrored(layout.grip), layout.grip, radius: 0.012, chrome, to: node)
        ModelKit.add(ModelKit.box(0.4, 0.1, 0.12, chamfer: 0.03), dark, to: node, at: RigVec(0, 0.98, -0.24))
        BikeBodiesStreet.gauge(node, at: RigVec(0.1, 1.04, -0.24), palette: palette)
        ModelKit.rod(RigVec(0, 0.62, 0.44), RigVec(0, 1.0, 0.44), radius: 0.03, dark, to: node)
        ModelKit.add(ModelKit.box(0.34, 0.08, 0.32, chamfer: 0.035), palette.seat, to: node, at: RigVec(0, 1.04, 0.46))
        ModelKit.add(ModelKit.box(0.34, 0.26, 0.06, chamfer: 0.03), palette.seat, to: node,
                     at: RigVec(0, 1.22, 0.64), euler: RigVec(-0.2, 0, 0))
        ModelKit.rod(RigVec(0, 1.3, 0.7), RigVec(0, 1.5, 0.7), radius: 0.015, dark, to: node)
        ModelKit.add(ModelKit.cylinder(0.05, 0.08), palette.glow, to: node, at: RigVec(0, 1.54, 0.7))
        ModelKit.add(ModelKit.sphere(0.05), palette.glow, to: node, at: RigVec(0, 1.58, 0.7))
    }

    // MARK: - Rocket: fuselage, nose cone, fins, glowing jet nozzle

    static func rocket(_ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        let node = SCNNode()
        let axisY: Float = 0.82
        let along = RigVec(.pi / 2, 0, 0)
        ModelKit.add(ModelKit.cylinder(0.22, 1.84), palette.primary, to: node, at: RigVec(0, axisY, 0), euler: along)
        ModelKit.add(ModelKit.cone(0, 0.22, 0.42), palette.secondary, to: node, at: RigVec(0, axisY, -1.13),
                     euler: RigVec(-.pi / 2, 0, 0))
        ModelKit.add(ModelKit.sphere(0.03), ModelMaterials.headlightLens, to: node, at: layout.headlight)
        for bandZ: Float in [-0.55, 0.55] {
            ModelKit.add(ModelKit.cylinder(0.227, 0.06), palette.secondary, to: node, at: RigVec(0, axisY, bandZ), euler: along)
        }
        ModelKit.add(ModelKit.torus(0.222, 0.012), palette.glow, to: node, at: RigVec(0, axisY, 0.86), euler: along)
        for side: Float in [-1, 1] {
            let port = RigVec(side * 0.212, axisY + 0.05, -0.62)
            ModelKit.add(ModelKit.cylinder(0.06, 0.02), ModelMaterials.visor(palette.style.glow), to: node,
                         at: port, euler: RigVec(0, 0, .pi / 2))
            ModelKit.add(ModelKit.torus(0.06, 0.012), chrome, to: node, at: port, euler: RigVec(0, 0, .pi / 2))
            ModelKit.rod(layout.rearAxle + RigVec(side * 0.08, 0, 0), RigVec(side * 0.08, 0.66, 0.5),
                         radius: 0.03, dark, to: node)
        }
        ModelKit.add(ModelKit.cone(0.13, 0.2, 0.3), dark, to: node, at: RigVec(0, axisY, 1.07), euler: RigVec(-.pi / 2, 0, 0))
        ModelKit.add(ModelKit.cylinder(0.17, 0.02), ModelMaterials.glow(palette.style.glow, strength: 1.4), to: node,
                     at: RigVec(0, axisY, 1.2), euler: along)
        for angle: Float in [0, 2 * .pi / 3, -2 * .pi / 3] {
            let finHolder = SCNNode()
            finHolder.simdPosition = RigVec(0, axisY, 0)
            finHolder.simdEulerAngles = RigVec(0, 0, angle)
            BikeShapes.panel(finHolder, "rocketFin", points: [(-0.42, 0.18), (-0.9, 0.18), (-1.04, 0.52), (-0.86, 0.52)],
                             width: 0.03, chamfer: 0.012, palette.secondary)
            node.addChildNode(finHolder)
        }
        BikeParts.fork(node, axle: layout.frontAxle, top: layout.forkTop, gap: 0.08)
        let clamp = RigVec(0, 1.04, layout.grip.z - 0.04)
        ModelKit.rod(RigVec(0, 0.96, clamp.z), clamp, radius: 0.03, dark, to: node)
        BikeParts.handlebar(node, clamp: clamp, grip: layout.grip)
        BikeShapes.seat(node, front: 0.14, back: -0.34, base: 1.02, height: 0.06, width: 0.26, palette.seat, rearRise: 0.4)
        BikeParts.pegs(node, peg: layout.peg)
        return node
    }
}
