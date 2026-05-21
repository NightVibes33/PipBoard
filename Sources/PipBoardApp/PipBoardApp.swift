import SwiftUI

@main
struct PipBoardApp: App {
    @StateObject private var model = PlaybackModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onOpenURL { url in
                    model.handleIncoming(url: url)
                }
        }
    }
}
