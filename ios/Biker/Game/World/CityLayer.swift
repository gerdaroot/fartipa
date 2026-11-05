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
        gantries.add(gantry.node, offset: 150, parent: root)
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

    private func dressGantry(worldZ: Double) {
        guard let gantry = gantryProp, gantry.panels.count == 2 else { return }
        let next = District.all.first { $0.startDistance > worldZ }
        let title: String
        let detail: String
        if let next {
            let kilometres = (next.startDistance - worldZ) / 1000
            title = next.name.uppercased()
            detail = String(format: "%.1f км  ↑", kilometres)
        } else {
            title = "ЖОПА МИРА"
            detail = "ДАЛЬШЕ НЕКУДА"
        }
        var random = SlotRandom.make(row: 6, slot: 0, lap: Int(worldZ))
        let jokes: [(String, String)] = [
            ("ТУАЛЕТ", "0,5 км  →"), ("ОБЪЕЗД КУЧИ", "ДЕРЖИСЬ ЛЕВЕЕ"), ("НЕ ПЕРДЕТЬ", "ШТРАФ 500 ₽"),
            ("ОСАДКИ: ЖЁЛТЫЕ", "ВКЛЮЧИ ДВОРНИКИ"), ("ЦЕНТР", "ПРЯМО И ВНИЗ"),
        ]
        let joke = jokes[random.int(below: jokes.count)]
        Self.show(CityTextures.roadSign(title: title, detail: detail), on: gantry.panels[0])
        Self.show(CityTextures.roadSign(title: joke.0, detail: joke.1), on: gantry.panels[1])
    }

    private static func show(_ image: UIImage, on panel: SCNNode) {
        panel.geometry?.firstMaterial?.diffuse.contents = image
        panel.geometry?.firstMaterial?.emission.contents = image
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
}
