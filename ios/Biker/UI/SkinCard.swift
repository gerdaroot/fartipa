import SwiftUI

/// One skin in the garage: a rarity frame and ribbon, a swatch of its colours and a clear shop
/// state (price, owned, equipped, locked). Solid offset lip, no blurred shadows.
struct SkinCard: View {
    enum Stock: Equatable { case equipped, owned, forSale, locked }

    let info: SkinInfo
    let swatch: [RGB]
    let state: Stock
    let isFocused: Bool
    let action: () -> Void

    private static let width: CGFloat = 118
    private static let lip: CGFloat = 4
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }
    private var rarity: Color { Palette.rarity(info.rarity) }
    private var edge: Color { Palette.rarityEdge(info.rarity) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ribbon
                swatchView
                Text(info.name)
                    .font(GameFont.styled(.footnote, weight: .heavy))
                    .foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(minHeight: 34)
                    .padding(.horizontal, 6)
                status
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
            }
            .frame(width: Self.width)
            .background(shape.fill(LinearGradient(
                colors: [edge, Palette.night], startPoint: .top, endPoint: .bottom
            )))
            .clipShape(shape)
            .overlay(shape.inset(by: 3).strokeBorder(rarity.opacity(0.85), lineWidth: 2))
            .overlay(shape.strokeBorder(isFocused ? Palette.gold : Palette.outline, lineWidth: isFocused ? 3.5 : 2.5))
            .background(shape.fill(isFocused ? Palette.goldEdge : edge).offset(y: Self.lip))
            .padding(.bottom, Self.lip)
            .overlay(alignment: .topTrailing) { badge }
            .scaleEffect(isFocused ? 1.05 : 1)
            .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(info.name), \(info.rarity.title), \(stateText)")
        .accessibilityAddTraits(isFocused ? AccessibilityTraits([.isButton, .isSelected]) : AccessibilityTraits.isButton)
    }

    /// The rarity name across the top of the card.
    private var ribbon: some View {
        Text(info.rarity.title.uppercased())
            .font(GameFont.label(10))
            .foregroundStyle(info.rarity == .common ? Palette.ink : Palette.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 20)
            .background(LinearGradient(colors: [rarity, rarity.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.outline).frame(height: 2) }
    }

    private var swatchView: some View {
        ZStack {
            Circle()
                .fill(rarity.opacity(0.18))
                .frame(width: 72, height: 72)
            Circle()
                .fill(RadialGradient(
                    colors: [swatchColor(0).opacity(0.95), swatchColor(1)], center: .topLeading,
                    startRadius: 2, endRadius: 46
                ))
                .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
                .overlay(alignment: .top) {
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: 26, height: 9).offset(x: -8, y: 7)
                }
                .frame(width: 58, height: 58)
            Circle()
                .fill(swatchColor(2))
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1.5))
                .offset(x: 20, y: 20)
            if state == .locked {
                Circle().fill(Color.black.opacity(0.45)).frame(width: 58, height: 58)
                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Palette.cream)
            }
        }
        .frame(height: 74)
    }

    private func swatchColor(_ index: Int) -> Color {
        guard !swatch.isEmpty else { return Palette.poop }
        return Palette.color(swatch[min(index, swatch.count - 1)])
    }

    @ViewBuilder
    private var badge: some View {
        if state == .equipped {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .black))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Palette.outline, Palette.greenTop)
                .offset(x: 6, y: -6)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch state {
        case .equipped:
            pill(Text("НАДЕТО").foregroundStyle(Palette.ink), fill: Palette.greenTop)
        case .owned:
            pill(Text("В ГАРАЖЕ").foregroundStyle(Palette.cream), fill: Palette.steelTop)
        case .locked:
            pill(Text("ДОСТИЖЕНИЕ").foregroundStyle(Palette.cream), fill: Palette.violetBottom)
        case .forSale:
            pill(
                HStack(spacing: 4) {
                    CoinIcon(size: 15)
                    Text("\(info.price)").monospacedDigit().foregroundStyle(Palette.gold)
                },
                fill: Color.black.opacity(0.55)
            )
        }
    }

    private func pill<Content: View>(_ content: Content, fill: Color) -> some View {
        content
            .font(GameFont.label(13))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1.5))
    }

    private var stateText: String {
        switch state {
        case .equipped: return "надето"
        case .owned: return "есть, можно надеть"
        case .forSale: return "цена \(info.price) говнокоинов"
        case .locked: return "даётся за достижение"
        }
    }
}
