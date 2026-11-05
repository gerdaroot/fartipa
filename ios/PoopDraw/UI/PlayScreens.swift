import SwiftUI

struct FreeDrawingScreen: View {
    @ObservedObject var model: GameModel
    private static let sizes: [FingerSize] = [
        FingerSize(name: "Мизинец", radius: 7, dot: 8),
        FingerSize(name: "Палец", radius: 12, dot: 14),
        FingerSize(name: "Кулак", radius: 22, dot: 23),
    ]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                RoundIconButton(symbol: "chevron.left", label: "В меню", action: model.goToMenu)
                Spacer()
                RoundIconButton(symbol: "square.and.arrow.up", label: "Сохранить картину", action: model.shareDrawing)
                SoundButton(model: model)
            }
            Spacer()
            HStack {
                Spacer()
                Button(action: model.fart) {
                    VStack(spacing: 1) {
                        Image(systemName: "wind").font(.system(size: 25, weight: .bold))
                        Text("Пук").font(GameFont.label(14))
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(width: 74, height: 74)
                    .background(Circle().fill(LinearGradient(
                        colors: [Palette.goldTop, Palette.goldBottom], startPoint: .top, endPoint: .bottom
                    )))
                    .background(Circle().fill(Palette.goldEdge).offset(y: 5))
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.45), radius: 7, x: 0, y: 6)
                }
                .buttonStyle(PressScaleStyle())
            }
            toolTray
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private var toolTray: some View {
        HStack(spacing: 4) {
            ForEach(Self.sizes) { size in
                ToolTile(title: size.name, selected: !model.isSmoothing && model.fingerRadius == size.radius) {
                    model.selectFinger(radius: size.radius)
                } icon: { color in
                    Circle().fill(color).frame(width: size.dot, height: size.dot)
                }
            }
            ToolTile(title: "Загладить", selected: model.isSmoothing, action: model.toggleSmoothing) { color in
                Image(systemName: "hand.raised.fill").font(.system(size: 19)).foregroundStyle(color)
            }
            Rectangle().fill(Palette.hairline).frame(width: 1, height: 38)
            ToolTile(title: "Новая куча", selected: false, action: model.newPile) { color in
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 19, weight: .bold)).foregroundStyle(color)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.tray))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

private struct FingerSize: Identifiable {
    let name: String
    let radius: CGFloat
    let dot: CGFloat
    var id: CGFloat { radius }
}

private struct ToolTile<Icon: View>: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let icon: (Color) -> Icon

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon(selected ? Palette.ink : Palette.cream).frame(height: 26)
                Text(title)
                    .font(GameFont.label(11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(selected ? Palette.ink : Palette.cream)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(selected ? Palette.gold : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct TraceScreen: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                RoundIconButton(symbol: "chevron.left", label: "К фигурам", action: model.goToLevels)
                progressPill
                SoundButton(model: model)
            }
            Spacer()
            HStack(spacing: 10) {
                Button(action: model.retryLevel) {
                    Label("Заново", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(ChunkyButtonStyle(fontSize: 17))
                Button(action: model.finishLevel) {
                    Label("Готово", systemImage: "checkmark")
                }
                .buttonStyle(ChunkyButtonStyle(kind: .gold, fontSize: 19))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private var progressPill: some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.currentFigure.name)
                    .font(GameFont.label(14))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("\(model.percent)%")
                    .font(GameFont.label(16).monospacedDigit())
                    .foregroundStyle(Palette.gold)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.cream.opacity(0.15))
                    Capsule().fill(Palette.gold)
                        .frame(width: proxy.size.width * CGFloat(model.percent) / 100)
                        .animation(.easeOut(duration: 0.12), value: model.percent)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(Capsule().fill(Palette.tray))
        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

struct ResultScreen: View {
    @ObservedObject var model: GameModel
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Sheet {
            if let result = model.result {
                resultHeader(result)
                Meter(title: "Обведено", value: result.coverage)
                Meter(title: "Точность", value: result.accuracy)
            }
            HStack(spacing: 10) {
                Button(action: model.retryLevel) {
                    Label("Ещё раз", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(ChunkyButtonStyle(height: 52, fontSize: 16))
                if model.hasNextLevel {
                    Button(action: model.nextLevel) {
                        Label("Дальше", systemImage: "arrow.right")
                    }
                    .buttonStyle(ChunkyButtonStyle(kind: .gold, height: 52, fontSize: 17))
                    .disabled(!model.canOpenNextLevel)
                }
            }
            HStack(spacing: 18) {
                Button(action: model.goToLevels) { Text("К фигурам").fixedSize() }
                Button(action: model.shareDrawing) { Text("Сохранить картину").fixedSize() }
            }
            .font(GameFont.label(14))
            .foregroundStyle(Palette.cream)
            .buttonStyle(PressScaleStyle())
            .padding(.top, 2)
        }
        .onAppear { appeared = true }
    }

    private func resultHeader(_ result: TraceResult) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(index < result.stars ? Palette.gold : Palette.cream.opacity(0.15))
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.2)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(Double(index) * 0.14), value: appeared)
                }
            }
            Text(TraceScoring.verdicts[result.stars])
                .font(GameFont.title(25))
                .foregroundStyle(Palette.gold)
                .multilineTextAlignment(.center)
            Text("\(result.score) очков из 100")
                .font(GameFont.body(15))
                .foregroundStyle(Palette.cream.opacity(0.85))
            if model.starReward > 0 {
                Text("+\(model.starReward) говнокоинов для байкера")
                    .font(GameFont.label(15))
                    .foregroundStyle(Palette.gold)
            }
        }
    }
}

private struct Meter: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value * 100).rounded()))%").monospacedDigit()
            }
            .font(GameFont.label(13))
            .foregroundStyle(Palette.cream)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.cream.opacity(0.15))
                    Capsule().fill(Palette.gold).frame(width: proxy.size.width * CGFloat(value))
                }
            }
            .frame(height: 7)
        }
    }
}
