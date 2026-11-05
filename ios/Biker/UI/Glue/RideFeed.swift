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
    /// 0...1: the jump button's charge; 1 means a tap jumps (or flips in the air off a ramp).
    var jumpReadiness = 0.0
    var canJump = false
    var isAirborne = false
    /// The road event running now and whole seconds left of it.
    var roadEvent: RoadEventKind?
    var roadEventSeconds = 0
    /// 0...1: how soon a stream lands where the bike is, for the red screen-edge glow.
    var danger = 0.0
}

/// The big banner of a road event: «ГОВНОЛИВЕНЬ» and its line.
struct RideBanner: Identifiable, Equatable {
    let id: Int
    let title: String
    let subtitle: String
    let born: Double
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
    static let bannerSeconds = 2.6
    /// A stream this many seconds from landing on the bike's line starts the danger glow.
    private static let dangerSeconds = 1.4
    private static let dangerReach = BikeRun.streamReach + BikeRun.bikeHalfWidth
    /// Numbers that change every frame (score, speed, coins, gauges) redraw at most this often.
    private static let numbersInterval = 1.0 / 15

    @Published private(set) var hud = HUDSnapshot()
    @Published private(set) var popups: [RidePopup] = []
    /// Bumped on every hit; the HUD flashes yellow when it changes.
    @Published private(set) var hitCount = 0
    /// Bumped on every near-miss slow motion; the HUD flashes white when it changes.
    @Published private(set) var slowMoCount = 0
    @Published private(set) var banner: RideBanner?

    private var nextId = 0
    private var numbersShownAt = -Double.infinity

    func reset() {
        hud = HUDSnapshot()
        if !popups.isEmpty { popups = [] }
        if banner != nil { banner = nil }
        numbersShownAt = -.infinity
    }

    /// Called every frame. Lives, warnings, pickups and boost state publish at once; the numbers
    /// that change every frame publish at `numbersInterval` so the HUD redraws ~15 times a second.
    func update(from run: BikeRun, ridesBefore: Int, now: Double) {
        let next = Self.snapshot(of: run, ridesBefore: ridesBefore)
        guard next != hud else { return }
        let onlyNumbers = Self.withNumbers(of: hud, in: next) == hud
        if onlyNumbers, now - numbersShownAt < Self.numbersInterval { return }
        numbersShownAt = now
        hud = next
    }

    func flashHit() {
        hitCount += 1
    }

    func flashSlowMo() {
        slowMoCount += 1
    }

    func showBanner(_ kind: RoadEventKind, now: Double) {
        nextId += 1
        banner = RideBanner(id: nextId, title: kind.title, subtitle: kind.subtitle, born: now)
    }

    func pop(_ text: String, tone: RidePopup.Tone, now: Double) {
        nextId += 1
        let fresh = RidePopup(id: nextId, text: text, tone: tone, born: now)
        popups = Array((popups + [fresh]).suffix(Self.maxPopups))
    }

    /// Called every frame; publishes only when a popup actually expires.
    func expire(now: Double) {
        if let shown = banner, now - shown.born > Self.bannerSeconds { banner = nil }
        guard !popups.isEmpty else { return }
        var anyDead = false
        for popup in popups where !Self.isAlive(popup, now: now) {
            anyDead = true
            break
        }
        guard anyDead else { return }
        popups = popups.filter { Self.isAlive($0, now: now) }
    }

    private static func isAlive(_ popup: RidePopup, now: Double) -> Bool {
        let life = popup.tone == .district ? districtSeconds : popupSeconds
        return now - popup.born <= life
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
        hud.jumpReadiness = rounded(run.jumpReadiness)
        hud.canJump = run.canJump
        hud.isAirborne = run.isAirborne
        hud.roadEvent = run.currentRoadEvent?.kind
        hud.roadEventSeconds = hud.roadEvent == nil ? 0 : Int(run.roadEventSecondsLeft.rounded(.up))
        hud.danger = rounded(danger(in: run))
        return hud
    }

    /// `target` with the fast-changing numbers taken from `source`.
    private static func withNumbers(of source: HUDSnapshot, in target: HUDSnapshot) -> HUDSnapshot {
        var merged = target
        merged.score = source.score
        merged.coins = source.coins
        merged.speedKmh = source.speedKmh
        merged.dial = source.dial
        merged.comboFraction = source.comboFraction
        merged.boostFraction = source.boostFraction
        merged.jumpReadiness = source.jumpReadiness
        merged.danger = source.danger
        merged.roadEventSeconds = source.roadEventSeconds
        return merged
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

    /// Grows from 0 to 1 as a stream (pouring or about to) comes within `dangerSeconds` of the
    /// bike on its current line.
    private static func danger(in run: BikeRun) -> Double {
        guard !run.isOver, run.speed > 0 else { return 0 }
        var level = 0.0
        for stream in run.streams where stream.isVisible {
            let ahead = stream.z - run.distance
            guard ahead > 0, abs(stream.x(atTime: run.time) - run.x) < dangerReach else { continue }
            let eta = ahead / run.speed
            level = max(level, 1 - eta / dangerSeconds)
        }
        return min(1, level)
    }
}
