// UNTESTED: written without a Swift compiler.
// The record of one service: every verse Word Cue cued and what happened to
// it. Saved on this Mac only. Audio is never part of it.
import Foundation

public struct LogEntry: Codable, Identifiable, Sendable, Equatable {
    public enum Outcome: String, Codable, Sendable { case waiting, sent, autoSent, skipped, expired, added }
    public enum Source: String, Codable, Sendable { case live, quote, file }

    public var id = UUID()
    public var time = Date()
    public var reference: Reference
    public var title: String
    public var confidence: Double
    public var heard: String            // the words that triggered it (or the file name)
    public var source: Source
    public var outcome: Outcome = .waiting
    /// What the operator says the verse should have been, when Word Cue got it wrong.
    /// These corrections are what churches can share to improve detection; never audio.
    public var correctedKey: String?

    public init(reference: Reference, title: String, confidence: Double, heard: String, source: Source) {
        self.reference = reference
        self.title = title
        self.confidence = confidence
        self.heard = heard
        self.source = source
    }
}

public struct ServiceRecord: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var started = Date()
    public var entries: [LogEntry] = []
    public var transcript: [String] = []     // kept only as long as Settings > Audio Input says
    public init() {}
}

public final class ServiceLog: @unchecked Sendable {
    public let folder: URL
    private let lock = NSLock()

    /// Default: ~/Library/Application Support/Word Cue/Services
    public init(folder: URL? = nil) {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        self.folder = folder ?? base.appendingPathComponent("Word Cue/Services", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
    }

    private func url(_ record: ServiceRecord) -> URL {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH-mm"
        return folder.appendingPathComponent("Service \(f.string(from: record.started)).json")
    }

    /// keepTranscriptDays: -1 = don't keep transcripts at all; 0 or more = keep for now, pruned later.
    public func save(_ record: ServiceRecord, keepTranscriptDays: Int) {
        var r = record
        if keepTranscriptDays < 0 { r.transcript = [] }
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted]
        e.dateEncodingStrategy = .iso8601
        lock.lock()
        defer { lock.unlock() }
        if let data = try? e.encode(r) { try? data.write(to: url(r), options: .atomic) }
    }

    public func all() -> [ServiceRecord] {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? d.decode(ServiceRecord.self, from: Data(contentsOf: $0)) }
            .sorted { $0.started > $1.started }
    }

    /// Removes transcripts older than the church allows. 0 = this service only.
    /// Call at launch and when a service ends. The verse history itself is kept.
    public func pruneTranscripts(keepDays: Int, currentService: UUID?) {
        for var r in all() where !r.transcript.isEmpty && r.id != currentService {
            let age = Date().timeIntervalSince(r.started) / 86_400
            if keepDays <= 0 || age > Double(keepDays) {
                r.transcript = []
                save(r, keepTranscriptDays: 0)
            }
        }
    }

    /// A plain-text record for the pastor: time, verse, what happened.
    public static func exportText(_ record: ServiceRecord) -> String {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .short
        let t = DateFormatter()
        t.timeStyle = .short
        var lines = ["Word Cue service log", f.string(from: record.started), ""]
        for e in record.entries {
            lines.append("\(t.string(from: e.time))\t\(e.title)\t\(e.outcome.rawValue)")
        }
        return lines.joined(separator: "\n")
    }

    /// Corrections in the shape of cases.json, ready for Word Cue Lab:
    /// the words heard, and the verse the operator says is right.
    public static func exportCorrections(_ records: [ServiceRecord]) -> Data {
        let cases: [[String: Any]] = records.flatMap { $0.entries }.compactMap { e in
            guard let fixed = e.correctedKey, e.source != .file else { return nil }
            return ["mode": "speech", "text": e.heard, "expect": fixed.isEmpty ? [] : [fixed], "suggested": e.reference.key]
        }
        return (try? JSONSerialization.data(withJSONObject: ["cases": cases], options: [.prettyPrinted])) ?? Data()
    }
}
