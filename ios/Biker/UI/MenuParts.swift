import SwiftUI

/// The sticker logo bitmap «ПИЗДЕЦ СУПЕР КРУТОЙ БАЙКЕР 3Д». A plain image: no outlines or
/// glows are drawn at run time.
struct MenuLogo: View {
    var body: some View {
        Image(MenuArt.logo)
            .resizable()
            .interpolation(.high)
            .aspectRatio(MenuArt.logoAspect, contentMode: .fit)
            .accessibilityElement()
            .accessibilityLabel(MenuArt.gameTitle)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Darkens the top and bottom of the screen so menus read over the 3D world; the centre stays clear.
struct MenuVignette: View {
    var body: some View {
        Image(MenuArt.vignette)
            .resizable()
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// «Авторы: gerda, okurok51, yamoo, xanaxx55», always readable.
struct MenuAuthorsLine: View {
    var body: some View {
        Text(MenuArt.authors)
            .font(GameFont.styled(.caption, weight: .heavy))
            .foregroundStyle(Palette.cream.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

/// A small "icon, caption, value" chip, e.g. the record and the daily streak.
struct MenuStatChip: View {
    let symbol: String
    let title: String
    let value: String
    var tint: Color = Palette.gold

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(GameFont.styled(.caption, weight: .heavy))
                .foregroundStyle(Palette.cream.opacity(0.8))
            Text(value)
                .font(GameFont.styled(.headline, weight: .black).monospacedDigit())
                .foregroundStyle(Palette.cream)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(Capsule().fill(Palette.tray))
        .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }
}

/// The biker level in a violet shield-like disc.
struct MenuLevelBadge: View {
    let level: Int

    var body: some View {
        VStack(spacing: -2) {
            Text("УР")
                .font(GameFont.label(10))
                .foregroundStyle(Palette.cream.opacity(0.85))
            Text("\(level)")
                .font(GameFont.label(19).monospacedDigit())
                .foregroundStyle(Palette.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 46, height: 46)
        .background(Circle().fill(LinearGradient(
            colors: [Palette.violetTop, Palette.violetBottom], startPoint: .top, endPoint: .bottom
        )))
        .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2.5))
        .overlay(Circle().inset(by: 3.5).strokeBorder(Palette.neonPink.opacity(0.6), lineWidth: 1.5))
        .background(Circle().fill(Palette.violetEdge).offset(y: 3))
        .accessibilityElement()
        .accessibilityLabel("Уровень байкера \(level)")
    }
}

/// Colours of a nav tile.
struct MenuTileColors {
    let top: Color
    let bottom: Color
    let edge: Color
    let symbol: Color

    static let red = MenuTileColors(top: Palette.redTop, bottom: Palette.redBottom, edge: Palette.redEdge, symbol: Palette.cream)
    static let violet = MenuTileColors(
        top: Palette.violetTop, bottom: Palette.violetBottom, edge: Palette.violetEdge, symbol: Palette.cream
    )
    static let green = MenuTileColors(
        top: Palette.greenTop, bottom: Palette.greenBottom, edge: Palette.greenEdge, symbol: Palette.ink
    )
    static let gold = MenuTileColors(top: Palette.goldTop, bottom: Palette.goldBottom, edge: Palette.goldEdge, symbol: Palette.ink)
    static let steel = MenuTileColors(
        top: Palette.steelTop, bottom: Palette.steelBottom, edge: Palette.steelEdge, symbol: Palette.cream
    )
}

/// A square glossy icon plate on a solid lip with a caption under it, for the hub's bottom row.
/// The label is the symbol image; the plate sinks into its lip when pressed.
struct MenuTileStyle: ButtonStyle {
    let title: String
    let colors: MenuTileColors
    var badge: String? = nil

    private let lip: CGFloat = 5
    private let plateHeight: CGFloat = 58
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 5) {
            plate(configuration.label, pressed: configuration.isPressed)
            Text(title)
                .font(GameFont.label(13))
                .foregroundStyle(Palette.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .outlined(width: 1.5)
        }
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }

    private func plate(_ label: Configuration.Label, pressed: Bool) -> some View {
        label
            .font(.system(size: 25, weight: .black))
            .foregroundStyle(colors.symbol)
            .frame(maxWidth: .infinity, minHeight: plateHeight)
            .background(shape.fill(LinearGradient(colors: [colors.top, colors.bottom], startPoint: .top, endPoint: .bottom)))
            .overlay(alignment: .top) {
                shape.fill(Color.white.opacity(0.22)).frame(height: plateHeight * 0.4).padding(4)
            }
            .overlay(shape.strokeBorder(Palette.outline, lineWidth: 2.5))
            .offset(y: pressed ? lip : 0)
            .background(shape.fill(colors.edge).overlay(shape.strokeBorder(Palette.outline, lineWidth: 2.5)).offset(y: lip))
            .padding(.bottom, lip)
            .overlay(alignment: .topTrailing) { badgeView }
    }

    @ViewBuilder
    private var badgeView: some View {
        if let badge {
            Text(badge)
                .font(GameFont.label(12))
                .foregroundStyle(Palette.cream)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(minWidth: 22, minHeight: 22)
                .background(Capsule().fill(Palette.danger))
                .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
                .offset(x: 6, y: -7)
                .accessibilityHidden(true)
        }
    }
}

/// One nav tile: a symbol on a glossy plate with a caption.
struct MenuNavTile: View {
    let title: String
    let symbol: String
    let colors: MenuTileColors
    var badge: String? = nil
    var accessibility: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(MenuTileStyle(title: title, colors: colors, badge: badge))
        .frame(maxWidth: .infinity)
        .accessibilityLabel(accessibility ?? title)
    }
}
