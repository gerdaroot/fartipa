import SceneKit
import UIKit
import simd

/// Every `RiderAccessory`. Static parts go into the rider body (and get flattened);
/// moving parts are returned in a separate node with `RiderMotion` names.
@MainActor
enum RiderAccessories {
    private static var gold: SCNMaterial { ModelMaterials.gold }

    static func add(_ accessory: RiderAccessory, style: RiderStyle, pose: RiderPose, to body: SCNNode) -> SCNNode? {
        let head = pose.head
        switch accessory {
        case .none: return nil
        case .crown: crown(body, head)
        case .horns: horns(body, head)
        case .poopHat: poopHat(body, head)
        case .mohawk: mohawk(body, head, style)
        case .cape: return cape(pose, style)
        case .gasMask: gasMask(body, head, style)
        case .wings: return wings(pose, style)
        case .plunger: plunger(body, head)
        case .halo: halo(body, head)
        case .toiletSeat: toiletSeat(body, head)
        case .propeller: return propeller(body, head)
        case .ushanka: ushanka(body, head)
        }
        return nil
    }

    // MARK: - Hats

    private static func crown(_ node: SCNNode, _ head: RigVec) {
        ModelKit.add(ModelKit.tube(0.125, 0.14, 0.09), gold, to: node, at: head + RigVec(0, 0.15, 0))
        for index in 0..<6 {
            let angle = Float(index) / 6 * 2 * .pi
            let spot = RigVec(sin(angle) * 0.132, 0, cos(angle) * 0.132)
            ModelKit.add(ModelKit.cone(0, 0.032, 0.1), gold, to: node, at: head + spot + RigVec(0, 0.24, 0))
            ModelKit.add(ModelKit.sphere(0.018), gold, to: node, at: head + spot + RigVec(0, 0.295, 0))
        }
        let ruby = ModelMaterials.glow(RGB(r: 1, g: 0.08, b: 0.2), strength: 0.7)
        for angle: Float in [-0.55, 0, 0.55] {
            ModelKit.add(ModelKit.sphere(0.022), ruby, to: node,
                         at: head + RigVec(sin(angle) * 0.142, 0.15, -cos(angle) * 0.142))
        }
    }

    private static func horns(_ node: SCNNode, _ head: RigVec) {
        let tip = ModelMaterials.pbr("hornTip", diffuse: UIColor(white: 0.1, alpha: 1), metal: 0, rough: 0.3, clearCoat: 0.6)
        for side: Float in [-1, 1] {
            let points: [RigVec] = [
                RigVec(side * 0.11, 0.08, -0.02), RigVec(side * 0.2, 0.15, -0.04),
                RigVec(side * 0.245, 0.25, -0.08), RigVec(side * 0.235, 0.34, -0.13),
            ]
            let radii: [Float] = [0.045, 0.034, 0.022]
            for index in 0..<radii.count {
                let material = index == radii.count - 1 ? tip : ModelMaterials.bone
                ModelKit.rod(head + points[index], head + points[index + 1], radius: radii[index], material, to: node)
            }
        }
    }

    private static func poopHat(_ node: SCNNode, _ head: RigVec) {
        let poop = ModelMaterials.poop(RGB(hex: 0x6B4423))
        let tiers: [(Float, Float, Float)] = [(0.11, 0.05, 0.16), (0.075, 0.042, 0.23), (0.042, 0.032, 0.29)]
        for (ring, pipe, height) in tiers {
            ModelKit.add(ModelKit.torus(ring, pipe), poop, to: node, at: head + RigVec(0, height, 0))
        }
        ModelKit.add(ModelKit.cone(0, 0.036, 0.09), poop, to: node, at: head + RigVec(0, 0.35, 0.01),
                     euler: RigVec(0.35, 0, 0))
        let fly = ModelMaterials.blackPlastic
        ModelKit.add(ModelKit.sphere(0.015), fly, to: node, at: head + RigVec(0.12, 0.4, -0.04))
        ModelKit.add(ModelKit.sphere(0.015), fly, to: node, at: head + RigVec(-0.1, 0.46, 0.06))
    }

    private static func mohawk(_ node: SCNNode, _ head: RigVec, _ style: RiderStyle) {
        let hair = ModelMaterials.pbr("mohawk-" + ModelMaterials.key(style.visor), diffuse: ModelMaterials.color(style.visor),
                                      metal: 0, rough: 0.5, emission: ModelMaterials.color(style.visor, scale: 0.35))
        let count = 7
        for index in 0..<count {
            let phi = -0.7 + Float(index) / Float(count - 1) * 2.1
            let outward = RigVec(0, cos(phi), sin(phi))
            let base = head + outward * (RiderPose.helmetRadius * 1.02)
            let height: Float = index == 1 || index == 2 ? 0.17 : 0.13
            let spike = ModelKit.add(ModelKit.cone(0, 0.04, height), hair, to: node, at: base + outward * (height * 0.45),
                                     scale: RigVec(0.45, 1, 1))
            spike.simdOrientation = ModelKit.orientation(alongY: outward)
        }
    }

    private static func gasMask(_ node: SCNNode, _ head: RigVec, _ style: RiderStyle) {
        let rubber = ModelMaterials.pbr("maskRubber", diffuse: UIColor(white: 0.12, alpha: 1), metal: 0, rough: 0.7)
        let filter = ModelMaterials.plastic(RGB(hex: 0x4B5A2E))
        let forward = RigVec(.pi / 2, 0, 0)
        ModelKit.add(ModelKit.cylinder(0.06, 0.09), rubber, to: node, at: head + RigVec(0, -0.06, -0.17), euler: forward)
        ModelKit.add(ModelKit.cylinder(0.04, 0.02), ModelMaterials.brushed, to: node, at: head + RigVec(0, -0.06, -0.22),
                     euler: forward)
        for side: Float in [-1, 1] {
            ModelKit.rod(head + RigVec(side * 0.05, -0.08, -0.17), head + RigVec(side * 0.13, -0.12, -0.2),
                         radius: 0.042, filter, to: node, rounded: false)
            ModelKit.add(ModelKit.cylinder(0.04, 0.015), ModelMaterials.visor(style.visor), to: node,
                         at: head + RigVec(side * 0.058, 0.035, -0.175), euler: forward)
            ModelKit.add(ModelKit.torus(0.042, 0.01), rubber, to: node, at: head + RigVec(side * 0.058, 0.035, -0.17),
                         euler: forward)
        }
    }

    private static func plunger(_ node: SCNNode, _ head: RigVec) {
        let cup = ModelMaterials.pbr("plungerCup", diffuse: UIColor(red: 0.75, green: 0.08, blue: 0.08, alpha: 1),
                                     metal: 0, rough: 0.35, clearCoat: 0.6)
        ModelKit.add(ModelKit.cone(0.035, 0.09, 0.08), cup, to: node, at: head + RigVec(0, 0.18, 0.01))
        ModelKit.rod(head + RigVec(0, 0.21, 0.01), head + RigVec(0, 0.62, 0.14), radius: 0.017, ModelMaterials.wood, to: node)
    }

    private static func halo(_ node: SCNNode, _ head: RigVec) {
        let light = ModelMaterials.glow(RGB(r: 1, g: 0.88, b: 0.4))
        ModelKit.add(ModelKit.torus(0.15, 0.018), light, to: node, at: head + RigVec(0, 0.34, 0.02), euler: RigVec(-0.15, 0, 0))
    }

    private static func toiletSeat(_ node: SCNNode, _ head: RigVec) {
        let seat = ModelMaterials.porcelain(RGB(r: 0.96, g: 0.96, b: 0.94))
        ModelKit.add(ModelKit.torus(0.2, 0.036), seat, to: node, at: head + RigVec(0, -0.02, -0.03),
                     euler: RigVec(.pi / 2, 0, 0), scale: RigVec(1, 1, 1.25))
        ModelKit.add(ModelKit.cylinder(0.21, 0.025), seat, to: node, at: head + RigVec(0, 0.27, 0.17),
                     euler: RigVec(1.1, 0, 0), scale: RigVec(1, 1, 1.2))
        for side: Float in [-1, 1] {
            ModelKit.add(ModelKit.cylinder(0.02, 0.05), ModelMaterials.chrome, to: node,
                         at: head + RigVec(side * 0.07, 0.24, 0.02), euler: RigVec(0, 0, .pi / 2))
        }
    }

    private static func ushanka(_ node: SCNNode, _ head: RigVec) {
        let fur = ModelMaterials.fur
        ModelKit.add(ModelKit.sphere(0.175), fur, to: node, at: head + RigVec(0, 0.07, 0), scale: RigVec(1.06, 0.66, 1.1))
        for side: Float in [-1, 1] {
            ModelKit.add(ModelKit.box(0.045, 0.17, 0.13, chamfer: 0.02), fur, to: node, at: head + RigVec(side * 0.168, -0.04, 0.02))
        }
        ModelKit.add(ModelKit.box(0.25, 0.08, 0.045, chamfer: 0.02), fur, to: node, at: head + RigVec(0, 0.13, -0.175),
                     euler: RigVec(-0.3, 0, 0))
        ModelKit.add(ModelKit.sphere(0.022), ModelMaterials.glow(RGB(r: 1, g: 0.1, b: 0.05), strength: 0.8), to: node,
                     at: head + RigVec(0, 0.135, -0.205))
    }

    // MARK: - Moving parts

    private static func propeller(_ node: SCNNode, _ head: RigVec) -> SCNNode {
        ModelKit.add(ModelKit.cylinder(0.012, 0.07), ModelMaterials.darkMetal, to: node, at: head + RigVec(0, 0.19, 0))
        let rotor = SCNNode()
        rotor.name = RiderMotion.spin
        rotor.simdPosition = head + RigVec(0, 0.235, 0)
        let blades: [(Float, RGB)] = [(1, RGB(hex: 0xE53935)), (-1, RGB(hex: 0x1E88E5))]
        for (side, color) in blades {
            ModelKit.add(ModelKit.box(0.17, 0.012, 0.055, chamfer: 0.005), ModelMaterials.plastic(color), to: rotor,
                         at: RigVec(side * 0.095, 0, 0), euler: RigVec(side * 0.25, 0, 0))
        }
        ModelKit.add(ModelKit.sphere(0.024), ModelMaterials.plastic(RGB(hex: 0xFDD835)), to: rotor, at: .zero)
        return rotor
    }

    private static func cape(_ pose: RiderPose, _ style: RiderStyle) -> SCNNode {
        let holder = SCNNode()
        holder.name = RiderMotion.sway
        holder.simdPosition = pose.upperBack + pose.torsoDirection * 0.08
        let cloth = ModelMaterials.fabric(style.helmet, doubleSided: true)
        let points: [RigVec] = [.zero, RigVec(0, -0.16, 0.3), RigVec(0, -0.24, 0.62)]
        let widths: [Float] = [0.46, 0.56]
        for index in 0..<widths.count {
            let start = points[index]
            let end = points[index + 1]
            let length = simd_length(end - start)
            let panel = ModelKit.add(ModelKit.box(widths[index], length, 0.016), cloth, to: holder, at: (start + end) * 0.5)
            panel.simdOrientation = ModelKit.orientation(alongY: simd_normalize(end - start))
        }
        ModelKit.add(ModelKit.sphere(0.03), gold, to: holder, at: RigVec(0.18, 0.02, -0.04))
        ModelKit.add(ModelKit.sphere(0.03), gold, to: holder, at: RigVec(-0.18, 0.02, -0.04))
        return holder
    }

    private static func wings(_ pose: RiderPose, _ style: RiderStyle) -> SCNNode {
        let pair = SCNNode()
        let feather = ModelMaterials.pbr("wing-" + ModelMaterials.key(style.helmet), diffuse: ModelMaterials.color(style.helmet),
                                         metal: 0.1, rough: 0.45, emission: ModelMaterials.color(style.visor, scale: 0.12),
                                         doubleSided: true)
        for side: Float in [1, -1] {
            let holder = SCNNode()
            holder.name = side > 0 ? RiderMotion.flapRight : RiderMotion.flapLeft
            holder.simdPosition = pose.upperBack + RigVec(side * 0.07, 0.04, 0.03)
            holder.simdScale = RigVec(side, 1, 1)
            ModelKit.add(wingShape(), feather, to: holder, at: .zero, euler: RigVec(0, -0.45, 0.12))
            pair.addChildNode(holder)
        }
        return pair
    }

    private static func wingShape() -> SCNGeometry {
        ModelKit.shape("wing", width: 0.025, chamfer: 0.008) {
            RigPathStep.path(0, 0, [
                .quad(0.66, 0.52, controlX: 0.18, controlY: 0.5),
                .line(0.6, 0.36), .line(0.64, 0.3), .line(0.48, 0.2), .line(0.52, 0.12),
                .line(0.36, 0.04), .line(0.38, -0.04), .line(0.2, -0.06), .line(0.06, -0.08),
            ])
        }
    }
}
