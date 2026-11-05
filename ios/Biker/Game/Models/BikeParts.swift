import SceneKit
import UIKit
import simd

/// The materials one bike is painted with.
@MainActor
struct BikePalette {
    let style: BikeStyle
    /// Main glossy paint (tank, fairing, body).
    let primary: SCNMaterial
    /// Second paint (stripes, panels, tail).
    let secondary: SCNMaterial
    /// Metal-flake version of the second colour (frame, rims, trim).
    let trim: SCNMaterial
    /// Self-lit accent in the bike's glow colour.
    let glow: SCNMaterial
    let seat: SCNMaterial

    init(_ style: BikeStyle) {
        self.style = style
        primary = ModelMaterials.paint(style.primary)
        secondary = ModelMaterials.paint(style.secondary)
        trim = ModelMaterials.candy(style.secondary)
        glow = ModelMaterials.glow(style.glow)
        seat = ModelMaterials.leather(RGB(r: 0.07, g: 0.06, b: 0.06))
    }
}

/// Parts most bikes share: forks, bars, lights, engines, pipes, seats, tanks and fenders.
@MainActor
enum BikeParts {
    private static var chrome: SCNMaterial { ModelMaterials.chrome }
    private static var dark: SCNMaterial { ModelMaterials.darkMetal }

    // MARK: - Steering

    static func forkAndBars(_ node: SCNNode, _ layout: BikeLayout, gap: Float = 0.1) {
        fork(node, axle: layout.frontAxle, top: layout.forkTop, gap: gap)
        handlebar(node, clamp: layout.forkTop, grip: layout.grip)
    }

    /// Two telescopic legs from the axle up to the clamp: dark sliders below, chrome tubes above.
    static func fork(_ node: SCNNode, axle: RigVec, top: RigVec, gap: Float) {
        let sliderEnd = axle + (top - axle) * 0.45
        for side: Float in [-1, 1] {
            let offset = RigVec(side * gap, 0, 0)
            ModelKit.rod(axle + offset, sliderEnd + offset, radius: 0.034, dark, to: node)
            ModelKit.rod(sliderEnd + offset, top + offset, radius: 0.024, chrome, to: node)
        }
        let down = simd_normalize(axle - top)
        ModelKit.add(ModelKit.box(gap * 2 + 0.1, 0.05, 0.11, chamfer: 0.02), ModelMaterials.brushed, to: node, at: top)
        ModelKit.add(ModelKit.box(gap * 2 + 0.09, 0.04, 0.1, chamfer: 0.02), ModelMaterials.brushed,
                     to: node, at: top + down * 0.2)
        ModelKit.rod(axle + RigVec(-gap - 0.03, 0, 0), axle + RigVec(gap + 0.03, 0, 0), radius: 0.02, chrome, to: node)
    }

    /// Risers from the clamp up (or down) to the bar, then out to rubber grips with levers.
    static func handlebar(_ node: SCNNode, clamp: RigVec, grip: RigVec) {
        let base = clamp + RigVec(0, 0.04, 0)
        let bend = RigVec(min(0.16, grip.x * 0.5), grip.y, grip.z)
        let inner = RigVec(grip.x - 0.07, grip.y, grip.z)
        let outer = RigVec(grip.x + 0.06, grip.y, grip.z)
        let rubber = ModelMaterials.rubber
        for point in [bend, ModelKit.mirrored(bend)] {
            ModelKit.rod(RigVec(point.x * 0.4, base.y, base.z), point, radius: 0.017, chrome, to: node)
        }
        ModelKit.rod(ModelKit.mirrored(bend), bend, radius: 0.016, chrome, to: node)
        for mirror in [false, true] {
            let pick: (RigVec) -> RigVec = { mirror ? ModelKit.mirrored($0) : $0 }
            ModelKit.rod(pick(bend), pick(inner), radius: 0.016, chrome, to: node)
            ModelKit.rod(pick(inner), pick(outer), radius: 0.027, rubber, to: node)
            let leverStart = RigVec(grip.x - 0.06, grip.y + 0.01, grip.z - 0.03)
            let leverEnd = RigVec(grip.x + 0.05, grip.y, grip.z - 0.1)
            ModelKit.rod(pick(leverStart), pick(leverEnd), radius: 0.008, ModelMaterials.brushed, to: node)
        }
    }

    static func mirrors(_ node: SCNNode, grip: RigVec) {
        for mirror in [false, true] {
            let pick: (RigVec) -> RigVec = { mirror ? ModelKit.mirrored($0) : $0 }
            let start = RigVec(grip.x - 0.09, grip.y + 0.01, grip.z + 0.01)
            let end = RigVec(grip.x + 0.01, grip.y + 0.22, grip.z + 0.03)
            ModelKit.rod(pick(start), pick(end), radius: 0.009, chrome, to: node)
            ModelKit.add(ModelKit.cylinder(0.055, 0.02), ModelMaterials.blackPlastic, to: node,
                         at: pick(end + RigVec(0.02, 0.03, 0)), euler: RigVec(.pi / 2, 0, 0))
        }
    }

    static func pegs(_ node: SCNNode, peg: RigVec) {
        for mirror in [false, true] {
            let pick: (RigVec) -> RigVec = { mirror ? ModelKit.mirrored($0) : $0 }
            ModelKit.rod(pick(RigVec(0.08, peg.y + 0.03, peg.z + 0.04)), pick(peg), radius: 0.015,
                         ModelMaterials.brushed, to: node)
            ModelKit.rod(pick(peg - RigVec(0.03, 0, 0)), pick(peg + RigVec(0.06, 0, 0)), radius: 0.022,
                         ModelMaterials.rubber, to: node)
        }
    }

    // MARK: - Lights

    /// Round headlight whose lens faces -z with its front at `front`.
    static func headlight(_ node: SCNNode, front: RigVec, radius: Float, bucket: SCNMaterial) {
        let facing = RigVec(.pi / 2, 0, 0)
        ModelKit.add(ModelKit.cylinder(radius + 0.012, 0.12), bucket, to: node,
                     at: front + RigVec(0, 0, 0.065), euler: facing)
        ModelKit.add(ModelKit.cylinder(radius, 0.014), ModelMaterials.headlightLens, to: node,
                     at: front + RigVec(0, 0, 0.007), euler: facing)
        ModelKit.add(ModelKit.torus(radius + 0.006, 0.012), chrome, to: node, at: front + RigVec(0, 0, 0.01), euler: facing)
    }

    static func taillight(_ node: SCNNode, at center: RigVec, width: Float, height: Float) {
        ModelKit.add(ModelKit.box(width, height, 0.04, chamfer: 0.015), ModelMaterials.taillightLens, to: node, at: center)
    }

    static func indicators(_ node: SCNNode, at center: RigVec, spread: Float) {
        for side: Float in [-1, 1] {
            let lamp = center + RigVec(side * spread, 0, 0)
            ModelKit.rod(center + RigVec(side * spread * 0.4, 0, 0.02), lamp, radius: 0.008, dark, to: node)
            ModelKit.add(ModelKit.capsule(0.022, 0.07), ModelMaterials.indicator, to: node, at: lamp,
                         euler: RigVec(.pi / 2, 0, 0))
        }
    }

    // MARK: - Engines and pipes

    /// Upright single/inline engine with cooling fins.
    static func engine(_ node: SCNNode, center: RigVec, palette: BikePalette) {
        ModelKit.add(ModelKit.box(0.3, 0.24, 0.42, chamfer: 0.06), dark, to: node, at: center)
        for index in 0..<5 {
            let fin = center + RigVec(0, 0.15 + Float(index) * 0.034, -0.05)
            ModelKit.add(ModelKit.box(0.27, 0.016, 0.24, chamfer: 0.006), ModelMaterials.brushed, to: node, at: fin)
        }
        ModelKit.add(ModelKit.box(0.24, 0.06, 0.2, chamfer: 0.025), palette.trim, to: node,
                     at: center + RigVec(0, 0.33, -0.05))
        ModelKit.add(ModelKit.cylinder(0.1, 0.33), chrome, to: node, at: center + RigVec(0, -0.02, 0.08),
                     euler: RigVec(0, 0, .pi / 2))
    }

    /// V-twin with finned chrome cylinders, an air cleaner and a primary cover.
    static func vTwin(_ node: SCNNode, center: RigVec, palette: BikePalette) {
        ModelKit.add(ModelKit.box(0.28, 0.22, 0.4, chamfer: 0.07), dark, to: node, at: center)
        let base = center + RigVec(0, 0.08, 0)
        for angle: Float in [-0.48, 0.48] {
            let direction = RigVec(0, cos(angle), -sin(angle))
            ModelKit.rod(base, base + direction * 0.3, radius: 0.06, dark, to: node)
            for ring in 0..<5 {
                let ringCenter = base + direction * (0.09 + Float(ring) * 0.04)
                let fin = ModelKit.add(ModelKit.torus(0.07, 0.016), ModelMaterials.brushed, to: node, at: ringCenter)
                fin.simdOrientation = ModelKit.orientation(alongY: direction)
            }
            let head = ModelKit.add(ModelKit.box(0.17, 0.07, 0.15, chamfer: 0.03), chrome, to: node,
                                    at: base + direction * 0.32)
            head.simdOrientation = ModelKit.orientation(alongY: direction)
        }
        ModelKit.add(ModelKit.cylinder(0.11, 0.05), chrome, to: node, at: center + RigVec(0.19, 0.2, 0),
                     euler: RigVec(0, 0, .pi / 2))
        ModelKit.add(ModelKit.cylinder(0.035, 0.052), palette.glow, to: node, at: center + RigVec(0.2, 0.2, 0),
                     euler: RigVec(0, 0, .pi / 2))
        ModelKit.add(ModelKit.capsule(0.11, 0.42), chrome, to: node, at: center + RigVec(-0.17, -0.02, 0.05),
                     euler: RigVec(.pi / 2, 0, 0), scale: RigVec(0.4, 1, 1))
    }

    /// Header pipe through `points`; the last `mufflerLength` metres before the tip are a muffler.
    static func exhaust(_ node: SCNNode, points: [RigVec], mufflerLength: Float, radius: Float) {
        guard points.count > 1, let tip = points.last else { return }
        let before = points[points.count - 2]
        let direction = simd_normalize(tip - before)
        let mufflerStart = tip - direction * mufflerLength
        ModelKit.pipe(Array(points.dropLast()) + [mufflerStart], radius: 0.028, chrome, to: node)
        ModelKit.rod(mufflerStart, tip, radius: radius, chrome, to: node, rounded: false)
        ModelKit.rod(mufflerStart - direction * 0.03, mufflerStart + direction * 0.04, radius: radius * 0.8,
                     ModelMaterials.brushed, to: node, rounded: false)
        ModelKit.rod(tip - direction * 0.02, tip + direction * 0.012, radius: radius * 0.68, dark, to: node, rounded: false)
    }

    /// Coil-over shock: chrome rod with a coloured spring.
    static func shock(_ node: SCNNode, from bottom: RigVec, to top: RigVec, spring: SCNMaterial) {
        ModelKit.rod(bottom, top, radius: 0.018, chrome, to: node)
        let direction = simd_normalize(top - bottom)
        let length = simd_length(top - bottom)
        for index in 0..<6 {
            let center = bottom + direction * (length * (0.2 + Float(index) * 0.12))
            let coil = ModelKit.add(ModelKit.torus(0.034, 0.009), spring, to: node, at: center)
            coil.simdOrientation = ModelKit.orientation(alongY: direction)
        }
    }

    /// Swingarm from the pivot to the rear axle, one arm per side.
    static func swingarm(_ node: SCNNode, pivot: RigVec, axle: RigVec, gap: Float, material: SCNMaterial) {
        for side: Float in [-1, 1] {
            let offset = RigVec(side * gap, 0, 0)
            ModelKit.rod(pivot + offset, axle + offset, radius: 0.03, material, to: node)
        }
        ModelKit.rod(axle + RigVec(-gap - 0.03, 0, 0), axle + RigVec(gap + 0.03, 0, 0), radius: 0.02, chrome, to: node)
        ModelKit.rod(pivot + RigVec(-gap, 0, 0), pivot + RigVec(gap, 0, 0), radius: 0.03, material, to: node)
    }
}
