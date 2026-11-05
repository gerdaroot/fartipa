import AVFoundation

/// Raw values index the decoded effect library; new cases only ever go at the end.
enum SoundEffect: Int, CaseIterable {
    case coin, goldenCoin, hit, skid, nearMiss, pickup, shield, boostStart, purchase, upgrade, gameOver, button
    case vehicleSmash, district, dailyReward
}

/// All the game's sound: the fart motor while riding, recorded effects, and real farts for hits.
/// Not MainActor, but call it from the main thread only. Everything is silent while muted.
///
/// Every node is attached at launch and every file is decoded once on a background queue, so a ride only
/// schedules ready buffers. Starting the audio engine (slow: it talks to the audio server) also happens
/// off the main thread, so nothing here can stall a frame.
final class SoundPlayer {
    private static let hitFartVolume: Float = 1
    private static let restartRetryInterval: TimeInterval = 1
    /// `play(.hit)` already farts; a `playFart()` right after it would double the recording.
    private static let fartSpacing: TimeInterval = 0.15

    private let engine = AVAudioEngine()
    private let motor: FartEngine?
    private let bank: EffectBank?
    private let startQueue = DispatchQueue(label: "krutoybiker.audio.start", qos: .userInitiated)
    /// Indexed by `SoundEffect.rawValue`; empty until the background decode lands.
    private var effects: [[AVAudioPCMBuffer]] = []
    private var variants = VariantPicker(effectCount: SoundEffect.allCases.count)
    private var hitFarts: [AVAudioPCMBuffer] = []
    private var hitDeck = ShuffleDeck(count: 0)
    private var observers: [NSObjectProtocol] = []
    private var starting = false
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
        loadSoundsInBackground()
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

    /// Restarts audio after a call, a route change or a media reset. Returns at once: the engine starts on
    /// a background queue. Cheap when already running or already starting.
    func ensureEngineRunning() {
        guard !engine.isRunning, !starting else { return }
        starting = true
        lastRestartAttempt = ProcessInfo.processInfo.systemUptime
        let engine = self.engine
        startQueue.async { [weak self] in
            let started = SoundPlayer.start(engine)
            DispatchQueue.main.async {
                self?.engineStartFinished(started: started)
            }
        }
    }

    /// Every frame while riding; `speed01` runs 0...1. `active` false fades the motor out. Never allocates.
    func setRide(active: Bool, speed01: Double, boosting: Bool) {
        let live = active && !isMuted
        if live { restartIfStopped() }
        motor?.setRide(active: live, speed01: speed01, boosting: boosting)
    }

    func play(_ effect: SoundEffect) {
        guard !isMuted, let bank else { return }
        guard engine.isRunning, !starting else {
            restartIfStopped()
            return
        }
        if let buffer = nextBuffer(for: effect) {
            let volume = EffectLibrary.volume(for: effect)
            if effect == .coin {
                bank.playChime(buffer, volume: volume)
            } else {
                bank.play(buffer, volume: volume)
            }
        }
        if effect == .hit { playFart() }
    }

    /// One whole fart recording; none repeats until all the others have played.
    func playFart() {
        let now = ProcessInfo.processInfo.systemUptime
        guard !isMuted, let bank, now - lastFartAt >= Self.fartSpacing else { return }
        guard engine.isRunning, !starting else {
            restartIfStopped()
            return
        }
        guard let index = hitDeck.next(), index < hitFarts.count else { return }
        lastFartAt = now
        bank.playFart(hitFarts[index], volume: Self.hitFartVolume)
    }

    /// Silences the motor and every effect at once: pause, game over, background.
    /// Play the game-over sound after calling this, not before.
    func stopAll() {
        motor?.stop()
        bank?.stopAll()
    }

    // MARK: - Engine

    /// Runs on `startQueue`. Activating the session and starting the engine can block for a while.
    private static func start(_ engine: AVAudioEngine) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // The engine may still start on an already active session; its own start decides.
        }
        engine.prepare()
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func engineStartFinished(started: Bool) {
        starting = false
        guard started else { return }
        // A (re)started engine resets every player's timeline.
        motor?.engineRestarted()
        bank?.stopAll()
    }

    /// Hot-path restart: at most one attempt per interval, so a dead route cannot hammer the audio server.
    private func restartIfStopped() {
        guard !engine.isRunning, !starting else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastRestartAttempt >= Self.restartRetryInterval else { return }
        ensureEngineRunning()
    }

    private func nextBuffer(for effect: SoundEffect) -> AVAudioPCMBuffer? {
        let index = effect.rawValue
        guard effects.indices.contains(index) else { return nil }
        let list = effects[index]
        guard let pick = variants.next(effect: index, variants: list.count), pick < list.count else { return nil }
        return list[pick]
    }

    private func applyMute() {
        engine.mainMixerNode.outputVolume = isMuted ? 0 : 1
        if isMuted { stopAll() }
    }

    /// `.playback` so the bike still farts with the ringer switch off; mixes with the player's music.
    /// Activation happens with the engine start, off the main thread.
    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    // MARK: - Loading

    /// Decoding every effect and fart recording takes a moment, so it all happens off the main thread;
    /// only the hand-over of finished buffers runs on main.
    private func loadSoundsInBackground() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let library = EffectLibrary.decodeAll()
            let clips = FartDecoder.decodeAll()
            DispatchQueue.main.async {
                self?.install(library: library, clips: clips)
            }
        }
    }

    private func install(library: [[AVAudioPCMBuffer]], clips: [FartClip]) {
        effects = library
        hitFarts = clips.map { $0.full }
        hitDeck = ShuffleDeck(count: hitFarts.count)
        motor?.install(clips.map { $0.engine })
    }

    // MARK: - Session

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
