import SceneKit
import UIKit

/// Where the tunnels are: one every `period` metres, `length` long. Lamps, signs and gantries
/// that would stand inside one are hidden.
enum TunnelSchedule {
    static let period = 1700.0
    static let offset = 1050.0
    static let length = 110.0
    private static let margin = 10.0

    static func covers(worldZ: Double) -> Bool {
        let lap = ((worldZ - offset) / period).rounded(.down)
        let local = worldZ - (offset + lap * period)
        return local >= -margin && local <= length + margin
    }
}

/// The big set pieces: an overpass bridge and a lit tunnel. Both are built from z 0 (the end the
/// rider meets first) towards -z.
@MainActor
enum CityStructures {
    private static let segments = 22

    static func bridge(kit: CityKit) -> SCNNode {
        let holder = SCNNode()
        let span = 120.0
        let deckY = 8.2
        let deck = 11.0
        holder.addChildNode(Shapes.box(span, 1.3, deck, kit.concrete, at: Shapes.v(0, deckY, -deck / 2)))
        for z in [0.15, -deck - 0.15] {
            holder.addChildNode(Shapes.box(span, 1.1, 0.3, kit.concrete, at: Shapes.v(0, deckY + 1.2, z)))
            holder.addChildNode(Shapes.box(span, 0.12, 0.12, kit.neonB, at: Shapes.v(0, deckY - 0.7, z + (z > 0 ? 0.05 : -0.05))))
        }
        for x in [-8.4, 8.4, -26.0, 26.0] {
            holder.addChildNode(Shapes.box(1.3, deckY - 0.6, 3.2, kit.concrete, at: Shapes.v(x, (deckY - 0.6) / 2, -deck / 2)))
        }
        for x in [-3.0, 3.0] {
            holder.addChildNode(Shapes.box(2.4, 0.08, 0.3, kit.tubeLight, at: Shapes.v(x, deckY - 0.7, -deck / 2)))
        }
        let name = kit.screen(named: "bridgeName", boost: 0.7) {
            CityTextures.plate("МОСТ ИМ. ДЕДА ПЕРДУНА", background: UIColor(red: 0.1, green: 0.12, blue: 0.3, alpha: 1),
                               foreground: UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1), size: CGSize(width: 1024, height: 128))
        }
        holder.addChildNode(Shapes.panel(16, 2, name, at: Shapes.v(0, deckY + 0.05, 0.32)))
        return kit.library.flatten(holder)
    }

    static func tunnel(kit: CityKit) -> SCNNode {
        let holder = SCNNode()
        let length = TunnelSchedule.length
        let halfWidth = RoadMetrics.sidewalkInner + RoadMetrics.sidewalkWidth + 0.4
        let height = 7.4
        let middle = -length / 2
        let wall = kit.library.shared("tunnelWall") {
            WorldMaterials.pbr(UIColor(red: 0.42, green: 0.45, blue: 0.4, alpha: 1), roughness: 0.35)
        }
        for side in [-1.0, 1.0] {
            holder.addChildNode(Shapes.box(0.8, height, length, wall, at: Shapes.v(side * halfWidth, height / 2, middle), segments: segments))
            holder.addChildNode(Shapes.box(0.08, 0.14, length, kit.neonA, at: Shapes.v(side * (halfWidth - 0.42), 1.3, middle), segments: segments))
            holder.addChildNode(Shapes.box(0.3, 0.1, length, kit.tubeLight, at: Shapes.v(side * 3.0, height - 0.35, middle), segments: segments))
        }
        holder.addChildNode(Shapes.box(halfWidth * 2 + 0.8, 0.8, length, wall, at: Shapes.v(0, height, middle), segments: segments))
        holder.addChildNode(Shapes.box(halfWidth * 2 + 6, 5, 2.4, kit.concrete, at: Shapes.v(0, height + 2.1, -1.2)))
        for z in stride(from: -8.0, to: -length, by: -14.0) {
            holder.addChildNode(Shapes.decal(7, 9, kit.lightPool, at: Shapes.v(0, 0.03, z)))
        }
        let name = kit.screen(named: "tunnelName", boost: 1) {
            CityTextures.neonSign("ТОННЕЛЬ «КИШКА»", color: ColorValue(hex: 0x8CFF2E), accent: ColorValue(hex: 0xFF2E93))
        }
        holder.addChildNode(Shapes.panel(11, 3, name, at: Shapes.v(0, height + 2.2, 0.05)))
        return kit.library.flatten(holder)
    }
}
