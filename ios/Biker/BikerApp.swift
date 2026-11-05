import SwiftUI

@main
struct BikerApp: App {
    var body: some Scene {
        WindowGroup {
            BikeRoot()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .defersSystemGestures(on: .all)
        }
    }
}
