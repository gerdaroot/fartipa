import SwiftUI

/// The riding screen: drag anywhere to steer, HUD around the edges.
struct RideHUD: View {
    @ObservedObject var game: BikeGame
    @ObservedObject var feed: RideFeed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash = 0.0

    private static let flashPeak = 0.6
    private static let flashPeakReduced = 0.3
    private static let flashSeconds = 0.45

    private var hud: HUDSnapshot { feed.hud }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                steeringLayer(width: proxy.size.width)
                Palette.piss
                    .opacity(flash)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    topBar
                    ScoreHeader(score: hud.score, district: hud.districtName, combo: hud.combo, comboFraction: hud.comboFraction)
                    PowerUpRow(hud: hud)
                    if let lane = hud.warningLane { StreamWarning(lane: lane) }
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
        }
        .onChange(of: feed.hitCount) { _ in hitFlash() }
    }

    private func steeringLayer(width: CGFloat) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        game.steerDrag(translation: Double(value.translation.width), width: Double(width))
                    }
                    .onEnded { _ in game.endSteer() }
            )
            .accessibilityHidden(true)
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
        Text("Веди пальцем влево-вправо. Жёлтое с неба — мимо, говнокоины — в карман, «ГАЗЫ» — тарань всех!")
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
            BoostButton(
                fraction: hud.boostFraction, canBoost: hud.canBoost, isBoosting: hud.isBoosting, action: { game.boost() }
            )
        }
    }

    private func hitFlash() {
        flash = reduceMotion ? Self.flashPeakReduced : Self.flashPeak
        withAnimation(.easeOut(duration: Self.flashSeconds)) { flash = 0 }
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
                .hudShadow()
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

    var body: some View {
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
