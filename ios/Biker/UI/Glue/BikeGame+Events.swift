import Foundation
import QuartzCore

/// How a ride ended, for the results sheet.
struct RideOutcome: Equatable {
    let summary: RideSummary
    let reward: RideReward
    /// False when the player ended the ride from the pause sheet.
    let crashed: Bool

    /// Ride coins plus achievement, mission and level pay.
    var totalCoins: Int { reward.totalCoins }
}

extension CADisplayLink {
    /// Asks for `fps` (60, or 30 on a hot phone) when it is not what is asked already.
    @MainActor
    func playFollow(fps: Int) {
        let rate = Float(fps)
        guard preferredFrameRateRange.preferred != rate else { return }
        preferredFrameRateRange = CAFrameRateRange(minimum: min(rate, Float(BikeWorld.hotFPS)), maximum: rate, preferred: rate)
    }
}

/// A short slow motion after a near miss: the world runs at `scale` for `seconds` of real time.
struct RideSlowMo: Equatable {
    static let seconds = 0.18
    static let scale = 0.45

    private(set) var left = 0.0

    mutating func trigger() {
        left = Self.seconds
    }

    mutating func reset() {
        left = 0
    }

    /// The ride step for `dt` seconds of real time, using up the slow motion.
    mutating func step(_ dt: Double) -> Double {
        guard left > 0 else { return dt }
        left = max(0, left - dt)
        return dt * Self.scale
    }
}

/// Announces missions the moment the ride finishes them. Checked a few times a second, not every frame.
struct RideMissionWatch: Equatable {
    static let interval = 0.5

    private var announced = Set<Int>()
    private var nextCheck = 0.0

    /// Missions already done before the ride (a repaired save) are never announced.
    mutating func start(with missions: [Mission], now: Double) {
        announced = Set(missions.filter { $0.isDone }.map { $0.id })
        nextCheck = now + Self.interval
    }

    /// The missions `ride` has just finished, each once per ride.
    mutating func newlyDone(in profile: Profile, ride: () -> RideSummary, now: Double) -> [Mission] {
        guard now >= nextCheck else { return [] }
        nextCheck = now + Self.interval
        let done = profile.missionsPreview(after: ride()).filter { $0.isDone && !announced.contains($0.id) }
        for mission in done { announced.insert(mission.id) }
        return done
    }
}

/// What each ride event sounds, buzzes and pops up like. Called from the frame loop only when
/// events happened, so nothing here runs on quiet frames.
extension BikeGame {
    func handle(_ event: BikeEvent, run current: BikeRun, now time: Double) {
        switch event {
        case .coin:
            sound.play(.coin)
            haptics.coin(now: time, golden: false)
        case .goldenCoin:
            sound.play(.goldenCoin)
            haptics.coin(now: time, golden: true)
            feed.pop("+\(RoadCoin.goldenValue) ЗОЛОТОЙ!", tone: .gold, now: time)
        case .hit:
            sound.play(.hit) // the hit sound is a real fart recording already
            haptics.hit()
            feed.flashHit()
            feed.pop(current.lives > 0 ? "ОБОССАН!" : "ВСЁ, ПРИЕХАЛ", tone: .bad, now: time)
        case .skid:
            sound.play(.skid)
            haptics.bump()
            feed.pop("ЗАНОС НА КУЧЕ!", tone: .bad, now: time)
        case .nearMiss:
            sound.play(.nearMiss)
            haptics.tick()
            let combo = current.combo > 1 ? " ×\(current.combo)" : ""
            feed.pop("НА ВОЛОСКЕ!\(combo)", tone: .good, now: time)
            slowMo.trigger()
            feed.flashSlowMo()
        case .pickup(let kind):
            sound.play(kind == .shield ? .shield : .pickup)
            haptics.bump()
            feed.pop(kind.title.uppercased(), tone: .gold, now: time)
        case .boostStart:
            sound.play(.boostStart)
            haptics.hit()
            world.setCamera(.boost)
        case .boostEnd:
            world.setCamera(.chase)
        case .shieldBlocked:
            sound.play(.shield)
            haptics.bump()
            feed.pop("ЛОПУХ СПАС!", tone: .good, now: time)
        case .vehicleSmashed:
            sound.play(.vehicleSmash)
            haptics.smash()
            feed.pop("ТАРАН! +\(BikeRun.smashScore)", tone: .gold, now: time)
        case .districtEntered(let index):
            guard District.all.indices.contains(index) else { return }
            sound.play(.district)
            feed.pop(District.all[index].name.uppercased(), tone: .district, now: time)
        case .gameOver:
            endRide()
        }
    }

    /// Jumps, ramps, flips and road events: what happened this frame besides `BikeEvent`s.
    func handle(_ moment: RideMoment, run current: BikeRun, now time: Double) {
        switch moment {
        case .jumped:
            sound.play(.boostStart)
            haptics.bump()
        case .rampLaunch:
            sound.play(.boostStart)
            haptics.hit()
            feed.pop("ТРАМПЛИН! ЖМИ ПРЫГ — САЛЬТО", tone: .good, now: time)
        case .flipStarted:
            haptics.tick()
        case .landed(let landing):
            handleLanding(landing, combo: current.combo, now: time)
        case .pileCleared:
            haptics.tick()
            feed.pop("ПЕРЕПРЫГНУЛ КУЧУ!", tone: .good, now: time)
        case .hazardCleared:
            haptics.tick()
            feed.pop("НАД ЛЮКОМ!", tone: .good, now: time)
        case .vaulted:
            sound.play(.vehicleSmash)
            haptics.smash()
            feed.pop("ПЕРЕЛЁТ! +\(BikeRun.vaultScore)", tone: .gold, now: time)
        case .roadEvent(let kind):
            sound.play(.district)
            haptics.success()
            feed.showBanner(kind, now: time)
        }
    }

    private func handleLanding(_ landing: AirLanding, combo: Int, now time: Double) {
        guard landing.kind == .ramp, !landing.botchedFlip else { return }
        haptics.bump()
        let air = Int(landing.seconds * BikeRun.airScorePerSecond)
        guard landing.flips > 0 else {
            feed.pop("ПОЛЁТ +\(air)", tone: .good, now: time)
            return
        }
        let flips = landing.flips > 1 ? "САЛЬТО ×\(landing.flips)" : "САЛЬТО"
        let points = air + BikeRun.flipScore * landing.flips * combo
        sound.play(.goldenCoin)
        feed.pop("\(flips)! +\(points)", tone: .gold, now: time)
    }

    /// Toasts for missions the ride has just finished. They are paid when the ride ends.
    func announceMissions(_ current: BikeRun, now time: Double) {
        let done = missionWatch.newlyDone(in: profile, ride: { current.summary }, now: time)
        for mission in done {
            sound.play(.purchase)
            haptics.success()
            notices.toast("ЗАДАНИЕ ВЫПОЛНЕНО", "\(mission.title) · +\(mission.reward)", tone: .reward, now: time)
        }
    }
}
