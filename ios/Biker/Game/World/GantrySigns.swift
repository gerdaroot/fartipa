import SceneKit
import UIKit

/// The two green signs on the overhead gantry: the distance to the next district and a joke.
/// Text pictures are painted on a background queue and cached; the main thread only swaps
/// finished images in, so a new lap never stalls a frame with text layout.
@MainActor
final class GantrySigns {
    private static let jokes: [(title: String, detail: String)] = [
        ("ТУАЛЕТ", "0,5 км  →"), ("ОБЪЕЗД КУЧИ", "ДЕРЖИСЬ ЛЕВЕЕ"), ("НЕ ПЕРДЕТЬ", "ШТРАФ 500 ₽"),
        ("ОСАДКИ: ЖЁЛТЫЕ", "ВКЛЮЧИ ДВОРНИКИ"), ("ЦЕНТР", "ПРЯМО И ВНИЗ"),
    ]
    private static let cacheLimit = 16

    private let panels: [SCNNode]
    private var cache: [String: UIImage] = [:]
    private var wanted: [String] = []
    private var painting = Set<String>()

    init(panels: [SCNNode]) {
        self.panels = panels
        wanted = panels.map { _ in "" }
        for joke in Self.jokes { paint(title: joke.title, detail: joke.detail) }
    }

    /// Dresses both panels for the gantry copy standing at `worldZ`. `now` paints on the calling
    /// thread (only while loading) instead of in the background.
    func show(worldZ: Double, now: Bool = false) {
        guard panels.count == 2 else { return }
        let distanceSign = Self.distanceText(worldZ: worldZ)
        var random = SlotRandom.make(row: 6, slot: 0, lap: Int(worldZ))
        let joke = Self.jokes[random.int(below: Self.jokes.count)]
        request(title: distanceSign.title, detail: distanceSign.detail, panel: 0, now: now)
        request(title: joke.title, detail: joke.detail, panel: 1, now: now)
    }

    private static func distanceText(worldZ: Double) -> (title: String, detail: String) {
        guard let next = District.all.first(where: { $0.startDistance > worldZ }) else {
            return ("ЖОПА МИРА", "ДАЛЬШЕ НЕКУДА")
        }
        let kilometres = (next.startDistance - worldZ) / 1000
        return (next.name.uppercased(), String(format: "%.1f км  ↑", kilometres))
    }

    private static func key(_ title: String, _ detail: String) -> String { title + "|" + detail }

    private func request(title: String, detail: String, panel: Int, now: Bool) {
        let key = Self.key(title, detail)
        wanted[panel] = key
        if let image = cache[key] {
            apply(image, panel: panel)
        } else if now {
            store(CityTextures.roadSign(title: title, detail: detail), key: key)
        } else {
            paint(title: title, detail: detail)
        }
    }

    private func paint(title: String, detail: String) {
        let key = Self.key(title, detail)
        guard cache[key] == nil, !painting.contains(key) else { return }
        painting.insert(key)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let image = CityTextures.roadSign(title: title, detail: detail)
            Task { @MainActor in self?.store(image, key: key) }
        }
    }

    private func store(_ image: UIImage, key: String) {
        painting.remove(key)
        if cache.count >= Self.cacheLimit {
            let jokeKeys = Set(Self.jokes.map { Self.key($0.title, $0.detail) })
            for old in Array(cache.keys) where !jokeKeys.contains(old) && !wanted.contains(old) {
                cache.removeValue(forKey: old)
            }
        }
        cache[key] = image
        for (panel, wantedKey) in wanted.enumerated() where wantedKey == key {
            apply(image, panel: panel)
        }
    }

    private func apply(_ image: UIImage, panel: Int) {
        guard let material = panels[panel].geometry?.firstMaterial else { return }
        if material.diffuse.contents as? UIImage === image { return }
        material.diffuse.contents = image
        material.emission.contents = image
    }
}
