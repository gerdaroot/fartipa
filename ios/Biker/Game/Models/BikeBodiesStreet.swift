import SceneKit
import UIKit
import simd

/// Road bikes: naked, sport, chopper and cruiser. Each builder returns an unflattened subtree
/// in rig space (wheels excluded).
@MainActor
enum BikeBodiesStreet {
    private static var chrome: SCNMaterial { ModelMaterials.chrome }

    // MARK: - Naked: round headlight, exposed engine, flat bars

    static func naked(_ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        let node = SCNNode()
        let frame = palette.trim
        BikeParts.forkAndBars(node, layout)
        BikeParts.mirrors(node, grip: layout.grip)
        BikeParts.pegs(node, peg: layout.peg)
        let head = layout.forkTop + RigVec(0, -0.06, 0.03)
        let pivot = RigVec(0, 0.5, 0.26)
        ModelKit.pipe([head, RigVec(0, 0.84, -0.1), RigVec(0, 0.86, 0.36), RigVec(0, 0.86, 0.62)],
                      radius: 0.032, frame, to: node)
        ModelKit.pipe([head + RigVec(0, -0.1, 0), RigVec(0, 0.36, -0.22), RigVec(0, 0.32, 0.12), pivot],
                      radius: 0.03, frame, to: node)
        ModelKit.rod(RigVec(0, 0.84, -0.05), pivot, radius: 0.028, frame, to: node)
        BikeParts.swingarm(node, pivot: pivot, axle: layout.rearAxle, gap: 0.12, material: frame)
        for side: Float in [-1, 1] {
            BikeParts.shock(node, from: RigVec(side * 0.12, 0.42, 0.6), to: RigVec(side * 0.11, 0.85, 0.38),
                            spring: palette.glow)
        }
        BikeParts.engine(node, center: RigVec(0, 0.5, -0.06), palette: palette)
        BikeShapes.tank(node, front: 0.44, back: -0.08, base: 0.8, height: 0.25, width: 0.36, palette.primary)
        BikeShapes.seat(node, front: 0.04, back: -0.58, base: 0.82, height: 0.09, width: 0.3, palette.seat)
        BikeShapes.panel(node, "nakedTail", points: [(-0.3, 0.78), (-0.62, 0.84), (-0.87, 0.96), (-0.87, 0.89), (-0.6, 0.74)],
                         width: 0.22, chamfer: 0.06, palette.secondary)
        BikeParts.taillight(node, at: RigVec(0, 0.93, 0.885), width: 0.1, height: 0.04)
        BikeShapes.fender(node, axle: layout.rearAxle, radius: 0.37, from: 95, to: 160, width: 0.16, palette.secondary)
        BikeShapes.fender(node, axle: layout.frontAxle, radius: 0.37, from: 25, to: 120, width: 0.14, palette.primary)
        BikeParts.headlight(node, front: layout.headlight, radius: 0.09, bucket: chrome)
        BikeParts.indicators(node, at: layout.headlight + RigVec(0, 0, 0.1), spread: 0.15)
        BikeParts.indicators(node, at: RigVec(0, 0.9, 0.84), spread: 0.12)
        gauge(node, at: layout.forkTop + RigVec(0, 0.09, -0.02), palette: palette)
        BikeParts.exhaust(node, points: [RigVec(0.1, 0.42, -0.22), RigVec(0.16, 0.32, 0.06), RigVec(0.2, 0.44, 0.48),
                                         layout.exhaust], mufflerLength: 0.38, radius: 0.06)
        return node
    }

    static func gauge(_ node: SCNNode, at center: RigVec, palette: BikePalette) {
        ModelKit.add(ModelKit.cylinder(0.06, 0.05), ModelMaterials.blackPlastic, to: node, at: center,
                     euler: RigVec(-1.1, 0, 0))
        ModelKit.add(ModelKit.cylinder(0.048, 0.052), palette.glow, to: node, at: center + RigVec(0, 0.002, 0.001),
                     euler: RigVec(-1.1, 0, 0))
    }

    // MARK: - Sport: full fairing, screen, clip-ons, tucked rider

    static func sport(_ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        let node = SCNNode()
        BikeParts.forkAndBars(node, layout, gap: 0.09)
        BikeParts.pegs(node, peg: layout.peg)
        BikeParts.mirrors(node, grip: RigVec(0.24, 0.92, -0.58))
        let spar = ModelMaterials.brushed
        for side: Float in [-1, 1] {
            ModelKit.pipe([layout.forkTop + RigVec(side * 0.06, -0.05, 0.04), RigVec(side * 0.14, 0.7, -0.1),
                           RigVec(side * 0.13, 0.54, 0.3)], radius: 0.04, spar, to: node)
        }
        BikeParts.swingarm(node, pivot: RigVec(0, 0.5, 0.3), axle: layout.rearAxle, gap: 0.12, material: spar)
        BikeParts.shock(node, from: RigVec(0, 0.46, 0.46), to: RigVec(0, 0.82, 0.3), spring: palette.glow)
        ModelKit.add(ModelKit.box(0.3, 0.3, 0.46, chamfer: 0.06), ModelMaterials.darkMetal, to: node, at: RigVec(0, 0.5, -0.08))
        sportFairing(node, palette)
        BikeShapes.tank(node, front: 0.38, back: -0.06, base: 0.84, height: 0.2, width: 0.38, palette.primary)
        BikeShapes.seat(node, front: 0.02, back: -0.38, base: 0.9, height: 0.07, width: 0.26, palette.seat, rearRise: 0.2)
        BikeShapes.curved(node, "sportTail", width: 0.26, chamfer: 0.08, palette.secondary, start: (-0.02, 0.8), steps: [
            .line(-0.04, 0.92),
            .quad(-0.86, 1.08, controlX: -0.6, controlY: 0.98),
            .line(-0.88, 1.02),
            .quad(-0.3, 0.74, controlX: -0.5, controlY: 0.8),
        ])
        BikeParts.taillight(node, at: RigVec(0, 1.04, 0.885), width: 0.1, height: 0.035)
        BikeShapes.fender(node, axle: layout.frontAxle, radius: 0.37, from: 15, to: 110, width: 0.13, palette.primary)
        BikeShapes.fender(node, axle: layout.rearAxle, radius: 0.37, from: 100, to: 160, width: 0.17, ModelMaterials.blackPlastic)
        BikeParts.exhaust(node, points: [RigVec(0.1, 0.36, -0.25), RigVec(0.14, 0.3, 0.15), RigVec(0.18, 0.5, 0.44),
                                         layout.exhaust], mufflerLength: 0.36, radius: 0.07)
        return node
    }

    private static func sportFairing(_ node: SCNNode, _ palette: BikePalette) {
        BikeShapes.curved(node, "sportFairing", width: 0.46, chamfer: 0.15, palette.primary, start: (0.9, 0.74), steps: [
            .quad(0.62, 0.96, controlX: 0.82, controlY: 0.94),
            .line(0.36, 0.92),
            .quad(0.3, 0.56, controlX: 0.24, controlY: 0.78),
            .line(0.02, 0.32),
            .line(0.4, 0.3),
            .quad(0.9, 0.74, controlX: 0.74, controlY: 0.36),
        ])
        BikeShapes.curved(node, "sportBelly", width: 0.3, chamfer: 0.08, palette.secondary, start: (0.46, 0.27), steps: [
            .line(0.0, 0.29), .line(-0.04, 0.42), .line(0.32, 0.36),
        ])
        let screen = ModelMaterials.visor(RGB(r: 0.25, g: 0.3, b: 0.36))
        BikeShapes.curved(node, "sportScreen", width: 0.3, chamfer: 0.02, screen, start: (0.66, 0.94), steps: [
            .quad(0.42, 1.1, controlX: 0.58, controlY: 1.08),
            .line(0.4, 1.05),
            .quad(0.6, 0.92, controlX: 0.52, controlY: 1.0),
        ])
        for side: Float in [-1, 1] {
            ModelKit.add(ModelKit.capsule(0.032, 0.15), ModelMaterials.headlightLens, to: node,
                         at: RigVec(side * 0.075, 0.8, -0.86), euler: RigVec(0, 0, .pi / 2))
        }
        ModelKit.add(ModelKit.box(0.22, 0.014, 0.03), palette.glow, to: node, at: RigVec(0, 0.755, -0.87))
        ModelKit.add(ModelKit.box(0.32, 0.012, 0.5), palette.glow, to: node, at: RigVec(0, 0.29, -0.2))
    }

    // MARK: - Chopper: long raked fork, ape hangers, sissy bar

    static func chopper(_ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        let node = SCNNode()
        let frame = palette.primary
        BikeParts.fork(node, axle: layout.frontAxle, top: layout.forkTop, gap: 0.085)
        BikeParts.handlebar(node, clamp: layout.forkTop, grip: layout.grip)
        BikeParts.pegs(node, peg: layout.peg)
        ModelKit.pipe([layout.forkTop + RigVec(0, -0.04, 0.04), RigVec(0, 0.86, -0.1), RigVec(0, 0.78, 0.38)],
                      radius: 0.034, frame, to: node)
        ModelKit.pipe([layout.forkTop + RigVec(0, -0.14, 0.03), RigVec(0, 0.32, -0.32), RigVec(0, 0.3, 0.16)],
                      radius: 0.032, frame, to: node)
        for side: Float in [-1, 1] {
            let axle = layout.rearAxle + RigVec(side * 0.11, 0, 0)
            ModelKit.rod(RigVec(side * 0.1, 0.3, 0.16), axle, radius: 0.028, frame, to: node)
            ModelKit.rod(RigVec(side * 0.1, 0.78, 0.38), axle, radius: 0.028, frame, to: node)
            ModelKit.pipe([RigVec(side * 0.13, 0.72, 0.84), RigVec(side * 0.13, 1.6, 0.72), RigVec(side * 0.06, 1.7, 0.7)],
                          radius: 0.016, chrome, to: node)
        }
        ModelKit.rod(RigVec(-0.06, 1.7, 0.7), RigVec(0.06, 1.7, 0.7), radius: 0.016, chrome, to: node)
        ModelKit.add(ModelKit.box(0.24, 0.26, 0.06, chamfer: 0.025), palette.seat, to: node,
                     at: RigVec(0, 1.12, 0.76), euler: RigVec(-0.12, 0, 0))
        ModelKit.rod(layout.rearAxle + RigVec(-0.14, 0, 0), layout.rearAxle + RigVec(0.14, 0, 0),
                     radius: 0.02, chrome, to: node)
        BikeParts.vTwin(node, center: RigVec(0, 0.46, -0.06), palette: palette)
        BikeShapes.tank(node, front: 0.52, back: 0.06, base: 0.86, height: 0.2, width: 0.26, palette.primary)
        BikeShapes.seat(node, front: 0.02, back: -0.42, base: 0.74, height: 0.07, width: 0.3, palette.seat, rearRise: 0.45)
        BikeShapes.fender(node, axle: layout.rearAxle, radius: 0.4, from: 40, to: 175, width: 0.23, palette.secondary)
        BikeParts.taillight(node, at: RigVec(0, 0.74, 0.97), width: 0.08, height: 0.04)
        BikeParts.headlight(node, front: layout.headlight, radius: 0.085, bucket: chrome)
        BikeParts.exhaust(node, points: [RigVec(0.1, 0.62, -0.18), RigVec(0.2, 0.46, 0.0), layout.exhaust],
                          mufflerLength: 0.26, radius: 0.045)
        BikeParts.exhaust(node, points: [RigVec(0.1, 0.58, 0.08), RigVec(0.2, 0.57, 0.2), RigVec(0.24, 0.57, 1.0)],
                          mufflerLength: 0.26, radius: 0.045)
        return node
    }

    // MARK: - Cruiser: fat tank, deep fenders, floorboards, saddlebags, screen

    static func cruiser(_ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        let node = SCNNode()
        BikeParts.forkAndBars(node, layout, gap: 0.11)
        for side: Float in [-1, 1] {
            ModelKit.rod(RigVec(side * 0.11, 0.72, -0.73), layout.forkTop + RigVec(side * 0.11, -0.04, 0),
                         radius: 0.046, palette.primary, to: node)
            ModelKit.add(ModelKit.box(0.13, 0.025, 0.3, chamfer: 0.01), ModelMaterials.brushed, to: node,
                         at: RigVec(side * 0.25, layout.peg.y - 0.02, layout.peg.z))
            ModelKit.rod(RigVec(side * 0.1, 0.34, -0.3), RigVec(side * 0.2, 0.34, -0.32), radius: 0.015, chrome, to: node)
        }
        ModelKit.pipe([layout.forkTop + RigVec(0, -0.05, 0.04), RigVec(0, 0.82, -0.1), RigVec(0, 0.76, 0.4),
                       RigVec(0, 0.64, 0.76)], radius: 0.034, palette.trim, to: node)
        ModelKit.pipe([layout.forkTop + RigVec(0, -0.14, 0.03), RigVec(0, 0.3, -0.36), RigVec(0, 0.28, 0.2),
                       layout.rearAxle], radius: 0.032, palette.trim, to: node)
        BikeParts.vTwin(node, center: RigVec(0, 0.46, -0.12), palette: palette)
        BikeShapes.tank(node, front: 0.52, back: -0.06, base: 0.8, height: 0.28, width: 0.42, palette.primary)
        ModelKit.rod(RigVec(0, 1.075, -0.44), RigVec(0, 1.04, -0.02), radius: 0.016, chrome, to: node)
        gauge(node, at: RigVec(0, 1.08, -0.24), palette: palette)
        BikeShapes.seat(node, front: 0.04, back: -0.58, base: 0.72, height: 0.1, width: 0.36, palette.seat, rearRise: 0.5)
        BikeShapes.fender(node, axle: layout.frontAxle, radius: 0.37, from: -5, to: 150, width: 0.2, palette.primary)
        BikeShapes.fender(node, axle: layout.rearAxle, radius: 0.38, from: 20, to: 185, width: 0.26, palette.primary)
        cruiserTouring(node, palette, layout)
        return node
    }

    private static func cruiserTouring(_ node: SCNNode, _ palette: BikePalette, _ layout: BikeLayout) {
        let bags = ModelMaterials.leather(palette.style.secondary)
        for side: Float in [-1, 1] {
            ModelKit.add(ModelKit.box(0.16, 0.25, 0.42, chamfer: 0.06), bags, to: node, at: RigVec(side * 0.31, 0.62, 0.64))
            ModelKit.add(ModelKit.box(0.02, 0.06, 0.04), chrome, to: node, at: RigVec(side * 0.395, 0.66, 0.64))
            ModelKit.pipe([RigVec(side * 0.13, 0.8, 0.52), RigVec(side * 0.11, 1.14, 0.6)], radius: 0.014, chrome, to: node)
            BikeParts.headlight(node, front: RigVec(side * 0.18, 0.8, -0.74), radius: 0.045, bucket: chrome)
        }
        ModelKit.rod(RigVec(-0.18, 0.8, -0.66), RigVec(0.18, 0.8, -0.66), radius: 0.014, chrome, to: node)
        ModelKit.add(ModelKit.box(0.26, 0.17, 0.06, chamfer: 0.025), palette.seat, to: node,
                     at: RigVec(0, 1.1, 0.6), euler: RigVec(-0.15, 0, 0))
        BikeParts.headlight(node, front: layout.headlight, radius: 0.11, bucket: chrome)
        let screen = ModelMaterials.visor(RGB(r: 0.55, g: 0.65, b: 0.75))
        BikeShapes.curved(node, "cruiserScreen", width: 0.5, chamfer: 0.012, screen, start: (0.66, 0.98), steps: [
            .quad(0.56, 1.36, controlX: 0.64, controlY: 1.24),
            .line(0.54, 1.35),
            .quad(0.63, 0.98, controlX: 0.61, controlY: 1.22),
        ])
        BikeParts.taillight(node, at: RigVec(0, 0.62, 1.1), width: 0.1, height: 0.04)
        BikeParts.exhaust(node, points: [RigVec(0.1, 0.5, -0.3), RigVec(0.2, 0.32, -0.1), RigVec(0.25, 0.3, 0.4),
                                         layout.exhaust], mufflerLength: 0.42, radius: 0.055)
        BikeParts.exhaust(node, points: [RigVec(0.1, 0.62, 0.06), RigVec(0.2, 0.44, 0.2), RigVec(0.25, 0.44, 0.6),
                                         RigVec(0.25, 0.45, 1.0)], mufflerLength: 0.36, radius: 0.05)
    }
}
