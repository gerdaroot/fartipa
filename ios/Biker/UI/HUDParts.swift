import SwiftUI

/// A racing speedometer: a 270° arc, ticks, a needle and the number.
struct SpeedDial: View {
    let kmh: Int
    let dial: Double
    let isBoosting: Bool

    private static let size: CGFloat = 116
    private static let sweep = 0.75
    private static let startDegrees = 135.0
    private static let tickCount = 11

    var body: some View {
        let size = Self.size
        let value = max(0, min(1, dial))
        ZStack {
            Circle().fill(RadialGradient(
                colors: [Palette.panelTop, Palette.panelBottom], center: .center, startRadius: 4, endRadius: size / 2
            ))
            Circle().strokeBorder(Palette.outline, lineWidth: 3)
            ForEach(0..<Self.tickCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 2, height: 7)
                    .offset(y: -size / 2 + 13)
                    .rotationEffect(.degrees(angle(Double(index) / Double(Self.tickCount - 1))))
            }
            Circle()
                .trim(from: 0, to: Self.sweep)
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(Self.startDegrees))
                .padding(7)
            Circle()
                .trim(from: 0, to: Self.sweep * value)
                .stroke(
                    AngularGradient(
                        colors: [Palette.greenTop, Palette.goldTop, Palette.redTop],
                        center: .center, startAngle: .degrees(0), endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(Self.startDegrees))
                .padding(7)
            Capsule()
                .fill(Palette.redTop)
                .frame(width: 4, height: size * 0.34)
                .offset(y: -size * 0.17)
                .rotationEffect(.degrees(angle(value)))
                .shadow(color: Palette.redTop, radius: isBoosting ? 6 : 0)
            Circle().fill(Palette.outline).frame(width: 12, height: 12)
            VStack(spacing: -2) {
                Text("\(kmh)")
                    .font(GameFont.title(26).monospacedDigit())
                    .foregroundStyle(isBoosting ? Palette.goldTop : Palette.cream)
                    .outlined(width: 1.5)
                Text("КМ/Ч")
                    .font(GameFont.label(10))
                    .foregroundStyle(Palette.cream.opacity(0.75))
            }
            .offset(y: size * 0.24)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 4)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Скорость \(kmh) километров в час")
    }

    /// Needle angle for a value 0...1, measured from straight up.
    private func angle(_ value: Double) -> Double {
        -135 + 270 * value
    }
}

/// «ГАЗЫ»: a big round button with the tank's charge as a ring around it.
struct BoostButton: View {
    let fraction: Double
    let canBoost: Bool
    let isBoosting: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let size: CGFloat = 104

    var body: some View {
        let size = Self.size
        let lit = canBoost || isBoosting
        Button(action: action) {
            ZStack {
                Circle().fill(Color.black.opacity(0.55))
                Circle()
                    .trim(from: 0, to: max(0, min(1, fraction)))
                    .stroke(
                        isBoosting ? Palette.redTop : Palette.greenTop,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(4)
                Circle()
                    .fill(LinearGradient(
                        colors: lit ? [Palette.greenTop, Palette.greenBottom] : [Palette.steelTop, Palette.steelBottom],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 3))
                    .padding(13)
                VStack(spacing: 0) {
                    Image(systemName: "wind")
                        .font(.system(size: 22, weight: .black))
                    Text("ГАЗЫ")
                        .font(GameFont.title(19))
                }
                .foregroundStyle(Palette.cream)
                .outlined(width: 1.5)
            }
            .frame(width: size, height: size)
            .shadow(color: lit ? Palette.greenTop.opacity(0.8) : .clear, radius: lit && !reduceMotion ? 12 : 0)
            .scaleEffect(isBoosting && !reduceMotion ? 1.08 : 1)
            .animation(.easeOut(duration: 0.2), value: isBoosting)
            .opacity(lit ? 1 : 0.7)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("Газы")
        .accessibilityValue(isBoosting ? "летим" : "заряд \(Int((fraction * 100).rounded())) процентов")
        .accessibilityHint(canBoost ? "Ускорение, тараним машины" : "Собирай монеты, чтобы накопить газы")
    }
}

/// A stream marker ahead: which lane it will pour on.
struct StreamWarning: View {
    let lane: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blink = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.ink)
            Text("ССУТ СВЕРХУ!")
                .font(GameFont.label(15))
                .foregroundStyle(Palette.ink)
            HStack(spacing: 3) {
                ForEach(-1...1, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index == lane ? Palette.redBottom : Palette.ink.opacity(0.25))
                        .frame(width: 12, height: 14)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Palette.piss))
        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2.5))
        .opacity(blink ? 0.55 : 1)
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.25).repeatForever(autoreverses: true)) { blink = true }
        }
        .accessibilityElement()
        .accessibilityLabel(laneText)
    }

    private var laneText: String {
        switch lane {
        case -1: return "Сверху польёт слева"
        case 1: return "Сверху польёт справа"
        default: return "Сверху польёт посередине"
        }
    }
}

/// Near misses, pickups, smashes and districts popping in the middle of the screen.
struct PopupStack: View {
    let popups: [RidePopup]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            ForEach(popups) { popup in
                text(popup)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: popups)
        .allowsHitTesting(false)
    }

    private func text(_ popup: RidePopup) -> some View {
        let isDistrict = popup.tone == .district
        return VStack(spacing: 0) {
            if isDistrict {
                Text("РАЙОН")
                    .font(GameFont.label(14))
                    .foregroundStyle(Palette.cream)
                    .outlined(width: 1.5)
            }
            Text(popup.text)
                .font(GameFont.title(isDistrict ? 36 : 26))
                .foregroundStyle(color(popup.tone))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .outlined(width: isDistrict ? 3 : 2)
        }
        .rotationEffect(.degrees(isDistrict || reduceMotion ? 0 : -4))
        .hudShadow()
        .accessibilityElement(children: .combine)
    }

    private func color(_ tone: RidePopup.Tone) -> Color {
        switch tone {
        case .good: return Palette.greenTop
        case .bad: return Palette.piss
        case .gold: return Palette.goldTop
        case .district: return Palette.redTop
        }
    }
}
