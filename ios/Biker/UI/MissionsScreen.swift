import SwiftUI

/// «Задания»: the three active missions with progress and rewards, and the player level.
struct MissionsScreen: View {
    @ObservedObject var game: BikeGame

    var body: some View {
        ZStack {
            MenuVignette()
            content
        }
    }

    private var content: some View {
        VStack(spacing: 10) {
            ScreenTopBar(title: "Задания", coins: game.profile.coins, back: { game.closeMissions() })
            // Leaves the bike on the road visible above the list.
            Spacer(minLength: 110)
            MissionLevelBar(progress: game.profile.levelProgress)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(game.profile.missions) { mission in
                        MissionRow(mission: mission)
                    }
                    Text("Выполненное задание платит в конце заезда, и на его место встаёт новое. "
                        + "Опыт идёт с очков: новый уровень — тоже говнокоины.")
                        .font(GameFont.styled(.caption, weight: .semibold))
                        .foregroundStyle(Palette.cream.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(10)
            }
            .background(PanelBackground(cornerRadius: 26, rim: Palette.greenTop.opacity(0.45)))
            .layoutPriority(1)
            Button(action: { game.startRide() }) {
                Label("Погнали выполнять", systemImage: "flag.checkered")
            }
            .buttonStyle(ChunkyButtonStyle(kind: .gold, height: 58, fontSize: 20))
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

/// One mission: task, progress bar, reward. `compact` is the smaller row of the results sheet.
struct MissionRow: View {
    let mission: Mission
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            Image(systemName: mission.isDone ? "checkmark.seal.fill" : "target")
                .font(.system(size: compact ? 18 : 24, weight: .black))
                .foregroundStyle(mission.isDone ? Palette.greenTop : Palette.gold)
                .outlined(width: 1)
                .frame(width: compact ? 26 : 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(mission.title)
                    .font(GameFont.styled(compact ? .footnote : .subheadline, weight: .heavy))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                MissionBar(fraction: mission.fraction, done: mission.isDone)
                Text("\(min(mission.progress, mission.goal)) / \(mission.goal)")
                    .font(GameFont.label(compact ? 11 : 12).monospacedDigit())
                    .foregroundStyle(Palette.cream.opacity(0.7))
            }
            Spacer(minLength: 0)
            reward
        }
        .padding(compact ? 8 : 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(mission.isDone ? 0.12 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(mission.isDone ? Palette.greenTop.opacity(0.7) : Palette.hairline, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var reward: some View {
        HStack(spacing: 4) {
            CoinIcon(size: compact ? 18 : 22)
            Text("+\(mission.reward)")
                .font(GameFont.label(compact ? 15 : 18).monospacedDigit())
                .foregroundStyle(Palette.gold)
                .outlined(width: 1.2)
        }
    }

    private var accessibilityText: String {
        let state = mission.isDone ? "выполнено" : "\(mission.progress) из \(mission.goal)"
        return "\(mission.title). \(state). Награда \(mission.reward) говнокоинов"
    }
}

/// A slim progress bar.
private struct MissionBar: View {
    let fraction: Double
    let done: Bool

    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(Color.white.opacity(0.12))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: done ? [Palette.greenTop, Palette.greenBottom] : [Palette.goldTop, Palette.goldBottom],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: proxy.size.width * max(0, min(1, fraction)))
                }
        }
        .frame(height: 8)
        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1))
    }
}

/// «УРОВЕНЬ 3» with the experience bar towards the next one and what the next level pays.
struct MissionLevelBar: View {
    let progress: LevelProgress
    var gained = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("УРОВЕНЬ \(progress.level)")
                    .font(GameFont.title(20))
                    .foregroundStyle(Palette.goldTop)
                    .outlined(width: 1.5)
                Spacer(minLength: 6)
                if gained > 0 {
                    Text("+\(gained) опыта")
                        .font(GameFont.label(13))
                        .foregroundStyle(Palette.greenTop)
                }
                Text("\(progress.xpIntoLevel) / \(progress.xpForLevel)")
                    .font(GameFont.label(13).monospacedDigit())
                    .foregroundStyle(Palette.cream.opacity(0.8))
            }
            MissionBar(fraction: progress.fraction, done: false)
            HStack(spacing: 4) {
                Text("Уровень \(progress.level + 1) даст")
                CoinIcon(size: 14)
                Text("+\(PlayerLevel.reward(reaching: progress.level + 1))")
            }
            .font(GameFont.styled(.caption, weight: .bold))
            .foregroundStyle(Palette.cream.opacity(0.75))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.tray))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.gold.opacity(0.45), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Уровень \(progress.level), опыт \(progress.xpIntoLevel) из \(progress.xpForLevel)")
    }
}
