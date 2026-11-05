import Foundation

/// A stretch of road with its own rules, announced by a banner.
enum RoadEventKind: String, CaseIterable, Equatable {
    /// Coins everywhere and almost nothing else.
    case coinRain
    /// Rows of streams one after another, with longer warnings.
    case pissHour
    /// Traffic in every segment, sewage tankers first, and ramps to jump over it.
    case trafficWave
    /// Geysers and rolling lids: jump over them.
    case manholes

    var title: String {
        switch self {
        case .coinRain: return "ГОВНОЛИВЕНЬ"
        case .pissHour: return "ЧАС ССАНЬЯ"
        case .trafficWave: return "ГОВНОВОЗЫ ПОПЁРЛИ"
        case .manholes: return "ЛЮКИ ПРОРВАЛО"
        }
    }

    var subtitle: String {
        switch self {
        case .coinRain: return "Монеты с неба, греби всё!"
        case .pissHour: return "Ссут гуще, зато метки висят дольше"
        case .trafficWave: return "Тарань на газах или прыгай с трамплина"
        case .manholes: return "Свайп вверх — прыжок через люк"
        }
    }

    /// Seconds of riding the event lasts.
    var seconds: Double {
        switch self {
        case .coinRain: return 8
        case .pissHour: return 12
        case .trafficWave: return 12
        case .manholes: return 10
        }
    }
}

/// One road event, from `startZ` to `endZ` metres along the road.
struct RoadEvent: Equatable {
    let id: Int
    let kind: RoadEventKind
    let startZ: Double
    let endZ: Double

    init(id: Int = 0, kind: RoadEventKind, startZ: Double, endZ: Double) {
        self.id = id
        self.kind = kind
        self.startZ = startZ
        self.endZ = endZ
    }

    func contains(_ z: Double) -> Bool {
        z >= startZ && z < endZ
    }
}

/// Decides where road events happen. It has its own random stream (from the road seed), so adding
/// events does not reshuffle anything else, and the first event is always the coin rain.
struct RoadEventPlanner: Equatable {
    static let firstAt = 480.0
    static let shortestSpacingSeconds = 24.0
    static let spacingSpreadSeconds = 14.0
    static let shortestSpan = 180.0
    private static let seedSalt: UInt64 = 0x5EED_E7E7_0BAD_F00D

    private var random: SplitMix
    private var nextId = 1
    private var lastKind: RoadEventKind?
    /// Where the next event may start.
    private(set) var nextStart = RoadEventPlanner.firstAt
    /// The latest event; it may be over already.
    private(set) var latest: RoadEvent?

    init(seed: UInt64) {
        random = SplitMix(seed: seed ^ Self.seedSalt)
    }

    /// The event under way at `z`, if any.
    func active(at z: Double) -> RoadEvent? {
        guard let event = latest, event.contains(z) else { return nil }
        return event
    }

    /// Starts the next event when the road has reached its place. Returns it once, when it starts.
    mutating func startIfDue(at z: Double, speed: Double) -> RoadEvent? {
        guard z >= nextStart, active(at: z) == nil else { return nil }
        let kind = chooseKind()
        let span = max(Self.shortestSpan, speed * kind.seconds)
        let event = RoadEvent(id: nextId, kind: kind, startZ: z, endZ: z + span)
        nextId += 1
        latest = event
        lastKind = kind
        let spacing = Self.shortestSpacingSeconds + random.unit() * Self.spacingSpreadSeconds
        nextStart = event.endZ + speed * spacing
        return event
    }

    private mutating func chooseKind() -> RoadEventKind {
        guard let last = lastKind else { return .coinRain }
        let options = RoadEventKind.allCases.filter { $0 != last }
        return options[random.int(below: options.count)]
    }
}
