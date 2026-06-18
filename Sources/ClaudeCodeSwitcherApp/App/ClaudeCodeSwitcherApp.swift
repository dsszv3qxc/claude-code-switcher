import SwiftUI

@main
struct ClaudeCodeSwitcherApp: App {
    @StateObject private var viewModel = SwitcherViewModel()

    var body: some Scene {
        WindowGroup("Claude Code 切换器") {
            ContentView(viewModel: viewModel)
                .frame(width: 900)
                .frame(height: 760)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
