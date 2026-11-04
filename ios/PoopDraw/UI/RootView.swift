import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var model = GameModel()

    var body: some View {
        ZStack {
            BoardHost(board: model.board).ignoresSafeArea()
            if model.isReady {
                screen.transition(.opacity)
            } else {
                LoadingView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: model.screen)
        .animation(.easeInOut(duration: 0.25), value: model.isReady)
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

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Palette.gold).controlSize(.large)
            Text("Лепим кучу…")
                .font(GameFont.label(17))
                .foregroundStyle(Palette.cream)
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
