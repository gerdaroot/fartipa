import UIKit

/// Taps for the hands. Coin taps are rate-limited so a row of coins does not turn into a buzz.
@MainActor
final class Haptics {
    private static let coinGap = 0.09

    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notice = UINotificationFeedbackGenerator()
    private var lastCoin = 0.0

    func prepare() {
        heavy.prepare()
        light.prepare()
    }

    func hit() { heavy.impactOccurred() }
    func smash() { rigid.impactOccurred() }
    func bump() { medium.impactOccurred() }
    func tick() { light.impactOccurred(intensity: 0.6) }
    func success() { notice.notificationOccurred(.success) }
    func failure() { notice.notificationOccurred(.error) }

    func coin(now: Double, golden: Bool) {
        guard golden || now - lastCoin >= Self.coinGap else { return }
        lastCoin = now
        if golden {
            medium.impactOccurred()
        } else {
            light.impactOccurred(intensity: 0.4)
        }
    }
}
