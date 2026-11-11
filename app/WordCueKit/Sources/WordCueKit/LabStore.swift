// UNTESTED: written without a Swift compiler.
// Word Cue Lab's saved work: one "session" per sermon recording or
// transcript, with the operator's review of every detection. Shared by the
// Lab app and the Lab's Claude connector (the wordcue-lab-mcp tool).
// Stored in ~/Library/Application Support/Word Cue Lab/. Local only.
import Foundation

public struct LabSegment: Codable, Sendable, Equatable {
    public var start: Double       // seconds into the recording (0 when unknown)
    public var end: Double
    public var text: String
    public init(start: Double, end: Double, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}

/// What the reviewer decided about one detection.
public struct LabReview: Codable, Sendable, Equatable {
    public enum Verdict: String, Codable, Sendable { case correct, wrong, falseAlarm }
    public var verdict: Verdict
    public var correctedKey: String?      // for .wrong: what it should have been, e.g. "1KI 13:2"
    public var note: String?
    public init(verdict: Verdict, correctedKey: String? = nil, note: String? = nil) {
        self.verdict = verdict
        self.correctedKey = correctedKey
        self.note = note
    }
}

/// A reference the detector missed entirely, added by the reviewer.
public struct LabMiss: Codable, Sendable, Equatable, Identifiable {
    public var id = UUID()
    public var text: String               // the words as transcribed
    public var expect: String             // "ACT 1:8"
    public init(text: String, expect: String) {
        self.text = text
        self.expect = expect
    }
}

public struct LabSession: Codable, Sendable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var created = Date()
    public var segments: [LabSegment] = []
    /// Keyed by "\(startToken)|\(key)" so a review survives re-running the detector.
    public var reviews: [String: LabReview] = [:]
    public var misses: [LabMiss] = []
    public var transcribedBy = ""         // "Apple SpeechTranscriber", "imported text", ...

    public init(name: String) { self.name = name }

    public var text: String { segments.map(\.text).joined(separator: " ") }
}

/// One detection in a session, with its time and review, ready to show or export.
public struct LabFinding: Identifiable, Sendable {
    public var detection: Detection
    public var display: String
    public var time: Double
    public var review: LabReview?
    public var reviewKey: String
    public var id: String { reviewKey }
}

public final class LabStore: @unchecked Sendable {
    public let folder: URL
    private var sessionsFolder: URL { folder.appendingPathComponent("Sessions", isDirectory: true) }
    public var proposedCasesURL: URL { folder.appendingPathComponent("proposed-cases.json") }

    public init(folder: URL? = nil) {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        self.folder = folder ?? base.appendingPathComponent("Word Cue Lab", isDirectory: true)
        try? FileManager.default.createDirectory(at: sessionsFolder, withIntermediateDirectories: true)
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public func save(_ session: LabSession) {
        if let data = try? Self.encoder.encode(session) {
            try? data.write(to: sessionsFolder.appendingPathComponent("\(session.id.uuidString).json"), options: .atomic)
        }
    }

    public func delete(_ session: LabSession) {
        try? FileManager.default.removeItem(at: sessionsFolder.appendingPathComponent("\(session.id.uuidString).json"))
    }

    public func sessions() -> [LabSession] {
        let files = (try? FileManager.default.contentsOfDirectory(at: sessionsFolder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? Self.decoder.decode(LabSession.self, from: Data(contentsOf: $0)) }
            .sorted { $0.created > $1.created }
    }

    public func session(named name: String) -> LabSession? {
        sessions().first { $0.name.caseInsensitiveCompare(name) == .orderedSame || $0.id.uuidString == name }
    }

    // MARK: Importing transcripts

    /// Reads a transcript made by any tool: a JSON list or JSON lines of
    /// {"start","end","text"}, or plain text with one line per segment.
    public static func segments(fromTranscript data: Data) -> [LabSegment] {
        let raw = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        struct Row: Decodable {
            let start: Double?
            let end: Double?
            let text: String
        }
        if raw.hasPrefix("["), let rows = try? JSONDecoder().decode([Row].self, from: Data(raw.utf8)) {
            return rows.map { LabSegment(start: $0.start ?? 0, end: $0.end ?? 0, text: $0.text) }
        }
        if raw.hasPrefix("{") {
            let rows = raw.split(separator: "\n").compactMap { try? JSONDecoder().decode(Row.self, from: Data($0.utf8)) }
            if !rows.isEmpty { return rows.map { LabSegment(start: $0.start ?? 0, end: $0.end ?? 0, text: $0.text) } }
        }
        return raw.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.map { LabSegment(start: 0, end: 0, text: $0) }
    }

    // MARK: Running the detector

    /// Runs the detector over a session the same way the live app does:
    /// segment by segment through a DetectionSession.
    public static func findings(in session: LabSession, engine: Engine, quotes: Bool, minimumConfidence: Double = 0) -> [LabFinding] {
        let live = DetectionSession(engine: engine)
        live.quotes = quotes
        var rows: [Int: (Detection, Double)] = [:]
        for segment in session.segments {
            for event in live.feed(segment.text) {
                switch event {
                case .new(let d): rows[d.start] = (d, segment.start)
                case .update(let d): rows[d.start] = (d, rows[d.start]?.1 ?? segment.start)
                case .remove(let id): rows[id] = nil
                }
            }
        }
        return rows.keys.sorted().compactMap { k in
            guard let (d, time) = rows[k], d.confidence >= minimumConfidence else { return nil }
            let key = "\(d.start)|\(d.key)"
            return LabFinding(detection: d, display: engine.display(d.reference), time: time, review: session.reviews[key], reviewKey: key)
        }
    }

    // MARK: Exporting test cases

    /// Turns a session's reviews into cases in the cases.json shape:
    /// wrong detections (with the right answer), false alarms (expect nothing), and misses.
    public static func cases(from session: LabSession, findings: [LabFinding]) -> [[String: Any]] {
        var out: [[String: Any]] = []
        for f in findings {
            guard let r = f.review, r.verdict != .correct else { continue }
            let expect: [String] = r.verdict == .wrong ? [r.correctedKey].compactMap { $0 }.filter { !$0.isEmpty } : []
            var c: [String: Any] = ["mode": "speech", "text": f.detection.text, "expect": expect,
                                    "note": "Lab: \(session.name). Detector said \(f.detection.key)."]
            if f.detection.kind == .quote { c["quotes"] = true }
            out.append(c)
        }
        for m in session.misses {
            out.append(["mode": "speech", "text": m.text, "expect": [m.expect], "note": "Lab: \(session.name). Missed."])
        }
        return out
    }

    /// Adds cases to proposed-cases.json. They are proposals: a person moves
    /// the good ones into the repo's cases.json and fixes the engine.
    @discardableResult
    public func propose(_ cases: [[String: Any]]) -> Int {
        var all = ((try? JSONSerialization.jsonObject(with: Data(contentsOf: proposedCasesURL))) as? [String: Any])?["cases"] as? [[String: Any]] ?? []
        all.append(contentsOf: cases)
        if let data = try? JSONSerialization.data(withJSONObject: ["cases": all], options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: proposedCasesURL, options: .atomic)
        }
        return all.count
    }

    /// Reads a corrections file exported from Word Cue (Service Log) by a church.
    public static func importCorrections(_ data: Data) -> [[String: Any]] {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["cases"] as? [[String: Any]] ?? []
    }

    /// Scores for a reviewed session.
    public static func summary(_ findings: [LabFinding], misses: Int) -> (correct: Int, wrong: Int, falseAlarms: Int, unreviewed: Int, missed: Int) {
        var c = 0, w = 0, f = 0, u = 0
        for x in findings {
            switch x.review?.verdict {
            case .correct: c += 1
            case .wrong: w += 1
            case .falseAlarm: f += 1
            case .none: u += 1
            }
        }
        return (c, w, f, u, misses)
    }

    /// Turns "Acts 2:38" or "ACT 2:38" into a key, using the engine itself.
    public static func key(for text: String, engine: Engine) -> String? {
        let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 2, engine.book(parts[0].uppercased()) != nil {
            return engine.detect("\(engine.book(parts[0].uppercased())!.name) \(parts[1])", mode: .document).first?.key
        }
        return engine.detect(text, mode: .document).first?.key ?? engine.detect(text).first?.key
    }
}
