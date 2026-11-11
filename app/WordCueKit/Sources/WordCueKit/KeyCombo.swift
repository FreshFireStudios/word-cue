// UNTESTED: written without a Swift compiler.
// Shortcuts are stored as plain text like "return", "cmd+b" or "cmd+\".
import Foundation

public struct KeyCombo: Equatable, Sendable {
    public var key: String                 // "return", "escape", "space", "delete", "left", or one character
    public var command = false
    public var option = false
    public var control = false
    public var shift = false

    public init?(_ text: String) {
        var parts = text.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let last = parts.popLast(), !last.isEmpty || text.hasSuffix("+") else { return nil }
        key = last.isEmpty ? "+" : last
        for p in parts {
            switch p {
            case "cmd", "command": command = true
            case "opt", "option", "alt": option = true
            case "ctrl", "control": control = true
            case "shift": shift = true
            default: return nil
            }
        }
    }

    public var text: String {
        (control ? "ctrl+" : "") + (option ? "opt+" : "") + (shift ? "shift+" : "") + (command ? "cmd+" : "") + key
    }

    /// How it reads on a key cap: "⌘B", "↩", "esc".
    public var symbol: String {
        let names = ["return": "\u{21A9}", "escape": "esc", "space": "space", "delete": "\u{232B}",
                     "left": "\u{2190}", "right": "\u{2192}", "up": "\u{2191}", "down": "\u{2193}"]
        return (control ? "\u{2303}" : "") + (option ? "\u{2325}" : "") + (shift ? "\u{21E7}" : "")
            + (command ? "\u{2318}" : "") + (names[key] ?? key.uppercased())
    }

    /// The same key with Control-Option added: the "Anywhere" version that
    /// works while the presentation app is in front.
    public var anywhere: KeyCombo {
        var c = self
        c.control = true
        c.option = true
        c.command = false
        return c
    }

    /// macOS virtual key codes for the keys Word Cue uses (US layout positions).
    public var keyCode: Int? {
        let special = ["return": 36, "escape": 53, "space": 49, "delete": 51, "left": 123, "right": 124, "down": 125, "up": 126, "pagedown": 121, "pageup": 116,
                       "\\": 42, ".": 47, ",": 43, "/": 44, ";": 41, "'": 39, "[": 33, "]": 30, "-": 27, "=": 24, "`": 50]
        if let c = special[key] { return c }
        let letters: [Character: Int] = ["a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
                                         "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21,
                                         "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35,
                                         "l": 37, "j": 38, "k": 40, "n": 45, "m": 46]
        guard key.count == 1, let ch = key.first else { return nil }
        return letters[ch]
    }
}
