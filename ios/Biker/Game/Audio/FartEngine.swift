import AVFoundation

/// The bike's motor is farts. Recordings are dealt from a shuffle bag onto three player nodes, each one
/// starting slightly before the previous one ends, so the exhaust never goes quiet. A varispeed raises
/// pitch and tempo with speed; boosting adds level, presence and distortion. Every change is smoothed.
///
/// `setRide` only stores targets (cheap, called every frame, never allocates). One main-queue timer, made
/// once at launch and only resumed while the motor is audible, does the smoothing and the scheduling at
/// 30 Hz; farts are scheduled well ahead, so a main-thread hitch shorter than the lookahead never gaps the
/// motor. No render callbacks: the audio thread only runs Apple's nodes. Main thread only.
final class FartEngine {
    private static let voiceCount = 3
    private static let tickInterval: Double = 1.0 / 30
    private static let rate = GameAudioFormat.sampleRate
    /// Schedule the next fart this far (real seconds) before it must start, so its start time is in the future.
    private static let lookaheadSeconds: Double = 0.18
    private static let overlapSlow: Double = 0.05
    private static let overlapFast: Double = 0.14
    private static let maxOverlapFraction: Double = 0.4

    private static let rateIdle: Double = 0.72
    private static let rateSpan: Double = 0.55
    private static let rateBoost: Double = 0.22
    private static let levelBase: Double = 0.5
    private static let levelSpeed: Double = 0.25
    private static let levelBoost: Double = 0.25
    private static let rumbleIdleDecibels: Double = 7
    private static let rumbleFastDecibels: Double = 2
    private static let presenceBoostDecibels: Double = 8
    private static let driveBoostPercent: Double = 40
    /// Below this wet share the distortion unit is bypassed.
    private static let driveBypassPercent: Float = 0.5

    private static let attackTime: Double = 0.15
    private static let releaseTime: Double = 0.22
    private static let speedTime: Double = 0.3
    private static let boostTime: Double = 0.18
    private static let silentLevel: Double = 0.002

    private let engine: AVAudioEngine
    private let voices: [AVAudioPlayerNode]
    private let bus = AVAudioMixerNode()
    private let varispeed = AVAudioUnitVarispeed()
    private let equalizer = AVAudioUnitEQ(numberOfBands: 2)
    private let distortion = AVAudioUnitDistortion()

    private var clips: [AVAudioPCMBuffer] = []
    private var bag = ShuffleDeck(count: 0)

    private var active = false
    private var targetSpeed: Double = 0
    private var targetBoost: Double = 0
    private var speed: Double = 0
    private var boost: Double = 0
    private var level: Double = 0
    private var written = Written()
    private var rumbleBand: AVAudioUnitEQFilterParameters?
    private var presenceBand: AVAudioUnitEQFilterParameters?

    private var voicesPlaying = false
    private var lastVoice = -1
    private var lastLength: AVAudioFramePosition = 0
    /// End of the newest fart, in the player-time samples of `lastVoice`.
    private var lastEnd: AVAudioFramePosition = 0
    /// Source samples left until the next fart should start (estimated between schedules).
    private var samplesUntilNext: Double = 0
    private let timer: DispatchSourceTimer
    private var timerRunning = false
    private var lastTick: TimeInterval = 0

    /// Last values handed to the audio units; parameters are only written when they move.
    private struct Written {
        var rate: Float = -1
        var volume: Float = -1
        var rumble: Float = -100
        var presence: Float = -100
        var drive: Float = -1
        var bypassed = false
    }

    init(engine: AVAudioEngine, voiceFormat: AVAudioFormat, busFormat: AVAudioFormat) {
        self.engine = engine
        voices = (0..<Self.voiceCount).map { _ in AVAudioPlayerNode() }
        // Made once and kept suspended between rides, so starting the motor never allocates.
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: Self.tickInterval, leeway: .milliseconds(5))
        let chain: [AVAudioNode] = [bus, varispeed, equalizer, distortion]
        chain.forEach { engine.attach($0) }
        voices.forEach { voice in
            engine.attach(voice)
            engine.connect(voice, to: bus, format: voiceFormat)
        }
        engine.connect(bus, to: varispeed, format: busFormat)
        engine.connect(varispeed, to: equalizer, format: busFormat)
        engine.connect(equalizer, to: distortion, format: busFormat)
        engine.connect(distortion, to: engine.mainMixerNode, format: busFormat)
        configureUnits()
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
    }

    deinit {
        timer.cancel()
        // A suspended source must be resumed before it is released.
        if !timerRunning { timer.resume() }
    }

    /// Hands over the decoded engine slices; the motor stays silent until this arrives.
    func install(_ buffers: [AVAudioPCMBuffer]) {
        clips = buffers
        bag = ShuffleDeck(count: buffers.count)
    }

    func setRide(active: Bool, speed01: Double, boosting: Bool) {
        self.active = active
        targetSpeed = min(1, max(0, speed01.isFinite ? speed01 : 0))
        targetBoost = boosting ? 1 : 0
        if active && !timerRunning { startTimer() }
    }

    /// Silences the motor at once (pause, game over, mute, interruption).
    func stop() {
        active = false
        level = 0
        finish()
    }

    /// The engine was restarted, which resets every node's timeline: start the voices again from scratch.
    func engineRestarted() {
        stopVoices()
    }

    // MARK: - Tick

    private func startTimer() {
        speed = targetSpeed
        boost = targetBoost
        lastTick = ProcessInfo.processInfo.systemUptime
        timerRunning = true
        timer.resume()
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, max(0, now - lastTick))
        lastTick = now
        smooth(dt: dt)
        applyParameters()
        if active, !clips.isEmpty, engine.isRunning {
            feed(dt: dt)
        }
        if !active && level < Self.silentLevel {
            finish()
        }
    }

    private func finish() {
        if timerRunning {
            timer.suspend()
            timerRunning = false
        }
        stopVoices()
        level = 0
        writeVolume(0)
    }

    private func smooth(dt: Double) {
        let base = Self.levelBase + Self.levelSpeed * targetSpeed + Self.levelBoost * targetBoost
        let targetLevel = active ? base : 0
        let levelTime = targetLevel > level ? Self.attackTime : Self.releaseTime
        level = Self.approach(level, to: targetLevel, time: levelTime, dt: dt)
        speed = Self.approach(speed, to: targetSpeed, time: Self.speedTime, dt: dt)
        boost = Self.approach(boost, to: targetBoost, time: Self.boostTime, dt: dt)
    }

    private static func approach(_ value: Double, to target: Double, time: Double, dt: Double) -> Double {
        value + (target - value) * (1 - exp(-dt / time))
    }

    private var currentRate: Double {
        Self.rateIdle + Self.rateSpan * speed + Self.rateBoost * boost
    }

    // MARK: - Parameters

    private func configureUnits() {
        let bands = equalizer.bands
        if bands.count >= 2 {
            let rumble = bands[0]
            rumble.filterType = .lowShelf
            rumble.frequency = 160
            rumble.gain = Float(Self.rumbleIdleDecibels)
            rumble.bypass = false
            let presence = bands[1]
            presence.filterType = .parametric
            presence.frequency = 1800
            presence.bandwidth = 1.2
            presence.gain = 0
            presence.bypass = false
            rumbleBand = rumble
            presenceBand = presence
        }
        distortion.loadFactoryPreset(.multiDistortedCubed)
        distortion.wetDryMix = 0
        varispeed.rate = Float(Self.rateIdle)
        bus.outputVolume = 0
    }

    private func applyParameters() {
        let rate = Float(currentRate)
        if abs(rate - written.rate) > 0.004 {
            varispeed.rate = rate
            written.rate = rate
        }
        writeVolume(Float(level))
        let rumble = Float(Self.rumbleIdleDecibels + (Self.rumbleFastDecibels - Self.rumbleIdleDecibels) * speed)
        if abs(rumble - written.rumble) > 0.1 {
            rumbleBand?.gain = rumble
            written.rumble = rumble
        }
        let presence = Float(Self.presenceBoostDecibels * boost)
        if abs(presence - written.presence) > 0.1 {
            presenceBand?.gain = presence
            written.presence = presence
        }
        let drive = Float(Self.driveBoostPercent * boost)
        if abs(drive - written.drive) > 0.5 {
            distortion.wetDryMix = drive
            written.drive = drive
        }
        // A fully dry distortion still runs its DSP on the audio thread; bypass it outside boosts.
        let idle = drive < Self.driveBypassPercent
        if idle != written.bypassed {
            distortion.bypass = idle
            written.bypassed = idle
        }
    }

    private func writeVolume(_ volume: Float) {
        guard abs(volume - written.volume) > 0.002 || (volume == 0 && written.volume != 0) else { return }
        bus.outputVolume = volume
        written.volume = volume
    }

    // MARK: - Scheduling

    private func feed(dt: Double) {
        if !voicesPlaying { startVoices() }
        samplesUntilNext -= dt * Self.rate * currentRate
        let lookahead = Self.lookaheadSeconds * Self.rate * currentRate
        if samplesUntilNext <= lookahead {
            scheduleNext()
        }
    }

    private func startVoices() {
        guard engine.isRunning else { return }
        voices.forEach { $0.play() }
        voicesPlaying = true
        lastVoice = -1
        samplesUntilNext = 0
    }

    private func stopVoices() {
        if voicesPlaying {
            voices.forEach { $0.stop() }
        }
        voicesPlaying = false
        lastVoice = -1
        lastLength = 0
        samplesUntilNext = 0
    }

    private func scheduleNext() {
        guard let index = bag.next(), index < clips.count else { return }
        let buffer = clips[index]
        let length = AVAudioFramePosition(buffer.frameLength)
        let voiceIndex = (lastVoice + 1) % voices.count
        let node = voices[voiceIndex]
        let overlap = overlapSamples(previous: lastLength, next: length)
        var delay: AVAudioFramePosition = 0
        var when: AVAudioTime?
        var start = Self.playerSample(node) ?? 0
        if lastVoice >= 0, let previousNow = Self.playerSample(voices[lastVoice]) {
            delay = max(0, lastEnd - overlap - previousNow)
            start += delay
            when = AVAudioTime(sampleTime: start, atRate: Self.rate)
        }
        node.scheduleBuffer(buffer, at: when, options: [], completionHandler: nil)
        lastVoice = voiceIndex
        lastLength = length
        lastEnd = start + length
        let nextOverlap = overlapSamples(previous: length, next: length)
        samplesUntilNext = Double(delay + length - nextOverlap)
    }

    /// Faster riding packs the farts tighter; never more than a fraction of the shorter one.
    private func overlapSamples(previous: AVAudioFramePosition, next: AVAudioFramePosition) -> AVAudioFramePosition {
        let seconds = Self.overlapSlow + (Self.overlapFast - Self.overlapSlow) * max(speed, boost)
        let wanted = AVAudioFramePosition(seconds * Self.rate)
        let shorter = previous > 0 ? min(previous, next) : next
        return min(wanted, AVAudioFramePosition(Double(shorter) * Self.maxOverlapFraction))
    }

    /// Samples this player has consumed; nil before it has rendered.
    private static func playerSample(_ node: AVAudioPlayerNode) -> AVAudioFramePosition? {
        guard
            let nodeTime = node.lastRenderTime,
            nodeTime.isSampleTimeValid,
            let playerTime = node.playerTime(forNodeTime: nodeTime)
        else { return nil }
        return playerTime.sampleTime
    }
}
