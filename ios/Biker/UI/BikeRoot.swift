import SceneKit
import SwiftUI

/// The 3D world fills the screen; each phase puts its own SwiftUI layer over it.
struct BikeRoot: View {
    @StateObject private var game = BikeGame(defaults: .standard)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            WorldHost(world: game.world)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            screen
            ToastStack(notices: game.notices)
        }
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.xSmall ... .accessibility1)
        .animation(.easeInOut(duration: 0.22), value: game.phase)
        .onAppear(perform: { game.launch() })
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background: game.enterBackground()
            case .inactive: game.enterInactive()
            case .active: game.enterForeground()
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch game.phase {
        case .hub: HubScreen(game: game).transition(.opacity)
        case .garage: GarageScreen(game: game).transition(.opacity)
        case .upgrades: UpgradesScreen(game: game).transition(.opacity)
        case .riding: RideHUD(game: game, feed: game.feed)
        case .paused:
            ZStack {
                RideHUD(game: game, feed: game.feed).allowsHitTesting(false)
                PauseSheet(game: game).transition(.opacity)
            }
        case .over: GameOverSheet(game: game).transition(.opacity)
        }
    }
}

private struct WorldHost: UIViewRepresentable {
    let world: BikeWorld

    func makeUIView(context: Context) -> SCNView { world.view }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

/// Achievement and reward banners, over every screen.
private struct ToastStack: View {
    @ObservedObject var notices: NoticeCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            ForEach(notices.toasts) { toast in
                ToastView(toast: toast)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 64)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: notices.toasts)
    }
}

private struct ToastView: View {
    let toast: GameToast

    private var symbol: String {
        switch toast.tone {
        case .achievement: return "trophy.fill"
        case .reward: return "gift.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var header: String {
        switch toast.tone {
        case .achievement: return "ДОСТИЖЕНИЕ"
        case .reward: return "НАГРАДА"
        case .info: return "ГАРАЖ"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Palette.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(LinearGradient(
                    colors: [Palette.goldTop, Palette.goldBottom], startPoint: .top, endPoint: .bottom
                )))
                .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                Text(header)
                    .font(GameFont.styled(.caption2, weight: .heavy))
                    .foregroundStyle(Palette.gold)
                Text(toast.title)
                    .font(GameFont.styled(.headline, weight: .black))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(2)
                Text(toast.subtitle)
                    .font(GameFont.styled(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.cream.opacity(0.85))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: 420)
        .background(PanelBackground(cornerRadius: 20, rim: Palette.gold.opacity(0.7)))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
