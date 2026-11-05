import SwiftUI

/// A gold coin with a little pile on it, drawn in SwiftUI so it needs no texture.
struct CoinIcon: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(
                colors: [Palette.goldTop, Palette.goldBottom], startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            Circle().strokeBorder(Palette.goldEdge, lineWidth: max(1, size * 0.09))
            VStack(spacing: -size * 0.05) {
                Capsule().fill(Palette.poop).frame(width: size * 0.18, height: size * 0.13)
                Capsule().fill(Palette.poop).frame(width: size * 0.32, height: size * 0.15)
                Capsule().fill(Palette.poop).frame(width: size * 0.46, height: size * 0.17)
            }
            .offset(y: size * 0.03)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Palette.outline, lineWidth: 1.5))
        .accessibilityHidden(true)
    }
}

/// The wallet: coin and amount in a dark capsule.
struct CoinBadge: View {
    let amount: Int
    var label = "Говнокоинов"

    var body: some View {
        HStack(spacing: 6) {
            CoinIcon(size: 26)
            Text("\(amount)")
                .font(GameFont.label(19).monospacedDigit())
                .foregroundStyle(Palette.gold)
                .outlined(width: 1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .frame(minHeight: 44)
        .background(Capsule().fill(Palette.tray))
        .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.45), lineWidth: 1.5))
        .accessibilityElement()
        .accessibilityLabel("\(label): \(amount)")
    }
}

/// A round button with a symbol, for the corners of the screen.
struct RoundIconButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 48
    var tint: Color = Palette.cream
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .black))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(LinearGradient(
                    colors: [Palette.steelTop, Palette.steelBottom], startPoint: .top, endPoint: .bottom
                )))
                .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2.5))
                .overlay(Circle().inset(by: 3).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

/// A dimmed backdrop with one centred panel on it.
struct SheetPanel<Content: View>: View {
    var rim: Color = Palette.hairline
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Palette.dim.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) { content }
                    .padding(20)
                    .frame(maxWidth: 400)
                    .background(PanelBackground(cornerRadius: 28, rim: rim))
                    .padding(16)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehaviorIfAvailable()
        }
    }
}

extension View {
    /// Sheets fit on most phones; they only scroll at the largest text sizes.
    @ViewBuilder
    func scrollBounceBehaviorIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}

/// A big outlined headline, gold to orange.
struct BigTitle: View {
    let text: String
    var size: CGFloat = 34
    var colors: [Color] = [Palette.goldTop, Palette.goldBottom]

    var body: some View {
        Text(text)
            .font(GameFont.title(size))
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .outlined(width: max(2, size / 14))
            .shadow(color: .black.opacity(0.6), radius: 0, x: 0, y: size / 12)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Level dots for an upgrade track.
struct LevelPips: View {
    let level: Int
    let maxLevel: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(0, maxLevel), id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index < level ? AnyShapeStyle(LinearGradient(
                        colors: [Palette.goldTop, Palette.goldBottom], startPoint: .top, endPoint: .bottom
                    )) : AnyShapeStyle(Color.white.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(Palette.outline, lineWidth: 1))
                    .frame(height: 12)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Уровень \(level) из \(maxLevel)")
    }
}

/// The shop's one-line complaint, shown above the cards.
struct MessageBanner: View {
    @ObservedObject var notices: NoticeCenter

    var body: some View {
        if let message = notices.message {
            Text(message)
                .font(GameFont.styled(.subheadline, weight: .heavy))
                .foregroundStyle(Palette.cream)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Capsule().fill(Palette.redBottom.opacity(0.92)))
                .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
                .transition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

/// A small "number over caption" block used in results.
struct StatBlock: View {
    let value: String
    let title: String
    var tint: Color = Palette.gold

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(GameFont.label(22).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .outlined(width: 1.5)
            Text(title)
                .font(GameFont.styled(.caption, weight: .bold))
                .foregroundStyle(Palette.cream.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
        .accessibilityElement(children: .combine)
    }
}
