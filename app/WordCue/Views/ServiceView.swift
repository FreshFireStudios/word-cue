// UNTESTED: written without Xcode.
// The Service View, built to Figures 7 to 11 of the User Guide.
// Top to bottom: title bar, status row, problem banner, Likely Match with
// Send / Skip, This Service, Live Transcript switch, footer.
import SwiftUI
import UniformTypeIdentifiers
import WordCueKit

struct ServiceView: View {
    @Environment(AppModel.self) private var model
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            TitleBar()
            StatusRow()
            if let problem = model.problem { ProblemBanner(problem: problem).padding(.horizontal, 12).padding(.bottom, 10) }
            LikelyMatchArea().padding(.horizontal, 12)
            ThisServiceList()
            LiveTranscriptRow()
            Footer()
        }
        .foregroundStyle(Theme.text)
        .background(Theme.window)
        .overlay { if dropTargeted { DropZone() } }
        .overlay { if let notice = model.notice { DropToast(title: notice) } }
        .dropDestination(for: URL.self) { urls, _ in
            model.importFiles(urls)
            return !urls.isEmpty
        } isTargeted: { dropTargeted = $0 }
    }
}

struct TitleBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 5) {
            Flame()
            Text("Word Cue").font(Theme.wordmark(12.5))
            Spacer()
            HStack(spacing: 0) {
                Button { model.perform("compact") } label: { Image(systemName: "arrow.down.right.and.arrow.up.left") }
                    .help("Compact panel (Command-\\)")
                    .accessibilityLabel("Compact panel")
                SettingsLink { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(Theme.dim)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Theme.raise, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.leading, 70)      // clear of the window's traffic lights
        .padding(.trailing, 12)
        .frame(height: 36)
    }
}

struct StatusRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            switch model.status {
            case .ready: StatusPill(text: "Ready")
            case .paused: StatusPill(text: "Paused")
            case .preparing: StatusPill(text: "Getting ready", color: Theme.green)
            case .listening: StatusPill(text: "Listening", color: Theme.green)
            case .noAudio: StatusPill(text: "No audio", color: Theme.red)
            }
            if model.status == .listening {
                MicBars(level: model.level)
                if model.musicPlaying {
                    Image(systemName: "music.note").font(.system(size: 10)).foregroundStyle(Theme.dim)
                        .help("Music is playing, so detection is paused.")
                }
            }
            Spacer()
            AppBadge(name: model.s.presentationApp.displayName, connected: model.appConnected)
                .help(model.connectionNote)
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 12)
    }
}

/// Only when something is wrong, with a one-click fix.
struct ProblemBanner: View {
    @Environment(AppModel.self) private var model
    let problem: AppModel.Problem
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.red).font(.system(size: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.red)
                if !compact {
                    Text(detail).font(.system(size: 10.5)).foregroundStyle(Theme.red.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            switch problem {
            case .appLost: Button("Reconnect") { model.reconnect() }.buttonStyle(PillButtonStyle())
            case .noAudio: SettingsLink { Text("Audio Settings") }.buttonStyle(PillButtonStyle())
            case .other: Button("Dismiss") { model.problem = nil }.buttonStyle(PillButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Theme.redFill, in: RoundedRectangle(cornerRadius: 10))
    }

    private var title: String {
        switch problem {
        case .appLost: return "\(model.s.presentationApp.displayName) lost connection"
        case .noAudio: return "No audio from the soundboard interface"
        case .other: return "Something needs attention"
        }
    }

    private var detail: String {
        switch problem {
        case .appLost: return "Verses can\u{2019}t be sent until it\u{2019}s back. Word Cue is still listening."
        case .noAudio: return "Check the USB cable and that the pulpit channel is up on the board."
        case .other(let message): return message
        }
    }
}

/// The reference in large type, translation, confidence, how long ago it was
/// heard, and the verse. Send puts it on screen. Skip clears it.
struct LikelyMatchArea: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Likely Match").font(.system(size: 10.5)).foregroundStyle(Theme.dim)
                Spacer()
                if let w = model.waiting {
                    if w.provisional {
                        Text("Listening\u{2026}").font(.system(size: 10.5)).foregroundStyle(Theme.dim)
                    } else {
                        ConfidenceLabel(value: w.confidence)
                    }
                }
            }
            .padding(.bottom, 6)
            if let w = model.waiting {
                match(w)
            } else {
                HStack(spacing: 9) {
                    IconTile(symbol: "sparkle", tint: .neutral, size: 24)
                    Text(emptyText).font(.system(size: 11)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 14)
            }
        }
    }

    private var emptyText: String {
        if let progress = model.practiceProgress, !model.isListening { return progress }
        switch model.status {
        case .ready: return "Start listening to catch verses as they\u{2019}re preached."
        case .paused: return "Paused. Nothing is being detected until you resume."
        case .noAudio: return "Waiting for audio from the soundboard"
        default: return "Listening for scripture\u{2026}"
        }
    }

    @ViewBuilder
    private func match(_ w: CueItem) -> some View {
        let age = Int(model.now.timeIntervalSince(w.time))
        let slides = w.slides(perSlide: model.s.versesPerSlide)
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(w.title).font(.system(size: 22, weight: .bold))
            if model.s.showAbbreviation {
                Text(model.s.translation).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.amber)
            }
        }
        if age >= 15 && !w.provisional {
            HStack(spacing: 4) {
                Circle().fill(Theme.amber).frame(width: 5, height: 5)
                Text("Waiting for you \u{00B7} \(age) seconds").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Theme.amber)
            }
            .padding(.top, 2).padding(.bottom, 8)
        } else {
            Text("Heard \(max(age, 1)) second\(age <= 1 ? "" : "s") ago").font(.system(size: 10.5)).foregroundStyle(Theme.dim)
                .padding(.top, 2).padding(.bottom, 8)
        }
        if slides.indices.contains(w.slide) {
            ScrollView {
                Text(slides[w.slide].map(\.text).joined(separator: " "))
                    .font(.system(size: 11.5))
                    .lineSpacing(3)
                    .foregroundStyle(Theme.verse)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 110)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, slides.count > 1 ? 6 : 12)
        }
        if slides.count > 1 {
            HStack(spacing: 6) {
                Button { model.stepSlide(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous slide")
                Text("Slide \(w.slide + 1) of \(slides.count)").font(.system(size: 10.5)).foregroundStyle(Theme.dim)
                Button { model.stepSlide(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next slide")
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
        }
        HStack(spacing: 8) {
            Button { model.sendWaiting() } label: {
                HStack(spacing: 6) { Text("Send"); KeyHint(text: "\u{21A9}", onPrimary: true) }
            }
            .buttonStyle(PillButtonStyle(kind: .primary, wide: true))
            .layoutPriority(2)
            Button { model.skipWaiting() } label: {
                HStack(spacing: 5) { Text("Skip"); KeyHint(text: "esc") }
            }
            .buttonStyle(PillButtonStyle(wide: true))
            .frame(maxWidth: 96)
        }
        .disabled(w.provisional || model.problemBlocksSending)
        .padding(.bottom, 14)
    }
}

/// Every verse handled, newest first, with time, tags and a resend button.
struct ThisServiceList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.hair).frame(height: 1)
            HStack {
                Text("This Service").font(.system(size: 10.5)).foregroundStyle(Theme.dim)
                Spacer()
                Text("\(model.history.count)").font(.system(size: 10.5)).foregroundStyle(Theme.dim)
            }
            .padding(.top, 10).padding(.bottom, 4)
            if model.history.isEmpty {
                Text("Verses appear here as they\u{2019}re sent.").font(.system(size: 11)).foregroundStyle(Theme.faint).padding(.top, 2)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.history) { item in row(item) }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func row(_ item: CueItem) -> some View {
        let muted = item.outcome == .skipped || item.outcome == .expired
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(item.title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(muted ? Theme.faint : Theme.text)
                Spacer()
                if item.id == model.onScreenID {
                    Text("On screen").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.green)
                } else if let tag = tag(item) {
                    Text(tag.0).font(.system(size: 10, weight: tag.1 ? .semibold : .regular)).foregroundStyle(tag.1 ? Theme.amber : Theme.faint)
                }
                Text(item.time.formatted(date: .omitted, time: .shortened).replacingOccurrences(of: " AM", with: "").replacingOccurrences(of: " PM", with: ""))
                    .font(.system(size: 10.5).monospacedDigit()).foregroundStyle(Theme.faint)
                Button { model.resend(item.id) } label: { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.dim)
                    .disabled(model.problemBlocksSending)
                    .help(item.outcome == .sent || item.outcome == .autoSent ? "Resend to the screen" : "Send to the screen")
                    .accessibilityLabel("Send \(item.title) to the screen")
            }
            .padding(.vertical, 8)
            Rectangle().fill(Theme.hair).frame(height: 1)
        }
        .contextMenu {
            Button("Send to Screen") { model.resend(item.id) }
            Button("Mark as Wrong Verse") { model.markWrong(item.id) }
            Text("Heard: \(item.heard)")
        }
    }

    /// (text, highlighted)
    private func tag(_ item: CueItem) -> (String, Bool)? {
        if item.correctedKey != nil { return ("Marked wrong", false) }
        switch item.outcome {
        case .skipped: return ("Skipped", false)
        case .autoSent: return ("Auto-sent", true)
        case .expired: return ("Not sent", false)
        case .added: return ("From file", false)
        default: return nil
        }
    }
}

/// "› Live Transcript" with its switch; off by default.
struct LiveTranscriptRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(Theme.hair).frame(height: 1)
            HStack(spacing: 6) {
                Image(systemName: settings.s.showLiveTranscript ? "chevron.down" : "chevron.right").font(.system(size: 8, weight: .bold))
                Text("Live Transcript").font(.system(size: 11, weight: .semibold))
                Spacer()
                Toggle("Live Transcript", isOn: $settings.s.showLiveTranscript)
                    .toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(Theme.orange)
            }
            .padding(.top, 4)
            if settings.s.showLiveTranscript {
                (Text(model.transcript.suffix(2).joined(separator: " ") + " ") + Text(model.volatileText).foregroundStyle(Theme.faint))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
                    .lineLimit(3, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

struct Footer: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Button { model.togglePause() } label: {
                HStack(spacing: 5) { Text(label); KeyHint(text: "space", onPrimary: isPrimary) }
            }
            .buttonStyle(PillButtonStyle(kind: isPrimary ? .primary : .secondary, wide: true))
            Button { model.clearScreen() } label: {
                HStack(spacing: 5) {
                    Text("Clear Screen")
                    Text("\u{2318}B").font(.system(size: 10.5)).foregroundStyle(Theme.red.opacity(0.6))
                }
            }
            .buttonStyle(PillButtonStyle(kind: .danger, wide: true))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .overlay(alignment: .top) {
            if model.s.cueMode == .autoSend {
                Text("AUTO-SEND ON").font(.system(size: 8.5, weight: .bold)).foregroundStyle(Theme.amber).offset(y: -11)
                    .help("Verses at \(Int(model.s.autoSendAt * 100))% or higher go straight to the screen.")
            }
        }
    }

    /// Start Listening and Resume are orange; Pause is grey.
    private var isPrimary: Bool { model.status == .ready || model.status == .paused }

    private var label: String {
        switch model.status {
        case .ready: return "Start Listening"
        case .paused: return "Resume"
        default: return "Pause"
        }
    }
}

/// The orange dashed zone shown while a file is dragged over the sidebar (Figure 11, left).
struct DropZone: View {
    var body: some View {
        ZStack {
            Theme.window.opacity(0.88)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.orange, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .padding(8)
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Theme.orange, in: RoundedRectangle(cornerRadius: 9))
                Text("Drop to add verses").font(.system(size: 12, weight: .semibold))
                Text("Every reference is added to Word Cue, in order.").font(.system(size: 10.5)).foregroundStyle(Theme.dim)
                Text("PDF \u{00B7} Image \u{00B7} Text").font(.system(size: 9.5)).foregroundStyle(Theme.faint)
            }
            .multilineTextAlignment(.center)
            .padding(24)
        }
    }
}

/// The confirmation card after a drop (Figure 11, right), with Undo.
struct DropToast: View {
    @Environment(AppModel.self) private var model
    let title: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: model.canUndoDrop ? "checkmark.circle.fill" : "questionmark.circle.fill")
                .font(.system(size: 22)).foregroundStyle(model.canUndoDrop ? Theme.green : Theme.dim)
            Text(title).font(.system(size: 11.5, weight: .semibold))
            Text(model.noticeDetail).font(.system(size: 10)).foregroundStyle(Theme.dim).multilineTextAlignment(.center)
            if model.canUndoDrop {
                Button { model.undoDrop() } label: { HStack(spacing: 5) { Text("Undo"); KeyHint(text: "\u{2318}Z") } }
                    .buttonStyle(PillButtonStyle())
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: 200)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        .onTapGesture { model.notice = nil }
    }
}

/// The compact floating panel (Figure 8): status, the reference with
/// confidence, the first line of the verse, and Send, Skip and Clear Screen.
struct CompactPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                if !model.problemBlocksSending {
                    switch model.status {
                    case .listening, .preparing: StatusPill(text: "Listening", color: Theme.green)
                    case .noAudio: StatusPill(text: "No audio", color: Theme.red)
                    case .paused: StatusPill(text: "Paused")
                    case .ready: StatusPill(text: "Ready")
                    }
                    if model.status == .listening { MicBars(level: model.level) }
                }
                Spacer()
                AppBadge(name: model.s.presentationApp.displayName, connected: model.appConnected)
                Button { model.perform("compact") } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 9, weight: .semibold))
                        .frame(width: 22, height: 22).background(Theme.raise, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Full sidebar (Command-\\)")
                .accessibilityLabel("Full sidebar")
            }
            if let problem = model.problem, model.problemBlocksSending {
                ProblemBanner(problem: problem, compact: true)
            }
            if let w = model.waiting {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(w.title).font(.system(size: 17, weight: .bold))
                    if model.s.showAbbreviation { Text(model.s.translation).font(.system(size: 9.5, weight: .bold)).foregroundStyle(Theme.amber) }
                    Spacer()
                    if model.s.showConfidence && !w.provisional { ConfidenceLabel(value: w.confidence) }
                }
                Text(w.verses.first?.text ?? "").font(.system(size: 11.5)).foregroundStyle(Theme.verse).lineLimit(1)
            } else {
                HStack(spacing: 9) {
                    IconTile(symbol: "sparkle", tint: .neutral, size: 22)
                    Text(model.isListening ? "Listening for scripture\u{2026}" : "Not listening").font(.system(size: 11)).foregroundStyle(Theme.dim)
                }
                .frame(maxHeight: .infinity)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button { model.sendWaiting() } label: { HStack(spacing: 6) { Text("Send"); KeyHint(text: "\u{21A9}", onPrimary: true) } }
                    .buttonStyle(PillButtonStyle(kind: .primary, wide: true))
                    .disabled(model.waiting == nil || model.waiting?.provisional == true || model.problemBlocksSending)
                Button { model.skipWaiting() } label: { HStack(spacing: 5) { Text("Skip"); KeyHint(text: "esc") } }
                    .buttonStyle(PillButtonStyle(wide: true))
                    .frame(maxWidth: 84)
                    .disabled(model.waiting == nil)
                Button { model.clearScreen() } label: {
                    Image(systemName: "xmark.rectangle").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.red)
                        .frame(width: 26, height: 26).background(Theme.raise, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Clear Screen (Command-B)")
                .accessibilityLabel("Clear Screen")
            }
        }
        .padding(12)
        .foregroundStyle(Theme.text)
        .background(Theme.window)
    }
}
