// UNTESTED: written without Xcode. Expect small fixes on the first build.
import SwiftUI

@main
struct WordCueApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Word Cue") {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.amber)
        }
        .defaultSize(width: 360, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Service") {
                Button(model.isListening ? "Stop Listening" : "Start Listening") { model.toggleListening() }
                    .keyboardShortcut("l", modifiers: .command)
                Divider()
                Button("Send to Screen") { model.sendSelected() }
                    .keyboardShortcut(.return, modifiers: [])
                Button("Dismiss Suggestion") { model.dismissSelected() }
                    .keyboardShortcut(.delete, modifiers: [])
                Button("Next Suggestion") { model.moveSelection(1) }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("Previous Suggestion") { model.moveSelection(-1) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Divider()
                Button("Next Verse") { model.stepVerse(1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Previous Verse") { model.stepVerse(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Clear Screen") { model.clearScreen() }
                    .keyboardShortcut(.escape, modifiers: [])
                Divider()
                Button(model.compact ? "Show Full Sidebar" : "Compact Mode") { model.compact.toggle() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Report a Problem…") { model.showingReport = true }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.amber)
        }
    }
}
