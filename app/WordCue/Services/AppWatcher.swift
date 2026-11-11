// UNTESTED: written without Xcode.
// Watches the presentation app: opened, quit, came to the front. This drives
// "Show Word Cue when your app opens", "Pair with app" and "When the app quits".
import AppKit
import WordCueKit

@MainActor
final class AppWatcher {
    var onLaunch: (() -> Void)?
    var onQuit: (() -> Void)?
    var onActivate: (() -> Void)?
    private var tokens: [NSObjectProtocol] = []
    private var bundleIDs: Set<String> = []

    func watch(_ app: PresentationApp) {
        stop()
        bundleIDs = Set(app.bundleIdentifiers)
        guard !bundleIDs.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        func observe(_ name: Notification.Name, _ action: @escaping @MainActor (AppWatcher) -> Void) {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier ?? ""
                Task { @MainActor in
                    guard let self, self.bundleIDs.contains(id) else { return }
                    action(self)
                }
            })
        }
        observe(NSWorkspace.didLaunchApplicationNotification) { $0.onLaunch?() }
        observe(NSWorkspace.didTerminateApplicationNotification) { $0.onQuit?() }
        observe(NSWorkspace.didActivateApplicationNotification) { $0.onActivate?() }
    }

    var isRunning: Bool {
        bundleIDs.contains { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }
    }

    func launchApp() {
        for id in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
                return
            }
        }
    }

    func stop() {
        tokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        tokens = []
    }
}
