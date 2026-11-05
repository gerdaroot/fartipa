import SwiftUI
import UIKit

enum BikePhase: Equatable {
    case hub
    case garage
    case riding
    case paused
    case over
}

struct RideResult: Equatable {
    let score: Int
    let meters: Int
    let coins: Int
    let isRecord: Bool
}

/// Drives the bike mode: rides, the wallet and the shop.
@MainActor
final class BikeGame: NSObject, ObservableObject {
    private enum Key {
        static let profile = "pd.bikeProfile"
    }

    private static let idleSpeed = 9.0
    private static let posterFile = "poster.jpg"

    @Published private(set) var phase = BikePhase.hub
    @Published private(set) var profile: Profile
    @Published private(set) var lives = BikeRun.startingLives
    @Published private(set) var runCoins = 0
    @Published private(set) var score = 0
    @Published private(set) var speedKmh = 0
    @Published private(set) var splashCount = 0
    @Published private(set) var result: RideResult?
    @Published private(set) var message: String?

    let world = BikeWorld()
    private let sound: SoundPlayer
    private let haptic = UIImpactFeedbackGenerator(style: .heavy)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private var run: BikeRun?
    private var idleDistance = 0.0
    private var idleTime = 0.0
    private var targetX = 0.0
    private var lastX = 0.0
    private var displayLink: CADisplayLink?
    private var isActive = false

    init(sound: SoundPlayer) {
        self.sound = sound
        profile = Profile.parse(UserDefaults.standard.data(forKey: Key.profile))
        super.init()
        if let saved = loadPoster() { world.setPoster(saved) }
        world.dressBike(bikeId: profile.bikeId, riderId: profile.riderId)
    }

    // MARK: - Launch

    func launch() {
        guard displayLink == nil else { return }
        isActive = true
        phase = .hub
        world.setCamera(.chase)
        startLink()
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--demo=") }) {
            sound.isMuted = true
            applyDemo(String(argument.dropFirst("--demo=".count)))
        }
        #endif
    }

    private func startLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Called when the app goes to the background.
    func pauseIfRiding() {
        if phase == .riding { pause() }
    }

    // MARK: - Commands

    func startRide() {
        run = BikeRun(seed: UInt64.random(in: 0 ... .max))
        targetX = 0
        lastX = 0
        lives = BikeRun.startingLives
        runCoins = 0
        score = 0
        result = nil
        phase = .riding
        world.setCamera(.chase)
        sound.ensureEngineRunning()
    }

    func pause() {
        phase = .paused
        sound.setEngine(level: 0, rev: 0)
    }

    func resume() {
        phase = .riding
        sound.ensureEngineRunning()
    }

    func openGarage() {
        run = nil
        phase = .garage
        world.setCamera(.showcase)
    }

    func closeGarage() {
        phase = .hub
        world.setCamera(.chase)
    }

    func quitToHub() {
        finishRide(recording: phase != .over)
        run = nil
        phase = .hub
        sound.setEngine(level: 0, rev: 0)
    }

    func steer(to x: Double) {
        targetX = x
    }

    var steerTarget: Double { targetX }

    /// Buys the item when needed, then puts it on.
    func tapShopItem(_ item: ShopItem) {
        var updated = profile
        switch updated.buy(item) {
        case .notEnoughCoins:
            message = "Не хватает \(item.price - profile.coins) говнокоинов"
            lightHaptic.impactOccurred()
            return
        case .bought:
            sound.playFanfare()
            haptic.impactOccurred()
        case .alreadyOwned:
            lightHaptic.impactOccurred()
        }
        message = nil
        updated.select(item)
        save(updated)
        world.dressBike(bikeId: updated.bikeId, riderId: updated.riderId)
    }

    func award(coins: Int) {
        guard coins > 0 else { return }
        var updated = profile
        updated.earn(coins)
        save(updated)
    }

    /// Hangs the player's latest picture on the roadside billboards.
    func usePoster(_ image: UIImage) {
        world.setPoster(image)
        guard let data = image.jpegData(compressionQuality: 0.8), let url = posterURL else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Frame

    @objc private func tick(_ link: CADisplayLink) {
        guard isActive else { return }
        let dt = min(0.05, link.targetTimestamp - link.timestamp)
        if phase == .riding, var ride = run {
            let events = ride.update(dt: dt, targetX: targetX)
            run = ride
            handle(events, ride: ride)
            publish(ride)
            syncWorld(ride, dt: dt)
        } else if let ride = run, phase == .paused || phase == .over {
            syncWorld(ride, dt: dt)
        } else {
            idleDistance += Self.idleSpeed * dt
            idleTime += dt
            world.sync(
                distance: idleDistance, x: 0, steerRate: 0, time: idleTime, speed: Self.idleSpeed,
                streams: [], coins: [], blink: false
            )
        }
    }

    private func syncWorld(_ ride: BikeRun, dt: Double) {
        let isMoving = phase == .riding
        let rate = isMoving && dt > 0 ? (ride.x - lastX) / dt : 0
        lastX = ride.x
        world.sync(
            distance: ride.distance, x: ride.x, steerRate: rate, time: ride.time,
            speed: isMoving ? ride.speed : 0,
            streams: ride.streams, coins: ride.pickups, blink: ride.invulnerable > 0
        )
    }

    private func publish(_ ride: BikeRun) {
        if lives != ride.lives { lives = ride.lives }
        if runCoins != ride.coins { runCoins = ride.coins }
        let kmh = Int(ride.speed * 3.6)
        if speedKmh != kmh { speedKmh = kmh }
        let newScore = ride.score / 10 * 10
        if score != newScore { score = newScore }
        guard phase == .riding else { return }
        let rev = Float((ride.speed - BikeRun.startSpeed) / (BikeRun.topSpeed - BikeRun.startSpeed))
        sound.setEngine(level: 0.2, rev: rev)
    }

    private func handle(_ events: [BikeEvent], ride: BikeRun) {
        for event in events {
            switch event {
            case .coin:
                sound.playCoin()
                lightHaptic.impactOccurred(intensity: 0.5)
            case .hit:
                sound.playNextFart()
                haptic.impactOccurred()
                splashCount += 1
            case .gameOver:
                finishRide(recording: true)
                phase = .over
                sound.setEngine(level: 0, rev: 0)
            }
        }
    }

    private func finishRide(recording: Bool) {
        guard recording, let ride = run, result == nil else { return }
        var updated = profile
        updated.earn(ride.coins)
        let isRecord = updated.recordScore(ride.score)
        save(updated)
        result = RideResult(score: ride.score, meters: Int(ride.distance), coins: ride.coins, isRecord: isRecord)
    }

    // MARK: - Saving

    private func save(_ updated: Profile) {
        profile = updated
        UserDefaults.standard.set(updated.encoded(), forKey: Key.profile)
    }

    private var posterURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(Self.posterFile)
    }

    private func loadPoster() -> UIImage? {
        guard let url = posterURL, let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    #if DEBUG
    /// Sample states for the screenshots CI takes.
    func applyDemo(_ name: String) {
        var rich = profile
        rich.earn(777)
        save(rich)
        switch name {
        case "ride":
            startRide()
            var ride = BikeRun(seed: 7)
            for _ in 0..<(60 * 25) { _ = ride.update(dt: 1.0 / 60, targetX: ride.autopilotTarget()) }
            run = ride
            demoAutopilot = true
        case "garage":
            for id in ["sport", "racer"] {
                if let item = Shop.item(id: id) { tapShopItem(item) }
            }
            openGarage()
        case "over":
            startRide()
            var ride = BikeRun(seed: 3)
            while !ride.isOver { _ = ride.update(dt: 1.0 / 60, targetX: 0) }
            run = ride
            finishRide(recording: true)
            phase = .over
        default:
            break
        }
    }

    var demoAutopilot = false {
        didSet { if demoAutopilot { startAutopilotTimer() } }
    }

    private func startAutopilotTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self, let ride = self.run { self.targetX = ride.autopilotTarget() }
            }
        }
    }
    #endif
}
