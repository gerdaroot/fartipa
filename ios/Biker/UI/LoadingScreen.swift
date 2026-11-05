import SwiftUI

/// Covers the screen while the world compiles its shaders and uploads its textures, so the first
/// ride and the first garage visit do not stutter. Static on purpose: only the system spinner moves.
struct LoadingScreen: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.steelBottom, Palette.panelBottom, Color.black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                BigTitle(text: "ПИЗДЕЦ КРУТОЙ\nБАЙКЕР 3Д", size: 40)
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Palette.gold)
                    .scaleEffect(1.4)
                Text("Разогреваем говно…")
                    .font(GameFont.styled(.headline, weight: .heavy))
                    .foregroundStyle(Palette.cream.opacity(0.85))
                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Загрузка")
    }
}
