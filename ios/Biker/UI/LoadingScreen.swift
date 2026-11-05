import SwiftUI

/// Covers the screen while the world compiles its shaders and uploads its textures, so the first
/// ride and the first garage visit do not stutter. Key art, the logo, a tip and the authors.
/// Static on purpose: only the system spinner moves.
struct LoadingScreen: View {
    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 16) {
                Spacer(minLength: 24)
                MenuLogo()
                    .frame(maxWidth: 400)
                    .padding(.horizontal, 12)
                Spacer(minLength: 24)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Palette.gold)
                    .scaleEffect(1.4)
                    .accessibilityHidden(true)
                Text("Разогреваем говно…")
                    .font(GameFont.styled(.headline, weight: .black))
                    .foregroundStyle(Palette.cream)
                    .outlined(width: 1.5)
                MenuTipCard(text: MenuTips.launchTip)
                MenuAuthorsLine()
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Загрузка")
    }

    /// Night road key art, cropped to fill; the colour beneath sets the layout size.
    private var backdrop: some View {
        Palette.night
            .overlay {
                Image(MenuArt.backdrop)
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
            }
            .clipped()
            .overlay { MenuVignette() }
            .ignoresSafeArea()
    }
}

/// «СОВЕТ» with one line of advice, on a dark plate.
private struct MenuTipCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Palette.piss)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("СОВЕТ")
                    .font(GameFont.label(12))
                    .foregroundStyle(Palette.gold)
                Text(text)
                    .font(GameFont.styled(.subheadline, weight: .bold))
                    .foregroundStyle(Palette.cream)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PanelBackground(cornerRadius: 18, rim: Palette.gold.opacity(0.5)))
        .accessibilityElement(children: .combine)
    }
}
