import SwiftUI

@main
struct BikerApp: App {
    @StateObject private var game = BikeGame(sound: SoundPlayer(muted: false))

    var body: some Scene {
        WindowGroup {
            BikeRoot(game: game)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .defersSystemGestures(on: .all)
                .onAppear(perform: game.launch)
        }
    }
}
