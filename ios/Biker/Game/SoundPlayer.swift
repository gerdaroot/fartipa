import AVFoundation

enum SoundEffect: CaseIterable {
    case coin, goldenCoin, hit, skid, nearMiss, pickup, shield, boostStart, purchase, upgrade, gameOver, button
}

/// All the game's sound: the fart motor while riding, synthesised effects, and real farts for hits.
/// Not MainActor, but call it from the main thread only. Everything is silent while muted.
final class SoundPlayer {
    private static let effectVolume: Float = 1
    private static let chimeVolume: Float = 0.9
    private static let hitFartVolume: Float = 1
    private static let thumpVolume: Float = 0.8
    private static let restartRetryInterval: TimeInterval = 1
    /// `play(.hit)` already farts; a `playFart()` right after it would double the recording.
    private static let fartSpacing: TimeInterval = 0.15

    private let engine = AVAudioEngine()
    private let motor: FartEngine?
    private let bank: EffectBank?
    private var effectBuffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var coinBuffers: [AVAudioPCMBuffer] = []
    private var nextCoin = 0
    private var hitFarts: [AVAudioPCMBuffer] = []
    private var hitBag = SoundBag(count: 0)
    private var observers: [NSObjectProtocol] = []
    private var lastRestartAttempt: TimeInterval = -.infinity
    private var lastFartAt: TimeInterval = -.infinity

    var isMuted: Bool {
        didSet {
            guard isMuted != oldValue else { return }
            applyMute()
        }
    }

    init(muted: Bool) {
        isMuted = muted
        if let mono = GameAudioFormat.mono, let stereo = GameAudioFormat.stereo {
            motor = FartEngine(engine: engine, voiceFormat: mono, busFormat: stereo)
            bank = EffectBank(engine: engine, format: mono)
        } else {
            motor = nil
            bank = nil
        }
        configureSession()
        buildEffects()
        loadFartsInBackground()
        observeSession()
        applyMute()
        ensureEngineRunning()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        motor?.stop()
        engine.stop()
    }

    // MARK: - API

    /// Restarts audio after a call, a route change or a media reset. Cheap when already running.
    func ensureEngineRunning() {
        guard !engine.isRunning else { return }
        lastRestartAttempt = ProcessInfo.processInfo.systemUptime
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            return
        }
        // A (re)started engine resets every player's timeline.
        motor?.engineRestarted()
        bank?.stopAll()
    }

    /// Every frame while riding; `speed01` runs 0...1. `active` false fades the motor out.
    func setRide(active: Bool, speed01: Double, boosting: Bool) {
        let live = active && !isMuted
        if live && !engine.isRunning {
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastRestartAttempt >= Self.restartRetryInterval { ensureEngineRunning() }
        }
        motor?.setRide(active: live, speed01: speed01, boosting: boosting)
    }

    func play(_ effect: SoundEffect) {
        guard !isMuted, let bank else { return }
        ensureEngineRunning()
        switch effect {
        case .coin:
            playCoin(bank)
        case .hit:
            if let thump = effectBuffers[.hit] { bank.play(thump, volume: Self.thumpVolume) }
            playFart()
        default:
            if let buffer = effectBuffers[effect] { bank.play(buffer, volume: Self.effectVolume) }
        }
    }

    /// One whole fart recording; none repeats until all the others have played.
    func playFart() {
        let now = ProcessInfo.processInfo.systemUptime
        guard !isMuted, let bank, now - lastFartAt >= Self.fartSpacing else { return }
        guard let index = hitBag.next(), index < hitFarts.count else { return }
        lastFartAt = now
        ensureEngineRunning()
        bank.playFart(hitFarts[index], volume: Self.hitFartVolume)
    }

    /// Silences the motor and every effect at once: pause, game over, background.
    /// Play the game-over sound after calling this, not before.
    func stopAll() {
        motor?.stop()
        bank?.stopAll()
    }

    // MARK: - Setup

    private func playCoin(_ bank: EffectBank) {
        guard !coinBuffers.isEmpty else { return }
        let buffer = coinBuffers[nextCoin % coinBuffers.count]
        nextCoin = (nextCoin + 1) % coinBuffers.count
        bank.playChime(buffer, volume: Self.chimeVolume)
    }

    private func applyMute() {
        engine.mainMixerNode.outputVolume = isMuted ? 0 : 1
        if isMuted { stopAll() }
    }

    /// `.playback` so the bike still farts with the ringer switch off; mixes with the player's music.
    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func buildEffects() {
        var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
        for effect in SoundEffect.allCases where effect != .coin {
            buffers[effect] = GameAudioFormat.buffer(EffectSynth.samples(for: effect))
        }
        effectBuffers = buffers
        coinBuffers = EffectSynth.coinPitches.compactMap { GameAudioFormat.buffer(EffectSynth.coin(pitch: $0)) }
    }

    /// Decoding sixteen compressed files takes a moment, so it happens off the main thread.
    private func loadFartsInBackground() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let clips = FartDecoder.decodeAll()
            DispatchQueue.main.async {
                self?.install(clips)
            }
        }
    }

    private func install(_ clips: [FartClip]) {
        hitFarts = clips.map { $0.full }
        hitBag = SoundBag(count: hitFarts.count)
        motor?.install(clips.map { $0.engine })
    }

    private func observeSession() {
        let center = NotificationCenter.default
        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.handleInterruption(note)
        }
        let names: [Notification.Name] = [
            AVAudioSession.routeChangeNotification,
            AVAudioSession.mediaServicesWereResetNotification,
            .AVAudioEngineConfigurationChange,
        ]
        let recoveries: [NSObjectProtocol] = names.map { name -> NSObjectProtocol in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.recover()
            }
        }
        observers = [interruption] + recoveries
    }

    private func handleInterruption(_ note: Notification) {
        guard
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }
        switch type {
        case .began:
            stopAll()
        case .ended:
            recover()
        @unknown default:
            break
        }
    }

    /// The system stops the engine on interruptions and device changes; start it again if it stopped.
    private func recover() {
        ensureEngineRunning()
    }
}
