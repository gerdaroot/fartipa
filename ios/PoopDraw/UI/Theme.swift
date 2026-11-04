import SwiftUI

enum Palette {
    static let goldTop = Color(red: 0.98, green: 0.79, blue: 0.33)
    static let goldBottom = Color(red: 0.86, green: 0.60, blue: 0.16)
    static let goldEdge = Color(red: 0.52, green: 0.33, blue: 0.05)
    static let brownTop = Color(red: 0.50, green: 0.32, blue: 0.16)
    static let brownBottom = Color(red: 0.35, green: 0.21, blue: 0.09)
    static let brownEdge = Color(red: 0.17, green: 0.09, blue: 0.03)
    static let gold = Color(red: 0.95, green: 0.74, blue: 0.28)
    static let cream = Color(red: 0.97, green: 0.91, blue: 0.75)
    static let ink = Color(red: 0.17, green: 0.09, blue: 0.03)
    static let tray = Color(red: 0.13, green: 0.07, blue: 0.03).opacity(0.92)
    static let hairline = Color(red: 0.97, green: 0.91, blue: 0.75).opacity(0.14)
}

enum GameFont {
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

/// A chunky game button: the face sits on a darker lip and sinks into it when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    enum Kind { case gold, brown }

    var kind: Kind = .brown
    var height: CGFloat = 58
    var fontSize: CGFloat = 19
    @Environment(\.isEnabled) private var isEnabled

    private let lip: CGFloat = 5
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    func makeBody(configuration: Configuration) -> some View {
        let isGold = kind == .gold
        return configuration.label
            .font(GameFont.label(fontSize))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isGold ? Palette.ink : Palette.cream)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(shape.fill(LinearGradient(
                colors: isGold ? [Palette.goldTop, Palette.goldBottom] : [Palette.brownTop, Palette.brownBottom],
                startPoint: .top,
                endPoint: .bottom
            )))
            .overlay(shape.strokeBorder(Color.white.opacity(isGold ? 0.35 : 0.14), lineWidth: 1))
            .offset(y: configuration.isPressed ? lip : 0)
            .background(shape.fill(isGold ? Palette.goldEdge : Palette.brownEdge).offset(y: lip))
            .padding(.bottom, lip)
            .shadow(color: .black.opacity(0.45), radius: 7, x: 0, y: 5)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

/// A round dark button with a symbol, for the corners of the screen.
struct RoundIconButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 46
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Palette.cream)
                .frame(width: size, height: size)
                .background(Circle().fill(Palette.tray))
                .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// A dimmed backdrop with one centred panel on it.
struct Sheet<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 14) { content }
                .padding(20)
                .frame(maxWidth: 380)
                .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Palette.tray))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 18, x: 0, y: 12)
                .padding(16)
        }
    }
}

/// Draws one level's figure from the same points the player traces.
struct FigureShape: Shape {
    let figure: Figure

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for line in figure.paths {
            let points = line.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
            path.addLines(points)
        }
        return path
    }
}

struct StarRow: View {
    let filled: Int
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(index < filled ? Palette.gold : Palette.cream.opacity(0.18))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Звёзд: \(filled) из 3")
    }
}
