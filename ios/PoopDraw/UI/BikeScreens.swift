import SceneKit
import SwiftUI

struct BikeRoot: View {
    @ObservedObject var game: BikeGame
    let onExit: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            WorldHost(world: game.world).ignoresSafeArea()
            switch game.phase {
            case .hub: BikeHub(game: game, onExit: onExit).transition(.opacity)
            case .garage: GarageScreen(game: game).transition(.opacity)
            case .riding: RideHUD(game: game)
            case .paused: PauseSheet(game: game).transition(.opacity)
            case .over: GameOverSheet(game: game).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: game.phase)
        .onChange(of: scenePhase) { phase in
            if phase != .active { game.pauseIfRiding() }
        }
    }
}

private struct WorldHost: UIViewRepresentable {
    let world: BikeWorld

    func makeUIView(context: Context) -> SCNView { world.view }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

/// A small gold coin with a pile on it, matching the ones on the road.
struct CoinBadge: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(uiImage: BikeTextures.coinImage)
                .resizable()
                .frame(width: 22, height: 22)
                .clipShape(Circle())
            Text("\(amount)")
                .font(GameFont.label(17).monospacedDigit())
                .foregroundStyle(Palette.gold)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 46)
        .background(Capsule().fill(Palette.tray))
        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
        .accessibilityElement()
        .accessibilityLabel("Говнокоинов: \(amount)")
    }
}

private struct BikeHub: View {
    @ObservedObject var game: BikeGame
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                RoundIconButton(symbol: "chevron.left", label: "В меню", action: onExit)
                Spacer()
                CoinBadge(amount: game.profile.coins)
            }
            VStack(spacing: 0) {
                Text("ПИЗДЕЦ СУПЕР")
                    .font(GameFont.title(25))
                    .foregroundStyle(Palette.cream)
                Text("ГОВНОБАЙКЕР")
                    .font(GameFont.title(44))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(LinearGradient(colors: [Palette.goldTop, Palette.goldBottom], startPoint: .top, endPoint: .bottom))
                Text("3Д")
                    .font(GameFont.title(58))
                    .foregroundStyle(Palette.gold)
            }
            .shadow(color: .black.opacity(0.75), radius: 6, x: 0, y: 3)
            .padding(.top, 20)
            Spacer()
            if game.profile.bestScore > 0 {
                Text("Рекорд: \(game.profile.bestScore)")
                    .font(GameFont.label(15))
                    .foregroundStyle(Palette.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.tray))
            }
            Button(action: game.startRide) {
                Label("Погнали", systemImage: "bolt.fill")
            }
            .buttonStyle(ChunkyButtonStyle(kind: .gold, height: 64, fontSize: 22))
            Button(action: game.openGarage) {
                Label("Гараж", systemImage: "wrench.and.screwdriver.fill")
            }
            .buttonStyle(ChunkyButtonStyle(height: 58, fontSize: 18))
        }
        .frame(maxWidth: 400)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
}

private struct RideHUD: View {
    @ObservedObject var game: BikeGame
    @State private var dragBase: Double?
    @State private var showHint = true
    @State private var splash = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(steering(width: proxy.size.width))
                Color(red: 1, green: 0.84, blue: 0.1)
                    .opacity(splash)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                VStack {
                    topBar
                    Spacer()
                    if showHint { hint }
                    speedometer
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
        }
        .onChange(of: game.splashCount) { _ in
            splash = 0.62
            withAnimation(.easeOut(duration: 0.5)) { splash = 0 }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            RoundIconButton(symbol: "pause.fill", label: "Пауза", action: game.pause)
            HStack(spacing: 3) {
                ForEach(0..<BikeRun.startingLives, id: \.self) { index in
                    Image(systemName: "heart.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(index < game.lives ? Color.red : Palette.cream.opacity(0.2))
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(Capsule().fill(Palette.tray))
            .accessibilityElement()
            .accessibilityLabel("Жизней: \(game.lives)")
            Spacer(minLength: 0)
            CoinBadge(amount: game.runCoins)
        }
    }

    private var hint: some View {
        Text("Веди пальцем влево и вправо. Жёлтое с неба — мимо, коины — в карман.")
            .font(GameFont.label(15))
            .foregroundStyle(Palette.cream)
            .multilineTextAlignment(.center)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.tray))
            .allowsHitTesting(false)
            .task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                withAnimation { showHint = false }
            }
    }

    private var speedometer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(game.speedKmh)")
                    .font(GameFont.title(38).monospacedDigit())
                    .foregroundStyle(Palette.gold)
                Text("км/ч").font(GameFont.label(13)).foregroundStyle(Palette.cream)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(game.score)")
                    .font(GameFont.title(28).monospacedDigit())
                    .foregroundStyle(Palette.cream)
                Text("очков").font(GameFont.label(13)).foregroundStyle(Palette.cream)
            }
        }
        .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
        .allowsHitTesting(false)
    }

    /// The bike follows the finger's sideways travel; a drag across most of the screen covers the road.
    private func steering(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let base = dragBase ?? game.steerTarget
                dragBase = base
                let travel = Double(value.translation.width / max(1, width * 0.72)) * BikeRun.roadHalfWidth * 2
                game.steer(to: min(3.4, max(-3.4, base + travel)))
            }
            .onEnded { _ in dragBase = nil }
    }
}

private struct PauseSheet: View {
    @ObservedObject var game: BikeGame

    var body: some View {
        Sheet {
            Text("Пауза")
                .font(GameFont.title(28))
                .foregroundStyle(Palette.gold)
            Button(action: game.resume) {
                Label("Ехать дальше", systemImage: "play.fill")
            }
            .buttonStyle(ChunkyButtonStyle(kind: .gold))
            Button(action: game.quitToHub) {
                Label("Закончить заезд", systemImage: "flag.fill")
            }
            .buttonStyle(ChunkyButtonStyle(fontSize: 17))
        }
    }
}

private struct GameOverSheet: View {
    @ObservedObject var game: BikeGame

    var body: some View {
        Sheet {
            Text("Тебя обоссали")
                .font(GameFont.title(28))
                .foregroundStyle(Palette.gold)
            if let result = game.result {
                if result.isRecord {
                    Text("Новый рекорд!")
                        .font(GameFont.label(16))
                        .foregroundStyle(Palette.cream)
                }
                HStack(spacing: 24) {
                    stat("\(result.score)", "очков")
                    stat("\(result.meters) м", "проехал")
                    stat("+\(result.coins)", "коинов")
                }
            }
            Button(action: game.startRide) {
                Label("Ещё заезд", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ChunkyButtonStyle(kind: .gold))
            HStack(spacing: 10) {
                Button(action: game.openGarage) {
                    Label("Гараж", systemImage: "wrench.and.screwdriver.fill")
                }
                .buttonStyle(ChunkyButtonStyle(height: 50, fontSize: 15))
                Button(action: game.quitToHub) {
                    Label("Выйти", systemImage: "chevron.left")
                }
                .buttonStyle(ChunkyButtonStyle(height: 50, fontSize: 15))
            }
        }
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(GameFont.title(22).monospacedDigit())
                .foregroundStyle(Palette.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(GameFont.body(13))
                .foregroundStyle(Palette.cream.opacity(0.85))
        }
    }
}
