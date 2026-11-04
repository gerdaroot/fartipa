import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var model = GameModel()

    var body: some View {
        ZStack {
            BoardHost(board: model.board).ignoresSafeArea()
            if model.isReady {
                screen
            }
        }
        .sheet(item: $model.sharedImage) { shared in
            ActivityView(image: shared.image)
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch model.screen {
        case .menu: MenuScreen(model: model)
        case .levels: LevelsScreen(model: model)
        case .free: FreeDrawingScreen(model: model)
        case .trace: TraceScreen(model: model)
        case .result: ResultScreen(model: model)
        }
    }
}

struct BoardHost: UIViewRepresentable {
    let board: BoardView

    func makeUIView(context: Context) -> BoardView { board }
    func updateUIView(_ uiView: BoardView, context: Context) {}
}

struct ActivityView: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct MenuScreen: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Button("Рисовать", action: model.startFreeDrawing)
                .buttonStyle(LumpButtonStyle(big: true))
            Button("Обводить фигуры", action: model.goToLevels)
                .buttonStyle(LumpButtonStyle(big: true))
        }
        .frame(maxWidth: 340)
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }
}

struct LevelsScreen: View {
    @ObservedObject var model: GameModel
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        Sheet {
            Text("Обводи пальцем")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.gold)
            Text("Три звезды получит тот, кто не вылез за контур.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Palette.cream.opacity(0.86))
                .multilineTextAlignment(.center)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(Figure.all.enumerated()), id: \.offset) { index, figure in
                    levelButton(index: index, figure: figure)
                }
            }
            Button("Назад", action: model.goToMenu)
                .buttonStyle(LumpButtonStyle())
        }
    }

    private func levelButton(index: Int, figure: Figure) -> some View {
        let unlocked = Progress.isUnlocked(model.progress, index: index)
        let best = model.progress[figure.id] ?? 0
        return Button {
            model.startLevel(index)
        } label: {
            VStack(spacing: 4) {
                Text(unlocked ? figure.name : "Закрыто")
                Text(String(repeating: "★", count: best) + String(repeating: "☆", count: 3 - best))
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.gold)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(LumpButtonStyle())
        .disabled(!unlocked)
    }
}

struct TopBar<Center: View>: View {
    @ObservedObject var model: GameModel
    @ViewBuilder var center: Center

    var body: some View {
        HStack(spacing: 10) {
            Button("Меню", action: model.goToMenu)
                .buttonStyle(LumpButtonStyle())
                .frame(width: 76)
            Spacer(minLength: 0)
            center
            Spacer(minLength: 0)
            Button(model.isMuted ? "Без звука" : "Звук", action: model.toggleSound)
                .buttonStyle(LumpButtonStyle(gold: !model.isMuted))
                .frame(width: 92)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }
}

struct FreeDrawingScreen: View {
    @ObservedObject var model: GameModel
    private let sizes: [(name: String, radius: CGFloat)] = [("Мизинец", 7), ("Палец", 12), ("Кулак", 22)]

    var body: some View {
        VStack(spacing: 8) {
            TopBar(model: model) { EmptyView() }
            Spacer()
            HStack(spacing: 8) {
                ForEach(sizes, id: \.radius) { size in
                    Button(size.name) { model.selectFinger(radius: size.radius) }
                        .buttonStyle(LumpButtonStyle(gold: !model.isSmoothing && model.fingerRadius == size.radius))
                }
                Button("Загладить", action: model.toggleSmoothing)
                    .buttonStyle(LumpButtonStyle(gold: model.isSmoothing))
            }
            HStack(spacing: 8) {
                Button("Новая куча", action: model.newPile).buttonStyle(LumpButtonStyle())
                Button("Пук", action: model.fart).buttonStyle(LumpButtonStyle())
                Button("Сохранить", action: model.shareDrawing).buttonStyle(LumpButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

struct TraceScreen: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 8) {
            TopBar(model: model) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.currentFigure.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.cream)
                        .lineLimit(1)
                    Text("\(model.percent)%")
                        .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.gold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.sheet))
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Заново", action: model.retryLevel).buttonStyle(LumpButtonStyle())
                Button("Готово", action: model.finishLevel).buttonStyle(LumpButtonStyle(gold: true))
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

struct ResultScreen: View {
    @ObservedObject var model: GameModel

    var body: some View {
        Sheet {
            if let result = model.result {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Text("★").foregroundStyle(index < result.stars ? Palette.gold : Palette.cream.opacity(0.2))
                    }
                }
                .font(.system(size: 46))
                Text(TraceScoring.verdicts[result.stars])
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.gold)
                    .multilineTextAlignment(.center)
                Text(summary(result))
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.86))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 8) {
                Button("Ещё раз", action: model.retryLevel).buttonStyle(LumpButtonStyle())
                if model.hasNextLevel {
                    Button("Дальше", action: model.nextLevel)
                        .buttonStyle(LumpButtonStyle(gold: true))
                        .disabled(!model.canOpenNextLevel)
                }
            }
            Button("Сохранить картину", action: model.shareDrawing).buttonStyle(LumpButtonStyle())
            Button("К фигурам", action: model.goToLevels).buttonStyle(LumpButtonStyle())
        }
    }

    private func summary(_ result: TraceResult) -> String {
        let covered = Int((result.coverage * 100).rounded())
        let accurate = Int((result.accuracy * 100).rounded())
        return "\(result.score) очков: обведено \(covered)%, точность \(accurate)%"
    }
}
