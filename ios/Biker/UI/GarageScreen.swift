import SwiftUI

/// The skin shop: the bike turns in the 3D showcase above, cards below preview, buy and equip.
struct GarageScreen: View {
    @ObservedObject var game: BikeGame
    @State private var tab = SkinKind.bike
    @State private var selectedId: String?

    private var items: [SkinInfo] { GarageCatalog.items(of: tab) }

    private var selected: SkinInfo? {
        selectedId.flatMap { Catalog.info(id: $0) }
    }

    var body: some View {
        VStack(spacing: 10) {
            ScreenTopBar(title: "Гараж", coins: game.profile.coins, back: { game.goHub() })
            Spacer(minLength: 0)
            if let selected { SkinHeadline(info: selected) }
            MessageBanner(notices: game.notices)
            VStack(spacing: 12) {
                GarageTabs(tab: $tab)
                cards
                actionButton
            }
            .padding(12)
            .background(PanelBackground(cornerRadius: 26))
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .onAppear { select(equippedId(of: tab)) }
        .onChange(of: tab) { kind in select(equippedId(of: kind)) }
    }

    private var cards: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items, id: \.id) { info in
                        SkinCard(
                            info: info,
                            swatch: GarageCatalog.swatch(id: info.id),
                            state: state(of: info),
                            isFocused: info.id == selectedId
                        ) { select(info.id) }
                        .id(info.id)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .onChange(of: selectedId) { id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo(id, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let info = selected {
            switch state(of: info) {
            case .equipped:
                Button {} label: { Label("Надето", systemImage: "checkmark.seal.fill") }
                    .buttonStyle(ChunkyButtonStyle(kind: .steel, height: 54, fontSize: 18))
                    .disabled(true)
            case .owned:
                Button { game.tapSkin(id: info.id) } label: { Label("Надеть", systemImage: "tshirt.fill") }
                    .buttonStyle(ChunkyButtonStyle(kind: .green, height: 54, fontSize: 20))
            case .forSale:
                Button { game.tapSkin(id: info.id) } label: {
                    HStack(spacing: 8) {
                        Text("Купить за")
                        CoinIcon(size: 24)
                        Text("\(info.price)").monospacedDigit()
                    }
                }
                .buttonStyle(ChunkyButtonStyle(kind: .gold, height: 54, fontSize: 20))
                .accessibilityLabel("Купить за \(info.price) говнокоинов")
            case .locked:
                Button { game.tapSkin(id: info.id) } label: { Label(game.lockText(info), systemImage: "lock.fill") }
                    .buttonStyle(ChunkyButtonStyle(kind: .steel, height: 54, fontSize: 15))
            }
        }
    }

    private func state(of info: SkinInfo) -> SkinCard.Stock {
        if game.profile.isSelected(id: info.id) { return .equipped }
        if game.profile.owns(id: info.id) { return .owned }
        return info.unlockedBy == nil ? .forSale : .locked
    }

    private func equippedId(of kind: SkinKind) -> String? {
        switch kind {
        case .bike: return game.profile.bikeId
        case .rider: return game.profile.riderId
        case .trail: return game.profile.trailId
        }
    }

    private func select(_ id: String?) {
        guard let id else { return }
        selectedId = id
        game.preview(id: id)
    }
}

/// Lists and colour swatches for the garage cards.
enum GarageCatalog {
    static func items(of kind: SkinKind) -> [SkinInfo] {
        switch kind {
        case .bike: return Catalog.bikes.map { $0.info }
        case .rider: return Catalog.riders.map { $0.info }
        case .trail: return Catalog.trails.map { $0.info }
        }
    }

    static func swatch(id: String) -> [RGB] {
        if let bike = Catalog.bike(id: id) { return [bike.style.primary, bike.style.secondary, bike.style.glow] }
        if let rider = Catalog.rider(id: id) { return [rider.style.jacket, rider.style.helmet, rider.style.visor] }
        if let trail = Catalog.trail(id: id) { return [trail.style.primary, trail.style.secondary] }
        return []
    }
}

/// The back button, the screen name and the wallet.
struct ScreenTopBar: View {
    let title: String
    let coins: Int
    let back: () -> Void

    var body: some View {
        HStack {
            RoundIconButton(symbol: "chevron.left", label: "Назад", action: back)
            Spacer()
            BigTitle(text: title.uppercased(), size: 30)
            Spacer()
            CoinBadge(amount: coins)
        }
    }
}

private struct GarageTabs: View {
    @Binding var tab: SkinKind

    var body: some View {
        HStack(spacing: 6) {
            button("Байки", "bicycle", .bike)
            button("Прикиды", "person.fill", .rider)
            button("Выхлоп", "wind", .trail)
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.45)))
    }

    private func button(_ title: String, _ symbol: String, _ kind: SkinKind) -> some View {
        let isOn = tab == kind
        return Button {
            tab = kind
        } label: {
            Label(title, systemImage: symbol)
                .font(GameFont.styled(.subheadline, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isOn ? Palette.ink : Palette.cream)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(isOn
                    ? AnyShapeStyle(LinearGradient(colors: [Palette.goldTop, Palette.goldBottom], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.clear)))
                .overlay(Capsule().strokeBorder(isOn ? Palette.outline : Color.clear, lineWidth: 2))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The name of the skin being previewed, with its rarity.
private struct SkinHeadline: View {
    let info: SkinInfo

    var body: some View {
        VStack(spacing: 4) {
            Text(info.rarity.title.uppercased())
                .font(GameFont.styled(.caption, weight: .black))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Palette.rarity(info.rarity)))
                .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1.5))
            Text(info.name)
                .font(GameFont.styled(.title2, weight: .black))
                .foregroundStyle(Palette.cream)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .outlined(width: 2)
        }
        .accessibilityElement(children: .combine)
    }
}
