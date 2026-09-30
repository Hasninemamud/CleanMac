import SwiftUI

@main
struct CleanMacApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .preferredColorScheme(.light)
                .background(Theme.bg)
                .onAppear {
                    MenuBarController.shared.install(state: state)
                }
        }
        .defaultSize(width: 1020, height: 680)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    state.showSettings = true
                    Task { await state.loadSettingsData() }
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
