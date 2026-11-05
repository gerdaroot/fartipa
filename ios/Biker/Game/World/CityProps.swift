import SceneKit
import UIKit

/// A roadside sign whose board is re-dressed every lap.
struct SignProp {
    let node: SCNNode
    let board: SCNNode
}

/// An overhead gantry; its two panels get fresh text every lap.
struct GantryProp {
    let node: SCNNode
    let panels: [SCNNode]
}

/// Builders for the city's repeating decor. Everything faces the road from the right-hand side
/// (x > 0); rows turn the left-hand copies around.
@MainActor
enum CityProps {
    static let lampX = RoadMetrics.sidewalkInner + 1.2
    private static let lampHeight = 7.5

    /// A tower: facade, roof with neon trim, sometimes a setback, an antenna or a rooftop sign.
    static func building(seed: UInt64, tall: Bool, kit: CityKit) -> SCNNode {
        var random = SplitMix(seed: seed)
        let style = FacadeStyle.allCases[random.int(below: FacadeStyle.allCases.count)]
        let units = 1 + random.int(below: 2)
        let floors = tall ? 2 + random.int(below: 3) : 1 + random.int(below: 2)
        let width = Double(units) * CityKit.facadeTileWidth
        let height = Double(floors) * CityKit.facadeTileHeight
        let holder = SCNNode()
        holder.addChildNode(Shapes.box(width, height, width, kit.facade(style, width: width, height: height), at: Shapes.v(0, height / 2, 0)))
        var top = height
        if units == 2, random.chance(0.5) {
            let extra = CityKit.facadeTileHeight * Double(1 + random.int(below: 2))
            let tower = CityKit.facadeTileWidth
            holder.addChildNode(Shapes.box(tower, extra, tower, kit.facade(style, width: tower, height: extra), at: Shapes.v(0, top + extra / 2, 0)))
            addRoof(to: holder, width: width, y: top, neon: random.chance(0.5) ? kit.neonA : kit.neonB, kit: kit)
            top += extra
            addRoof(to: holder, width: tower, y: top, neon: kit.neonB, kit: kit)
        } else {
            addRoof(to: holder, width: width, y: top, neon: random.chance(0.5) ? kit.neonA : kit.neonB, kit: kit)
        }
        if random.chance(0.45) {
            holder.addChildNode(Shapes.cylinder(0.12, 7, kit.steel, at: Shapes.v(0, top + 3.5, 0)))
            holder.addChildNode(Shapes.cylinder(0.35, 0.35, kit.beacon, at: Shapes.v(0, top + 7.1, 0)))
        } else if random.chance(0.5) {
            let sign = kit.randomSign(&random)
            holder.addChildNode(Shapes.panel(min(width, 10) * 0.9, 2.5, sign, at: Shapes.v(0, top + 1.9, width / 2 - 0.5)))
            holder.addChildNode(Shapes.box(0.2, 1.2, 0.2, kit.steel, at: Shapes.v(-2.5, top + 0.6, width / 2 - 0.6)))
            holder.addChildNode(Shapes.box(0.2, 1.2, 0.2, kit.steel, at: Shapes.v(2.5, top + 0.6, width / 2 - 0.6)))
        }
        return kit.library.flatten(holder)
    }

    private static func addRoof(to holder: SCNNode, width: Double, y: Double, neon: SCNMaterial, kit: CityKit) {
        holder.addChildNode(Shapes.box(width + 0.4, 0.5, width + 0.4, kit.roof, at: Shapes.v(0, y + 0.25, 0)))
        let edge = width / 2 + 0.22
        let trim = 0.14
        holder.addChildNode(Shapes.box(width + 0.5, trim, trim, neon, at: Shapes.v(0, y + 0.55, edge)))
        holder.addChildNode(Shapes.box(width + 0.5, trim, trim, neon, at: Shapes.v(0, y + 0.55, -edge)))
        holder.addChildNode(Shapes.box(trim, trim, width + 0.5, neon, at: Shapes.v(edge, y + 0.55, 0)))
        holder.addChildNode(Shapes.box(trim, trim, width + 0.5, neon, at: Shapes.v(-edge, y + 0.55, 0)))
    }

    /// A low shop with a glowing sign over the door, facing the road (-x).
    static func shop(seed: UInt64, kit: CityKit) -> SCNNode {
        var random = SplitMix(seed: seed)
        let style: FacadeStyle = random.chance(0.5) ? .brick : .flats
        let depth = 9.0
        let length = 10 + random.unit() * 6
        let height = 6 + random.unit() * 3
        let holder = SCNNode()
        holder.addChildNode(Shapes.box(depth, height, length, kit.facade(style, width: length, height: height), at: Shapes.v(0, height / 2, 0)))
        holder.addChildNode(Shapes.box(depth + 0.3, 0.4, length + 0.3, kit.roof, at: Shapes.v(0, height + 0.2, 0)))
        let front = -depth / 2 - 0.06
        holder.addChildNode(Shapes.panel(length * 0.8, 1.7, kit.randomSign(&random), at: Shapes.v(front, 3.6, 0), yaw: -.pi / 2))
        let strip = random.chance(0.5) ? kit.neonA : kit.neonB
        holder.addChildNode(Shapes.box(0.12, 0.12, length, strip, at: Shapes.v(front - 0.05, 2.6, 0)))
        holder.addChildNode(Shapes.box(0.12, 0.12, length, strip, at: Shapes.v(front - 0.05, height + 0.45, 0)))
        return kit.library.flatten(holder)
    }

    /// A street lamp on the sidewalk with its arm over the road and a pool of light under it.
    static func lamp(kit: CityKit) -> SCNNode {
        let holder = SCNNode()
        let reach = 2.4
        holder.addChildNode(Shapes.cylinder(0.09, lampHeight, kit.steel, at: Shapes.v(0, lampHeight / 2, 0)))
        holder.addChildNode(Shapes.box(reach, 0.1, 0.12, kit.steel, at: Shapes.v(-reach / 2, lampHeight, 0)))
        holder.addChildNode(Shapes.box(0.9, 0.12, 0.34, kit.lampHead, at: Shapes.v(-reach, lampHeight - 0.08, 0)))
        let poolY = -RoadMetrics.sidewalkHeight + 0.025
        holder.addChildNode(Shapes.decal(8, 8, kit.lightPool, at: Shapes.v(-reach - 0.6, poolY, 0)))
        return kit.library.flatten(holder)
    }

    /// A neon billboard on two legs, angled towards oncoming riders.
    static func billboard(kit: CityKit) -> SignProp {
        let frame = SCNNode()
        let width = 7.0
        let height = 1.9
        let boardY = 5.6
        frame.addChildNode(Shapes.box(0.22, boardY, 0.22, kit.steel, at: Shapes.v(-width * 0.35, boardY / 2, -0.1)))
        frame.addChildNode(Shapes.box(0.22, boardY, 0.22, kit.steel, at: Shapes.v(width * 0.35, boardY / 2, -0.1)))
        frame.addChildNode(Shapes.box(width + 0.3, height + 0.3, 0.16, kit.roof, at: Shapes.v(0, boardY, -0.1)))
        frame.addChildNode(Shapes.box(width + 0.3, 0.08, 0.08, kit.neonB, at: Shapes.v(0, boardY - height / 2 - 0.2, 0.02)))
        let node = SCNNode()
        node.addChildNode(kit.library.flatten(frame))
        let board = Shapes.panel(width, height, kit.signMaterials[0], at: Shapes.v(0, boardY, 0))
        node.addChildNode(board)
        return SignProp(node: node, board: board)
    }

    /// A steel gantry over the whole road carrying two green signs.
    static func gantry(kit: CityKit) -> GantryProp {
        let frame = SCNNode()
        let span = (RoadMetrics.sidewalkInner + 1.4) * 2
        let postHeight = 7.6
        for side in [-1.0, 1.0] {
            frame.addChildNode(Shapes.box(0.45, postHeight, 0.45, kit.steel, at: Shapes.v(side * span / 2, postHeight / 2, 0)))
        }
        frame.addChildNode(Shapes.box(span + 0.6, 0.4, 0.5, kit.steel, at: Shapes.v(0, postHeight, 0)))
        frame.addChildNode(Shapes.box(span, 0.25, 0.3, kit.steel, at: Shapes.v(0, postHeight - 1.9, 0)))
        for x in [-2.6, 2.6] {
            frame.addChildNode(Shapes.box(3.6, 0.1, 0.2, kit.tubeLight, at: Shapes.v(x, postHeight + 0.3, 0.45)))
        }
        let node = SCNNode()
        node.addChildNode(kit.library.flatten(frame))
        var panels: [SCNNode] = []
        for (index, x) in [-2.6, 2.6].enumerated() {
            let material = kit.library.shared("gantry-panel-\(index)") { WorldMaterials.screen(UIImage(), boost: 0.35) }
            let panel = Shapes.panel(4.6, 1.85, material, at: Shapes.v(x, postHeight - 0.95, 0.3))
            node.addChildNode(panel)
            panels.append(panel)
        }
        return GantryProp(node: node, panels: panels)
    }
}
