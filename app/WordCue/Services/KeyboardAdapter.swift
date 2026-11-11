// UNTESTED: written without Xcode and never run against a real presentation app.
// For apps with no API (EasyWorship, "Other"), and as the fallback when an
// API drops: Word Cue brings the app forward and types the reference for the
// operator. Needs Accessibility permission (System Settings > Privacy & Security).
import AppKit
import ApplicationServices
import WordCueKit

struct KeyboardAdapter: PresentationAdapter {
    let appName: String
    let bundleIDs: [String]
    /// Keystroke that opens the app's Bible search, e.g. "cmd+b". Empty = just type.
    let openSearch: String

    init(settings: WordCueSettings) {
        appName = settings.presentationApp.displayName
        bundleIDs = settings.presentationApp.bundleIdentifiers
        openSearch = settings.keyboardOpenSearch
    }

    static var hasPermission: Bool { AXIsProcessTrusted() }

    /// Shows the macOS prompt that sends the operator to the Accessibility list.
    static func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private func runningApp() -> NSRunningApplication? {
        for id in bundleIDs {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first { return app }
        }
        return nil
    }

    func test() async throws -> String {
        guard Self.hasPermission else {
            throw AdapterError.notSupported("Keyboard mode needs Accessibility. Allow Word Cue in System Settings > Privacy & Security > Accessibility.")
        }
        if !bundleIDs.isEmpty && runningApp() == nil { throw AdapterError.notReachable("\(appName) is not open") }
        return "Ready to type references into \(appName)."
    }

    func show(_ item: VerseItem) async throws {
        _ = try await test()
        await MainActor.run { _ = runningApp()?.activate() }
        try await Task.sleep(for: .milliseconds(250))      // let the app come forward
        if let combo = KeyCombo(openSearch), let code = combo.keyCode {
            Self.press(CGKeyCode(code), combo)
            try await Task.sleep(for: .milliseconds(150))
        }
        Self.type(item.title)
        try await Task.sleep(for: .milliseconds(80))
        Self.press(36, nil)                                 // Return
    }

    func addToServiceList(_ item: VerseItem) async throws {
        throw AdapterError.notSupported("Keyboard mode can only put a verse on screen. It cannot add to \(appName)'s service list.")
    }

    func clear() async throws {
        throw AdapterError.notSupported("Keyboard mode cannot clear \(appName)'s screen. Use \(appName)'s own clear key.")
    }

    static func press(_ code: CGKeyCode, _ combo: KeyCombo?) {
        var flags: CGEventFlags = []
        if let combo {
            if combo.command { flags.insert(.maskCommand) }
            if combo.option { flags.insert(.maskAlternate) }
            if combo.control { flags.insert(.maskControl) }
            if combo.shift { flags.insert(.maskShift) }
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            e?.flags = flags
            e?.post(tap: .cghidEventTap)
        }
    }

    /// Types text as if from the keyboard, whatever the keyboard layout.
    static func type(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for ch in text {
            let units = Array(String(ch).utf16)
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
                e?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
                e?.post(tap: .cghidEventTap)
            }
        }
    }
}
