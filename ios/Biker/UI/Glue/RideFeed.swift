import Foundation

/// What the riding HUD shows. Values are rounded so the snapshot changes only when the screen would.
struct HUDSnapshot: Equatable {
    var lives = 0
    var maxLives = 0
    var startingLives = 0
    var coins = 0
    var score = 0
    var speedKmh = 0
    /// 0...1 of the dial.
    var dial = 0.0
    var combo = 1
    var comboFraction = 0.0
    var boostFraction = 0.0
    var canBoost = false
    var isBoosting = false
    var districtName = ""
    var magnetSeconds = 0
    var shieldSeconds = 0
    var doublerSeconds = 0
    /// Lane of the nearest stream marker ahead: -1 left, 0 middle, 1 right. Nil when none.
    var warningLane: Int?
    var showsHint = false
    var isHurt = false
}

struct RidePopup: Identifiable, Equatable {
    enum Tone: Equatable { case good, bad, gold, district }

    let id: Int
    let text: String
    let tone: Tone
    let born: Double
}

/// Per-frame ride state for the HUD only, so menus do not redraw at 60 fps.
@MainActor
final class RideFeed: ObservableObject {
    static let popupSeconds = 1.1
    static let districtSeconds = 2.2
    private static let maxPopups = 3
    private static let quantum = 50.0
    private static let warningMetres = 110.0
    private static let laneSplit = 1.3
    private static let hintSeconds = 4.0
    private static let hintRides = 3
    private static let msToKmh = 3.6

    @Published private(set) var hud = HUDSnapshot()
    @Published private(set) var popups: [RidePopup] = []
    /// Bumped on every hit; the HUD flashes yellow when it changes.
    @Published private(set) var hitCount = 0

    private var nextId = 0

    func reset() {
        hud = HUDSnapshot()
        popups = []
    }

    func update(from run: BikeRun, ridesBefore: Int) {
        let next = Self.snapshot(of: run, ridesBefore: ridesBefore)
        if next != hud { hud = next }
    }

    func flashHit() {
        hitCount += 1
    }

    func pop(_ text: String, tone: RidePopup.Tone, now: Double) {
        nextId += 1
        let fresh = RidePopup(id: nextId, text: text, tone: tone, born: now)
        popups = Array((popups + [fresh]).suffix(Self.maxPopups))
    }

    func expire(now: Double) {
        let alive: (RidePopup) -> Bool = { popup in
            let life = popup.tone == .district ? Self.districtSeconds : Self.popupSeconds
            return now - popup.born <= life
        }
        if popups.contains(where: { !alive($0) }) {
            popups = popups.filter(alive)
        }
    }

    // MARK: - Snapshot

    private static func snapshot(of run: BikeRun, ridesBefore: Int) -> HUDSnapshot {
        var hud = HUDSnapshot()
        hud.lives = run.lives
        hud.maxLives = run.maxLives
        hud.startingLives = run.loadout.startingLives
        hud.coins = run.coins
        hud.score = run.score
        hud.speedKmh = Int((run.speed * msToKmh).rounded())
        let dialTop = max(1, run.loadout.topSpeed * BikeRun.boostFactor)
        hud.dial = rounded(min(1, max(0, run.speed / dialTop)))
        hud.combo = run.combo
        hud.comboFraction = rounded(run.comboFraction)
        hud.boostFraction = rounded(run.boostFraction)
        hud.canBoost = run.canBoost
        hud.isBoosting = run.isBoosting
        hud.districtName = run.district.name
        hud.magnetSeconds = Int(run.powerUps.magnet.rounded(.up))
        hud.shieldSeconds = Int(run.powerUps.shield.rounded(.up))
        hud.doublerSeconds = Int(run.powerUps.doubler.rounded(.up))
        hud.warningLane = warningLane(in: run)
        hud.showsHint = run.time < hintSeconds && ridesBefore < hintRides
        hud.isHurt = run.invulnerable > 0 && !run.isOver
        return hud
    }

    private static func rounded(_ value: Double) -> Double {
        (value * quantum).rounded() / quantum
    }

    /// The closest stream that shows its marker but does not pour yet.
    private static func warningLane(in run: BikeRun) -> Int? {
        var best: PissStream?
        for stream in run.streams where stream.isVisible && !stream.isPouring {
            let ahead = stream.z - run.distance
            guard ahead > 0, ahead < warningMetres else { continue }
            if let current = best, current.z <= stream.z { continue }
            best = stream
        }
        guard let stream = best else { return nil }
        let x = stream.x(atTime: run.time)
        if x < -laneSplit { return -1 }
        if x > laneSplit { return 1 }
        return 0
    }
}
