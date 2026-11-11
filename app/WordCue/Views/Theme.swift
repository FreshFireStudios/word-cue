// UNTESTED: written without Xcode.
// Apple structure, Fresh Fire identity: native macOS backgrounds, controls
// and type, with the studio's colour on top. Each status colour has one job:
// green is healthy, yellow means a verse is waiting, red means a problem.
import SwiftUI
import WordCueKit

enum Theme {
    static let orange = Color(red: 0xB8 / 255, green: 0x5A / 255, blue: 0x1B / 255)
    static let amber = Color(red: 0xF0 / 255, green: 0xA0 / 255, blue: 0x50 / 255)
    static let green = Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255)
    static let yellow = Color(red: 0xE8 / 255, green: 0xB3 / 255, blue: 0x30 / 255)
    static let red = Color(red: 0xE5 / 255, green: 0x48 / 255, blue: 0x3F / 255)

    static func accent(_ hex: String) -> Color {
        guard hex.count == 6, let v = Int(hex, radix: 16) else { return amber }
        return Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    static func scheme(_ choice: AppearanceChoice) -> ColorScheme? {
        switch choice {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// The wordmark. Plus Jakarta Sans is the brand face; until the font file
    /// is added to the project this falls back to the system's rounded bold.
    static func wordmark(_ size: CGFloat) -> Font {
        NSFont(name: "PlusJakartaSans-Bold", size: size) != nil
            ? .custom("PlusJakartaSans-Bold", size: size) : .system(size: size, weight: .bold, design: .rounded)
    }
}

extension KeyCombo {
    /// The same shortcut in the form SwiftUI menus want.
    var shortcut: KeyboardShortcut? {
        let special: [String: KeyEquivalent] = ["return": .return, "escape": .escape, "space": .space, "delete": .delete,
                                                "left": .leftArrow, "right": .rightArrow, "up": .upArrow, "down": .downArrow]
        var modifiers: EventModifiers = []
        if command { modifiers.insert(.command) }
        if option { modifiers.insert(.option) }
        if control { modifiers.insert(.control) }
        if shift { modifiers.insert(.shift) }
        if let k = special[key] { return KeyboardShortcut(k, modifiers: modifiers) }
        guard key.count == 1, let ch = key.first else { return nil }
        return KeyboardShortcut(KeyEquivalent(ch), modifiers: modifiers)
    }
}

/// A small key cap, as in the footer: ↩ Send.
struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
    }
}
