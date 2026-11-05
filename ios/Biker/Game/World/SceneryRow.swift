import SceneKit

/// Where something that repeats every `period` metres along the road sits right now.
/// Copy `k` of an item with `offset` lies at `offset + k * period`; this picks the nearest copy
/// that is not more than `behind` metres behind the bike.
enum LoopMath {
    static func lap(offset: Double, period: Double, distance: Double, behind: Double) -> Int {
        Int(((distance - behind - offset) / period).rounded(.up))
    }

    static func worldZ(offset: Double, period: Double, lap: Int) -> Double {
        offset + Double(lap) * period
    }
}

/// Roadside things that recycle: when one falls behind it jumps a whole period ahead and is
/// re-dressed for its new lap. Works for any distance, including a new ride starting at 0.
@MainActor
final class SceneryRow {
    private struct Item {
        let node: SCNNode
        let offset: Double
        var lap: Int
        var isShown: Bool
    }

    let period: Double
    private let behind: Double
    /// Items further ahead than this are hidden. Lower tiers draw less of the city.
    var maxAhead: Double
    private var items: [Item] = []

    init(period: Double, behind: Double, maxAhead: Double) {
        self.period = period
        self.behind = behind
        self.maxAhead = maxAhead
    }

    func add(_ node: SCNNode, offset: Double, parent: SCNNode) {
        parent.addChildNode(node)
        items.append(Item(node: node, offset: offset, lap: Int.min, isShown: true))
    }

    /// Places every item. `dress(node, slot, lap, worldZ)` runs when an item starts a new lap and
    /// returns whether it should be shown on that lap.
    func update(distance: Double, dress: (SCNNode, Int, Int, Double) -> Bool) {
        for index in items.indices {
            let item = items[index]
            let lap = LoopMath.lap(offset: item.offset, period: period, distance: distance, behind: behind)
            let worldZ = LoopMath.worldZ(offset: item.offset, period: period, lap: lap)
            if lap != item.lap {
                items[index].lap = lap
                items[index].isShown = dress(item.node, index, lap, worldZ)
            }
            let sceneZ = distance - worldZ
            let node = item.node
            let hidden = !items[index].isShown || sceneZ < -maxAhead
            if node.isHidden != hidden { node.isHidden = hidden }
            guard !hidden else { continue }
            var position = node.position
            position.z = Float(sceneZ)
            node.position = position
        }
    }

    /// Forces every item to be re-dressed on the next update, e.g. after a palette change.
    func invalidate() {
        for index in items.indices { items[index].lap = Int.min }
    }
}

/// Seeded randomness for one item on one lap, so the same place always looks the same.
enum SlotRandom {
    static func make(row: UInt64, slot: Int, lap: Int) -> SplitMix {
        let mixed = row &* 0x9E37_79B9 &+ UInt64(bitPattern: Int64(slot)) &* 0x85EB_CA6B &+ UInt64(bitPattern: Int64(lap)) &* 0xC2B2_AE35
        var random = SplitMix(seed: mixed)
        _ = random.next()
        return random
    }
}
