// UNTESTED: written without Xcode.
// The small jobs macOS does for Word Cue: start at login, stay awake,
// permissions, alerts.
import AppKit
import AVFoundation
import Speech
import ServiceManagement
import UserNotifications

enum SystemIntegration {
    // MARK: Launch at login
    static func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            DebugLog.write("Launch at login could not be changed: \(error.localizedDescription)")
        }
    }

    // MARK: Keep the Mac awake while listening
    private static var awakeToken: NSObjectProtocol?

    static func keepAwake(_ on: Bool) {
        if on, awakeToken == nil {
            awakeToken = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .idleDisplaySleepDisabled],
                                                               reason: "Word Cue is listening to a service")
        } else if !on, let token = awakeToken {
            ProcessInfo.processInfo.endActivity(token)
            awakeToken = nil
        }
    }

    // MARK: Permissions (Settings > Support shows these live)
    struct Permissions: Equatable {
        var microphone = false
        var speech = false
        var accessibility = false
        var notifications = false
    }

    static func permissions() async -> Permissions {
        var p = Permissions()
        p.microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        p.speech = SFSpeechRecognizer.authorizationStatus() == .authorized
        p.accessibility = KeyboardAdapter.hasPermission
        p.notifications = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
        return p
    }

    static func requestMicrophone() async -> Bool { await AVCaptureDevice.requestAccess(for: .audio) }

    /// VERIFY: the newer SpeechAnalyzer may not need this permission at all (an open question in the guide).
    static func requestSpeech() async -> Bool {
        await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
    }

    static func requestNotifications() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func openPrivacySettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Alerts
    /// Tells the operator about a problem when Word Cue's window is hidden.
    static func notify(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    static func playWaitingSound() { NSSound(named: "Glass")?.play() }
}

/// Settings > Advanced > Debug logging. Never contains audio. Transcript text
/// is only written when the caller chooses to pass it.
enum DebugLog {
    static var enabled = false
    static let folder: URL = {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let f = base.appendingPathComponent("Word Cue/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: f, withIntermediateDirectories: true)
        return f
    }()
    private static let queue = DispatchQueue(label: "wordcue.log")

    static func write(_ line: String) {
        guard enabled else { return }
        queue.async {
            let day = Date().formatted(.iso8601.year().month().day())
            let url = folder.appendingPathComponent("wordcue-\(day).log")
            let text = "\(Date().formatted(date: .omitted, time: .standard))  \(line)\n"
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(text.utf8))
                try? handle.close()
            } else {
                try? Data(text.utf8).write(to: url)
            }
        }
    }

    static func recent(lines: Int = 200) -> String {
        let files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        guard let newest = files.first, let text = try? String(contentsOf: newest, encoding: .utf8) else { return "" }
        return text.split(separator: "\n").suffix(lines).joined(separator: "\n")
    }
}
