import SwiftUI

@main
struct CleanMacApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .preferredColorScheme(.dark)
                .background(Theme.bg)
        }
        .defaultSize(width: 1020, height: 680)
        .windowStyle(.hiddenTitleBar)
    }
}
