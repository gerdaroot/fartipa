import SwiftUI

/// One skin in the garage: rarity colours, a swatch of its colours and its shop state.
struct SkinCard: View {
    enum Stock: Equatable { case equipped, owned, forSale, locked }

    let info: SkinInfo
    let swatch: [RGB]
    let state: Stock
    let isFocused: Bool
    let action: () -> Void

    private static let width: CGFloat = 116
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }
    private var rarity: Color { Palette.rarity(info.rarity) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                swatchView
                Text(info.name)
                    .font(GameFont.styled(.footnote, weight: .heavy))
                    .foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(minHeight: 34)
                status
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(width: Self.width)
            .background(shape.fill(LinearGradient(
                colors: [rarity.opacity(0.55), Color.black.opacity(0.75)], startPoint: .top, endPoint: .bottom
            )))
            .overlay(shape.strokeBorder(isFocused ? Palette.gold : rarity.opacity(0.9), lineWidth: isFocused ? 3.5 : 2))
            .overlay(alignment: .topTrailing) { badge }
            .scaleEffect(isFocused ? 1.04 : 1)
            .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(info.name), \(info.rarity.title), \(stateText)")
        .accessibilityAddTraits(isFocused ? AccessibilityTraits([.isButton, .isSelected]) : AccessibilityTraits.isButton)
    }

    private var swatchView: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [swatchColor(0).opacity(0.95), swatchColor(1)], center: .topLeading,
                    startRadius: 2, endRadius: 46
                ))
                .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
                .frame(width: 58, height: 58)
            Circle()
                .fill(swatchColor(2))
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1.5))
                .shadow(color: swatchColor(2), radius: 6)
                .offset(x: 18, y: 18)
        }
        .frame(height: 64)
    }

    private func swatchColor(_ index: Int) -> Color {
        guard !swatch.isEmpty else { return Palette.poop }
        return Palette.color(swatch[min(index, swatch.count - 1)])
    }

    @ViewBuilder
    private var badge: some View {
        switch state {
        case .equipped:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .black))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Palette.outline, Palette.greenTop)
                .padding(5)
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Palette.cream)
                .padding(7)
        case .owned, .forSale:
            EmptyView()
        }
    }

    @ViewBuilder
    private var status: some View {
        switch state {
        case .equipped:
            statusText("НАДЕТО", Palette.greenTop)
        case .owned:
            statusText("ЕСТЬ", Palette.cream)
        case .locked:
            statusText("ДОСТИЖЕНИЕ", Palette.rarity(.epic))
        case .forSale:
            HStack(spacing: 4) {
                CoinIcon(size: 16)
                Text("\(info.price)")
                    .font(GameFont.label(15).monospacedDigit())
                    .foregroundStyle(Palette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(height: 22)
        }
    }

    private func statusText(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(GameFont.label(12))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(height: 22)
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
