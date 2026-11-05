import SwiftUI

struct MenuScreen: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                SoundButton(model: model)
            }
            Spacer()
            Button(action: model.goToBike) {
                Label("Говнобайкер 3Д", systemImage: "bolt.fill")
            }
            .buttonStyle(ChunkyButtonStyle(kind: .gold, height: 64, fontSize: 22))

            Button(action: model.startFreeDrawing) {
                Label("Рисовать", systemImage: "hand.draw.fill")
            }
            .buttonStyle(ChunkyButtonStyle(height: 60, fontSize: 18))

            Button(action: model.goToLevels) {
                HStack(spacing: 10) {
                    Label("Обводить фигуры", systemImage: "scribble.variable")
                    Spacer(minLength: 4)
                    Label("\(model.totalStars)/\(model.maxStars)", systemImage: "star.fill")
                        .font(GameFont.label(15))
                        .foregroundStyle(Palette.gold)
                }
            }
            .buttonStyle(ChunkyButtonStyle(height: 60, fontSize: 18))

            Text("Авторы: gerda, okurok51, yamoo")
                .font(GameFont.body(13))
                .foregroundStyle(Palette.cream)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.tray))
                .padding(.top, 6)
        }
        .frame(maxWidth: 380)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

struct LevelsScreen: View {
    @ObservedObject var model: GameModel
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        Sheet {
            HStack {
                RoundIconButton(symbol: "chevron.left", label: "Назад", size: 40, action: model.goToMenu)
                Spacer()
                Text("Обводи пальцем")
                    .font(GameFont.title(22))
                    .foregroundStyle(Palette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            Text("Чем точнее контур, тем больше звёзд. Одна звезда открывает следующую фигуру.")
                .font(GameFont.body(14))
                .foregroundStyle(Palette.cream.opacity(0.85))
                .multilineTextAlignment(.center)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(Figure.all.enumerated()), id: \.offset) { index, figure in
                    LevelCard(
                        figure: figure,
                        unlocked: Progress.isUnlocked(model.progress, index: index),
                        stars: model.progress[figure.id] ?? 0
                    ) {
                        model.startLevel(index)
                    }
                }
            }
        }
    }
}

private struct LevelCard: View {
    let figure: Figure
    let unlocked: Bool
    let stars: Int
    let action: () -> Void

    private var card: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    FigureShape(figure: figure)
                        .stroke(
                            unlocked ? Palette.cream : Palette.cream.opacity(0.18),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 58, height: 58)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Palette.cream.opacity(0.75))
                    }
                }
                Text(figure.name)
                    .font(GameFont.label(14))
                    .foregroundStyle(unlocked ? Palette.cream : Palette.cream.opacity(0.45))
                    .lineLimit(1)
                StarRow(filled: stars)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(card.fill(Palette.brownBottom.opacity(unlocked ? 0.85 : 0.35)))
            .overlay(card.strokeBorder(stars == 3 ? Palette.gold : Palette.hairline, lineWidth: stars == 3 ? 2 : 1))
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!unlocked)
    }
}

struct SoundButton: View {
    @ObservedObject var model: GameModel

    var body: some View {
        RoundIconButton(
            symbol: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            label: model.isMuted ? "Включить звук" : "Выключить звук",
            action: model.toggleSound
        )
    }
}
