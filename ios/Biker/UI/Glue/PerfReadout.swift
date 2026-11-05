import Foundation

/// What the hidden performance overlay shows. Publishes once per second at most, and only while
/// the overlay is on, so it never redraws anything during normal play.
@MainActor
final class PerfReadout: ObservableObject {
    private static let key = "biker.perfOverlay"

    @Published private(set) var isOn: Bool
    @Published private(set) var line = "замеряю…"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        isOn = defaults.bool(forKey: Self.key)
    }

    func setOn(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        defaults.set(on, forKey: Self.key)
    }

    func publish(_ report: FrameMonitor.Report, highQuality: Bool, thermal: ProcessInfo.ThermalState) {
        guard isOn else { return }
        let quality = highQuality ? "высокое" : "низкое"
        let next = "\(report.fps) FPS · худший \(report.worstMs) мс · фризов >50 мс: \(report.hitches)\n"
            + "графика: \(quality) · нагрев: \(Self.name(thermal))"
        if next != line { line = next }
    }

    private static func name(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "норм"
        case .fair: return "тёплый"
        case .serious: return "горячий"
        case .critical: return "ПЕЧКА"
        @unknown default: return "?"
        }
    }
}

extension BikeGame {
    /// The hidden diagnostics: fps, worst frame and hitches, plus SceneKit's own statistics bar.
    func togglePerfOverlay() {
        perf.setOn(!perf.isOn)
        world.view.showsStatistics = perf.isOn
        haptics.tick()
    }
}
