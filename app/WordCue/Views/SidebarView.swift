// UNTESTED: written without Xcode.
import SwiftUI

/// The main window: header, what is on screen now, suggestion cards, live transcript.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            if let banner = model.banner {
                Text(banner)
                    .font(.callout)
                    .foregroundStyle(Theme.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.yellow.opacity(0.08))
            }
            if model.visibleSuggestions.isEmpty {
                EmptyStateView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(model.visibleSuggestions) { suggestion in
                                SuggestionCard(suggestion: suggestion, isSelected: suggestion.id == model.selectedID)
                                    .id(suggestion.id)
                                    .onTapGesture { model.selectedID = suggestion.id }
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: model.selectedID) { _, id in
                        if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }
            if model.settings.showTranscript {
                TranscriptView()
            }
            FooterView()
        }
    }
}

struct HeaderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Button { model.toggleListening() } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 9, height: 9)
                    Text(statusText).font(.headline)
                }
            }
            .buttonStyle(.plain)
            .help("Start or stop listening (Command-L)")
            .accessibilityLabel(model.isListening ? "Stop listening" : "Start listening")

            LevelMeter(level: model.level)
                .frame(width: 54, height: 6)
                .opacity(model.isListening ? 1 : 0.25)

            Spacer()
            Button { model.compact = true } label: { Image(systemName: "rectangle.compress.vertical") }
                .buttonStyle(.plain)
                .help("Compact mode (Command-K)")
                .accessibilityLabel("Compact mode")
            SettingsLink { Image(systemName: "gearshape") }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.panel)
    }

    private var statusText: String {
        switch model.status {
        case .idle: return "Not listening"
        case .preparing: return "Getting ready…"
        case .listening: return "Listening"
        case .problem: return "Needs attention"
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .idle: return Theme.dim
        case .preparing: return Theme.yellow
        case .listening: return Theme.green
        case .problem: return .red
        }
    }
}

struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(Theme.amber).frame(width: geo.size.width * CGFloat(level))
            }
        }
        .accessibilityHidden(true)
    }
}

struct EmptyStateView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            if case .problem(let message) = model.status {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(Theme.yellow)
                Text(message).multilineTextAlignment(.center)
                Button("Try Again") { model.startListening() }
            } else if model.isListening {
                Text("Listening for scripture").font(.title3.weight(.semibold))
                Text("References show up here as they are preached,\nlike \u{201C}Acts 2:38.\u{201D}")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.dim)
            } else {
                Text("Ready when you are").font(.title3.weight(.semibold))
                Text("Press Command-L to start listening,\nor drop a PDF, image or text file here.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.dim)
                Button("Start Listening") { model.startListening() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 6)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TranscriptView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HEARING").font(.caption2.weight(.semibold)).foregroundStyle(Theme.dim)
            (Text(model.transcript.suffix(2).joined(separator: " ") + " ")
                + Text(model.volatileText).foregroundStyle(Theme.dim))
                .font(.callout)
                .lineLimit(3, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.panel)
    }
}

struct FooterView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 14) {
            KeyHint(key: "\u{21A9}", label: "Send")
            KeyHint(key: "\u{232B}", label: "Dismiss")
            KeyHint(key: "\u{2190}\u{2192}", label: "Verse")
            KeyHint(key: "esc", label: "Clear")
            Spacer()
            if model.settings.autoSend {
                Text("AUTO").font(.caption2.weight(.bold)).foregroundStyle(Theme.amber)
                    .help("Auto-send is on: sure matches go to the screen without waiting.")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.charcoal)
    }
}

struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption.monospaced())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            Text(label).font(.caption).foregroundStyle(Theme.dim)
        }
    }
}
