// UNTESTED: written without Xcode.
// Builds a plain-text problem report. Today it saves the report in
// ~/Library/Application Support/Word Cue/Reports and shows it in Finder.
// Sending it to Bryson's Google account (one Google Doc per report) needs a
// small web endpoint that does not exist yet; set `endpoint` when it does.
import AppKit

enum FeedbackReporter {
    /// A Google Apps Script web-app URL that turns a posted report into a Google Doc. Not set up yet.
    static let endpoint: URL? = nil

    static func buildReport(note: String, suggestions: [Suggestion], transcriptTail: [String], includeTranscript: Bool) -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        var lines = [
            "Word Cue problem report",
            "Date: \(Date().formatted(date: .abbreviated, time: .standard))",
            "App version: \(version)",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "",
            "What happened:",
            note.isEmpty ? "(nothing written)" : note,
            "",
            "Suggestions this service (\(suggestions.count)):"
        ]
        for s in suggestions.reversed() {
            lines.append("- \(s.time.formatted(date: .omitted, time: .standard))  \(s.title)  score \(String(format: "%.2f", s.confidence))  \(s.state)  heard: \"\(s.heard)\"  \(s.flags.joined(separator: ","))")
        }
        if includeTranscript {
            lines.append("")
            lines.append("Last transcript lines:")
            lines.append(contentsOf: transcriptTail)
        }
        return lines.joined(separator: "\n")
    }

    /// Saves the report and returns where it went.
    @discardableResult
    static func save(_ report: String) throws -> URL {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)
            .appendingPathComponent("Word Cue/Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("Report \(stamp).txt")
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
                return "Report sent. A copy was saved on this Mac."
            }
            await MainActor.run { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            return "Report saved on this Mac. Sending to the developer is not set up yet."
        } catch {
            return "Could not save the report: \(error.localizedDescription)"
        }
    }
}
