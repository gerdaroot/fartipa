import SwiftUI

enum Palette {
    static let lumpTop = Color(red: 0.54, green: 0.35, blue: 0.18)
    static let lumpBottom = Color(red: 0.30, green: 0.18, blue: 0.07)
    static let gold = Color(red: 0.90, green: 0.69, blue: 0.24)
    static let goldDeep = Color(red: 0.58, green: 0.40, blue: 0.06)
    static let cream = Color(red: 0.96, green: 0.89, blue: 0.71)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.03)
    static let sheet = Color(red: 0.15, green: 0.08, blue: 0.03).opacity(0.94)
}

/// A slightly lopsided pebble, so no two buttons sit quite like a rounded rectangle.
struct LumpShape: Shape {
    var skew: CGFloat = 0.06

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let bulge = min(w, h) * 0.5
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + w * (0.5 - skew), y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + h * (0.5 + skew)),
            control1: CGPoint(x: rect.maxX - bulge * 0.5, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + bulge * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * (0.5 + skew), y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - bulge * 0.3),
            control2: CGPoint(x: rect.maxX - bulge * 0.6, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * (0.5 - skew)),
            control1: CGPoint(x: rect.minX + bulge * 0.5, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - bulge * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * (0.5 - skew), y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + bulge * 0.3),
            control2: CGPoint(x: rect.minX + bulge * 0.6, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct LumpButtonStyle: ButtonStyle {
    var gold = false
    var big = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: big ? 21 : 15, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(gold ? Palette.ink : Palette.cream)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: big ? 66 : 46)
            .background(
                LumpShape()
                    .fill(RadialGradient(
                        colors: gold ? [Palette.gold, Palette.goldDeep] : [Palette.lumpTop, Palette.lumpBottom],
                        center: UnitPoint(x: 0.32, y: 0.18),
                        startRadius: 2,
                        endRadius: big ? 220 : 90
                    ))
                    .shadow(color: .black.opacity(0.55), radius: 5, x: 0, y: 4)
            )
            .contentShape(LumpShape())
            .opacity(isEnabled ? 1 : 0.42)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

struct Sheet<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea()
            VStack(spacing: 14) { content }
                .padding(20)
                .frame(maxWidth: 370)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.sheet))
                .shadow(color: .black.opacity(0.6), radius: 17, x: 0, y: 12)
                .padding(16)
        }
    }
}
