// UNTESTED: written without Xcode. Expect small fixes on the first build.
import SwiftUI
import WordCueKit

@main
struct WordCueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Word Cue", id: "service") {
            RootView()
                .environment(model)
                .preferredColorScheme(Theme.scheme(model.s.appearance))
                .tint(Theme.accent(model.s.accentHex))
                .onAppear { delegate.model = model }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Service") {
                action("Send Verse", "send")
                action("Skip Verse", "skip")
                action(model.isListening ? "Pause Listening" : "Start Listening", "pause")
                Divider()
                action("Clear Screen", "clear")
                action("Resend Last Verse", "resend")
                Button("Next Slide of Passage") { model.stepSlide(1) }.keyboardShortcut(.rightArrow, modifiers: [])
                Button("Previous Slide of Passage") { model.stepSlide(-1) }.keyboardShortcut(.leftArrow, modifiers: [])
                Divider()
                action(model.s.compact ? "Show Full Sidebar" : "Compact Panel", "compact")
                action("Undo File Drop", "undo").disabled(!model.canUndoDrop)
                Divider()
                Button("Start a New Service") { model.newService() }
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .preferredColorScheme(Theme.scheme(model.s.appearance))
                .tint(Theme.accent(model.s.accentHex))
        }

        MenuBarExtra(isInserted: Binding(get: { model.s.showMenuBarIcon }, set: { model.settings.s.showMenuBarIcon = $0 })) {
            MenuBarView().environment(model)
        } label: {
            // The icon turns orange while listening; the waiting verse can sit beside it.
            let listening = model.isListening && model.s.menuBarShowsListening
            HStack(spacing: 4) {
                Image(systemName: model.s.menuBarIcon.symbol)
                    .symbolRenderingMode(listening ? .palette : .monochrome)
                    .foregroundStyle(listening ? Theme.orange : .primary)
                if model.s.menuBarShowsWaitingVerse, let w = model.waiting, !w.provisional { Text(w.title) }
            }
        }
    }

    /// A menu item whose key comes from Settings > Shortcuts & Controls.
    @ViewBuilder
    private func action(_ title: String, _ name: String) -> some View {
        if let combo = KeyCombo(model.s.shortcuts[name] ?? ""), let shortcut = combo.shortcut {
            Button(title) { model.perform(name) }.keyboardShortcut(shortcut)
        } else {
            Button(title) { model.perform(name) }
        }
    }
}

/// Handles the two things SwiftUI does not: asking before quitting while
/// listening, and staying alive in the menu bar when the window closes.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor var model: AppModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.isListening, model.s.confirmBeforeQuitting else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Word Cue is still listening."
        alert.informativeText = "If you quit now, no more verses will be caught in this service."
        alert.addButton(withTitle: "Keep Listening")
        alert.addButton(withTitle: "Quit")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let w = model.waiting, !w.provisional {
            Text("Waiting: \(w.title)")
            Button("Send") { model.sendWaiting() }
            Button("Skip") { model.skipWaiting() }
            Divider()
        }
        Button(model.isListening ? "Pause Listening" : "Start Listening") { model.togglePause() }
        Button("Clear Screen") { model.clearScreen() }
        Divider()
        Button("Show Word Cue") {
            openWindow(id: "service")
            model.windowActions.show()
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Word Cue") { NSApp.terminate(nil) }
    }
}

/// Switches between the full sidebar and the compact panel, places the
/// window, and shows first-run setup.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var window: NSWindow?

    var body: some View {
        @Bindable var model = model
        Group {
            if model.s.compact {
                CompactPanelView()
                    .frame(width: WindowManager.compactSize.width, height: WindowManager.compactSize.height)
            } else {
                ServiceView()
                    .frame(width: WindowManager.sidebarWidth)
                    .frame(minHeight: 480, maxHeight: .infinity)
            }
        }
        .background(WindowManager(compact: model.s.compact, corner: model.s.panelCorner, opacity: model.s.panelOpacity,
                                  onTop: model.s.keepPanelOnTop) { w in
            guard window !== w else { return }
            window = w
            model.windowActions = (
                show: { w.orderFrontRegardless() },      // comes forward without taking the keyboard from the presentation app
                hide: { w.orderOut(nil) },
                toggle: { w.isVisible ? w.orderOut(nil) : w.orderFrontRegardless() }
            )
        })
        .sheet(isPresented: $model.showSetup) {
            SetupView().environment(model)
        }
    }
}
