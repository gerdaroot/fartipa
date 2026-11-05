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
/// Events live in `BikeGame+Events.swift`, shop and achievements in `BikeGame+Shop.swift`,
/// demo states in `BikeGame+Demo.swift`.
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
    static let defaultStep = 1.0 / 60
    /// A drag across this share of the screen width moves the bike across the whole road.
    private static let dragSpan = 0.75
    /// The loading screen stops waiting for the warm-up after this long.
    private static let loadingTimeoutNanos: UInt64 = 10_000_000_000
    /// Lets the loading screen reach the display before the heavy warm-up starts.
    private static let warmUpDelayNanos: UInt64 = 50_000_000

    @Published private(set) var phase = BikePhase.hub
    @Published private(set) var profile: Profile
    @Published private(set) var outcome: RideOutcome? = nil
    @Published private(set) var isMuted: Bool
    /// True until the world has compiled its shaders and uploaded its textures.
    @Published private(set) var isLoading = true

    let world: BikeWorld
    let sound: SoundPlayer
    let feed = RideFeed()
    let notices = NoticeCenter()
    let haptics = Haptics()
    let perf: PerfReadout
    /// Demo screens turn this off so screenshots never touch the real save.
    var persists = true
    /// A garage card tap waits a moment, so rapid taps build only the last bike.
    var pendingPreview: Task<Void, Never>?

    private let defaults: UserDefaults
    /// Profile saves run here, so JSON encoding never stalls a frame.
    private let saveQueue = DispatchQueue(label: "biker.profile.save", qos: .utility)
    private(set) var run: BikeRun?
    private var isBanked = false
    private var targetX = 0.0
    private var dragBase: Double?
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var monitor = FrameMonitor()
    private var quality: AutoQuality
    /// The fart motor was told to run; outside a ride it is told to stop once, not every frame.
    private var rideAudioOn = false
    #if DEBUG
    var demoAutopilot = false
    private static let demoBoostAfter = 7.0
    #endif

    init(defaults: UserDefaults) {
        let pending = defaults.data(forKey: Key.pendingProfile)
        let muted = defaults.bool(forKey: Key.muted)
        let startsHigh = !ProcessInfo.processInfo.isLowPowerModeEnabled
        self.defaults = defaults
        profile = Profile.parse(pending ?? defaults.data(forKey: Key.profile))
        isMuted = muted
        perf = PerfReadout(defaults: defaults)
        quality = AutoQuality(isHigh: startsHigh)
        sound = SoundPlayer(muted: muted)
        world = BikeWorld()
        super.init()
        if pending != nil {
            commit(profile)
            defaults.removeObject(forKey: Key.pendingProfile)
        }
        world.setQuality(high: startsHigh)
        world.view.showsStatistics = perf.isOn
        dressWorld()
        world.setCamera(.chase)
    }

    var now: Double { CACurrentMediaTime() }

    // MARK: - Lifecycle

    /// Starts the frame loop and the warm-up behind the loading screen; the hub opens when it is done.
    func launch() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        // The rate SceneKit renders at, so every drawn frame gets exactly one world update.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.warmUpDelayNanos)
            self?.startWarmUp()
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.loadingTimeoutNanos)
            self?.finishLoading()
        }
    }

    private func startWarmUp() {
        // Whatever queue the completion arrives on, the hand-off happens on main.
        world.prepare(completion: { [weak self] in
            guard let game = self else { return }
            Task { @MainActor in game.finishLoading() }
        })
    }

    private func finishLoading() {
        guard isLoading else { return }
        isLoading = false
        haptics.prepare()
        monitor.restartWindow()
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
        rideAudioOn = false
        displayLink?.isPaused = true
        // Queued profile saves must land before iOS may suspend the app.
        saveQueue.sync {}
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
        guard phase != .riding, !isLoading else { return }
        bankRide()
        pendingPreview?.cancel()
        run = BikeRun(seed: seed, loadout: profile.loadout)
        isBanked = false
        outcome = nil
        targetX = 0
        dragBase = nil
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
        silenceRide()
        sound.stopAll()
    }

    func resume() {
        guard phase == .paused, let current = run, !current.isOver else { return }
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
        pendingPreview?.cancel()
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
        pendingPreview?.cancel()
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

    /// Replaces the profile and saves it off the main thread.
    func commit(_ updated: Profile) {
        profile = updated
        guard persists else { return }
        let store = defaults
        let key = Key.profile
        saveQueue.async { store.set(updated.encoded(), forKey: key) }
    }

    // MARK: - Ride end

    private func leaveRide() {
        bankRide()
        run = nil
        feed.reset()
    }

    func endRide() {
        bankRide()
        dragBase = nil
        silenceRide()
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

    /// The only place the world moves: one update per displayed frame, with clamped real time.
    @objc private func tick(_ link: CADisplayLink) {
        let time = link.targetTimestamp
        let elapsed: Double? = lastTimestamp.map { time - $0 }
        lastTimestamp = time
        guard !isLoading else { return }
        if let elapsed { observeFrame(elapsed) }
        let dt = elapsed.map { min(Self.maxStep, max(0, $0)) } ?? Self.defaultStep
        notices.expire(now: time)
        feed.expire(now: time)
        switch phase {
        case .riding:
            stepRide(dt: dt, now: time)
        case .paused, .over:
            silenceRide()
            if let current = run { world.render(current, dt: dt, isLive: false) }
        case .hub, .garage, .upgrades:
            silenceRide()
            world.renderIdle(dt: dt)
        }
    }

    /// Feeds the frame statistics; once a second it may lower the graphics and refresh the overlay.
    private func observeFrame(_ elapsed: Double) {
        guard let report = monitor.record(elapsed) else { return }
        let thermal = ProcessInfo.processInfo.thermalState
        if quality.shouldDrop(after: report, thermal: thermal) {
            world.setQuality(high: false)
        }
        perf.publish(report, highQuality: quality.isHigh, thermal: thermal)
    }

    private func silenceRide() {
        guard rideAudioOn else { return }
        rideAudioOn = false
        sound.setRide(active: false, speed01: 0, boosting: false)
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
        feed.update(from: current, ridesBefore: profile.stats.rides, now: time)
        for event in events { handle(event, run: current, now: time) }
        guard phase == .riding else { return }
        let speed01 = min(1, max(0, current.rev))
        rideAudioOn = true
        sound.setRide(active: true, speed01: speed01, boosting: current.isBoosting)
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
        feed.update(from: current, ridesBefore: profile.stats.rides, now: now)
        if current.isOver { endRide() }
    }
    #endif
}
