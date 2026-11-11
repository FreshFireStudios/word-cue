// UNTESTED: written without Xcode.
// The Service View (User Guide sections 04 and 05): where the operator works
// during a service. Top to bottom: title bar, status row, problem banner,
// Likely Match with Send / Skip, This Service, Live Transcript, footer.
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
            if let problem = model.problem { ProblemBanner(problem: problem) }
            if let notice = model.notice { NoticeBar(text: notice) }
            LikelyMatchArea()
            Divider()
            ThisServiceList()
            if model.s.showLiveTranscript { LiveTranscript() }
            Divider()
            Footer()
        }
        .background(.background)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.orange, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .background(Theme.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "doc.text").font(.largeTitle)
                            Text("Drop to add its verses").font(.headline)
                            Text("PDF, image or text").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.importFiles(urls)
            return !urls.isEmpty
        } isTargeted: { dropTargeted = $0 }
    }
}

struct TitleBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Text("Word Cue").font(Theme.wordmark(15))
            Spacer()
            Button { model.perform("compact") } label: { Image(systemName: "rectangle.compress.vertical") }
                .help("Compact panel")
                .accessibilityLabel("Compact panel")
            SettingsLink { Image(systemName: "gearshape") }
                .accessibilityLabel("Settings")
        }
        .buttonStyle(.plain)
        .padding(.leading, 76)      // clear of the window's close/minimize buttons
        .padding(.trailing, 14)
        .frame(height: 38)
    }
}

struct StatusRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            if model.isListening {
                LevelMeter(level: model.level).frame(width: 56, height: 6)
                if model.musicPlaying {
                    Image(systemName: "music.note").foregroundStyle(.secondary).help("Music is playing, so detection is paused.")
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Text(model.s.presentationApp.displayName).font(.callout).foregroundStyle(.secondary)
                switch model.appConnected {
                case .some(true): Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                case .some(false): Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.red)
                case .none: ProgressView().controlSize(.mini)
                }
            }
            .help(model.connectionNote)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(model.s.presentationApp.displayName) \(model.appConnected == true ? "connected" : "not connected")")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var label: String {
        switch model.status {
        case .ready: return "Ready"
        case .preparing: return "Getting ready"
        case .listening: return "Listening"
        case .paused: return "Paused"
        case .noAudio: return "No audio"
        }
    }

    private var color: Color {
        switch model.status {
        case .ready, .paused: return .gray
        case .preparing, .listening: return Theme.green
        case .noAudio: return Theme.red
        }
    }
}

struct LevelMeter: View {
    let level: Float
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(Theme.green).frame(width: geo.size.width * CGFloat(level))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Only when something is wrong, with a one-click fix.
struct ProblemBanner: View {
    @Environment(AppModel.self) private var model
    let problem: AppModel.Problem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            switch problem {
            case .appLost: Button("Reconnect") { model.reconnect() }
            case .noAudio: SettingsLink { Text("Audio Settings") }
            case .other: Button("Dismiss") { model.problem = nil }
            }
        }
        .controlSize(.small)
        .foregroundStyle(.white)
        .padding(10)
        .background(Theme.red, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var title: String {
        switch problem {
        case .appLost: return "\(model.s.presentationApp.displayName) lost connection"
        case .noAudio: return "No audio"
        case .other: return "Something needs attention"
        }
    }

    private var detail: String {
        switch problem {
        case .appLost(let why): return "Still listening. Verses stay in This Service and can be resent. \(why)"
        case .noAudio: return "Check the USB cable and that the pulpit channel is up on the board."
        case .other(let message): return message
        }
    }
}

struct NoticeBar: View {
    @Environment(AppModel.self) private var model
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            Text(text).font(.callout)
            Spacer()
            if model.canUndoDrop { Button("Undo") { model.undoDrop() } }
            Button { model.notice = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
        }
        .controlSize(.small)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

/// The reference in large type, translation, confidence, how long ago it was
/// heard, and the verse. Send puts it on screen. Skip clears it.
struct LikelyMatchArea: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let w = model.waiting {
                match(w)
            } else {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(14)
    }

    private var emptyText: String {
        switch model.status {
        case .ready: return "Start listening to catch verses as they\u{2019}re preached."
        case .paused: return "Nothing is being detected until you resume."
        default: return model.practiceProgress ?? "Listening for scripture\u{2026}"
        }
    }

    @ViewBuilder
    private func match(_ w: CueItem) -> some View {
        let age = Int(model.now.timeIntervalSince(w.time))
        let overdue = age >= 15
        let slides = w.slides(perSlide: model.s.versesPerSlide)
        HStack {
            Text("LIKELY MATCH").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            if w.provisional {
                Text("Listening\u{2026}").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("\(Int(w.confidence * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .accessibilityLabel("Confidence \(Int(w.confidence * 100)) percent")
            }
        }
        HStack(alignment: .firstTextBaseline) {
            Text(w.title).font(.system(size: 30, weight: .bold))
            if model.s.showAbbreviation { Text(model.s.translation).font(.callout).foregroundStyle(.secondary) }
        }
        Text(overdue ? "Waiting for you \u{00B7} \(age) seconds" : "Heard \(max(age, 1)) second\(age <= 1 ? "" : "s") ago")
            .font(.caption.weight(overdue ? .semibold : .regular))
            .foregroundStyle(overdue ? Theme.yellow : .secondary)
        if slides.indices.contains(w.slide) {
            ScrollView {
                Text(slides[w.slide].map(\.text).joined(separator: " "))
                    .font(.system(.body, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 130)
        }
        if slides.count > 1 {
            HStack {
                Button { model.stepSlide(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous slide")
                Text("Slide \(w.slide + 1) of \(slides.count)").font(.caption).foregroundStyle(.secondary)
                Button { model.stepSlide(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next slide")
            }
            .controlSize(.small)
        }
        HStack(spacing: 8) {
            Button { model.sendWaiting() } label: {
                HStack { Text("Send"); KeyCap(text: "\u{21A9}") }.frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button { model.skipWaiting() } label: {
                HStack { Text("Skip"); KeyCap(text: "esc") }.frame(maxWidth: .infinity)
            }
        }
        .controlSize(.large)
        .disabled(w.provisional || model.problemBlocksSending)
        .opacity(w.provisional ? 0.6 : 1)
    }
}

/// Every verse handled, newest first, with time, tags and Resend.
struct ThisServiceList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THIS SERVICE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
            if model.history.isEmpty {
                Text("Verses you send or skip are listed here.")
                    .font(.callout).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.history) { item in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(item.title).font(.callout.weight(.medium))
                                if item.id == model.onScreenID {
                                    Text("On screen").font(.caption2.weight(.semibold)).foregroundStyle(Theme.green)
                                }
                            }
                            HStack(spacing: 6) {
                                Text(item.time.formatted(date: .omitted, time: .shortened))
                                if let tag = tag(item) { Text(tag) }
                                if item.correctedKey != nil { Text("Marked wrong") }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(item.outcome == .sent || item.outcome == .autoSent ? "Resend" : "Send") { model.resend(item.id) }
                            .controlSize(.small)
                            .disabled(model.problemBlocksSending)
                    }
                    .contextMenu {
                        Button("Mark as Wrong Verse") { model.markWrong(item.id) }
                        Text("Heard: \(item.heard)")
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func tag(_ item: CueItem) -> String? {
        switch item.outcome {
        case .skipped: return "Skipped"
        case .autoSent: return "Auto-sent"
        case .expired: return "Not sent"
        case .added: return "From file"
        default: return nil
        }
    }
}

struct LiveTranscript: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Text("LIVE TRANSCRIPT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            (Text(model.transcript.suffix(2).joined(separator: " ") + " ")
                + Text(model.volatileText).foregroundStyle(.secondary))
                .font(.callout)
                .lineLimit(3, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

struct Footer: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            Button { model.togglePause() } label: {
                HStack { Text(label); KeyCap(text: "space") }
            }
            Spacer()
            if model.s.cueMode == .autoSend {
                Text("AUTO").font(.caption2.weight(.bold)).foregroundStyle(Theme.orange)
                    .help("Auto-send is on: verses at \(Int(model.s.autoSendAt * 100))% or higher go straight to the screen.")
            }
            Button { model.clearScreen() } label: {
                HStack { Text("Clear Screen"); KeyCap(text: "\u{2318}B") }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var label: String {
        switch model.status {
        case .ready: return "Start Listening"
        case .paused: return "Resume"
        default: return "Pause"
        }
    }
}

/// The compact floating panel: status, the reference with confidence, the
/// first line of the verse, and Send, Skip and Clear Screen.
struct CompactPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(model.status == .listening ? "Listening" : (model.status == .paused ? "Paused" : (model.status == .noAudio ? "No audio" : "Ready")))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: model.appConnected == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(model.appConnected == true ? Theme.green : Theme.red)
                    .accessibilityLabel(model.appConnected == true ? "Connected" : "Not connected")
                Button { model.perform("compact") } label: { Image(systemName: "rectangle.expand.vertical") }
                    .buttonStyle(.plain)
                    .help("Full sidebar")
                    .accessibilityLabel("Full sidebar")
            }
            if let w = model.waiting {
                HStack(alignment: .firstTextBaseline) {
                    Text(w.title).font(.title2.weight(.bold))
                    if model.s.showConfidence && !w.provisional {
                        Text("\(Int(w.confidence * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                Text(w.verses.first?.text ?? "").font(.system(.callout, design: .serif)).lineLimit(1)
            } else {
                Text(model.isListening ? "Listening for scripture\u{2026}" : "Not listening")
                    .font(.headline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Send") { model.sendWaiting() }.buttonStyle(.borderedProminent)
                Button("Skip") { model.skipWaiting() }
                Spacer()
                Button("Clear Screen") { model.clearScreen() }
            }
            .controlSize(.small)
            .disabled(model.problemBlocksSending)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .padding(.top, 30)
        .background(.regularMaterial)
    }

    private var dot: Color {
        switch model.status {
        case .listening, .preparing: return model.waiting != nil ? Theme.yellow : Theme.green
        case .noAudio: return Theme.red
        default: return .gray
        }
    }
}
