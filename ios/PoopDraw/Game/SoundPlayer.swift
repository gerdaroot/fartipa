import AVFoundation

/// Plays the fart recordings and the synthesised effects. Everything stays silent while muted.
final class SoundPlayer {
    private static let farts = ["perdezh-40", "perdezh-puk-puk", "farts-42", "farts-8", "farts-4", "long-fart"]

    private let engine = AVAudioEngine()
    private let effects = AVAudioPlayerNode()
    private var plopBuffer: AVAudioPCMBuffer?
    private var fanfareBuffer: AVAudioPCMBuffer?
    private var fartPlayers: [String: AVAudioPlayer] = [:]
    private var loadedFarts: [String] = []
    private var fartBag = SoundBag(count: 0)
    private var observers: [NSObjectProtocol] = []

    // Read on the audio thread, written here. Raw memory keeps the render callback free of runtime checks.
    private let squelchGain = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    private let squelchFrequency = UnsafeMutablePointer<Float>.allocate(capacity: 1)

    var isMuted: Bool {
        didSet {
            if isMuted {
                squelchGain.pointee = 0
                fartPlayers.values.forEach { $0.stop() }
                effects.stop()
            }
        }
    }

    init(muted: Bool) {
        isMuted = muted
        squelchGain.initialize(to: 0)
        squelchFrequency.initialize(to: 420)
        configureSession()
        loadFarts()
        configureEngine()
        observeInterruptions()
        ensureEngineRunning()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        engine.stop()
        squelchGain.deallocate()
        squelchFrequency.deallocate()
    }

    // MARK: - Playing

    /// Plays the next recording from the bag, so a sound repeats only after all the others played.
    func playNextFart() {
        guard !isMuted, let index = fartBag.next() else { return }
        play(fart: loadedFarts[index])
    }

    func playPlop() {
        play(buffer: plopBuffer)
    }

    func playFanfare() {
        play(buffer: fanfareBuffer)
    }

    /// `speed` is finger speed in points per second; 0 silences the squelch.
    func setSquelch(speed: Double) {
        guard !isMuted else { return }
        let amount = Float(min(1, speed / 1600))
        squelchGain.pointee = amount * 0.34
        squelchFrequency.pointee = 280 + amount * 720 + Float.random(in: 0..<120)
    }

    /// Audio stops after a call or when headphones change; call this on every new touch.
    func ensureEngineRunning() {
        guard !engine.isRunning else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        do {
            try engine.start()
        } catch {
            return
        }
    }

    // MARK: - Setup

    private func play(fart name: String) {
        guard let player = fartPlayers[name] else { return }
        ensureEngineRunning()
        player.currentTime = 0
        player.play()
    }

    private func play(buffer: AVAudioPCMBuffer?) {
        guard !isMuted, let buffer else { return }
        ensureEngineRunning()
        guard engine.isRunning else { return }
        effects.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !effects.isPlaying { effects.play() }
    }

    /// `.playback` so the app still sounds with the ringer switch off; farts are the whole point.
    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func loadFarts() {
        for name in Self.farts {
            guard
                let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
                let player = try? AVAudioPlayer(contentsOf: url)
            else { continue }
            player.prepareToPlay()
            fartPlayers[name] = player
            loadedFarts.append(name)
        }
        fartBag = SoundBag(count: loadedFarts.count)
    }

    private func configureEngine() {
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let rate = sampleRate > 0 ? sampleRate : 44100
        guard let mono = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return }

        let squelch = Self.makeSquelchNode(sampleRate: rate, gain: squelchGain, frequency: squelchFrequency)
        engine.attach(squelch)
        engine.attach(effects)
        engine.connect(squelch, to: engine.mainMixerNode, format: mono)
        engine.connect(effects, to: engine.mainMixerNode, format: mono)
        plopBuffer = Self.makeBuffer(Synth.plop(sampleRate: rate), format: mono)
        fanfareBuffer = Self.makeBuffer(Synth.fanfare(sampleRate: rate), format: mono)
    }

    private static func makeSquelchNode(
        sampleRate: Double,
        gain: UnsafeMutablePointer<Float>,
        frequency: UnsafeMutablePointer<Float>
    ) -> AVAudioSourceNode {
        var generator = SquelchGenerator(sampleRate: sampleRate)
        return AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let first = buffers.first, let data = first.mData else { return noErr }
            let output = UnsafeMutableBufferPointer(
                start: data.assumingMemoryBound(to: Float.self),
                count: Int(frameCount)
            )
            generator.fill(output, gain: gain.pointee, frequency: frequency.pointee)
            return noErr
        }
    }

    private static func makeBuffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData?[0]
        else { return nil }
        samples.withUnsafeBufferPointer { source in
            if let address = source.baseAddress {
                channel.update(from: address, count: samples.count)
            }
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        return buffer
    }

    private func observeInterruptions() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            AVAudioSession.interruptionNotification,
            .AVAudioEngineConfigurationChange,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.ensureEngineRunning()
            }
        }
    }
}
