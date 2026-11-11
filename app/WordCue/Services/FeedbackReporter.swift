// UNTESTED: written without Xcode.
// Settings > Support > Send Feedback. A report holds the note, and, if the
// operator ticks the box, settings and recent logs. Never audio, never
// transcripts. It is saved on this Mac; sending it to the developer's Google
// account (one Google Doc per report) needs `endpoint` to be filled in.
import AppKit
import WordCueKit

enum FeedbackReporter {
    enum Kind: String, CaseIterable, Identifiable {
        case bug = "Bug", feature = "Feature Request", other = "Other"
        var id: String { rawValue }
    }

    /// A Google Apps Script web-app URL that turns a posted report into a Google Doc. Not set up yet.
    static let endpoint: URL? = nil

    static func build(kind: Kind, note: String, email: String, includeDiagnostics: Bool, settings: WordCueSettings) -> String {
        var lines = [
            "Word Cue feedback: \(kind.rawValue)",
            "Date: \(Date().formatted(date: .abbreviated, time: .standard))",
            "App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Reply to: \(email.isEmpty ? "(none given)" : email)",
            "",
            note.isEmpty ? "(nothing written)" : note
        ]
        if includeDiagnostics {
            lines += ["", "--- Settings ---", diagnostics(settings), "", "--- Recent log ---", DebugLog.recent()]
        }
        return lines.joined(separator: "\n")
    }

    /// Settings as text, with anything private (password, email) left out.
    static func diagnostics(_ settings: WordCueSettings) -> String {
        var s = settings
        s.apiPassword = s.apiPassword.isEmpty ? "" : "(set)"
        s.feedbackEmail = ""
        return (try? String(data: s.exported(), encoding: .utf8)) ?? ""
    }

    @discardableResult
    static func save(_ report: String, name: String = "Report") throws -> URL {
        let folder = DebugLog.folder.deletingLastPathComponent().appendingPathComponent("Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("\(name) \(stamp).txt")
        try report.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func send(_ report: String) async -> String {
        do {
            let url = try save(report)
            if let endpoint {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
                request.httpBody = Data(report.utf8)
                _ = try await URLSession.shared.data(for: request)
                return "Sent. A copy was saved on this Mac."
            }
            await MainActor.run { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            return "Saved on this Mac. Sending to the developer is not set up yet."
        } catch {
            return "Could not save the report: \(error.localizedDescription)"
        }
    }
}
