import SwiftUI

/// The riding screen: drag anywhere to steer, HUD around the edges.
/// This outer view observes nothing that changes during a ride, so the gesture layer and the
/// geometry reader are never rebuilt; only `HUDLayer` and `HitFlash` follow the ride feed.
struct RideHUD: View {
    let game: BikeGame
    let feed: RideFeed
    /// A class, so marking a swipe as used does not rebuild this view.
    @State private var swipe = HUDSwipeLatch()

    /// Points the finger must travel up, and how much more up than sideways, to jump.
    private static let swipeUpPoints: CGFloat = 46
    private static let swipeUpRatio: CGFloat = 1.1

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                steeringLayer(width: proxy.size.width)
                DangerGlow(feed: feed)
                HitFlash(feed: feed)
                HUDLayer(game: game, feed: feed)
            }
        }
    }

    private func steeringLayer(width: CGFloat) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        game.steerDrag(translation: Double(value.translation.width), width: Double(width))
                        jumpIfSwipedUp(value.translation)
                    }
                    .onEnded { _ in
                        swipe.fired = false
                        game.endSteer()
                    }
            )
            .accessibilityHidden(true)
    }

    /// One jump per drag: the finger has to lift before the next swipe counts.
    private func jumpIfSwipedUp(_ travel: CGSize) {
        guard !swipe.fired else { return }
        let up = -travel.height
        guard up > Self.swipeUpPoints, up > abs(travel.width) * Self.swipeUpRatio else { return }
        swipe.fired = true
        game.jump()
    }
}

/// Remembers whether the current drag has already jumped.
final class HUDSwipeLatch {
    var fired = false
}

/// The yellow flash when the rider gets hit.
private struct HitFlash: View {
    @ObservedObject var feed: RideFeed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash = 0.0
    @State private var slowFlash = 0.0

    private static let flashPeak = 0.6
    private static let flashPeakReduced = 0.3
    private static let flashSeconds = 0.45
    /// The near-miss slow motion: a short white blink.
    private static let slowPeak = 0.22
    private static let slowSeconds = 0.3

    var body: some View {
        ZStack {
            Palette.piss.opacity(flash)
            Color.white.opacity(slowFlash)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: feed.hitCount) { _ in hitFlash() }
        .onChange(of: feed.slowMoCount) { _ in slowMoFlash() }
    }

    private func hitFlash() {
        flash = reduceMotion ? Self.flashPeakReduced : Self.flashPeak
        withAnimation(.easeOut(duration: Self.flashSeconds)) { flash = 0 }
    }

    private func slowMoFlash() {
        guard !reduceMotion else { return }
        slowFlash = Self.slowPeak
        withAnimation(.easeOut(duration: Self.slowSeconds)) { slowFlash = 0 }
    }
}

/// Red glow at the screen edges while a stream is about to land on the bike's line.
private struct DangerGlow: View {
    @ObservedObject var feed: RideFeed

    private static let width: CGFloat = 26

    var body: some View {
        let level = feed.hud.danger
        Rectangle()
            .strokeBorder(Palette.danger.opacity(0.75 * level), lineWidth: Self.width)
            .blendMode(.screen)
            .opacity(level > 0 ? 1 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Everything drawn from the ride feed. The feed publishes the fast numbers ~15 times a second.
private struct HUDLayer: View {
    let game: BikeGame
    @ObservedObject var feed: RideFeed

    private var hud: HUDSnapshot { feed.hud }

    var body: some View {
        VStack(spacing: 8) {
            topBar
            ScoreHeader(score: hud.score, district: hud.districtName, combo: hud.combo, comboFraction: hud.comboFraction)
            PowerUpRow(hud: hud)
            // One child: a view builder takes at most 10 on iOS 16.
            Group {
                if let lane = hud.warningLane { StreamWarning(lane: lane) }
                if let banner = feed.banner {
                    RoadEventBanner(banner: banner)
                } else if let event = hud.roadEvent {
                    RoadEventTimer(kind: event, seconds: hud.roadEventSeconds)
                }
            }
            Spacer(minLength: 0)
            PopupStack(popups: feed.popups)
            Spacer(minLength: 0)
            if hud.showsHint { hint }
            bottomBar
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            RoundIconButton(symbol: "pause.fill", label: "Пауза", action: { game.pause() })
            LivesView(lives: hud.lives, slots: max(hud.startingLives, hud.lives), isHurt: hud.isHurt)
            Spacer(minLength: 0)
            CoinBadge(amount: hud.coins, label: "Монет за заезд")
        }
    }

    private var hint: some View {
        Text("Веди пальцем влево-вправо, свайп вверх — пердёж-прыжок через кучи и люки. Жёлтое с неба — мимо, «ГАЗЫ» — тарань всех!")
            .font(GameFont.styled(.subheadline, weight: .heavy))
            .foregroundStyle(Palette.cream)
            .multilineTextAlignment(.center)
            .padding(12)
            .background(PanelBackground(cornerRadius: 16))
            .allowsHitTesting(false)
            .transition(.opacity)
    }

    private var bottomBar: some View {
        HStack(alignment: .bottom) {
            SpeedDial(kmh: hud.speedKmh, dial: hud.dial, isBoosting: hud.isBoosting)
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                JumpButton(
                    readiness: hud.jumpReadiness, canJump: hud.canJump, isAirborne: hud.isAirborne, action: { game.jump() }
                )
                BoostButton(
                    fraction: hud.boostFraction, canBoost: hud.canBoost, isBoosting: hud.isBoosting, action: { game.boost() }
                )
            }
        }
    }
}

/// Hearts: full for lives left, dim for lost ones. They blink while the rider is untouchable.
private struct LivesView: View {
    let lives: Int
    let slots: Int
    let isHurt: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(0, slots), id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(index < lives ? Palette.danger : Color.white.opacity(0.18))
                    .outlined(width: 1.2)
            }
        }
        .opacity(isHurt ? 0.6 : 1)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Capsule().fill(Palette.tray))
        .overlay(Capsule().strokeBorder(Palette.danger.opacity(0.5), lineWidth: 1.5))
        .accessibilityElement()
        .accessibilityLabel("Жизней: \(lives)")
    }
}

/// Score in the middle, the district under it and the combo beside it.
private struct ScoreHeader: View {
    let score: Int
    let district: String
    let combo: Int
    let comboFraction: Double

    var body: some View {
        VStack(spacing: 2) {
            Text("\(score)")
                .font(GameFont.title(40).monospacedDigit())
                .foregroundStyle(Palette.cream)
                .outlined(width: 2.5)
            HStack(spacing: 8) {
                Text(district.uppercased())
                    .font(GameFont.label(12))
                    .foregroundStyle(Palette.gold)
                    .outlined(width: 1)
                if combo > 1 { ComboChip(combo: combo, fraction: comboFraction) }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Очки: \(score). \(district)\(combo > 1 ? ". Комбо \(combo)" : "")")
    }
}

private struct ComboChip: View {
    let combo: Int
    let fraction: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 1

    private static let pulsePeak: CGFloat = 1.35

    var body: some View {
        chip
            .scaleEffect(pulse)
            .onChange(of: combo) { newValue in bump(up: newValue > 1) }
    }

    /// The chip jumps when the combo grows, so every near miss and flip is felt.
    private func bump(up: Bool) {
        guard up, !reduceMotion else { return }
        pulse = Self.pulsePeak
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { pulse = 1 }
    }

    private var chip: some View {
        VStack(spacing: 2) {
            Text("КОМБО ×\(combo)")
                .font(GameFont.label(13))
                .foregroundStyle(Palette.ink)
            GeometryReader { proxy in
                Capsule().fill(Palette.ink.opacity(0.3))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Palette.ink).frame(width: proxy.size.width * max(0, min(1, fraction)))
                    }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(LinearGradient(
            colors: [Palette.goldTop, Palette.goldBottom], startPoint: .top, endPoint: .bottom
        )))
        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
        .fixedSize()
    }
}

/// Timers of the pickups in effect.
private struct PowerUpRow: View {
    let hud: HUDSnapshot

    var body: some View {
        HStack(spacing: 6) {
            if hud.magnetSeconds > 0 { chip("dollarsign.circle.fill", "Магнит", hud.magnetSeconds) }
            if hud.shieldSeconds > 0 { chip("leaf.fill", "Щит", hud.shieldSeconds) }
            if hud.doublerSeconds > 0 { chip("multiply.circle.fill", "Двойной навар", hud.doublerSeconds) }
        }
        .allowsHitTesting(false)
    }

    private func chip(_ symbol: String, _ name: String, _ seconds: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text("\(seconds)").monospacedDigit()
        }
        .font(GameFont.label(14))
        .foregroundStyle(Palette.cream)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Palette.tray))
        .overlay(Capsule().strokeBorder(Palette.greenTop.opacity(0.7), lineWidth: 1.5))
        .accessibilityElement()
        .accessibilityLabel("\(name): \(seconds) секунд")
    }
}
