import Foundation

// Everything that lies on the road. `x` is metres across the road (0 is the middle),
// `z` is metres along it, in the same units as `BikeRun.distance`.

enum StreamMotion: String, Equatable {
    case still
    /// Wobbles around its lane.
    case sway
    /// Crosses the whole road from side to side.
    case sweep
}

/// A column of piss falling from the sky.
///
/// It first shows as a marker on the road: `warning` climbs from 0 to 1 while the marker grows,
/// and at 1 it pours. Before that it cannot hurt anyone.
struct PissStream: Equatable {
    static let swayAmplitude = 0.9
    static let swayRate = 2.2
    static let sweepAmplitude = 3.0
    static let sweepRate = 1.1
    /// Seconds of real pouring the rider still has ahead of him when the warning ends.
    static let pourLeadSeconds = 0.5
    private static let shortestWarning = 0.01

    let id: Int
    /// Streams of one row share this. A row always leaves a lane open.
    let rowId: Int
    let motion: StreamMotion
    let baseX: Double
    let z: Double
    let phase: Double
    let warningSeconds: Double
    /// 0 is not on the road yet, between 0 and 1 is the marker, 1 is pouring.
    private(set) var warning: Double

    init(
        id: Int = 0, rowId: Int = 0, motion: StreamMotion = .still, baseX: Double, z: Double,
        phase: Double = 0, warningSeconds: Double = 1, warning: Double = 0
    ) {
        self.id = id
        self.rowId = rowId
        self.motion = motion
        self.baseX = baseX
        self.z = z
        self.phase = phase
        self.warningSeconds = warningSeconds
        self.warning = warning
    }

    var isVisible: Bool { warning > 0 }
    var isPouring: Bool { warning >= 1 }

    /// Where the stream hits the road at a moment of `BikeRun.time`.
    func x(atTime time: Double) -> Double {
        switch motion {
        case .still: return baseX
        case .sway: return baseX + Self.swayAmplitude * sin(phase + time * Self.swayRate)
        case .sweep: return baseX + Self.sweepAmplitude * sin(phase + time * Self.sweepRate)
        }
    }

    /// The warning starts by how soon the rider arrives and then only moves forward.
    func advanced(dt: Double, riderDistance: Double, riderSpeed: Double) -> PissStream {
        let secondsAway = (z - riderDistance) / max(1, riderSpeed)
        guard warning > 0 || secondsAway <= warningSeconds + Self.pourLeadSeconds else { return self }
        var next = self
        next.warning = min(1, warning + dt / max(Self.shortestWarning, warningSeconds))
        return next
    }
}

enum VehicleKind: String, CaseIterable, Codable, Equatable {
    case car
    case truck
    case sewageTanker

    var halfLength: Double {
        switch self {
        case .car: return 2.2
        case .truck: return 4.5
        case .sewageTanker: return 3.8
        }
    }

    var halfWidth: Double {
        switch self {
        case .car: return 1.0
        case .truck, .sewageTanker: return 1.25
        }
    }

    var cruiseSpeed: Double {
        switch self {
        case .car: return 14
        case .truck: return 11
        case .sewageTanker: return 9
        }
    }
}

/// Slow traffic in a lane. It drives off when the rider is close and brakes before `limitZ`,
/// so it never rolls into the next obstacle on the road and walls off the last open lane.
struct Vehicle: Equatable {
    /// How long before the rider arrives the vehicle starts to move.
    static let activationSeconds = 2.5
    static let brakingMetres = 15.0

    let id: Int
    let kind: VehicleKind
    let x: Double
    private(set) var z: Double
    let limitZ: Double
    /// Hit by the rider: stopped, no longer dangerous. Graphics can show it smoking.
    private(set) var isWrecked = false
    /// The rider has gone past it.
    private(set) var wasPassed = false

    init(id: Int = 0, kind: VehicleKind, x: Double, z: Double, limitZ: Double) {
        self.id = id
        self.kind = kind
        self.x = x
        self.z = z
        self.limitZ = limitZ
    }

    /// Metres per second while it is moving, slowing down near its limit.
    var drivingSpeed: Double {
        guard !isWrecked else { return 0 }
        return kind.cruiseSpeed * max(0, min(1, (limitZ - z) / Self.brakingMetres))
    }

    func advanced(dt: Double, riderDistance: Double, riderSpeed: Double) -> Vehicle {
        guard z - riderDistance < riderSpeed * Self.activationSeconds else { return self }
        var next = self
        next.z = min(limitZ, z + drivingSpeed * dt)
        return next
    }

    func wrecked() -> Vehicle {
        var next = self
        next.isWrecked = true
        return next
    }

    func passed() -> Vehicle {
        var next = self
        next.wasPassed = true
        return next
    }
}

/// A poop pile: the bike skids and slows down, but no life is lost.
struct PoopPile: Equatable {
    let id: Int
    let x: Double
    let z: Double

    init(id: Int = 0, x: Double, z: Double) {
        self.id = id
        self.x = x
        self.z = z
    }
}

struct RoadCoin: Equatable {
    static let goldenValue = 10

    let id: Int
    let x: Double
    let z: Double
    let isGolden: Bool

    init(id: Int = 0, x: Double, z: Double, isGolden: Bool = false) {
        self.id = id
        self.x = x
        self.z = z
        self.isGolden = isGolden
    }

    var value: Int { isGolden ? Self.goldenValue : 1 }
}

enum PickupKind: String, CaseIterable, Codable, Equatable {
    case magnet
    case shield
    case coinDoubler
    case boostRefill
    case repair

    /// The name shown when it is picked up.
    var title: String {
        switch self {
        case .magnet: return "Говномагнит"
        case .shield: return "Щит из лопуха"
        case .coinDoubler: return "Двойной навар"
        case .boostRefill: return "Банка фасоли"
        case .repair: return "Изолента"
        }
    }
}

struct RoadPickup: Equatable {
    let id: Int
    let kind: PickupKind
    let x: Double
    let z: Double

    init(id: Int = 0, kind: PickupKind, x: Double, z: Double) {
        self.id = id
        self.kind = kind
        self.x = x
        self.z = z
    }
}

/// What graphics and audio must react to. `BikeRun.update` returns these in order;
/// `gameOver` is always the last one.
enum BikeEvent: Equatable {
    case coin
    case goldenCoin
    case hit
    case skid
    case nearMiss
    case pickup(PickupKind)
    case boostStart
    case boostEnd
    case shieldBlocked
    /// Rammed through a vehicle under gas.
    case vehicleSmashed(VehicleKind)
    /// The ride crossed into `District.all[index]`.
    case districtEntered(Int)
    case gameOver
}
