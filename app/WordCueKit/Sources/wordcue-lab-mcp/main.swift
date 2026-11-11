// UNTESTED: written without a Swift compiler.
//
// wordcue-lab-mcp: the Word Cue Lab connector for Claude.
//
// It speaks the Model Context Protocol (MCP) over standard input/output:
// Claude starts this program, sends it one JSON message per line, and reads
// one JSON reply per line. No network, no API key. Claude can then read Lab
// sessions, run the detector on any sentence, and propose new test cases.
//
// Build:   cd app/WordCueKit && swift build -c release --product wordcue-lab-mcp
// Connect: see docs/LAB.md for the lines to add to Claude's settings.
//
// Privacy: when Claude asks for a transcript, that text goes to Claude.
// Only load sermons into the Lab that are fine to share that way.
import Foundation
import WordCueKit

let engine = Engine()
let store = LabStore()

// MARK: - Tools

struct Tool {
    let name: String
    let description: String
    let properties: [String: [String: Any]]
    let required: [String]
    let run: ([String: Any]) throws -> String
}

struct ToolError: Error { let message: String }

func string(_ args: [String: Any], _ key: String) throws -> String {
    guard let v = args[key] as? String, !v.isEmpty else { throw ToolError(message: "Missing \"\(key)\".") }
    return v
}

func loadSession(_ args: [String: Any]) throws -> LabSession {
    let name = try string(args, "session")
    guard let s = store.session(named: name) else {
        throw ToolError(message: "No session named \"\(name)\". Use list_sessions to see the names.")
    }
    return s
}

func clock(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }

func describe(_ f: LabFinding) -> String {
    var line = "\(clock(f.time))  \(f.display)  [\(f.detection.key)]  \(Int(f.detection.confidence * 100))%  \(f.detection.kind.rawValue)"
    if !f.detection.flags.isEmpty { line += "  flags: \(f.detection.flags.joined(separator: ","))" }
    line += "  heard: \"\(f.detection.text)\""
    if let r = f.review {
        line += "  review: \(r.verdict.rawValue)" + (r.correctedKey.map { " -> \($0)" } ?? "") + (r.note.map { " (\($0))" } ?? "")
    }
    return line
}

let tools: [Tool] = [
    Tool(name: "list_sessions",
         description: "List the sermon sessions saved in Word Cue Lab, with how many segments, reviews and misses each has.",
         properties: [:], required: []) { _ in
        let all = store.sessions()
        if all.isEmpty { return "No sessions yet. Import a recording or transcript in the Word Cue Lab app first." }
        return all.map { "\($0.name)  (\($0.segments.count) segments, \($0.reviews.count) reviewed, \($0.misses.count) misses, \($0.transcribedBy))" }
            .joined(separator: "\n")
    },
    Tool(name: "get_transcript",
         description: "Get the transcript of a session. Optional from/to limit it to a range of segment numbers (starting at 0).",
         properties: ["session": ["type": "string", "description": "Session name"],
                      "from": ["type": "integer"], "to": ["type": "integer"]],
         required: ["session"]) { args in
        let s = try loadSession(args)
        let from = max(0, args["from"] as? Int ?? 0)
        let to = min(s.segments.count, args["to"] as? Int ?? s.segments.count)
        guard from < to else { return "(no segments in that range; the session has \(s.segments.count))" }
        return s.segments[from..<to].enumerated()
            .map { "[\(from + $0.offset) \(clock($0.element.start))] \($0.element.text)" }.joined(separator: "\n")
    },
    Tool(name: "get_detections",
         description: "Run the Word Cue detector over a session and list every reference it finds, with time, confidence, flags, the words heard and any review.",
         properties: ["session": ["type": "string"],
                      "quotes": ["type": "boolean", "description": "Also match quoted scripture with no reference (Beta)"]],
         required: ["session"]) { args in
        let s = try loadSession(args)
        let found = LabStore.findings(in: s, engine: engine, quotes: args["quotes"] as? Bool ?? false)
        let sum = LabStore.summary(found, misses: s.misses.count)
        var lines = found.map(describe)
        lines.append("")
        lines.append("\(found.count) detections: \(sum.correct) correct, \(sum.wrong) wrong, \(sum.falseAlarms) false alarms, \(sum.unreviewed) not reviewed, \(sum.missed) missed.")
        for m in s.misses { lines.append("MISSED: expected \(m.expect) for \"\(m.text)\"") }
        return lines.joined(separator: "\n")
    },
    Tool(name: "detect",
         description: "Run the Word Cue detector on any text and show what it finds. Use this to try out phrasings.",
         properties: ["text": ["type": "string"],
                      "mode": ["type": "string", "enum": ["speech", "document"]],
                      "quotes": ["type": "boolean"]],
         required: ["text"]) { args in
        let text = try string(args, "text")
        let mode = DetectionMode(rawValue: args["mode"] as? String ?? "speech") ?? .speech
        let found = engine.detect(text, mode: mode, quotes: args["quotes"] as? Bool ?? false)
        if found.isEmpty { return "No reference found." }
        return found.map { "\(engine.display($0.reference))  [\($0.key)]  \(Int($0.confidence * 100))%  \($0.kind.rawValue)  flags: \($0.flags.joined(separator: ","))  heard: \"\($0.text)\"" }
            .joined(separator: "\n")
    },
    Tool(name: "lookup_verse",
         description: "Look up King James verse text for a reference such as \"Acts 2:38\" or \"John 3:16-18\".",
         properties: ["reference": ["type": "string"]], required: ["reference"]) { args in
        let text = try string(args, "reference")
        guard let d = engine.detect(text, mode: .document).first ?? engine.detect(text).first else {
            throw ToolError(message: "Could not read \"\(text)\" as a reference.")
        }
        return KJVStore.shared.verses(for: d.reference).prefix(40).map { "\($0.chapter):\($0.number) \($0.text)" }.joined(separator: "\n")
    },
    Tool(name: "review_detection",
         description: "Record a review of one detection in a session. Use the bracketed key and the heard text from get_detections to pick it.",
         properties: ["session": ["type": "string"],
                      "key": ["type": "string", "description": "The detection's key, e.g. \"1KI 13:20\""],
                      "verdict": ["type": "string", "enum": ["correct", "wrong", "falseAlarm"]],
                      "corrected": ["type": "string", "description": "For wrong: the right reference, e.g. \"1 Kings 13:2\""],
                      "note": ["type": "string"]],
         required: ["session", "key", "verdict"]) { args in
        var s = try loadSession(args)
        let key = try string(args, "key")
        guard let verdict = LabReview.Verdict(rawValue: try string(args, "verdict")) else { throw ToolError(message: "verdict must be correct, wrong or falseAlarm.") }
        let found = LabStore.findings(in: s, engine: engine, quotes: true)
        guard let f = found.first(where: { $0.detection.key == key && $0.review == nil }) ?? found.first(where: { $0.detection.key == key }) else {
            throw ToolError(message: "No detection with key \(key) in that session.")
        }
        var corrected: String?
        if let c = args["corrected"] as? String, !c.isEmpty {
            guard let k = LabStore.key(for: c, engine: engine) else { throw ToolError(message: "Could not read \"\(c)\" as a reference.") }
            corrected = k
        }
        s.reviews[f.reviewKey] = LabReview(verdict: verdict, correctedKey: corrected, note: args["note"] as? String)
        store.save(s)
        return "Saved: \(f.display) marked \(verdict.rawValue)" + (corrected.map { ", should be \($0)" } ?? "") + "."
    },
    Tool(name: "add_miss",
         description: "Record a reference the detector missed in a session: the words as transcribed, and the reference they should produce.",
         properties: ["session": ["type": "string"], "text": ["type": "string"], "expect": ["type": "string", "description": "e.g. \"Acts 1:8\""]],
         required: ["session", "text", "expect"]) { args in
        var s = try loadSession(args)
        let expect = try string(args, "expect")
        guard let key = LabStore.key(for: expect, engine: engine) else { throw ToolError(message: "Could not read \"\(expect)\" as a reference.") }
        s.misses.append(LabMiss(text: try string(args, "text"), expect: key))
        store.save(s)
        return "Saved a miss: expected \(key)."
    },
    Tool(name: "propose_cases",
         description: "Turn a session's reviews (wrong, false alarm) and misses into test cases and add them to proposed-cases.json for a person to move into the engine's cases.json.",
         properties: ["session": ["type": "string"]], required: ["session"]) { args in
        let s = try loadSession(args)
        let cases = LabStore.cases(from: s, findings: LabStore.findings(in: s, engine: engine, quotes: true))
        if cases.isEmpty { return "Nothing to propose: no wrong detections, false alarms or misses are recorded for this session." }
        let total = store.propose(cases)
        return "Added \(cases.count) case(s). proposed-cases.json now holds \(total). File: \(store.proposedCasesURL.path)"
    }
]

// MARK: - JSON-RPC over stdin/stdout

func reply(_ id: Any, result: [String: Any]) {
    send(["jsonrpc": "2.0", "id": id, "result": result])
}

func replyError(_ id: Any, _ code: Int, _ message: String) {
    send(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
}

func send(_ object: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: object),
          let line = String(data: data, encoding: .utf8) else { return }
    print(line)
    fflush(stdout)
}

while let line = readLine(strippingNewline: true) {
    guard let data = line.data(using: .utf8),
          let message = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let method = message["method"] as? String else { continue }
    guard let id = message["id"] else { continue }      // a notification: nothing to answer
    let params = message["params"] as? [String: Any] ?? [:]
    switch method {
    case "initialize":
        reply(id, result: [
            "protocolVersion": params["protocolVersion"] as? String ?? "2024-11-05",
            "capabilities": ["tools": [String: Any]()],
            "serverInfo": ["name": "wordcue-lab", "version": "0.1.0"]
        ])
    case "ping":
        reply(id, result: [:])
    case "tools/list":
        reply(id, result: ["tools": tools.map { t in
            ["name": t.name, "description": t.description,
             "inputSchema": ["type": "object", "properties": t.properties, "required": t.required] as [String: Any]] as [String: Any]
        }])
    case "tools/call":
        let name = params["name"] as? String ?? ""
        guard let tool = tools.first(where: { $0.name == name }) else {
            replyError(id, -32602, "Unknown tool \(name)")
            continue
        }
        do {
            let text = try tool.run(params["arguments"] as? [String: Any] ?? [:])
            reply(id, result: ["content": [["type": "text", "text": text]], "isError": false])
        } catch let e as ToolError {
            reply(id, result: ["content": [["type": "text", "text": e.message]], "isError": true])
        } catch {
            reply(id, result: ["content": [["type": "text", "text": error.localizedDescription]], "isError": true])
        }
    default:
        replyError(id, -32601, "Method not found: \(method)")
    }
}
