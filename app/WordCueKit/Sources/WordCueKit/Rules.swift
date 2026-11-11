// UNTESTED: written without a Swift compiler. Verify with `swift test` on the Mac.
import Foundation

/// The shared rule files in Resources/. The Python reference engine reads the
/// very same files, so a rule changed there changes both engines.
public struct Book: Codable, Sendable {
    public let id: String
    public let name: String
    public let ordinal: Int?
    public let names: [String]
    public let abbr: [String]
    public let chapters: Int
    public let risky: Bool
    public let mishearings: [String]
    public let singular: String?
}

struct NumberRules: Codable {
    let units: [String: Int]
    let tens: [String: Int]
    let hundred: [String]
    let zero: [String]
    let ordinals: [String: Int]
    let bookOrdinals: [String: Int]
}

struct DetectionRules: Codable {
    let chapterWords: [String]
    let docChapterWords: [String]
    let verseWords: [String]
    let docVerseWords: [String]
    let verseNumberFillers: [String]
    let rangeWords: [String]
    let rangeSymbols: [String]
    let andWords: [String]
    let ofWords: [String]
    let bookIntroWords: [String]
    let nextWords: [String]
    let shortAbbrChapterOnly: [String]
    let limits: [String: Int]
    let confidence: [String: Double]
}

enum Resources {
    static func load<T: Decodable>(_ name: String, as type: T.Type) -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            fatalError("WordCueKit: could not load \(name).json from the package resources")
        }
        return value
    }
}
