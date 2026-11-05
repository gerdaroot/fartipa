import SwiftUI

/// The paused ride: how it goes so far, go on or end it.
struct PauseSheet: View {
    @ObservedObject var game: BikeGame

    var body: some View {
        SheetPanel {
            BigTitle(text: "ПАУЗА", size: 40)
            if let run = game.run {
                HStack(spacing: 8) {
                    StatBlock(value: "\(run.score)", title: "очки")
                    StatBlock(value: "\(Int(run.distance)) м", title: "проехал")
                    StatBlock(value: "+\(run.coins)", title: "монеты")
                }
            }
            Button(action: { game.resume() }) {
                Label("Погнали дальше", systemImage: "play.fill")
            }
            .buttonStyle(ChunkyButtonStyle(kind: .gold, height: 62, fontSize: 22))
            Button(action: { game.finishRide() }) {
                Label("Закончить заезд", systemImage: "flag.checkered")
            }
            .buttonStyle(ChunkyButtonStyle(kind: .red, height: 54, fontSize: 18))
            Button(action: { game.toggleMute() }) {
                Label(game.isMuted ? "Включить звук" : "Выключить звук",
                      systemImage: game.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .buttonStyle(ChunkyButtonStyle(kind: .steel, height: 48, fontSize: 15))
            Text("Монеты и рекорд не пропадут, даже если выйти.")
                .font(GameFont.styled(.caption, weight: .semibold))
                .foregroundStyle(Palette.cream.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}

/// The results: score, coins banked, record, a few numbers and where to go next.
struct GameOverSheet: View {
    @ObservedObject var game: BikeGame

    var body: some View {
        SheetPanel(rim: Palette.gold.opacity(0.6)) {
            if let outcome = game.outcome {
                content(outcome)
            } else {
                BigTitle(text: "ПРИЕХАЛИ", size: 36)
                Button(action: { game.goHub() }) { Label("В меню", systemImage: "house.fill") }
                    .buttonStyle(ChunkyButtonStyle(kind: .gold))
            }
        }
    }

    @ViewBuilder
    private func content(_ outcome: RideOutcome) -> some View {
        BigTitle(text: outcome.crashed ? "ТЕБЯ ОБОССАЛИ!" : "ЗАЕЗД ОКОНЧЕН", size: 34)
        if outcome.reward.isNewRecord { NewRecordBadge() }
        VStack(spacing: 0) {
            Text("\(outcome.summary.score)")
                .font(GameFont.title(52).monospacedDigit())
                .foregroundStyle(Palette.cream)
                .outlined(width: 3)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("ОЧКОВ")
                .font(GameFont.label(13))
                .foregroundStyle(Palette.cream.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
        coinsEarned(outcome)
        HStack(spacing: 8) {
            StatBlock(value: "\(outcome.summary.distance) м", title: "проехал")
            StatBlock(value: "\(outcome.summary.nearMisses)", title: "на волоске")
            StatBlock(value: "×\(outcome.summary.bestCombo)", title: "комбо")
        }
        HStack(spacing: 8) {
            StatBlock(value: "\(outcome.summary.vehiclesSmashed)", title: "тараны")
            StatBlock(value: "\(outcome.summary.hits)", title: "обоссан")
            StatBlock(value: districtName(outcome.summary.districtIndex), title: "район", tint: Palette.redTop)
        }
        buttons
    }

    private func coinsEarned(_ outcome: RideOutcome) -> some View {
        HStack(spacing: 10) {
            CoinIcon(size: 34)
            Text("+\(outcome.reward.coinsEarned)")
                .font(GameFont.title(34).monospacedDigit())
                .foregroundStyle(Palette.gold)
                .outlined(width: 2)
            if outcome.reward.achievementCoins > 0 {
                Text("+\(outcome.reward.achievementCoins) за ачивки")
                    .font(GameFont.styled(.caption, weight: .heavy))
                    .foregroundStyle(Palette.greenTop)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.4)))
        .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.6), lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(coinsLabel(outcome))
    }

    private func coinsLabel(_ outcome: RideOutcome) -> String {
        let base = "Заработано \(outcome.reward.coinsEarned) говнокоинов"
        guard outcome.reward.achievementCoins > 0 else { return base }
        return base + " и \(outcome.reward.achievementCoins) за достижения"
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            Button(action: { game.startRide() }) {
                Label("Ещё заезд", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ChunkyButtonStyle(kind: .gold, height: 62, fontSize: 22))
            HStack(spacing: 8) {
                Button(action: { game.openGarage() }) { Label("Гараж", systemImage: "bicycle") }
                    .buttonStyle(ChunkyButtonStyle(kind: .red, height: 50, fontSize: 15))
                Button(action: { game.openUpgrades() }) { Label("Прокачка", systemImage: "wrench.and.screwdriver.fill") }
                    .buttonStyle(ChunkyButtonStyle(kind: .red, height: 50, fontSize: 15))
            }
            Button(action: { game.goHub() }) { Label("В меню", systemImage: "house.fill") }
                .buttonStyle(ChunkyButtonStyle(kind: .steel, height: 46, fontSize: 15))
        }
    }

    private func districtName(_ index: Int) -> String {
        District.all.indices.contains(index) ? District.all[index].name : "—"
    }
}

/// «НОВЫЙ РЕКОРД!» on a red ribbon.
private struct NewRecordBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grow = false

    var body: some View {
        Label("НОВЫЙ РЕКОРД!", systemImage: "crown.fill")
            .font(GameFont.title(20))
            .foregroundStyle(Palette.goldTop)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Capsule().fill(LinearGradient(
                colors: [Palette.redTop, Palette.redBottom], startPoint: .top, endPoint: .bottom
            )))
            .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2.5))
            .rotationEffect(.degrees(-3))
            .scaleEffect(grow ? 1.08 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { grow = true }
            }
    }
}
