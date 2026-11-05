import SwiftUI
import UIKit

/// The hidden diagnostics label: fps, worst frame of the last second and hitches over 50 ms.
/// Toggled by a three-finger tap anywhere or a long press on the hub title.
struct PerfOverlay: View {
    @ObservedObject var perf: PerfReadout

    var body: some View {
        if perf.isOn {
            VStack {
                Text(perf.line)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.green)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.75)))
                Spacer()
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// Puts a three-finger tap recogniser on the window, so it works over every screen without
/// taking touches away from SwiftUI.
struct ThreeFingerTap: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> WindowTapInstaller {
        let view = WindowTapInstaller()
        view.isUserInteractionEnabled = false
        view.action = action
        return view
    }

    func updateUIView(_ uiView: WindowTapInstaller, context: Context) {
        uiView.action = action
    }
}

final class WindowTapInstaller: UIView {
    private static let fingers = 3

    var action: (() -> Void)?
    private weak var installedOn: UIWindow?
    private lazy var recognizer: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(fire(_:)))
        tap.numberOfTouchesRequired = Self.fingers
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        return tap
    }()

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window, window !== installedOn else { return }
        installedOn?.removeGestureRecognizer(recognizer)
        window.addGestureRecognizer(recognizer)
        installedOn = window
    }

    @objc private func fire(_ sender: UITapGestureRecognizer) {
        guard sender.state == .ended else { return }
        action?()
    }
}
