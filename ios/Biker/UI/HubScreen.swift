import SwiftUI

/// The main menu. The 3D bike cruises behind it, so the middle of the screen stays empty:
/// wallet and level on top, the sticker logo, then the big «ПОГНАЛИ» and a nav row at the bottom.
/// Everything here is static between taps; nothing animates continuously.
struct HubScreen: View {
    @ObservedObject var game: BikeGame
    @State private var showsSettings = false
    @State private var logoIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let secretPressSeconds = 1.5

    var body: some View {
        ZStack(alignment: .top) {
            MenuVignette()
            VStack(spacing: 10) {
                MenuHubTopBar(
                    level: game.profile.level,
                    coins: game.profile.coins,
                    settingsOn: showsSettings,
                    onSettings: { toggleSettings() }
                )
                logo
                chips
                Spacer(minLength: 12)
                MessageBanner(notices: game.notices)
                playButton
                navRow
                MenuAuthorsLine()
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
            if showsSettings {
                MenuSettingsCard(game: game, close: { toggleSettings() })
                    .padding(.top, 62)
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                    .zIndex(1)
            }
        }
        .onAppear {
            guard !logoIn else { return }
            if reduceMotion {
                logoIn = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { logoIn = true }
            }
        }
    }

    private var logo: some View {
        MenuLogo()
            .frame(maxWidth: 380, maxHeight: 190)
            .padding(.horizontal, 6)
            .scaleEffect(logoIn ? 1 : 0.8)
            .opacity(logoIn ? 1 : 0)
            .onLongPressGesture(minimumDuration: Self.secretPressSeconds, perform: { game.togglePerfOverlay() })
    }

    private var chips: some View {
        HStack(spacing: 8) {
            MenuStatChip(
                symbol: "trophy.fill",
                title: "РЕКОРД",
                value: game.profile.bestScore > 0 ? "\(game.profile.bestScore)" : "—"
            )
            if game.profile.dailyStreak > 0 {
                MenuStatChip(
                    symbol: "flame.fill",
                    title: "СЕРИЯ",
                    value: "\(game.profile.dailyStreak) дн.",
                    tint: Palette.neonPink
                )
            }
        }
    }

    private var playButton: some View {
        Button(action: { game.startRide() }) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("Погнали")
            }
        }
        .buttonStyle(ChunkyButtonStyle(kind: .gold, height: 76, fontSize: 34))
        .accessibilityLabel("Погнали, начать заезд")
    }

    private var navRow: some View {
        HStack(alignment: .top, spacing: 10) {
            MenuNavTile(title: "Гараж", symbol: "bicycle", colors: .red, action: { game.openGarage() })
            MenuNavTile(title: "Прокачка", symbol: "wrench.and.screwdriver.fill", colors: .violet, action: { game.openUpgrades() })
            MenuNavTile(title: "Задания", symbol: "checklist", colors: .green, action: { game.openMissions() })
            dailyTile
        }
        .padding(.top, 2)
    }

    private var dailyTile: some View {
        let ready = game.canClaimDaily
        let reward = game.dailyRewardPreview
        return MenuNavTile(
            title: "Награда дня",
            symbol: "gift.fill",
            colors: ready ? .gold : .steel,
            badge: ready ? "!" : nil,
            accessibility: ready ? "Забрать награду дня: \(reward) говнокоинов" : "Награда дня уже забрана, приходи завтра",
            action: { game.claimDaily() }
        )
    }

    private func toggleSettings() {
        if reduceMotion {
            showsSettings.toggle()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showsSettings.toggle() }
        }
    }
}

/// Level and wallet on the left, the settings button on the right.
private struct MenuHubTopBar: View {
    let level: Int
    let coins: Int
    let settingsOn: Bool
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            MenuLevelBadge(level: level)
            CoinBadge(amount: coins)
            Spacer(minLength: 4)
            RoundIconButton(
                symbol: settingsOn ? "xmark" : "gearshape.fill",
                label: settingsOn ? "Закрыть настройки" : "Настройки",
                action: onSettings
            )
        }
    }
}

/// The settings drop-down: sound on/off and who made this.
private struct MenuSettingsCard: View {
    @ObservedObject var game: BikeGame
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("НАСТРОЙКИ")
                .font(GameFont.label(18))
                .foregroundStyle(Palette.gold)
                .outlined(width: 1.5)
            Button(action: { game.toggleMute() }) {
                HStack(spacing: 10) {
                    Image(systemName: game.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 26)
                    Text(game.isMuted ? "Звук выключен" : "Звук включён")
                }
            }
            .buttonStyle(ChunkyButtonStyle(kind: game.isMuted ? .steel : .green, height: 50, fontSize: 16))
            .accessibilityLabel(game.isMuted ? "Включить звук" : "Выключить звук")
            VStack(alignment: .leading, spacing: 4) {
                Text(MenuArt.gameTitle)
                    .font(GameFont.styled(.subheadline, weight: .black))
                    .foregroundStyle(Palette.cream)
                Text(MenuArt.authors)
                    .font(GameFont.styled(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.cream.opacity(0.8))
            }
            .accessibilityElement(children: .combine)
        }
        .padding(16)
        .frame(maxWidth: 340)
        .background(PanelBackground(cornerRadius: 22, rim: Palette.neonPink.opacity(0.6)))
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
