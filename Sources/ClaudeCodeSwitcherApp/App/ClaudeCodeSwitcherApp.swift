import SwiftUI

@main
struct ClaudeCodeSwitcherApp: App {
    @StateObject private var viewModel = SwitcherViewModel()
    @AppStorage(SwitcherViewModel.languageDefaultsKey) private var languageID = SwitcherViewModel.defaultLanguageID

    var body: some Scene {
        WindowGroup(windowTitle) {
            ContentView(viewModel: viewModel, languageID: $languageID)
                .frame(width: 900)
                .frame(height: 760)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }

    private var windowTitle: String {
        languageID.hasPrefix("en") ? "Claude Code Switcher" : "Claude Code 切换器"
    }
}
