import SceneKit
import UIKit

/// A built bike and rider, with the parts that move during a ride.
struct BikeRig {
    let root: SCNNode
    let frontWheel: SCNNode
    let rearWheel: SCNNode
}

/// Builds every bike and outfit in the shop out of simple shapes.
enum BikeModels {
    private struct BikeLook {
        let frame: UIColor
        let accent: UIColor
        let forkLength: Double
    }

    private struct RiderLook {
        let jacket: UIColor
        let pants: UIColor
        let helmet: UIColor
        let visor: UIColor
    }

    private static let brown = UIColor(red: 0.33, green: 0.19, blue: 0.08, alpha: 1)
    private static let darkBrown = UIColor(red: 0.2, green: 0.11, blue: 0.04, alpha: 1)
    private static let gold = UIColor(red: 0.95, green: 0.72, blue: 0.2, alpha: 1)
    private static let rubber = UIColor(white: 0.07, alpha: 1)
    private static let steel = UIColor(white: 0.72, alpha: 1)

    static func material(_ color: UIColor, shine: CGFloat = 0.4, glow: UIColor? = nil) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = color
        material.specular.contents = UIColor(white: shine, alpha: 1)
        material.shininess = 0.5
        if let glow { material.emission.contents = glow }
        return material
    }

    static func part(
        _ geometry: SCNGeometry, _ color: UIColor, x: Double = 0, y: Double, z: Double,
        pitch: Double = 0, roll: Double = 0, shine: CGFloat = 0.4, glow: UIColor? = nil
    ) -> SCNNode {
        geometry.firstMaterial = material(color, shine: shine, glow: glow)
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(Float(x), Float(y), Float(z))
        node.eulerAngles = SCNVector3(Float(pitch), 0, Float(roll))
        return node
    }

    static func makeRig(bikeId: String, riderId: String) -> BikeRig {
        let root = SCNNode()
        let look = bikeLook(bikeId)
        let front = makeWheel(z: -0.78 - (look.forkLength - 0.6) * 0.6)
        let rear = makeWheel(z: 0.78)
        root.addChildNode(front)
        root.addChildNode(rear)
        root.addChildNode(makeBike(id: bikeId, look: look))
        root.addChildNode(makeRider(id: riderId))
        return BikeRig(root: root, frontWheel: front, rearWheel: rear)
    }

    private static func bikeLook(_ id: String) -> BikeLook {
        switch id {
        case "sport": return BikeLook(frame: UIColor(red: 0.8, green: 0.08, blue: 0.08, alpha: 1), accent: .white, forkLength: 0.6)
        case "chopper": return BikeLook(frame: UIColor(white: 0.1, alpha: 1), accent: steel, forkLength: 1.2)
        case "turdmobile": return BikeLook(frame: brown, accent: darkBrown, forkLength: 0.6)
        case "toilet": return BikeLook(frame: gold, accent: .white, forkLength: 0.6)
        default: return BikeLook(frame: UIColor(red: 0.52, green: 0.3, blue: 0.14, alpha: 1), accent: darkBrown, forkLength: 0.6)
        }
    }

    private static func riderLook(_ id: String) -> RiderLook {
        let black = UIColor(white: 0.08, alpha: 1)
        switch id {
        case "racer":
            return RiderLook(jacket: UIColor(red: 0.8, green: 0.1, blue: 0.08, alpha: 1), pants: black, helmet: .white, visor: black)
        case "turdman":
            return RiderLook(jacket: brown, pants: darkBrown, helmet: brown, visor: darkBrown)
        case "hazmat":
            let yellow = UIColor(red: 0.95, green: 0.8, blue: 0.12, alpha: 1)
            return RiderLook(jacket: yellow, pants: yellow, helmet: yellow, visor: UIColor(red: 0.2, green: 0.5, blue: 0.6, alpha: 1))
        case "king":
            return RiderLook(jacket: UIColor(red: 0.42, green: 0.08, blue: 0.5, alpha: 1), pants: black, helmet: gold, visor: black)
        default:
            return RiderLook(jacket: black, pants: UIColor(red: 0.12, green: 0.14, blue: 0.2, alpha: 1), helmet: UIColor(white: 0.2, alpha: 1), visor: black)
        }
    }

    private static func makeWheel(z: Double) -> SCNNode {
        let holder = SCNNode()
        holder.position = SCNVector3(0, 0.36, Float(z))
        let tyre = part(SCNCylinder(radius: 0.36, height: 0.16), rubber, y: 0, z: 0, roll: .pi / 2, shine: 0.1)
        let hub = part(SCNCylinder(radius: 0.17, height: 0.18), steel, y: 0, z: 0, roll: .pi / 2, shine: 0.8)
        let spoke = part(SCNBox(width: 0.19, height: 0.6, length: 0.05, chamferRadius: 0), steel, y: 0, z: 0)
        [tyre, hub, spoke].forEach { holder.addChildNode($0) }
        return holder
    }

    private static func makeBike(id: String, look: BikeLook) -> SCNNode {
        let bike = SCNNode()
        let fork = look.forkLength
        let frontZ = -0.78 - (fork - 0.6) * 0.6
        let parts: [SCNNode] = [
            part(SCNCapsule(capRadius: 0.11, height: 1.5), look.frame, y: 0.68, z: 0, pitch: .pi / 2 - 0.08, shine: 0.6),
            part(SCNCapsule(capRadius: 0.2, height: 0.72), look.frame, y: 0.92, z: -0.3, pitch: .pi / 2, shine: 0.9),
            part(SCNBox(width: 0.3, height: 0.1, length: 0.62, chamferRadius: 0.05), look.accent, y: 0.92, z: 0.28),
            part(SCNBox(width: 0.32, height: 0.3, length: 0.42, chamferRadius: 0.06), UIColor(white: 0.2, alpha: 1), y: 0.5, z: 0.02, shine: 0.7),
            part(SCNCylinder(radius: 0.035, height: fork + 0.25), steel, y: 0.36 + (fork + 0.25) / 2 - 0.05, z: frontZ + fork * 0.28, pitch: -0.5, shine: 0.9),
            part(SCNCapsule(capRadius: 0.03, height: 0.7), steel, y: 0.72 + fork * 0.5, z: frontZ + fork * 0.55, roll: .pi / 2, shine: 0.9),
            part(SCNSphere(radius: 0.11), UIColor(white: 1, alpha: 1), y: 0.74 + fork * 0.35, z: frontZ + fork * 0.25 - 0.13, glow: UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)),
            part(SCNSphere(radius: 0.07), UIColor(red: 0.8, green: 0, blue: 0, alpha: 1), y: 0.95, z: 0.63, glow: UIColor(red: 0.9, green: 0, blue: 0, alpha: 1)),
            part(SCNCapsule(capRadius: 0.05, height: 0.9), steel, x: 0.22, y: 0.4, z: 0.5, pitch: .pi / 2 - 0.12, shine: 0.9),
            part(SCNCylinder(radius: 0.4, height: 0.03), look.accent, y: 0.74, z: 0.78, roll: .pi / 2),
        ]
        parts.forEach { bike.addChildNode($0) }
        if id == "turdmobile" { addLumps(to: bike) }
        if id == "toilet" { addToilet(to: bike) }
        return bike
    }

    private static func addLumps(to bike: SCNNode) {
        let lumps: [(Double, Double, Double, CGFloat)] = [
            (0, 1.08, -0.45, 0.2), (0.1, 1.2, -0.32, 0.14), (-0.08, 1.3, -0.3, 0.09), (0.16, 0.76, -0.1, 0.13), (-0.16, 0.72, 0.15, 0.13),
        ]
        for (x, y, z, radius) in lumps {
            bike.addChildNode(part(SCNSphere(radius: radius), brown, x: x, y: y, z: z, shine: 0.7))
        }
    }

    private static func addToilet(to bike: SCNNode) {
        let white = UIColor(white: 0.97, alpha: 1)
        bike.addChildNode(part(SCNCone(topRadius: 0.32, bottomRadius: 0.17, height: 0.34), white, y: 0.94, z: 0.14, shine: 1))
        bike.addChildNode(part(SCNTorus(ringRadius: 0.27, pipeRadius: 0.055), gold, y: 1.12, z: 0.14, shine: 1))
        bike.addChildNode(part(SCNBox(width: 0.5, height: 0.46, length: 0.2, chamferRadius: 0.04), white, y: 1.28, z: 0.5, shine: 1))
        bike.addChildNode(part(SCNCylinder(radius: 0.045, height: 0.05), gold, x: 0.16, y: 1.42, z: 0.38, pitch: .pi / 2, shine: 1))
    }

    private static func makeRider(id: String) -> SCNNode {
        let look = riderLook(id)
        let rider = SCNNode()
        let parts: [SCNNode] = [
            part(SCNCapsule(capRadius: 0.21, height: 0.8), look.jacket, y: 1.32, z: 0.02, pitch: -0.62),
            part(SCNCapsule(capRadius: 0.075, height: 0.7), look.jacket, x: 0.27, y: 1.3, z: -0.42, pitch: -1.15),
            part(SCNCapsule(capRadius: 0.075, height: 0.7), look.jacket, x: -0.27, y: 1.3, z: -0.42, pitch: -1.15),
            part(SCNCapsule(capRadius: 0.1, height: 0.72), look.pants, x: 0.22, y: 0.82, z: 0.04, pitch: 0.75),
            part(SCNCapsule(capRadius: 0.1, height: 0.72), look.pants, x: -0.22, y: 0.82, z: 0.04, pitch: 0.75),
            part(SCNSphere(radius: 0.21), look.helmet, y: 1.75, z: -0.26, shine: 0.9),
            part(SCNBox(width: 0.3, height: 0.11, length: 0.14, chamferRadius: 0.04), look.visor, y: 1.76, z: -0.42, shine: 1),
        ]
        parts.forEach { rider.addChildNode($0) }
        if id == "king" { addCrown(to: rider) }
        if id == "turdman" {
            rider.addChildNode(part(SCNCone(topRadius: 0, bottomRadius: 0.13, height: 0.24), brown, y: 2, z: -0.26, shine: 0.7))
        }
        return rider
    }

    private static func addCrown(to rider: SCNNode) {
        rider.addChildNode(part(SCNCylinder(radius: 0.17, height: 0.09), gold, y: 1.95, z: -0.26, shine: 1))
        for index in 0..<5 {
            let angle = Double(index) / 5 * 2 * .pi
            let spike = part(SCNCone(topRadius: 0, bottomRadius: 0.05, height: 0.14), gold,
                             x: cos(angle) * 0.14, y: 2.05, z: -0.26 + sin(angle) * 0.14, shine: 1)
            rider.addChildNode(spike)
        }
    }
}
