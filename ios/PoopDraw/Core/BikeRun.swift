import Foundation

/// Small seeded generator, so a run can be replayed exactly in tests.
struct SplitMix {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func int(below limit: Int) -> Int {
        Int(next() % UInt64(limit))
    }
}

struct RoadCoin {
    let x: Double
    let z: Double
}

/// A column of piss falling from the sky. From far along the road some of them sway.
struct PissStream {
    let baseX: Double
    let z: Double
    let sway: Double
    let phase: Double

    func x(atTime time: Double) -> Double {
        baseX + sway * sin(phase + time * 2.2)
    }
}

enum BikeEvent: Equatable {
    case coin
    case hit
    case gameOver
}

/// One ride: all the rules, no graphics. `z` is metres along the road.
struct BikeRun {
    static let laneX = [-2.6, 0, 2.6]
    static let roadHalfWidth = 4.0
    static let startingLives = 3
    static let startSpeed = 22.0
    static let topSpeed = 55.0

    private static let bikeLimit = 3.4
    private static let steerRate = 12.0
    private static let rampSeconds = 150.0
    private static let streamReach = 1.35
    private static let coinReach = 1.2
    private static let lookAhead = 260.0
    private static let behind = 12.0
    private static let reactionSeconds = 0.8
    private static let invulnerableSeconds = 1.4
    private static let slowdownSeconds = 1.0
    private static let slowdownFactor = 0.6

    private(set) var x = 0.0
    private(set) var distance = 0.0
    private(set) var time = 0.0
    private(set) var lives = BikeRun.startingLives
    private(set) var coins = 0
    private(set) var invulnerable = 0.0
    private(set) var isOver = false
    private(set) var streams: [PissStream] = []
    private(set) var pickups: [RoadCoin] = []

    private var slowdown = 0.0
    private var nextRowAt = 70.0
    private var random: SplitMix

    init(seed: UInt64) {
        random = SplitMix(seed: seed)
        spawnAhead()
    }

    var speed: Double {
        let ramp = min(1, time / Self.rampSeconds)
        let cruising = Self.startSpeed + (Self.topSpeed - Self.startSpeed) * ramp
        return slowdown > 0 ? cruising * Self.slowdownFactor : cruising
    }

    var score: Int { Int(distance) + coins * 5 }

    /// Moves the ride forward and reports what happened. `targetX` is where the finger steers.
    mutating func update(dt: Double, targetX: Double) -> [BikeEvent] {
        guard !isOver, dt > 0 else { return [] }
        let previous = distance
        let limit = Self.steerRate * dt
        let wanted = min(Self.bikeLimit, max(-Self.bikeLimit, targetX))
        x += min(limit, max(-limit, wanted - x))
        distance += speed * dt
        time += dt
        invulnerable = max(0, invulnerable - dt)
        slowdown = max(0, slowdown - dt)

        var events = collectCoins(after: previous)
        events += checkStreams(after: previous)
        spawnAhead()
        let cutoff = distance - Self.behind
        streams.removeAll { $0.z < cutoff }
        pickups.removeAll { $0.z < cutoff }
        return events
    }

    /// Where a careful rider would steer now: away from the next stream, otherwise toward coins.
    func autopilotTarget() -> Double {
        let ahead = streams.filter { $0.z > distance }.sorted { $0.z < $1.z }
        if let next = ahead.first, next.z - distance < speed * 1.5 {
            let row = ahead.filter { abs($0.z - next.z) < 1 }
            let safe = Self.laneX.filter { lane in
                row.allSatisfy { abs(lane - $0.baseX) > $0.sway + Self.streamReach }
            }
            return safe.min { abs($0 - x) < abs($1 - x) } ?? x
        }
        return pickups.first { $0.z > distance }?.x ?? x
    }

    private mutating func collectCoins(after previous: Double) -> [BikeEvent] {
        let end = distance
        let bikeX = x
        let isCollected = { (coin: RoadCoin) in
            coin.z > previous && coin.z <= end && abs(coin.x - bikeX) < Self.coinReach
        }
        let count = pickups.filter(isCollected).count
        guard count > 0 else { return [] }
        coins += count
        pickups.removeAll(where: isCollected)
        return [BikeEvent](repeating: .coin, count: count)
    }

    private mutating func checkStreams(after previous: Double) -> [BikeEvent] {
        guard invulnerable == 0 else { return [] }
        let currentTime = time
        let currentX = x
        let touched = streams.contains { stream in
            stream.z > previous && stream.z <= distance
                && abs(stream.x(atTime: currentTime) - currentX) < Self.streamReach
        }
        guard touched else { return [] }
        lives -= 1
        invulnerable = Self.invulnerableSeconds
        slowdown = Self.slowdownSeconds
        if lives <= 0 {
            isOver = true
            return [.hit, .gameOver]
        }
        return [.hit]
    }

    // MARK: - Road layout

    private mutating func spawnAhead() {
        while nextRowAt < distance + Self.lookAhead {
            let z = nextRowAt
            let gap = rowGap(at: z)
            if random.unit() < 0.7 { spawnStreams(at: z) }
            spawnCoins(from: z + gap * 0.25, spacing: min(3, gap * 0.1))
            nextRowAt += gap
        }
    }

    /// Rows never come closer than a rider at that speed can react to.
    private func rowGap(at z: Double) -> Double {
        let secondsThere = time + (z - distance) / max(1, speed)
        let ramp = min(1, secondsThere / Self.rampSeconds)
        let speedThere = Self.startSpeed + (Self.topSpeed - Self.startSpeed) * ramp
        return max(max(22, 34 - z / 200), speedThere * Self.reactionSeconds)
    }

    /// At most two of the three lanes, so there is always a way through.
    private mutating func spawnStreams(at z: Double) {
        let twoLanes = z > 300 && random.unit() < 0.45
        let first = random.int(below: 3)
        let lanes = twoLanes ? [first, (first + 1 + random.int(below: 2)) % 3] : [first]
        let sway = !twoLanes && z > 800 && random.unit() < 0.5 ? 1.0 : 0
        for lane in lanes {
            streams.append(PissStream(baseX: Self.laneX[lane], z: z, sway: sway, phase: random.unit() * 6.28))
        }
    }

    private mutating func spawnCoins(from start: Double, spacing: Double) {
        let lane = Self.laneX[random.int(below: 3)]
        let weave = random.unit() < 0.4 ? (lane == 0 ? 1.4 : -lane * 0.4) : 0
        for index in 0..<5 {
            let offset = weave * sin(Double(index) / 4 * .pi)
            pickups.append(RoadCoin(x: lane + offset, z: start + Double(index) * spacing))
        }
    }
}
