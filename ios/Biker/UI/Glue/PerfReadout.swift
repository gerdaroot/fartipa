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

    /// Builds the text once per second, and only while the overlay is on. Draw calls and triangles
    /// are on SceneKit's own statistics bar, shown together with this overlay.
    func publish(_ report: FrameMonitor.Report, highQuality: Bool, thermal: ProcessInfo.ThermalState) {
        guard isOn else { return }
        let quality = highQuality ? "высокое" : "низкое"
        var next = "\(report.fps) FPS · худший \(report.worstMs) мс · фризов >50 мс: \(report.hitches) · >100 мс: \(report.freezes)\n"
            + "графика: \(quality) · нагрев: \(Self.name(thermal))"
        if let world = PerfWorldLink.world {
            next += "\n" + world.perfSummary
        }
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

/// The world the overlay reports on (tier, frame-rate cap, pooled objects drawn). Set by `BikeWorld`.
@MainActor
enum PerfWorldLink {
    static weak var world: BikeWorld?
}

extension BikeGame {
    /// The hidden diagnostics: fps, worst frame and hitches, plus SceneKit's own statistics bar.
    func togglePerfOverlay() {
        perf.setOn(!perf.isOn)
        world.view.showsStatistics = perf.isOn
        haptics.tick()
    }
}

extension BikeWorld {
    /// What the performance overlay shows about the scene. Built only when the overlay asks.
    var perfSummary: String {
        let shadows = settings.shadows ? "тени" : "без теней"
        let shading = PerfMaterialThrift.isCheap ? "ламберт" : "PBR"
        return "уровень: \(tier.title) · \(targetFPS) к/с · объектов: \(PoolCulling.shown) · \(shadows) · \(shading)"
    }
}
