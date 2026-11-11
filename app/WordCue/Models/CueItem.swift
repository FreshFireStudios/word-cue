// UNTESTED: written without Xcode.
import Foundation
import WordCueKit

/// One verse Word Cue has cued: the Likely Match while it waits, then a row
/// in This Service.
struct CueItem: Identifiable, Equatable {
    let id = UUID()
    var detectionID: Int?           // ties it to a spot in the live transcript
    var reference: Reference
    var title: String               // "Acts 2:38" or "Matthew 13:55–58"
    var verses: [Verse]
    var slide = 0                   // which slide of a longer passage is up
    var confidence: Double
    var heard: String
    var source: LogEntry.Source
    var outcome: LogEntry.Outcome = .waiting
    var provisional = false         // heard, but the recogniser has not settled yet
    var time = Date()
    var correctedKey: String?

    static func == (a: CueItem, b: CueItem) -> Bool {
        a.id == b.id && a.outcome == b.outcome && a.slide == b.slide && a.reference == b.reference
            && a.provisional == b.provisional && a.correctedKey == b.correctedKey
    }

    /// Verses grouped into slides. perSlide 0 = the whole passage on one slide.
    func slides(perSlide: Int) -> [[Verse]] {
        guard perSlide > 0 else { return verses.isEmpty ? [] : [verses] }
        return stride(from: 0, to: verses.count, by: perSlide).map { Array(verses[$0..<min($0 + perSlide, verses.count)]) }
    }

    /// What goes to the presentation app for the current slide.
    func verseItem(perSlide: Int, bookName: String, translation: String) -> VerseItem? {
        let all = slides(perSlide: perSlide)
        guard all.indices.contains(slide), let first = all[slide].first, let last = all[slide].last else { return nil }
        var title = "\(bookName) \(first.chapter):\(first.number)"
        if last.number != first.number { title += "\u{2013}\(last.number)" }
        let text = all[slide].map(\.text).joined(separator: " ")
        return VerseItem(reference: Reference(book: first.book, chapter: first.chapter, verse: first.number,
                                              endVerse: last.number == first.number ? nil : last.number),
                         title: title, text: text, translation: translation)
    }

    var logEntry: LogEntry {
        var e = LogEntry(reference: reference, title: title, confidence: confidence, heard: heard, source: source)
        e.id = id
        e.time = time
        e.outcome = outcome
        e.correctedKey = correctedKey
        return e
    }
}
