import SwiftUI

/// The main menu over the bike cruising an empty road.
struct HubScreen: View {
    @ObservedObject var game: BikeGame

    var body: some View {
        VStack(spacing: 12) {
            topBar
            HubTitle(onSecret: { game.togglePerfOverlay() })
                .padding(.top, 8)
            if game.profile.bestScore > 0 { record }
            Spacer(minLength: 8)
            if game.canClaimDaily { dailyButton }
            MessageBanner(notices: game.notices)
            buttons
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var topBar: some View {
        HStack {
            RoundIconButton(
                symbol: game.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: game.isMuted ? "Включить звук" : "Выключить звук",
                action: { game.toggleMute() }
            )
            Spacer()
            CoinBadge(amount: game.profile.coins)
        }
    }

    private var record: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill").foregroundStyle(Palette.gold)
            Text("РЕКОРД  \(game.profile.bestScore)")
                .font(GameFont.styled(.headline, weight: .black).monospacedDigit())
                .foregroundStyle(Palette.cream)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(Palette.tray))
        .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.5), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Рекорд: \(game.profile.bestScore) очков")
    }

    private var dailyButton: some View {
        Button(action: { game.claimDaily() }) {
            HStack(spacing: 10) {
                Image(systemName: "gift.fill")
                Text("Ежедневный подгон  +\(game.dailyRewardPreview)")
            }
        }
        .buttonStyle(ChunkyButtonStyle(kind: .green, height: 52, fontSize: 17))
        .accessibilityLabel("Забрать ежедневный подгон: \(game.dailyRewardPreview) говнокоинов")
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button(action: { game.startRide() }) {
                Label("Погнали!", systemImage: "flame.fill")
            }
            .buttonStyle(ChunkyButtonStyle(kind: .gold, height: 72, fontSize: 30))
            HStack(spacing: 10) {
                Button(action: { game.openGarage() }) {
                    Label("Гараж", systemImage: "bicycle")
                }
                .buttonStyle(ChunkyButtonStyle(kind: .red, height: 58, fontSize: 19))
                Button(action: { game.openUpgrades() }) {
                    Label("Прокачка", systemImage: "wrench.and.screwdriver.fill")
                }
                .buttonStyle(ChunkyButtonStyle(kind: .red, height: 58, fontSize: 19))
            }
        }
    }
}

/// «ПИЗДЕЦ КРУТОЙ БАЙКЕР 3Д» as a stacked sticker logo.
/// The logo is drawn once into a single texture (`drawingGroup`), so its outlines, gradients and
/// blurred glows are not re-rendered while it pulses; the pulse only scales the finished picture.
private struct HubTitle: View {
    let onSecret: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    /// Room for the glows inside the texture, which clips at its edges.
    private static let glowRoom: CGFloat = 20
    private static let secretPressSeconds = 1.5

    var body: some View {
        logo
            .padding(Self.glowRoom)
            .drawingGroup()
            .padding(-Self.glowRoom)
            .scaleEffect(pulse ? 1.03 : 1)
            .accessibilityElement()
            .accessibilityLabel("Пиздец крутой байкер 3Д")
            .accessibilityAddTraits(.isHeader)
            .onLongPressGesture(minimumDuration: Self.secretPressSeconds, perform: onSecret)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            }
    }

    private var logo: some View {
        VStack(spacing: -6) {
            Text("ПИЗДЕЦ КРУТОЙ")
                .font(GameFont.title(28))
                .foregroundStyle(Palette.cream)
                .outlined(width: 2.5)
                .rotationEffect(.degrees(-3))
            BigTitle(text: "БАЙКЕР", size: 64, colors: [Palette.goldTop, Palette.goldBottom])
                .lineLimit(1)
            Text("3Д")
                .font(GameFont.title(70))
                .foregroundStyle(LinearGradient(
                    colors: [Palette.redTop, Palette.redBottom], startPoint: .top, endPoint: .bottom
                ))
                .outlined(width: 4)
                .shadow(color: Palette.redTop.opacity(0.6), radius: 14)
                .rotationEffect(.degrees(4))
        }
        .shadow(color: .black.opacity(0.7), radius: 8, x: 0, y: 4)
    }
}
