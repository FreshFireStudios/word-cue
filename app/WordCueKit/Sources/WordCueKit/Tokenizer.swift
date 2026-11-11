// UNTESTED: written without a Swift compiler. Mirrors tokenize() in
// engine-python/wordcue_engine.py. Verify with `swift test` on the Mac.
import Foundation

enum Tokenizer {
    static let punctuation: Set<String> = [":", ";", ",", ".", "-", "\u{2013}", "\u{2014}"]

    /// Lower-cases and splits text into words, numbers and the few punctuation
    /// marks that matter (: ; , . and dashes). Everything else is dropped.
    ///
    /// Same result as the Python pattern
    /// `[0-9]+(?:st|nd|rd|th)?|[a-z]+(?:'[a-z]+)*|[:;,.\-–—]`
    static func tokenize(_ text: String) -> [String] {
        let chars = Array(text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'").unicodeScalars)
        var tokens: [String] = []
        var i = 0
        let n = chars.count

        func isDigit(_ c: Unicode.Scalar) -> Bool { c >= "0" && c <= "9" }
        func isLetter(_ c: Unicode.Scalar) -> Bool { c >= "a" && c <= "z" }
        func string(_ from: Int, _ to: Int) -> String {
            var s = String.UnicodeScalarView()
            s.append(contentsOf: chars[from..<to])
            return String(s)
        }

        while i < n {
            let c = chars[i]
            if isDigit(c) {
                var j = i
                while j < n && isDigit(chars[j]) { j += 1 }
                // optional ordinal ending: 1st 2nd 3rd 4th
                if j + 1 < n {
                    let pair = string(j, j + 2)
                    if pair == "st" || pair == "nd" || pair == "rd" || pair == "th" { j += 2 }
                }
                tokens.append(string(i, j))
                i = j
            } else if isLetter(c) {
                var j = i
                while j < n && isLetter(chars[j]) { j += 1 }
                // apostrophes inside a word: don't, y'all
                while j + 1 < n && chars[j] == "'" && isLetter(chars[j + 1]) {
                    j += 1
                    while j < n && isLetter(chars[j]) { j += 1 }
                }
                tokens.append(string(i, j))
                i = j
            } else {
                let s = String(c)
                if punctuation.contains(s) { tokens.append(s) }
                i += 1
            }
        }
        return tokens
    }

    /// Puts matched tokens back together for display ("acts 2:38").
    static func join(_ tokens: ArraySlice<String>) -> String {
        var s = ""
        for w in tokens {
            if !s.isEmpty && !punctuation.contains(w) && !s.hasSuffix(":") && !s.hasSuffix("-") {
                s += " "
            }
            s += w
        }
        return s
    }
}
