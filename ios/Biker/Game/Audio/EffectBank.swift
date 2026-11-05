import AVFoundation

/// Small pools of player nodes for one-shot effects. Each sound interrupts its own node, so nothing queues
/// behind anything else; coin chimes are dropped when the chime pool is full instead of lagging.
/// Main thread only.
final class EffectBank {
    private struct Voice {
        let node: AVAudioPlayerNode
        var startedAt: TimeInterval = 0
        var busyUntil: TimeInterval = 0
    }

    private enum Pool { case chime, general, fart }

    private static let chimeVoiceCount = 3
    private static let generalVoiceCount = 4
    private static let fartVoiceCount = 2
    /// Two chimes closer than this sound like one; the second is dropped.
    private static let minChimeSpacing: TimeInterval = 0.03

    private let engine: AVAudioEngine
    private var chimes: [Voice]
    private var general: [Voice]
    private var farts: [Voice]
    private var lastChime: TimeInterval = 0

    init(engine: AVAudioEngine, format: AVAudioFormat) {
        self.engine = engine
        chimes = Self.makeVoices(Self.chimeVoiceCount, engine: engine, format: format)
        general = Self.makeVoices(Self.generalVoiceCount, engine: engine, format: format)
        farts = Self.makeVoices(Self.fartVoiceCount, engine: engine, format: format)
    }

    /// Plays on a free chime voice, or not at all.
    func playChime(_ buffer: AVAudioPCMBuffer, volume: Float) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastChime >= Self.minChimeSpacing,
              let index = chimes.firstIndex(where: { $0.busyUntil <= now })
        else { return }
        lastChime = now
        start(buffer, pool: .chime, index: index, volume: volume, now: now)
    }

    /// Plays on a free voice, cutting off the oldest sound when all are busy.
    func play(_ buffer: AVAudioPCMBuffer, volume: Float) {
        let now = ProcessInfo.processInfo.systemUptime
        start(buffer, pool: .general, index: Self.pick(general, now: now), volume: volume, now: now)
    }

    func playFart(_ buffer: AVAudioPCMBuffer, volume: Float) {
        let now = ProcessInfo.processInfo.systemUptime
        start(buffer, pool: .fart, index: Self.pick(farts, now: now), volume: volume, now: now)
    }

    func stopAll() {
        chimes = Self.stopped(chimes)
        general = Self.stopped(general)
        farts = Self.stopped(farts)
    }

    // MARK: - Private

    private func start(_ buffer: AVAudioPCMBuffer, pool: Pool, index: Int, volume: Float, now: TimeInterval) {
        guard engine.isRunning else { return }
        let duration = GameAudioFormat.seconds(of: buffer)
        let voice: Voice
        switch pool {
        case .chime: voice = chimes[index]
        case .general: voice = general[index]
        case .fart: voice = farts[index]
        }
        voice.node.volume = volume
        voice.node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.node.isPlaying { voice.node.play() }
        let updated = Voice(node: voice.node, startedAt: now, busyUntil: now + duration)
        switch pool {
        case .chime: chimes[index] = updated
        case .general: general[index] = updated
        case .fart: farts[index] = updated
        }
    }

    private static func pick(_ voices: [Voice], now: TimeInterval) -> Int {
        if let free = voices.firstIndex(where: { $0.busyUntil <= now }) { return free }
        var oldest = 0
        for index in voices.indices where voices[index].startedAt < voices[oldest].startedAt {
            oldest = index
        }
        return oldest
    }

    private static func stopped(_ voices: [Voice]) -> [Voice] {
        voices.map { voice -> Voice in
            voice.node.stop()
            return Voice(node: voice.node)
        }
    }

    private static func makeVoices(_ count: Int, engine: AVAudioEngine, format: AVAudioFormat) -> [Voice] {
        (0..<count).map { _ -> Voice in
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            return Voice(node: node)
        }
    }
}
