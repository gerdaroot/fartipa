import SceneKit
import SwiftUI

/// Shows the loading screen at once, then builds the game on the next run-loop turn so the
/// heavy setup (scene, audio) never sits behind a blank launch screen.
struct BikeRoot: View {
    @StateObject private var holder = GameHolder()

    var body: some View {
        ZStack {
            if let game = holder.game {
                GameRoot(game: game)
            } else {
                LoadingScreen()
            }
        }
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.xSmall ... .accessibility1)
        .onAppear(perform: { holder.start() })
    }
}

@MainActor
private final class GameHolder: ObservableObject {
    /// Long enough for the loading screen to reach the display before the main thread gets busy.
    private static let firstFrameNanos: UInt64 = 60_000_000

    @Published private(set) var game: BikeGame?
    private var isStarting = false

    func start() {
        guard game == nil, !isStarting else { return }
        isStarting = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.firstFrameNanos)
            guard let self, self.game == nil else { return }
            let made = BikeGame(defaults: .standard)
            self.game = made
            made.launch()
        }
    }
}

/// The 3D world fills the screen; each phase puts its own SwiftUI layer over it.
private struct GameRoot: View {
    @ObservedObject var game: BikeGame
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            WorldHost(world: game.world)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            if !game.isLoading { screen }
            ToastStack(notices: game.notices)
            if game.isLoading {
                LoadingScreen().transition(.opacity)
            }
            PerfOverlay(perf: game.perf)
        }
        .background(ThreeFingerTap(action: { game.togglePerfOverlay() }))
        .animation(.easeInOut(duration: 0.22), value: game.phase)
        .animation(.easeInOut(duration: 0.3), value: game.isLoading)
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
        case .missions: MissionsScreen(game: game).transition(.opacity)
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
