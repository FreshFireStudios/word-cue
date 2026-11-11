// UNTESTED: written without Xcode.
// The studio's colours (same values as the Word Cue website).
import SwiftUI

enum Theme {
    static let charcoal = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1A / 255)
    static let window = Color(red: 0x24 / 255, green: 0x23 / 255, blue: 0x21 / 255)
    static let panel = Color(red: 0x20 / 255, green: 0x1F / 255, blue: 0x1D / 255)
    static let card = Color.white.opacity(0.05)
    static let text = Color(red: 0xF2 / 255, green: 0xF0 / 255, blue: 0xEC / 255)
    static let dim = Color(red: 0x9E / 255, green: 0x99 / 255, blue: 0x8F / 255)
    static let orange = Color(red: 0xB8 / 255, green: 0x5A / 255, blue: 0x1B / 255)
    static let amber = Color(red: 0xF0 / 255, green: 0xA0 / 255, blue: 0x50 / 255)
    static let green = Color(red: 0x5B / 255, green: 0xD2 / 255, blue: 0x7A / 255)
    static let yellow = Color(red: 0xE8 / 255, green: 0xC3 / 255, blue: 0x5A / 255)

    /// Green when sure, yellow when it is a good guess, grey when it is a long shot.
    static func confidenceColor(_ value: Double) -> Color {
        value >= 0.85 ? green : (value >= 0.6 ? yellow : dim)
    }

    static func confidenceWord(_ value: Double) -> String {
        value >= 0.85 ? "Sure" : (value >= 0.6 ? "Likely" : "Maybe")
    }
}
