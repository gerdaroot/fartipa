import Foundation
import UIKit

/// A banner at the top of any screen: achievements, daily reward, purchases.
struct GameToast: Identifiable, Equatable {
    enum Tone: Equatable { case achievement, reward, info }

    let id: Int
    let title: String
    let subtitle: String
    let tone: Tone
    let born: Double
}

/// Toasts and the one-line shop message. Separate from `BikeGame` so a toast does not
/// redraw every screen.
@MainActor
final class NoticeCenter: ObservableObject {
    static let toastSeconds = 3.2
    static let messageSeconds = 2.4
    private static let maxToasts = 3

    @Published private(set) var toasts: [GameToast] = []
    /// "Не хватает монет" and similar. Cleared by time and when the screen changes.
    @Published private(set) var message: String?

    private var nextId = 0
    private var messageBorn = 0.0

    func toast(_ title: String, _ subtitle: String, tone: GameToast.Tone, now: Double) {
        nextId += 1
        let fresh = GameToast(id: nextId, title: title, subtitle: subtitle, tone: tone, born: now)
        toasts = Array((toasts + [fresh]).suffix(Self.maxToasts))
        UIAccessibility.post(notification: .announcement, argument: "\(title). \(subtitle)")
    }

    func say(_ text: String, now: Double) {
        message = text
        messageBorn = now
    }

    func clearMessage() {
        if message != nil { message = nil }
    }

    /// Called every frame; only publishes when something actually expires.
    func expire(now: Double) {
        if toasts.contains(where: { now - $0.born > Self.toastSeconds }) {
            toasts = toasts.filter { now - $0.born <= Self.toastSeconds }
        }
        if message != nil, now - messageBorn > Self.messageSeconds {
            message = nil
        }
    }
}
