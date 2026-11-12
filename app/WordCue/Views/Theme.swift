// UNTESTED: written without Xcode.
// The look of Word Cue, taken from the figures in the User Guide: a warm
// near-black window, pill buttons, burnt orange for the one action that
// matters (Send), amber for small accents, green only for "healthy".
// Each status colour has one job: green healthy, amber/yellow a verse is
// waiting, red a problem.
import SwiftUI
import AppKit
import WordCueKit

enum Theme {
    /// A colour with a light and a dark value. The guide's figures are the dark values.
    private static func dyn(_ light: UInt32, _ dark: UInt32, alpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let v = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                           blue: CGFloat(v & 0xFF) / 255, alpha: alpha)
        })
    }

    static let window = dyn(0xF4F2EE, 0x232220)       // the window itself
    static let raise = dyn(0xFFFFFF, 0x2E2D2A)        // cards and the settings sidebar
    static let raise2 = dyn(0xE7E4DE, 0x3A3936)       // pills, selects, off switches
    static let inset = dyn(0xECE9E3, 0x191817)        // meter and preview boxes
    static let hair = dyn(0x000000, 0xFFFFFF, alpha: 0.08)
    static let text = dyn(0x1C1C1A, 0xF4F2EE)
    static let dim = dyn(0x6B665E, 0x9A958C)
    static let faint = dyn(0x9A958C, 0x6F6B64)
    static let verse = dyn(0x33312D, 0xDDD9D2)

    static let orange = Color(red: 0xC2 / 255, green: 0x61 / 255, blue: 0x1F / 255)
    static let amber = dyn(0xB86A12, 0xF0A050)
    static let green = dyn(0x1F9D4C, 0x4ADE80)
    static let red = dyn(0xD23F36, 0xF0685F)
    static let redFill = dyn(0xFBE3E0, 0x4A2320)
    static let yellow = amber

    static func accent(_ hex: String) -> Color {
        guard hex.count == 6, let v = Int(hex, radix: 16) else { return orange }
        return Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    static func scheme(_ choice: AppearanceChoice) -> ColorScheme? {
        switch choice {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Confidence is shown as words, as in the guide ("High confidence").
    /// The guide only shows the top level; "Likely" and "Possible" are placeholders for Bryson to confirm.
    static func confidence(_ value: Double) -> (label: String, color: Color) {
        value >= 0.85 ? ("High confidence", green) : (value >= 0.72 ? ("Likely", amber) : ("Possible", dim))
    }

    /// The wordmark. Plus Jakarta Sans is the brand face; until the font file
    /// is added to the project this falls back to the system semibold.
    static func wordmark(_ size: CGFloat) -> Font {
        NSFont(name: "PlusJakartaSans-Bold", size: size) != nil
            ? .custom("PlusJakartaSans-Bold", size: size) : .system(size: size, weight: .semibold)
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

// MARK: - Small parts used on every screen

/// Pill buttons. `.primary` is the orange one (Send, Start Listening, Continue).
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .secondary
    var wide = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(kind == .primary ? Color.white : (kind == .danger ? Theme.red : Theme.text))
            .padding(.horizontal, 14)
            .padding(.vertical, wide ? 8 : 5)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(kind == .primary ? Theme.orange : (kind == .danger ? Theme.red.opacity(0.14) : Theme.raise2), in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .contentShape(Capsule())
    }
}

/// The dim key hint inside a button: "Send ↩", "Skip esc".
struct KeyHint: View {
    let text: String
    var onPrimary = false
    var body: some View {
        Text(text).font(.system(size: 10.5)).foregroundStyle(onPrimary ? Color.white.opacity(0.75) : Theme.faint)
    }
}

/// A key cap box, as in the Shortcuts table.
struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .frame(width: 52)
            .padding(.vertical, 3)
            .background(Theme.window, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.hair))
    }
}

/// The small rounded-square icon at the start of a row.
struct IconTile: View {
    enum Tint { case orange, green, blue, purple, neutral }
    let symbol: String
    var tint: Tint = .orange
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(fg)
            .frame(width: size, height: size)
            .background(bg, in: RoundedRectangle(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }

    private var fg: Color {
        switch tint {
        case .orange: return Theme.amber
        case .green: return Theme.green
        case .blue: return Color(red: 0.55, green: 0.70, blue: 1)
        case .purple: return Color(red: 0.72, green: 0.63, blue: 1)
        case .neutral: return Theme.dim
        }
    }

    private var bg: Color {
        switch tint {
        case .orange: return Theme.orange.opacity(0.25)
        case .green: return Theme.green.opacity(0.16)
        case .blue: return Color(red: 0.35, green: 0.59, blue: 1).opacity(0.18)
        case .purple: return Color(red: 0.63, green: 0.47, blue: 1).opacity(0.2)
        case .neutral: return Theme.raise2
        }
    }
}

/// "● Listening", "● Ready", "● No audio".
struct StatusPill: View {
    let text: String
    var color: Color? = nil      // nil = grey

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color ?? Theme.dim).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(color ?? Theme.dim)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background((color ?? Theme.dim).opacity(color == nil ? 0.12 : 0.13), in: Capsule())
    }
}

/// The little amber bar meter beside the status pill.
struct MicBars: View {
    let level: Float      // 0...1
    private let shape: [CGFloat] = [0.45, 0.75, 1.0, 0.7, 0.4, 0.3]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(shape.indices, id: \.self) { i in
                let lit = Float(i) / Float(shape.count) < max(level, 0.05) * 1.4
                RoundedRectangle(cornerRadius: 1)
                    .fill(lit ? Theme.amber : Theme.raise2)
                    .frame(width: 2.5, height: lit ? 3 + 9 * shape[i] * CGFloat(min(1, level * 1.6 + 0.25)) : 3)
            }
        }
        .frame(height: 12, alignment: .bottom)
        .animation(.easeOut(duration: 0.15), value: level)
        .accessibilityHidden(true)
    }
}

/// "● High confidence"
struct ConfidenceLabel: View {
    let value: Double
    var body: some View {
        let c = Theme.confidence(value)
        HStack(spacing: 4) {
            Circle().fill(c.color).frame(width: 5, height: 5)
            Text(c.label).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(c.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(c.label), \(Int(value * 100)) percent")
    }
}

/// Green check or red x beside the presentation app's name.
struct AppBadge: View {
    let name: String
    let connected: Bool?

    var body: some View {
        HStack(spacing: 5) {
            switch connected {
            case .some(true): Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            case .some(false): Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.red)
            case .none: ProgressView().controlSize(.mini)
            }
            Text(name).font(.system(size: 11, weight: .semibold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) \(connected == true ? "connected" : "not connected")")
    }
}

/// The flame mark.
struct Flame: View {
    var size: CGFloat = 11
    var body: some View {
        Image(systemName: "flame.fill").font(.system(size: size)).foregroundStyle(Theme.amber).accessibilityHidden(true)
    }
}

/// Orange square checkbox, as in the Settings figures.
struct OrangeCheckbox: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(alignment: .top, spacing: 9) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(configuration.isOn ? Theme.orange : Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white).opacity(configuration.isOn ? 1 : 0))
                    .padding(.top, 2)
                configuration.label
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

/// A pill-shaped segmented control; the chosen segment is solid orange.
struct Segmented<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, label in
                Button { selection = value } label: {
                    Text(label)
                        .font(.system(size: 10.5, weight: selection == value ? .bold : .regular))
                        .foregroundStyle(selection == value ? Color.white : Theme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selection == value ? Theme.orange : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Theme.window, in: Capsule())
    }
}

/// A dark pill that opens a menu of choices.
struct SelectPill<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { value, label in
                Button(label) { selection = value }
            }
        } label: {
            HStack(spacing: 5) {
                Text(options.first { $0.0 == selection }?.1 ?? "").font(.system(size: 10.5))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 7)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Theme.raise2, in: RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// A small dark pill holding one word, as in the vocabulary and book lists.
struct Chip: View {
    let text: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(.system(size: 10, weight: .semibold))
            if let onRemove {
                Button(action: onRemove) { Image(systemName: "xmark").font(.system(size: 7, weight: .bold)) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(text)")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Theme.raise2, in: Capsule())
    }
}

/// Lays chips out in rows that wrap.
struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? 400, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in arrange(bounds.width, subviews).points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, points: [CGPoint] = []
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
