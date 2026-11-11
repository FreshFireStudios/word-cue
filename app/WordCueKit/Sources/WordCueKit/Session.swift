// UNTESTED: written without a Swift compiler. Mirrors class Session in
// engine-python/wordcue_engine.py. Verify with `swift test` on the Mac.
import Foundation

/// Live use: feed finalized transcript text as it arrives.
///
/// Every `feed` re-reads the recent transcript, so a reference can grow as
/// more words come in: "Acts 2" appears first, then becomes "Acts 2:38".
/// Re-reading 3,000 words took about 2 ms in the (slower) Python version, so
/// the cost is nothing next to the 1-2 second goal.
public final class DetectionSession {
    public enum Event: Sendable {
        case new(Detection)       // first time this reference shows up
        case update(Detection)    // same spot in the transcript, more detail
        case remove(Int)          // a provisional one turned out to be a repeat; value is Detection.id
    }

    var maxTokens = 3000    // when the buffer grows past this...
    var keepTokens = 300    // ...keep roughly this many and remember the context

    private let engine: Engine
    private let mode: DetectionMode
    private var tokens: [String] = []
    private var base = 0                 // absolute index of tokens[0]
    private var context0 = Context()     // context at tokens[0]
    private var seen: [Int: String] = [:]   // absolute start index -> key last reported

    public init(engine: Engine, mode: DetectionMode = .speech) {
        self.engine = engine
        self.mode = mode
    }

    private func scan(_ tokens: [String]) -> [Detection] {
        engine.detectTokens(tokens, mode: mode, context: context0).detections.map { d in
            var d = d
            d.start += base
            d.end += base
            return d
        }
    }

    /// Adds finalized words and reports what changed.
    public func feed(_ text: String) -> [Event] {
        tokens.append(contentsOf: Tokenizer.tokenize(text))
        var events: [Event] = []
        let detections = scan(tokens)
        for d in detections {
            if let old = seen[d.start] {
                if old != d.key { events.append(.update(d)) }
            } else {
                events.append(.new(d))
            }
            seen[d.start] = d.key
        }
        let live = Set(detections.map { $0.start })
        for start in seen.keys.sorted() where start >= base && !live.contains(start) {
            seen[start] = nil
            events.append(.remove(start))
        }
        if tokens.count > maxTokens {
            trim(detections)
        }
        return events
    }

    /// Detections including words the recogniser has not finalized yet.
    /// Nothing is remembered, so call it as often as you like.
    public func preview(_ volatileText: String) -> [Detection] {
        scan(tokens + Tokenizer.tokenize(volatileText)).filter { seen[$0.start] != $0.key }
    }

    private func trim(_ detections: [Detection]) {
        var cut = tokens.count - keepTokens + base   // absolute
        let dedupe = engine.limits["dedupeTokens"]!
        var moved = true
        while moved {   // never cut through a detection or its de-duplication window
            moved = false
            for d in detections where d.start < cut && (d.end > cut || cut - d.start <= dedupe) {
                cut = d.start
                moved = true
            }
        }
        if let last = detections.last(where: { $0.end <= cut }) {
            context0 = Context(book: last.reference.book, chapter: last.reference.chapter,
                               verse: last.reference.endVerse ?? last.reference.verse, pos: last.end - cut)
        } else {
            context0.pos -= cut - base
        }
        tokens.removeFirst(cut - base)
        base = cut
        seen = seen.filter { $0.key >= cut }
    }
}
