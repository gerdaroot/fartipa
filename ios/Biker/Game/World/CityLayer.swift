import SceneKit
import UIKit

/// The night city along the highway: rows of towers and shops, lamps, neon billboards, a gantry,
/// and now and then a bridge or a tunnel. Everything recycles in loops of about 330 m.
@MainActor
final class CityLayer {
    private static let behind = 30.0
    private static let maxAhead = 330.0
    private static let lampSpacing = 16.0
    private static let lampCount = 20
    private static let signCount = 8
    private static let shopCount = 12
    private static let nearCount = 14
    private static let farCount = 10
    private static let gantryOffset = 150.0

    private let kit: CityKit
    private let root = SCNNode()
    private let lamps: SceneryRow
    private let signs: SceneryRow
    private let shops: SceneryRow
    private let nearTowers: SceneryRow
    private let farTowers: SceneryRow
    private let gantries: SceneryRow
    private let bridges: SceneryRow
    private let tunnels: SceneryRow
    private var signProps: [SignProp] = []
    private var gantryProp: GantryProp?
    private var gantrySigns: GantrySigns?
    private var posterMaterial: SCNMaterial?

    init(parent: SCNNode, library: MaterialLibrary) {
        kit = CityKit(library: library)
        lamps = SceneryRow(period: Self.lampSpacing * Double(Self.lampCount), behind: Self.behind, maxAhead: Self.maxAhead)
        signs = SceneryRow(period: 336, behind: Self.behind, maxAhead: Self.maxAhead)
        shops = SceneryRow(period: 336, behind: Self.behind, maxAhead: Self.maxAhead)
        nearTowers = SceneryRow(period: 336, behind: Self.behind + 10, maxAhead: Self.maxAhead + 40)
        farTowers = SceneryRow(period: 360, behind: Self.behind + 20, maxAhead: Self.maxAhead + 60)
        gantries = SceneryRow(period: 290, behind: Self.behind, maxAhead: Self.maxAhead)
        bridges = SceneryRow(period: 1150, behind: Self.behind + 10, maxAhead: Self.maxAhead + 40)
        tunnels = SceneryRow(period: TunnelSchedule.period, behind: TunnelSchedule.length + 25, maxAhead: Self.maxAhead + 40)
        parent.addChildNode(root)
        populate()
    }

    private func populate() {
        for index in 0..<Self.lampCount {
            lamps.add(CityProps.lamp(kit: kit), offset: Double(index) * Self.lampSpacing, parent: root)
        }
        for index in 0..<Self.signCount {
            let prop = CityProps.billboard(kit: kit)
            signProps.append(prop)
            signs.add(prop.node, offset: 13 + Double(index) * signs.period / Double(Self.signCount), parent: root)
        }
        for index in 0..<Self.shopCount {
            shops.add(CityProps.shop(seed: UInt64(500 + index), kit: kit), offset: 6 + Double(index) * shops.period / Double(Self.shopCount), parent: root)
        }
        for index in 0..<Self.nearCount {
            let tower = CityProps.building(seed: UInt64(1000 + index), tall: false, kit: kit)
            nearTowers.add(tower, offset: Double(index) * nearTowers.period / Double(Self.nearCount), parent: root)
        }
        for index in 0..<Self.farCount {
            let tower = CityProps.building(seed: UInt64(2000 + index), tall: true, kit: kit)
            farTowers.add(tower, offset: 9 + Double(index) * farTowers.period / Double(Self.farCount), parent: root)
        }
        let gantry = CityProps.gantry(kit: kit)
        gantryProp = gantry
        gantrySigns = GantrySigns(panels: gantry.panels)
        gantries.add(gantry.node, offset: Self.gantryOffset, parent: root)
        bridges.add(CityStructures.bridge(kit: kit), offset: 610, parent: root)
        tunnels.add(CityStructures.tunnel(kit: kit), offset: TunnelSchedule.offset, parent: root)
    }

    // MARK: - Per frame

    func update(distance: Double, time: Double) {
        lamps.update(distance: distance) { node, slot, _, worldZ in
            let side = slot % 2 == 0 ? 1.0 : -1.0
            Self.face(node, side: side, x: CityProps.lampX)
            return !TunnelSchedule.covers(worldZ: worldZ)
        }
        signs.update(distance: distance) { node, slot, lap, worldZ in
            dressSign(node, slot: slot, lap: lap)
            return !TunnelSchedule.covers(worldZ: worldZ)
        }
        shops.update(distance: distance) { node, slot, lap, worldZ in
            var random = SlotRandom.make(row: 3, slot: slot, lap: lap)
            Self.face(node, side: random.chance(0.5) ? 1 : -1, x: 16 + random.unit())
            return !TunnelSchedule.covers(worldZ: worldZ) && random.chance(0.8)
        }
        nearTowers.update(distance: distance) { node, slot, lap, _ in
            var random = SlotRandom.make(row: 4, slot: slot, lap: lap)
            Self.face(node, side: slot % 2 == 0 ? 1 : -1, x: 31 + random.unit() * 5)
            return true
        }
        farTowers.update(distance: distance) { node, slot, lap, _ in
            var random = SlotRandom.make(row: 5, slot: slot, lap: lap)
            Self.face(node, side: slot % 2 == 0 ? -1 : 1, x: 58 + random.unit() * 20)
            return true
        }
        gantries.update(distance: distance) { _, _, _, worldZ in
            dressGantry(worldZ: worldZ)
            return !TunnelSchedule.covers(worldZ: worldZ)
        }
        bridges.update(distance: distance) { _, _, _, worldZ in !TunnelSchedule.covers(worldZ: worldZ) }
        tunnels.update(distance: distance) { _, _, _, _ in true }
        kit.pulse(time: time)
    }

    /// Hides decor further ahead than `metres` (lower tiers draw less of the city).
    func setDrawDistance(_ metres: Double) {
        for row in [lamps, signs, shops, gantries] { row.maxAhead = metres }
        nearTowers.maxAhead = metres + 40
        farTowers.maxAhead = metres + 60
        bridges.maxAhead = metres + 40
        tunnels.maxAhead = metres + 40
    }

    /// Paints the first gantry signs ahead of time; call while loading.
    func prepareSigns() {
        let first = LoopMath.worldZ(offset: Self.gantryOffset, period: gantries.period, lap: 0)
        gantrySigns?.show(worldZ: first, now: true)
    }

    /// Puts a right-hand-built prop on one side of the road, turned to face it.
    private static func face(_ node: SCNNode, side: Double, x: Double) {
        node.position = SCNVector3(Float(side * x), node.position.y, node.position.z)
        node.eulerAngles.y = side > 0 ? 0 : .pi
    }

    private func dressSign(_ node: SCNNode, slot: Int, lap: Int) {
        var random = SlotRandom.make(row: 2, slot: slot, lap: lap)
        let side: Double = slot % 2 == 0 ? 1 : -1
        node.position = SCNVector3(Float(side * (8.4 + random.unit() * 0.5)), 0, node.position.z)
        node.eulerAngles.y = Float(-side * 0.38)
        guard slot < signProps.count else { return }
        let board = signProps[slot].board
        if let posterMaterial, random.chance(0.2) {
            board.geometry?.firstMaterial = posterMaterial
        } else {
            board.geometry?.firstMaterial = kit.randomSign(&random)
        }
    }

    /// The gantry gets fresh text every lap. The pictures are painted off the main thread and swapped
    /// in when ready; the gantry is still a few hundred metres away at that point.
    private func dressGantry(worldZ: Double) {
        gantrySigns?.show(worldZ: worldZ)
    }

    // MARK: - Looks

    func apply(_ palette: WorldPalette) {
        kit.apply(palette)
    }

    /// Shows the player's own picture on some billboards.
    func setPoster(_ image: UIImage) {
        let material = kit.library.shared("poster") { WorldMaterials.screen(image, boost: 0.5) }
        material.diffuse.contents = image
        material.emission.contents = image
        posterMaterial = material
        signs.invalidate()
    }

    /// Paints the neon slogans in the background; `done` runs on the main actor when they are on.
    func paintSigns(done: @escaping @MainActor () -> Void) {
        kit.paintSigns(done: done)
    }

}
