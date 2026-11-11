// UNTESTED: written without a Swift compiler. Verify with `swift test` on the Mac.
import Foundation

/// One verse of Bible text.
public struct Verse: Identifiable, Hashable, Sendable {
    public let book: String
    public let chapter: Int
    public let number: Int
    public let text: String
    public var id: String { "\(book) \(chapter):\(number)" }
}

/// Verse text lookup. Ships with the King James Version (public domain).
/// kjv.json is about 4 MB and is read once, the first time a verse is needed.
public final class KJVStore: @unchecked Sendable {
    public static let shared = KJVStore()
    public let translation = "KJV"
    private lazy var text: [String: [[String]]] = Resources.load("kjv", as: [String: [[String]]].self)
    private let lock = NSLock()

    public init() {}

    /// The verses for a reference. A chapter-only reference returns the whole chapter.
    public func verses(for ref: Reference) -> [Verse] {
        lock.lock()
        defer { lock.unlock() }
        guard let chapters = text[ref.book], ref.chapter >= 1, ref.chapter <= chapters.count else { return [] }
        let chapter = chapters[ref.chapter - 1]
        let first = ref.verse ?? 1
        let last = ref.endVerse ?? ref.verse ?? chapter.count
        guard first >= 1, last <= chapter.count, first <= last else { return [] }
        return (first...last).map { Verse(book: ref.book, chapter: ref.chapter, number: $0, text: chapter[$0 - 1]) }
    }

    /// Call at launch so the first suggestion does not wait on the file read.
    public func preload() {
        lock.lock()
        _ = text.count
        lock.unlock()
    }
}
