// UNTESTED: written without Xcode.
import SwiftUI

/// A small strip showing only the selected suggestion, for tight screens.
struct CompactView: View {
    @Environment(AppModel.self) private var model

    private var current: Suggestion? {
        model.visibleSuggestions.first { $0.id == model.selectedID } ?? model.visibleSuggestions.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(model.status == .listening ? Theme.green : Theme.dim).frame(width: 8, height: 8)
                Text(model.status == .listening ? "Listening" : "Not listening").font(.caption).foregroundStyle(Theme.dim)
                Spacer()
                Text("\(model.visibleSuggestions.filter { $0.state == .pending }.count) waiting")
                    .font(.caption).foregroundStyle(Theme.dim)
                Button { model.compact = false } label: { Image(systemName: "rectangle.expand.vertical") }
                    .buttonStyle(.plain)
                    .help("Full sidebar (Command-K)")
                    .accessibilityLabel("Full sidebar")
            }
            if let s = current {
                Text(s.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(s.state == .onScreen ? Theme.green : Theme.amber)
                Text(s.currentVerse?.text ?? "")
                    .font(.system(.callout, design: .serif))
                    .lineLimit(2)
                HStack {
                    Button(s.state == .onScreen ? "On Screen" : "Send") { model.send(s.id) }
                        .buttonStyle(.borderedProminent)
                        .disabled(s.state == .onScreen)
                    Button("Dismiss") { model.dismissSelected() }
                    Spacer()
                }
                .controlSize(.small)
            } else {
                Text(model.isListening ? "Listening for scripture" : "Press Command-L to start")
                    .font(.headline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
    }
}
