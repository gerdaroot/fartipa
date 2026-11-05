import SwiftUI

/// «Прокачка»: every upgrade track with its level pips, effect now and next, and the price.
struct UpgradesScreen: View {
    @ObservedObject var game: BikeGame

    var body: some View {
        VStack(spacing: 10) {
            ScreenTopBar(title: "Прокачка", coins: game.profile.coins, back: { game.goHub() })
            // Leaves the showcase bike visible above the list.
            Spacer(minLength: 150)
            MessageBanner(notices: game.notices)
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(UpgradeTrack.allCases, id: \.self) { track in
                        UpgradeRow(
                            track: track,
                            level: game.profile.level(of: track),
                            price: game.profile.nextPrice(of: track),
                            coins: game.profile.coins
                        ) { game.buyUpgrade(track) }
                    }
                }
                .padding(10)
            }
            .background(PanelBackground(cornerRadius: 26))
            .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

private struct UpgradeRow: View {
    let track: UpgradeTrack
    let level: Int
    let price: Int?
    let coins: Int
    let buy: () -> Void

    private var info: UpgradeInfo { track.info }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: UpgradeLook.symbol(track))
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Palette.ink)
                .frame(width: 50, height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LinearGradient(
                    colors: [Palette.goldTop, Palette.goldBottom], startPoint: .top, endPoint: .bottom
                )))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(info.name.uppercased())
                    .font(GameFont.styled(.headline, weight: .black))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(info.description)
                    .font(GameFont.styled(.caption, weight: .semibold))
                    .foregroundStyle(Palette.cream.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                LevelPips(level: level, maxLevel: info.maxLevel)
                effect
            }
            buyButton
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }

    private var effect: some View {
        HStack(spacing: 4) {
            Text(track.effectText(level: level))
                .foregroundStyle(Palette.cream)
            if price != nil {
                Image(systemName: "arrow.right")
                    .foregroundStyle(Palette.gold)
                    .accessibilityHidden(true)
                Text(track.effectText(level: level + 1))
                    .foregroundStyle(Palette.greenTop)
            }
        }
        .font(GameFont.styled(.caption, weight: .heavy))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(effectLabel)
    }

    private var effectLabel: String {
        let now = track.effectText(level: level)
        guard price != nil else { return "Сейчас: \(now), максимум" }
        return "Сейчас: \(now), после улучшения: \(track.effectText(level: level + 1))"
    }

    @ViewBuilder
    private var buyButton: some View {
        if let price {
            Button(action: buy) {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 18, weight: .black))
                    HStack(spacing: 3) {
                        CoinIcon(size: 14)
                        Text("\(price)").monospacedDigit()
                    }
                }
            }
            .buttonStyle(ChunkyButtonStyle(kind: price <= coins ? .gold : .steel, height: 56, fontSize: 15))
            .frame(width: 96)
            .accessibilityLabel("Улучшить \(info.name) за \(price) говнокоинов")
        } else {
            Text("МАКС")
                .font(GameFont.label(17))
                .foregroundStyle(Palette.greenTop)
                .outlined(width: 1.5)
                .frame(width: 96, height: 56)
                .accessibilityLabel("Прокачано до максимума")
        }
    }
}

/// An SF Symbol per track.
enum UpgradeLook {
    static func symbol(_ track: UpgradeTrack) -> String {
        switch track {
        case .engine: return "engine.combustion.fill"
        case .handling: return "steeringwheel"
        case .tires: return "circle.circle.fill"
        case .magnet: return "dollarsign.circle.fill"
        case .armor: return "shield.lefthalf.filled"
        case .shield: return "leaf.fill"
        case .tank: return "fuelpump.fill"
        case .beans: return "flame.fill"
        case .piggy: return "banknote.fill"
        case .combo: return "bolt.fill"
        case .luck: return "gift.fill"
        case .raincoat: return "umbrella.fill"
        }
    }
}
