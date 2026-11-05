import SceneKit
import UIKit

/// A pooled vehicle that smokes once wrecked.
@MainActor
final class VehicleItem: PooledItem {
    let root = SCNNode()
    let body: SCNNode
    private let smoke = WorldParticles.smoke()
    private static let smokeRate: CGFloat = 26

    init(kind: VehicleKind, library: MaterialLibrary) {
        body = VehicleModels.make(kind, library: library)
        root.addChildNode(body)
        let smokeNode = SCNNode()
        smokeNode.position = Shapes.v(0, 1.8, -kind.halfLength + 1)
        smokeNode.addParticleSystem(smoke)
        root.addChildNode(smokeNode)
    }

    func recycle() {
        smoke.birthRate = 0
        body.eulerAngles = SCNVector3(0, 0, 0)
    }

    func update(wrecked: Bool, clock: Double, phase: Double, live: Bool, budget: CGFloat) {
        smoke.birthRate = wrecked && live ? Self.smokeRate * budget : 0
        if wrecked {
            body.eulerAngles = SCNVector3(0, 0.35, 0.12)
        } else {
            body.position.y = Float(0.02 * sin(clock * 9 + phase))
        }
    }
}

/// Draws everything on the road from a `BikeRun`: one stable node per object id.
@MainActor
final class ObjectsLayer {
    private static let visibleAhead = 230.0
    /// Coins are small; past this they are a few pixels in the fog, so they are not drawn.
    private static let coinsAhead = 170.0
    private static let visibleBehind = 14.0
    /// Pool sizes for the worst case the road generator can put in view, so nothing is built mid-ride.
    private static let streamCount = 24
    private static let pileCount = 16
    private static let coinCount = 72
    private static let goldenCount = 4
    private static let vehiclesPerKind = 6
    private static let pickupsPerKind = 2

    private let root: SCNNode
    private let library: MaterialLibrary
    private let streamKit: StreamKit
    private let streams: KeyedPool<StreamItem>
    private let piles: KeyedPool<SimpleItem>
    private let coins: KeyedPool<SimpleItem>
    private let goldenCoins: KeyedPool<SimpleItem>
    private var vehicles: [VehicleKind: KeyedPool<VehicleItem>] = [:]
    private var pickups: [PickupKind: KeyedPool<SimpleItem>] = [:]
    var budget: CGFloat = 1

    init(parent: SCNNode, library: MaterialLibrary) {
        self.library = library
        let holder = SCNNode()
        root = holder
        parent.addChildNode(holder)
        let kit = StreamKit(library: library)
        streamKit = kit
        streams = KeyedPool(parent: holder, prewarm: Self.streamCount) { StreamItem(kit: kit) }
        var pileSeed: UInt64 = 0
        piles = KeyedPool(parent: holder, prewarm: Self.pileCount) {
            pileSeed &+= 1
            return ObjectModels.pile(library: library, seed: pileSeed)
        }
        coins = KeyedPool(parent: holder, prewarm: Self.coinCount) { ObjectModels.coin(library: library, golden: false) }
        goldenCoins = KeyedPool(parent: holder, prewarm: Self.goldenCount) { ObjectModels.coin(library: library, golden: true) }
        for kind in VehicleKind.allCases {
            vehicles[kind] = KeyedPool(parent: holder, prewarm: Self.vehiclesPerKind) { VehicleItem(kind: kind, library: library) }
        }
        for kind in PickupKind.allCases {
            pickups[kind] = KeyedPool(parent: holder, prewarm: Self.pickupsPerKind) { ObjectModels.pickup(kind, library: library) }
        }
        for index in 0..<VehicleModels.paints.count { _ = VehicleModels.paint(index, library: library) }
    }

    /// Shows every pooled item spread out in front of the camera (or hides them again), so their
    /// shaders, textures and geometry reach the GPU behind the loading screen, not mid-ride.
    func setWarming(_ on: Bool) {
        var slot = 0
        let show: (SCNNode) -> Void = { node in
            node.isHidden = !on
            guard on else { return }
            let column = slot % 9
            let row = slot / 9
            node.position = SCNVector3(Float(column - 4) * 1.6, 0, Float(-12 - row * 5))
            slot += 1
        }
        streams.forEachSpare { show($0.root) }
        piles.forEachSpare { show($0.root) }
        coins.forEachSpare { show($0.root) }
        goldenCoins.forEachSpare { show($0.root) }
        for pool in vehicles.values { pool.forEachSpare { show($0.root) } }
        for pool in pickups.values { pool.forEachSpare { show($0.root) } }
    }

    /// Drops every node, e.g. when a new ride starts.
    func releaseAll() {
        streams.releaseAll()
        piles.releaseAll()
        coins.releaseAll()
        goldenCoins.releaseAll()
        for pool in vehicles.values { pool.releaseAll() }
        for pool in pickups.values { pool.releaseAll() }
    }

    func update(_ run: BikeRun, bend: BendAmount, clock: Double, dt: Double, live: Bool) {
        let distance = run.distance
        streamKit.flow(clock: clock)
        updateStreams(run, bend: bend, clock: clock, dt: dt)
        updateVehicles(run.vehicles, distance: distance, bend: bend, clock: clock, live: live)
        piles.begin()
        for pile in run.piles {
            guard let ahead = visible(pile.z, distance) else { continue }
            place(piles.item(for: pile.id).item.root, x: pile.x, ahead: ahead, lift: 0, bend: bend)
        }
        piles.end()
        updateCoins(run.roadCoins, distance: distance, bend: bend, clock: clock)
        updatePickups(run.roadPickups, distance: distance, bend: bend, clock: clock)
    }

    private func visible(_ z: Double, _ distance: Double) -> Double? {
        let ahead = z - distance
        return ahead > Self.visibleAhead || ahead < -Self.visibleBehind ? nil : ahead
    }

    /// Puts a node on the bent road `ahead` metres in front of the bike and turns it along the curve.
    private func place(_ node: SCNNode, x: Double, ahead: Double, lift: Double, bend: BendAmount) {
        let offset = bend.offset(ahead: ahead)
        let slope = bend.slope(ahead: ahead)
        node.position = SCNVector3(Float(x + offset.x), Float(offset.y + lift), Float(-ahead))
        node.eulerAngles = SCNVector3(Float(slope.pitch), Float(slope.yaw), 0)
    }

    private func updateStreams(_ run: BikeRun, bend: BendAmount, clock: Double, dt: Double) {
        streams.begin()
        for stream in run.streams where stream.isVisible {
            guard let ahead = visible(stream.z, run.distance) else { continue }
            let item = streams.item(for: stream.id).item
            item.budget = budget
            place(item.root, x: stream.x(atTime: run.time), ahead: ahead, lift: 0, bend: bend)
            item.root.eulerAngles = SCNVector3(0, 0, 0)
            item.update(stream, clock: clock, dt: dt)
        }
        streams.end()
    }

    private func updateVehicles(_ list: [Vehicle], distance: Double, bend: BendAmount, clock: Double, live: Bool) {
        for pool in vehicles.values { pool.begin() }
        for vehicle in list {
            guard let ahead = visible(vehicle.z, distance), let pool = vehicles[vehicle.kind] else { continue }
            let (item, isNew) = pool.item(for: vehicle.id)
            if isNew, vehicle.kind == .car {
                VehicleModels.repaint(item.body, with: VehicleModels.paint(vehicle.id, library: library))
            }
            place(item.root, x: vehicle.x, ahead: ahead, lift: 0, bend: bend)
            item.update(wrecked: vehicle.isWrecked, clock: clock, phase: Double(vehicle.id), live: live, budget: budget)
        }
        for pool in vehicles.values { pool.end() }
    }

    private func updateCoins(_ list: [RoadCoin], distance: Double, bend: BendAmount, clock: Double) {
        coins.begin()
        goldenCoins.begin()
        let spin = Float((clock * 3.4).truncatingRemainder(dividingBy: 2 * .pi))
        for coin in list {
            guard let ahead = visible(coin.z, distance), ahead < Self.coinsAhead else { continue }
            let pool = coin.isGolden ? goldenCoins : coins
            let item = pool.item(for: coin.id).item
            place(item.root, x: coin.x, ahead: ahead, lift: 0, bend: bend)
            item.spinner?.eulerAngles.y = spin + Float(coin.id % 7) * 0.2
            item.spinner?.position.y = Float(ObjectModels.coinHeight + (coin.isGolden ? 0.3 : 0) + 0.08 * sin(clock * 3 + Double(coin.id)))
        }
        coins.end()
        goldenCoins.end()
    }

    private func updatePickups(_ list: [RoadPickup], distance: Double, bend: BendAmount, clock: Double) {
        for pool in pickups.values { pool.begin() }
        for pickup in list {
            guard let ahead = visible(pickup.z, distance), let pool = pickups[pickup.kind] else { continue }
            let item = pool.item(for: pickup.id).item
            place(item.root, x: pickup.x, ahead: ahead, lift: 0, bend: bend)
            item.spinner?.position.y = Float(ObjectModels.pickupHeight + 0.18 * sin(clock * 2.6 + Double(pickup.id)))
        }
        for pool in pickups.values { pool.end() }
    }
}
