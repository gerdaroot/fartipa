import QuartzCore
import SwiftUI
import UIKit

enum BikePhase: Equatable {
    case hub
    case garage
    case upgrades
    case riding
    case paused
    case over
}

/// How a ride ended, for the results sheet.
struct RideOutcome: Equatable {
    let summary: RideSummary
    let reward: RideReward
    /// False when the player ended the ride from the pause sheet.
    let crashed: Bool

    var totalCoins: Int { reward.coinsEarned + reward.achievementCoins }
}

/// The glue: drives `BikeRun` every frame, feeds `BikeWorld` and `SoundPlayer`, keeps the `Profile`.
/// Shop, daily reward and achievements live in `BikeGame+Shop.swift`, demo states in `BikeGame+Demo.swift`.
@MainActor
final class BikeGame: NSObject, ObservableObject {
    private enum Key {
        static let profile = "biker.profile"
        /// The profile with a paused ride already banked, written when the app goes to the
        /// background. Adopted on the next launch if the app was killed; dropped on return.
        static let pendingProfile = "biker.pendingProfile"
        static let muted = "biker.muted"
    }

    private static let maxStep = 1.0 / 20
    private static let defaultStep = 1.0 / 60
    /// A drag across this share of the screen width moves the bike across the whole road.
    private static let dragSpan = 0.75

    @Published private(set) var phase = BikePhase.hub
    @Published private(set) var profile: Profile
    @Published private(set) var outcome: RideOutcome? = nil
    @Published private(set) var isMuted: Bool

    let world: BikeWorld
    let sound: SoundPlayer
    let feed = RideFeed()
    let notices = NoticeCenter()
    let haptics = Haptics()
    /// Demo screens turn this off so screenshots never touch the real save.
    var persists = true

    private let defaults: UserDefaults
    private(set) var run: BikeRun?
    private var isBanked = false
    private var targetX = 0.0
    private var dragBase: Double?
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    #if DEBUG
    var demoAutopilot = false
    private static let demoBoostAfter = 7.0
    #endif

    init(defaults: UserDefaults) {
        let pending = defaults.data(forKey: Key.pendingProfile)
        let muted = defaults.bool(forKey: Key.muted)
        self.defaults = defaults
        profile = Profile.parse(pending ?? defaults.data(forKey: Key.profile))
        isMuted = muted
        sound = SoundPlayer(muted: muted)
        world = BikeWorld()
        super.init()
        if pending != nil {
            commit(profile)
            defaults.removeObject(forKey: Key.pendingProfile)
        }
        world.setQuality(high: !ProcessInfo.processInfo.isLowPowerModeEnabled)
        dressWorld()
        world.setCamera(.chase)
    }

    var now: Double { CACurrentMediaTime() }

    // MARK: - Lifecycle

    func launch() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--demo=") }) {
            applyDemo(String(argument.dropFirst("--demo=".count)))
        }
        #endif
    }

    /// The app lost focus (control centre, a call): stop the ride, keep it.
    func enterInactive() {
        pause()
    }

    /// The app went to the background. A paused ride is banked into a pending save, so coins and
    /// the record survive if iOS kills the app; returning drops it and the ride goes on.
    func enterBackground() {
        pause()
        sound.stopAll()
        displayLink?.isPaused = true
        guard persists, phase == .paused, !isBanked, let current = run else { return }
        var provisional = profile
        _ = provisional.recordRide(current.summary)
        defaults.set(provisional.encoded(), forKey: Key.pendingProfile)
    }

    func enterForeground() {
        defaults.removeObject(forKey: Key.pendingProfile)
        lastTimestamp = nil
        displayLink?.isPaused = false
    }

    // MARK: - Ride commands

    func startRide() {
        startRide(seed: UInt64.random(in: 0...UInt64.max))
    }

    func startRide(seed: UInt64) {
        guard phase != .riding else { return }
        bankRide()
        run = BikeRun(seed: seed, loadout: profile.loadout)
        isBanked = false
        outcome = nil
        targetX = 0
        dragBase = nil
        lastTimestamp = nil
        feed.reset()
        notices.clearMessage()
        dressWorld()
        world.setCamera(.chase)
        sound.ensureEngineRunning()
        sound.play(.button)
        haptics.prepare()
        phase = .riding
    }

    func pause() {
        guard phase == .riding else { return }
        phase = .paused
        dragBase = nil
        sound.setRide(active: false, speed01: 0, boosting: false)
        sound.stopAll()
    }

    func resume() {
        guard phase == .paused, let current = run, !current.isOver else { return }
        lastTimestamp = nil
        sound.ensureEngineRunning()
        phase = .riding
    }

    /// Ends the ride from the pause sheet: banks it and shows the results.
    func finishRide() {
        guard phase == .paused || phase == .riding, run != nil else { return }
        endRide()
    }

    func boost() {
        guard phase == .riding, var current = run else { return }
        if current.activateBoost() {
            run = current
        } else {
            haptics.failure()
        }
    }

    /// Horizontal drag anywhere. `translation` is the finger's travel since the drag began.
    /// When the target hits the road edge the drag's base moves with it, so reversing the finger
    /// turns the bike back at once instead of crossing a dead zone first.
    func steerDrag(translation: Double, width: Double) {
        guard phase == .riding, translation.isFinite else { return }
        let base = dragBase ?? targetX
        let travel = translation / max(1, width * Self.dragSpan) * BikeRun.bikeLimit * 2
        let wanted = base + travel
        let clamped = min(BikeRun.bikeLimit, max(-BikeRun.bikeLimit, wanted))
        dragBase = clamped == wanted ? base : clamped - travel
        targetX = clamped
    }

    func endSteer() {
        dragBase = nil
    }

    // MARK: - Navigation

    func goHub() {
        guard phase != .riding, phase != .paused else { return }
        leaveRide()
        notices.clearMessage()
        dressWorld()
        world.setCamera(.chase)
        phase = .hub
    }

    func openGarage() {
        guard phase != .riding, phase != .paused else { return }
        leaveRide()
        notices.clearMessage()
        world.setCamera(.showcase)
        phase = .garage
    }

    func openUpgrades() {
        guard phase != .riding, phase != .paused else { return }
        leaveRide()
        notices.clearMessage()
        dressWorld()
        world.setCamera(.showcase)
        phase = .upgrades
    }

    func toggleMute() {
        isMuted.toggle()
        sound.isMuted = isMuted
        defaults.set(isMuted, forKey: Key.muted)
        if !isMuted { sound.play(.button) }
    }

    /// Puts the equipped skins on the bike, or a garage preview in place of one of them.
    func dressWorld(preview: SkinInfo? = nil) {
        let bikeId = preview?.kind == .bike ? preview?.id : nil
        let riderId = preview?.kind == .rider ? preview?.id : nil
        let trailId = preview?.kind == .trail ? preview?.id : nil
        guard
            let bike = Catalog.bike(id: bikeId ?? profile.bikeId) ?? Catalog.bike(id: Catalog.starterBikeId),
            let rider = Catalog.rider(id: riderId ?? profile.riderId) ?? Catalog.rider(id: Catalog.starterRiderId),
            let trail = Catalog.trail(id: trailId ?? profile.trailId) ?? Catalog.trail(id: Catalog.starterTrailId)
        else { return }
        world.dress(bike: bike.style, rider: rider.style, trail: trail.style)
    }

    /// Replaces the profile and saves it.
    func commit(_ updated: Profile) {
        profile = updated
        guard persists else { return }
        defaults.set(updated.encoded(), forKey: Key.profile)
    }

    // MARK: - Ride end

    private func leaveRide() {
        bankRide()
        run = nil
        feed.reset()
    }

    private func endRide() {
        bankRide()
        dragBase = nil
        sound.setRide(active: false, speed01: 0, boosting: false)
        sound.stopAll()
        sound.play(.gameOver)
        world.setCamera(.chase)
        phase = .over
    }

    /// Banks coins, record, stats and achievements once per ride, however the ride ends.
    private func bankRide() {
        guard let current = run, !isBanked else { return }
        isBanked = true
        let before = profile
        var updated = profile
        let summary = current.summary
        let reward = updated.recordRide(summary)
        commit(updated)
        defaults.removeObject(forKey: Key.pendingProfile)
        outcome = RideOutcome(summary: summary, reward: reward, crashed: current.isOver)
        announceAchievements(since: before)
    }

    // MARK: - Frame

    @objc private func tick(_ link: CADisplayLink) {
        let time = link.timestamp
        let dt = frameStep(time)
        notices.expire(now: time)
        feed.expire(now: time)
        switch phase {
        case .riding:
            stepRide(dt: dt, now: time)
        case .paused, .over:
            sound.setRide(active: false, speed01: 0, boosting: false)
            if let current = run { world.render(current, dt: dt, isLive: false) }
        case .hub, .garage, .upgrades:
            sound.setRide(active: false, speed01: 0, boosting: false)
            world.renderIdle(dt: dt)
        }
    }

    /// Real time since the last frame, clamped so a hitch never teleports the bike.
    private func frameStep(_ timestamp: CFTimeInterval) -> Double {
        defer { lastTimestamp = timestamp }
        guard let last = lastTimestamp else { return Self.defaultStep }
        return min(Self.maxStep, max(0, timestamp - last))
    }

    private func stepRide(dt: Double, now time: Double) {
        guard var current = run else { return }
        #if DEBUG
        if demoAutopilot {
            targetX = current.autopilotTarget()
            if current.time > Self.demoBoostAfter, current.canBoost { current.activateBoost() }
        }
        #endif
        let events = current.update(dt: dt, targetX: targetX)
        run = current
        if !events.isEmpty { world.react(to: events, run: current) }
        world.render(current, dt: dt, isLive: !current.isOver)
        feed.update(from: current, ridesBefore: profile.stats.rides)
        for event in events { handle(event, run: current, now: time) }
        guard phase == .riding else { return }
        let speed01 = min(1, max(0, current.rev))
        sound.setRide(active: true, speed01: speed01, boosting: current.isBoosting)
    }

    private func handle(_ event: BikeEvent, run current: BikeRun, now time: Double) {
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
            sound.play(.hit)
            haptics.smash()
            feed.pop("ТАРАН! +\(BikeRun.smashScore)", tone: .gold, now: time)
        case .districtEntered(let index):
            guard District.all.indices.contains(index) else { return }
            sound.play(.upgrade)
            feed.pop(District.all[index].name.uppercased(), tone: .district, now: time)
        case .gameOver:
            endRide()
        }
    }

    // MARK: - Debug

    #if DEBUG
    /// Plays the ride ahead without drawing it, for demo screenshots.
    func fastForward(seconds: Double, autopilot: Bool) {
        guard phase == .riding, var current = run else { return }
        let step = Self.defaultStep
        var left = seconds
        while left > 0, !current.isOver {
            _ = current.update(dt: step, targetX: autopilot ? current.autopilotTarget() : 0)
            left -= step
        }
        run = current
        targetX = current.x
        feed.update(from: current, ridesBefore: profile.stats.rides)
        if current.isOver { endRide() }
    }
    #endif
}
