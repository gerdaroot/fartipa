import Foundation

/// Frame-time statistics of the main loop, for the automatic quality switch and the debug overlay.
/// Fed once per frame with the real, unclamped time since the previous frame. Allocates nothing.
struct FrameMonitor {
    struct Report: Equatable {
        var fps = 0
        /// The slowest frame of the last second, in milliseconds.
        var worstMs = 0
        /// Frames over `hitchSeconds` since launch.
        var hitches = 0
        /// Frames over `freezeSeconds` since launch: the stalls a player calls a freeze.
        var freezes = 0
    }

    static let hitchSeconds = 0.05
    static let freezeSeconds = 0.1
    private static let windowSeconds = 1.0
    private static let msPerSecond = 1000.0

    private(set) var hitches = 0
    private(set) var freezes = 0
    private var windowTime = 0.0
    private var windowFrames = 0
    private var windowWorst = 0.0

    /// Records one frame; returns a report once per second and nil otherwise.
    mutating func record(_ elapsed: Double) -> Report? {
        guard elapsed > 0, elapsed.isFinite else { return nil }
        if elapsed > Self.hitchSeconds { hitches += 1 }
        if elapsed > Self.freezeSeconds { freezes += 1 }
        windowTime += elapsed
        windowFrames += 1
        windowWorst = max(windowWorst, elapsed)
        guard windowTime >= Self.windowSeconds else { return nil }
        let report = Report(
            fps: Int((Double(windowFrames) / windowTime).rounded()),
            worstMs: Int((windowWorst * Self.msPerSecond).rounded()),
            hitches: hitches,
            freezes: freezes
        )
        windowTime = 0
        windowFrames = 0
        windowWorst = 0
        return report
    }

    /// Starts a fresh window, e.g. after loading, so the warm-up does not count as slow frames.
    mutating func restartWindow() {
        windowTime = 0
        windowFrames = 0
        windowWorst = 0
    }
}

/// Drops the graphics to low once when the phone cannot keep up or gets hot. Never climbs back
/// on its own, so the picture does not flip back and forth.
struct AutoQuality {
    /// Below this, a second counts as slow.
    private static let slowFps = 48
    /// This many slow seconds in a row drop the quality.
    private static let slowSecondsNeeded = 3
    /// Seconds after loading that are ignored: the first frames are always the roughest.
    private static let graceSeconds = 3

    private(set) var isHigh: Bool
    private var slowSeconds = 0
    private var seconds = 0

    init(isHigh: Bool) {
        self.isHigh = isHigh
    }

    /// Feed one report per second. Returns true exactly once, when the quality should drop now.
    mutating func shouldDrop(after report: FrameMonitor.Report, thermal: ProcessInfo.ThermalState) -> Bool {
        seconds += 1
        guard isHigh, seconds > Self.graceSeconds else { return false }
        let hot = thermal == .serious || thermal == .critical
        slowSeconds = report.fps < Self.slowFps ? slowSeconds + 1 : 0
        guard hot || slowSeconds >= Self.slowSecondsNeeded else { return false }
        isHigh = false
        return true
    }
}
