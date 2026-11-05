import SwiftUI

/// Loud night-racer colours: gold and red on deep navy, with brown for the poop jokes.
enum Palette {
    static let goldTop = Color(red: 1.00, green: 0.88, blue: 0.30)
    static let goldBottom = Color(red: 0.95, green: 0.58, blue: 0.08)
    static let goldEdge = Color(red: 0.55, green: 0.30, blue: 0.02)
    static let redTop = Color(red: 1.00, green: 0.33, blue: 0.24)
    static let redBottom = Color(red: 0.78, green: 0.07, blue: 0.10)
    static let redEdge = Color(red: 0.40, green: 0.02, blue: 0.05)
    static let steelTop = Color(red: 0.27, green: 0.31, blue: 0.43)
    static let steelBottom = Color(red: 0.15, green: 0.17, blue: 0.26)
    static let steelEdge = Color(red: 0.06, green: 0.07, blue: 0.12)
    static let greenTop = Color(red: 0.55, green: 0.92, blue: 0.30)
    static let greenBottom = Color(red: 0.20, green: 0.66, blue: 0.12)
    static let greenEdge = Color(red: 0.07, green: 0.30, blue: 0.04)
    static let gold = Color(red: 1.00, green: 0.80, blue: 0.20)
    static let cream = Color(red: 1.00, green: 0.97, blue: 0.88)
    static let ink = Color(red: 0.10, green: 0.05, blue: 0.02)
    static let outline = Color(red: 0.08, green: 0.03, blue: 0.02)
    static let piss = Color(red: 1.00, green: 0.86, blue: 0.10)
    static let poop = Color(red: 0.45, green: 0.27, blue: 0.11)
    static let danger = Color(red: 1.00, green: 0.25, blue: 0.20)
    static let panelTop = Color(red: 0.10, green: 0.11, blue: 0.20).opacity(0.94)
    static let panelBottom = Color(red: 0.04, green: 0.04, blue: 0.09).opacity(0.94)
    static let tray = Color(red: 0.05, green: 0.05, blue: 0.10).opacity(0.82)
    static let hairline = Color.white.opacity(0.16)
    static let dim = Color.black.opacity(0.55)

    static func rarity(_ rarity: Rarity) -> Color {
        switch rarity {
        case .common: return Color(red: 0.62, green: 0.70, blue: 0.78)
        case .rare: return Color(red: 0.25, green: 0.62, blue: 1.00)
        case .epic: return Color(red: 0.74, green: 0.36, blue: 1.00)
        case .legendary: return Color(red: 1.00, green: 0.66, blue: 0.10)
        }
    }

    static func color(_ rgb: RGB) -> Color {
        Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}

/// Heavy rounded type. Menu text follows Dynamic Type through text styles; HUD numbers use fixed
/// sizes so the riding screen keeps its layout.
enum GameFont {
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func styled(_ style: Font.TextStyle, weight: Font.Weight = .heavy) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

/// Draws a thick dark outline around text or a symbol, like stickers in mobile racers.
/// `color` should be dark: the copies behind are the content multiplied by it.
struct OutlinedModifier: ViewModifier {
    var color: Color = Palette.outline
    var width: CGFloat = 2

    private static let directions: [(CGFloat, CGFloat)] = [
        (1, 0), (-1, 0), (0, 1), (0, -1), (0.7, 0.7), (-0.7, 0.7), (0.7, -0.7), (-0.7, -0.7),
    ]

    func body(content: Content) -> some View {
        ZStack {
            ForEach(0..<Self.directions.count, id: \.self) { index in
                // Multiplying keeps working when the content already set its own colour.
                content
                    .colorMultiply(color)
                    .offset(x: Self.directions[index].0 * width, y: Self.directions[index].1 * width)
                    .accessibilityHidden(true)
            }
            content
        }
    }
}

extension View {
    func outlined(_ color: Color = Palette.outline, width: CGFloat = 2) -> some View {
        modifier(OutlinedModifier(color: color, width: width))
    }
}

/// A chunky game button: the face sits on a darker lip and sinks into it when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    enum Kind { case gold, red, steel, green }

    var kind: Kind = .steel
    var height: CGFloat = 58
    var fontSize: CGFloat = 20
    @Environment(\.isEnabled) private var isEnabled

    private let lip: CGFloat = 6
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }

    private var colors: (top: Color, bottom: Color, edge: Color) {
        switch kind {
        case .gold: return (Palette.goldTop, Palette.goldBottom, Palette.goldEdge)
        case .red: return (Palette.redTop, Palette.redBottom, Palette.redEdge)
        case .steel: return (Palette.steelTop, Palette.steelBottom, Palette.steelEdge)
        case .green: return (Palette.greenTop, Palette.greenBottom, Palette.greenEdge)
        }
    }

    /// No `.shadow` here: over a 3D view that redraws every frame, each blurred shadow costs an
    /// offscreen pass per frame. The text "shadow" is a plain offset copy instead.
    func makeBody(configuration: Configuration) -> some View {
        let set = colors
        let text: Color = kind == .gold ? Palette.ink : Palette.cream
        let under: Color = kind == .gold ? Color.white.opacity(0.4) : Color.black.opacity(0.6)
        return ZStack {
            configuration.label
                .foregroundStyle(under)
                .offset(y: 1.5)
                .accessibilityHidden(true)
            configuration.label
                .foregroundStyle(text)
        }
            .font(GameFont.label(fontSize))
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(shape.fill(LinearGradient(colors: [set.top, set.bottom], startPoint: .top, endPoint: .bottom)))
            .overlay(alignment: .top) {
                shape.fill(Color.white.opacity(0.22)).frame(height: height * 0.42).padding(4)
            }
            .overlay(shape.strokeBorder(Palette.outline, lineWidth: 2.5))
            .offset(y: configuration.isPressed ? lip : 0)
            .background(shape.fill(set.edge).overlay(shape.strokeBorder(Palette.outline, lineWidth: 2.5)).offset(y: lip))
            .padding(.bottom, lip)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// A dark glassy panel with a thin bright rim.
struct PanelBackground: View {
    var cornerRadius: CGFloat = 24
    var rim: Color = Palette.hairline

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Palette.panelTop, Palette.panelBottom], startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(rim, lineWidth: 1.5))
            .overlay(shape.inset(by: 3).strokeBorder(Color.black.opacity(0.4), lineWidth: 1))
    }
}
