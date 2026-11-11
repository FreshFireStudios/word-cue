// UNTESTED: written without a Swift compiler.
// Runs the same cases.json the Python reference engine passes.
// In Terminal:  cd app/WordCueKit && swift test
import XCTest
@testable import WordCueKit

final class SharedCasesTests: XCTestCase {
    struct CaseFile: Decodable { let cases: [Case] }
    struct Case: Decodable {
        let id: String
        let mode: String
        let text: String
        let expect: [String]
    }

    static let engine = Engine()

    func loadCases() throws -> [Case] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "cases", withExtension: "json"))
        return try JSONDecoder().decode(CaseFile.self, from: Data(contentsOf: url)).cases
    }

    /// Feeds text one word at a time, the way live speech arrives.
    func streamKeys(_ text: String, mode: DetectionMode, small: Bool = false) -> [String] {
        let session = DetectionSession(engine: Self.engine, mode: mode)
        if small {
            session.maxTokens = 40
            session.keepTokens = 10
        }
        var latest: [Int: String] = [:]
        for word in text.components(separatedBy: " ") {
            for event in session.feed(word) {
                switch event {
                case .new(let d), .update(let d): latest[d.start] = d.key
                case .remove(let id): latest[id] = nil
                }
            }
        }
        return latest.keys.sorted().map { latest[$0]! }
    }

    func testEverySharedCase() throws {
        for c in try loadCases() {
            let mode = DetectionMode(rawValue: c.mode) ?? .speech
            let got = Self.engine.detect(c.text, mode: mode).map(\.key)
            XCTAssertEqual(got, c.expect, "\(c.id): \(c.text)")
            XCTAssertEqual(streamKeys(c.text, mode: mode), c.expect, "\(c.id) (word by word): \(c.text)")
        }
    }

    func testLongStreamWithTrimmingMatchesWholeText() throws {
        let joined = try loadCases().filter { $0.mode == "speech" }.map(\.text).joined(separator: " . ")
        let whole = Self.engine.detect(joined).map(\.key)
        XCTAssertEqual(streamKeys(joined, mode: .speech, small: true), whole)
    }

    func testTokenizer() {
        XCTAssertEqual(Tokenizer.tokenize("Acts 2:38\u{2013}39, y\u{2019}all! 2nd twenty-four 7/29"),
                       ["acts", "2", ":", "38", "\u{2013}", "39", ",", "y'all", "2nd", "twenty", "-", "four", "7", "29"])
    }

    func testKJVLookup() {
        let store = KJVStore()
        let one = store.verses(for: Reference(book: "ACT", chapter: 2, verse: 38))
        XCTAssertEqual(one.count, 1)
        XCTAssertTrue(one[0].text.hasPrefix("Then Peter said unto them, Repent, and be baptized"))
        XCTAssertEqual(store.verses(for: Reference(book: "ACT", chapter: 2, verse: 38, endVerse: 39)).map(\.number), [38, 39])
        XCTAssertEqual(store.verses(for: Reference(book: "PSA", chapter: 117)).count, 2)
        XCTAssertTrue(store.verses(for: Reference(book: "ACT", chapter: 99)).isEmpty)
    }

    func testDisplay() {
        XCTAssertEqual(Self.engine.display(Reference(book: "PSA", chapter: 23)), "Psalm 23")
        XCTAssertEqual(Self.engine.display(Reference(book: "MAT", chapter: 13, verse: 55, endVerse: 58)), "Matthew 13:55\u{2013}58")
    }
}
