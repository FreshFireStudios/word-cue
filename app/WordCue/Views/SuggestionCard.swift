// UNTESTED: written without Xcode.
import SwiftUI

/// One suggested verse. Return sends the selected card; nothing goes to the
/// screen on its own unless the church has turned on auto-send.
struct SuggestionCard: View {
    @Environment(AppModel.self) private var model
    let suggestion: Suggestion
    let isSelected: Bool

    private var isLive: Bool { suggestion.state == .onScreen }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(suggestion.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isLive ? Theme.green : Theme.amber)
                Spacer()
                stateBadge
            }
            if let verse = suggestion.currentVerse {
                Text(verse.text)
                    .font(.system(.body, design: .serif))
                    .lineLimit(isSelected ? 8 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if suggestion.verses.count > 1 {
                Text("Verse \(suggestion.currentVerse?.number ?? 0) \u{00B7} \(suggestion.verseIndex + 1) of \(suggestion.verses.count)")
                    .font(.caption)
                    .foregroundStyle(Theme.dim)
            }
            if isSelected {
                HStack(spacing: 8) {
                    Button(isLive ? "On Screen" : "Send to Screen") { model.send(suggestion.id) }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLive)
                    if suggestion.verses.count > 1 {
                        Button { model.stepVerse(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous verse")
                        Button { model.stepVerse(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Next verse")
                    }
                    Spacer()
                    Button(isLive ? "Clear" : "Dismiss") { isLive ? model.clearScreen() : model.dismissSelected() }
                }
                .controlSize(.regular)
                Text(suggestion.isFromFile ? "From \(suggestion.heard)" : "Heard: \u{201C}\(suggestion.heard)\u{201D}")
                    .font(.caption)
                    .foregroundStyle(Theme.dim)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isLive ? Theme.green.opacity(0.10) : Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Theme.amber : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
        )
        .opacity(suggestion.state == .provisional ? 0.6 : (suggestion.state == .sent ? 0.55 : 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch suggestion.state {
        case .onScreen:
            Label("On screen", systemImage: "tv").font(.caption.weight(.semibold)).foregroundStyle(Theme.green)
        case .sent:
            Text("Shown").font(.caption).foregroundStyle(Theme.dim)
        case .provisional:
            Text("Listening…").font(.caption).foregroundStyle(Theme.dim)
        default:
            HStack(spacing: 5) {
                Circle().fill(Theme.confidenceColor(suggestion.confidence)).frame(width: 7, height: 7)
                Text(Theme.confidenceWord(suggestion.confidence)).font(.caption).foregroundStyle(Theme.dim)
            }
            .help("How sure Word Cue is: \(Int(suggestion.confidence * 100))%")
        }
    }
}
