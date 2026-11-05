import SceneKit
import UIKit
import simd

/// Wheels for every `WheelStyle`. A wheel is built around the origin with its axle along x,
/// so the world can spin it with `eulerAngles.x`.
@MainActor
enum BikeWheels {
    private static let alongX = RigVec(0, 0, .pi / 2)
    private static var chrome: SCNMaterial { ModelMaterials.chrome }

    static func build(style: WheelStyle, radius: Float, width: Float, knobby: Bool, palette: BikePalette) -> SCNNode {
        let node = SCNNode()
        switch style {
        case .standard: cast(node, radius, width, palette)
        case .spoked: spoked(node, radius, width)
        case .chunky: chunky(node, radius, width, palette)
        case .whitewall: whitewall(node, radius, width)
        case .flaming: flaming(node, radius, width, palette)
        case .toiletRolls: toiletRoll(node, radius, width)
        case .donuts: donut(node, radius, width)
        case .neon: neon(node, radius, width, palette)
        }
        if knobby && style != .chunky && style != .toiletRolls && style != .donuts {
            knobs(node, radius, width)
        }
        return node
    }

    /// Direction from the axle at `angle` around the wheel.
    private static func radial(_ angle: Float) -> RigVec {
        RigVec(0, cos(angle), sin(angle))
    }

    private static func tyre(_ node: SCNNode, _ radius: Float, _ width: Float) {
        ModelKit.add(ModelKit.torus(radius - width / 2, width / 2), ModelMaterials.rubber, to: node, at: .zero, euler: alongX)
    }

    private static func hub(_ node: SCNNode, _ width: Float, _ material: SCNMaterial) {
        ModelKit.add(ModelKit.cylinder(0.055, width * 0.85), material, to: node, at: .zero, euler: alongX)
    }

    /// Radial bars from the hub to `outer`, rotated `twist` radians for swept spokes.
    private static func spokes(
        _ node: SCNNode, count: Int, from inner: Float, to outer: Float, thickness: Float, depth: Float,
        _ material: SCNMaterial, x: Float = 0, twist: Float = 0, phase: Float = 0
    ) {
        let length = outer - inner
        for index in 0..<count {
            let angle = phase + Float(index) / Float(count) * 2 * .pi
            let center = radial(angle) * (inner + length / 2) + RigVec(x, 0, 0)
            ModelKit.add(ModelKit.box(depth, length, thickness, chamfer: thickness * 0.3), material, to: node,
                         at: center, euler: RigVec(angle + twist, 0, 0))
        }
    }

    // MARK: - Styles

    private static func cast(_ node: SCNNode, _ radius: Float, _ width: Float, _ palette: BikePalette) {
        tyre(node, radius, width)
        let rim = radius - width
        for side: Float in [-1, 1] {
            ModelKit.add(ModelKit.torus(rim, 0.013), palette.trim, to: node, at: RigVec(side * width * 0.3, 0, 0), euler: alongX)
        }
        spokes(node, count: 5, from: 0.05, to: rim, thickness: 0.035, depth: width * 0.35, palette.trim)
        hub(node, width, chrome)
        ModelKit.add(ModelKit.cylinder(radius * 0.52, 0.008), ModelMaterials.brushed, to: node,
                     at: RigVec(width * 0.33, 0, 0), euler: alongX)
    }

    private static func spoked(_ node: SCNNode, _ radius: Float, _ width: Float) {
        tyre(node, radius, width)
        let rim = radius - width + 0.01
        for side: Float in [-1, 1] {
            ModelKit.add(ModelKit.torus(rim, 0.012), chrome, to: node, at: RigVec(side * width * 0.22, 0, 0), euler: alongX)
        }
        hub(node, width, chrome)
        let count = 24
        for index in 0..<count {
            let angle = Float(index) / Float(count) * 2 * .pi
            let side: Float = index % 2 == 0 ? 1 : -1
            let hubPoint = radial(angle + side * 0.35) * 0.05 + RigVec(side * width * 0.35, 0, 0)
            let rimPoint = radial(angle) * rim + RigVec(-side * width * 0.12, 0, 0)
            ModelKit.rod(hubPoint, rimPoint, radius: 0.0045, chrome, to: node, rounded: false)
        }
    }

    private static func chunky(_ node: SCNNode, _ radius: Float, _ width: Float, _ palette: BikePalette) {
        tyre(node, radius, width)
        knobs(node, radius, width)
        ModelKit.add(ModelKit.cylinder(radius - width, width * 0.5), palette.trim, to: node, at: .zero, euler: alongX)
        hub(node, width * 0.75, chrome)
        for index in 0..<6 {
            let angle = Float(index) / 6 * 2 * .pi
            ModelKit.add(ModelKit.sphere(0.016), chrome, to: node, at: radial(angle) * 0.085 + RigVec(width * 0.26, 0, 0))
        }
    }

    private static func knobs(_ node: SCNNode, _ radius: Float, _ width: Float) {
        let count = max(16, Int(radius * 60))
        for index in 0..<count {
            let angle = Float(index) / Float(count) * 2 * .pi
            let side: Float = index % 2 == 0 ? 1 : -1
            let center = radial(angle) * (radius - 0.012) + RigVec(side * width * 0.2, 0, 0)
            ModelKit.add(ModelKit.box(width * 0.48, 0.05, 0.07, chamfer: 0.012), ModelMaterials.rubber, to: node,
                         at: center, euler: RigVec(angle, side * 0.25, 0))
        }
    }

    private static func whitewall(_ node: SCNNode, _ radius: Float, _ width: Float) {
        tyre(node, radius, width)
        ModelKit.add(ModelKit.tube(radius - width * 0.92, radius - width * 0.5, width * 0.96), ModelMaterials.whiteRubber,
                     to: node, at: .zero, euler: alongX)
        ModelKit.add(ModelKit.sphere(radius - width * 0.95), chrome, to: node, at: .zero, scale: RigVec(0.32, 1, 1))
        ModelKit.add(ModelKit.cylinder(0.04, width * 1.05), ModelMaterials.brushed, to: node, at: .zero, euler: alongX)
    }

    private static func flaming(_ node: SCNNode, _ radius: Float, _ width: Float, _ palette: BikePalette) {
        tyre(node, radius, width)
        let rim = radius - width
        let fire = ModelMaterials.glow(palette.style.glow, strength: 1.2)
        ModelKit.add(ModelKit.cylinder(rim, width * 0.4), ModelMaterials.darkMetal, to: node, at: .zero, euler: alongX)
        for side: Float in [-1, 1] {
            let x = side * width * 0.22
            ModelKit.add(ModelKit.torus(rim - 0.01, 0.015), fire, to: node, at: RigVec(x, 0, 0), euler: alongX)
            for index in 0..<6 {
                let angle = Float(index) / 6 * 2 * .pi
                let center = radial(angle) * (rim * 0.52) + RigVec(x, 0, 0)
                ModelKit.add(ModelKit.cone(0, 0.045, rim * 0.85), fire, to: node, at: center,
                             euler: RigVec(angle + 0.35, 0, 0), scale: RigVec(0.4, 1, 1))
            }
        }
        hub(node, width, ModelMaterials.darkMetal)
    }

    private static func toiletRoll(_ node: SCNNode, _ radius: Float, _ width: Float) {
        let rollWidth = width * 1.8
        ModelKit.add(ModelKit.tube(radius * 0.33, radius, rollWidth), ModelMaterials.paper, to: node, at: .zero, euler: alongX)
        ModelKit.add(ModelKit.tube(radius * 0.29, radius * 0.34, rollWidth + 0.006), ModelMaterials.cardboard,
                     to: node, at: .zero, euler: alongX)
        ModelKit.add(ModelKit.cylinder(0.03, rollWidth + 0.04), chrome, to: node, at: .zero, euler: alongX)
        spokes(node, count: 3, from: 0.02, to: radius * 0.3, thickness: 0.02, depth: 0.02, chrome)
        for index in 0..<12 {
            let angle = Float(index) / 12 * 2 * .pi
            ModelKit.add(ModelKit.box(rollWidth * 1.003, 0.004, 0.006), ModelMaterials.cardboard, to: node,
                         at: radial(angle) * (radius - 0.001), euler: RigVec(angle, 0, 0))
        }
    }

    private static func donut(_ node: SCNNode, _ radius: Float, _ width: Float) {
        let pipe = width * 0.8
        let ring = radius - pipe
        let dough = ModelMaterials.pbr("dough", diffuse: UIColor(red: 0.84, green: 0.56, blue: 0.27, alpha: 1),
                                       metal: 0, rough: 0.7)
        let icing = ModelMaterials.pbr("icing", diffuse: UIColor(red: 1, green: 0.46, blue: 0.72, alpha: 1),
                                       metal: 0, rough: 0.2, clearCoat: 1)
        ModelKit.add(ModelKit.torus(ring, pipe), dough, to: node, at: .zero, euler: alongX)
        for side: Float in [-1, 1] {
            ModelKit.add(ModelKit.torus(ring, pipe * 0.9), icing, to: node, at: RigVec(side * pipe * 0.3, 0, 0), euler: alongX)
        }
        sprinkles(node, ring: ring, pipe: pipe)
        ModelKit.add(ModelKit.cylinder(0.035, width), chrome, to: node, at: .zero, euler: alongX)
        spokes(node, count: 3, from: 0.02, to: ring - pipe * 0.8, thickness: 0.016, depth: 0.016, chrome)
    }

    private static func sprinkles(_ node: SCNNode, ring: Float, pipe: Float) {
        let colors: [RGB] = [
            RGB(hex: 0xFFE14D), RGB(hex: 0x4DA6FF), RGB(hex: 0x6CE06C), RGB(hex: 0xFFFFFF), RGB(hex: 0xFF4D4D),
        ]
        let count = 28
        for index in 0..<count {
            let side: Float = index % 2 == 0 ? 1 : -1
            let angle = Float(index) / Float(count) * 2 * .pi
            let spread = (Float(index % 5) - 2) * 0.22 * pipe
            let center = radial(angle) * (ring + spread) + RigVec(side * pipe * 1.12, 0, 0)
            let material = ModelMaterials.plastic(colors[index % colors.count])
            ModelKit.add(ModelKit.capsule(0.008, 0.034), material, to: node, at: center,
                         euler: RigVec(angle + Float(index) * 0.9, 0.3 * side, 0))
        }
    }

    private static func neon(_ node: SCNNode, _ radius: Float, _ width: Float, _ palette: BikePalette) {
        tyre(node, radius, width)
        let rim = radius - width
        let light = ModelMaterials.glow(palette.style.glow, strength: 1.3)
        ModelKit.add(ModelKit.cylinder(rim, width * 0.5), ModelMaterials.blackPlastic, to: node, at: .zero, euler: alongX)
        for side: Float in [-1, 1] {
            ModelKit.add(ModelKit.torus(rim - 0.006, 0.01), light, to: node, at: RigVec(side * width * 0.27, 0, 0), euler: alongX)
            ModelKit.add(ModelKit.torus(radius - width * 0.5, 0.008), light, to: node,
                         at: RigVec(side * width * 0.5, 0, 0), euler: alongX)
        }
        spokes(node, count: 3, from: 0.05, to: rim - 0.01, thickness: 0.02, depth: width * 0.56, light, twist: 0.2)
        hub(node, width, ModelMaterials.darkMetal)
    }
}
