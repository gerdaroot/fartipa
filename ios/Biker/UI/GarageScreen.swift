import SwiftUI

/// The shop: the bike turns in the 3D world above, cards below buy and equip.
struct GarageScreen: View {
    @ObservedObject var game: BikeGame
    @State private var tab = ShopKind.bike

    private var items: [ShopItem] { tab == .bike ? Shop.bikes : Shop.riders }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                RoundIconButton(symbol: "chevron.left", label: "Назад", action: game.closeGarage)
                Spacer()
                CoinBadge(amount: game.profile.coins)
            }
            Spacer()
            if let message = game.message {
                Text(message)
                    .font(GameFont.label(15))
                    .foregroundStyle(Palette.cream)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.tray))
            }
            VStack(spacing: 12) {
                tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items, id: \.id) { item in
                            ShopCard(item: item, profile: game.profile) { game.tapShopItem(item) }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.tray))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            tabButton("Байк", kind: .bike)
            tabButton("Прикид", kind: .rider)
        }
    }

    private func tabButton(_ title: String, kind: ShopKind) -> some View {
        let selected = tab == kind
        return Button {
            tab = kind
        } label: {
            Text(title)
                .font(GameFont.label(15))
                .foregroundStyle(selected ? Palette.ink : Palette.cream)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(selected ? Palette.gold : Palette.cream.opacity(0.08)))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ShopCard: View {
    let item: ShopItem
    let profile: Profile
    let action: () -> Void

    private var owned: Bool { profile.owns(item) }
    private var selected: Bool { profile.isSelected(item) }
    private var card: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(item.name)
                    .font(GameFont.label(15))
                    .foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 40)
                status
            }
            .frame(width: 112)
            .padding(.vertical, 12)
            .background(card.fill(Palette.brownBottom.opacity(0.85)))
            .overlay(card.strokeBorder(selected ? Palette.gold : Palette.hairline, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(PressScaleStyle())
    }

    @ViewBuilder
    private var status: some View {
        if selected {
            Label("Надето", systemImage: "checkmark.circle.fill")
                .font(GameFont.label(13))
                .foregroundStyle(Palette.gold)
        } else if owned {
            Text("Надеть")
                .font(GameFont.label(13))
                .foregroundStyle(Palette.cream)
        } else {
            HStack(spacing: 4) {
                Image(uiImage: BikeTextures.coinImage)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
                Text("\(item.price)")
                    .font(GameFont.label(14).monospacedDigit())
                    .foregroundStyle(profile.coins >= item.price ? Palette.gold : Palette.cream.opacity(0.5))
            }
        }
    }
}
