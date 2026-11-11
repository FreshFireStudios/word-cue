// UNTESTED: written without Xcode.
import Foundation
import WordCueKit

/// One card in the sidebar: a reference Word Cue thinks the operator may want.
struct Suggestion: Identifiable, Equatable {
    enum State { case provisional, pending, onScreen, sent, dismissed }

    let id = UUID()
    var detectionID: Int?          // ties the card to a spot in the live transcript
    var reference: Reference
    var title: String              // "Acts 2:38"
    var verses: [Verse]
    var verseIndex = 0             // which verse of a range (or chapter) is up
    var confidence: Double
    var heard: String              // the words that triggered it
    var flags: [String] = []
    var state: State = .pending
    var time = Date()
    var isFromFile = false

    var currentVerse: Verse? { verses.indices.contains(verseIndex) ? verses[verseIndex] : nil }

    /// "Acts 2:38" for the verse that is up right now, even inside a range.
    func currentTitle(bookName: String) -> String {
        guard let v = currentVerse else { return title }
        return "\(bookName) \(v.chapter):\(v.number)"
    }

    static func == (a: Suggestion, b: Suggestion) -> Bool {
        a.id == b.id && a.state == b.state && a.verseIndex == b.verseIndex && a.reference == b.reference
    }
}
