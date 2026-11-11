// UNTESTED: written without a Swift compiler. Verify with `swift test` on the Mac.
import Foundation

/// A Bible reference: a book, a chapter, and optionally a verse or verse range.
public struct Reference: Hashable, Codable, Sendable {
    public var book: String        // book id from books.json, e.g. "ACT"
    public var chapter: Int
    public var verse: Int?         // nil = the whole chapter
    public var endVerse: Int?      // nil = a single verse

    public init(book: String, chapter: Int, verse: Int? = nil, endVerse: Int? = nil) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.endVerse = endVerse
    }

    /// Stable text form used by the shared tests: "ACT 2:38", "ACT 2", "ACT 2:38-39".
    public var key: String {
        var s = "\(book) \(chapter)"
        if let verse {
            s += ":\(verse)"
            if let endVerse { s += "-\(endVerse)" }
        }
        return s
    }
}

/// One reference the engine found in the transcript.
public struct Detection: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case explicit, followOn }

    public var reference: Reference
    public var start: Int          // index of the first matched token
    public var end: Int            // index after the last matched token
    public var confidence: Double  // 0...1, see rules.json "confidence"
    public var kind: Kind
    public var flags: [String]     // why the score is what it is ("gap", "mishearing", ...)
    public var text: String        // the words that matched

    /// The start position identifies a detection for the whole session.
    public var id: Int { start }
    public var key: String { reference.key }
}

/// The last reference heard, so "verse 4" or "the next verse" can be resolved.
/// `pos` is the token index where that reference ended.
struct Context {
    var book: String?
    var chapter: Int = 0
    var verse: Int?
    var pos: Int = 0
}

public enum DetectionMode: String, Sendable {
    case speech      // live sermon audio
    case document    // text from a dropped PDF, image or text file
}
