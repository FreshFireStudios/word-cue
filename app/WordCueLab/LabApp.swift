// UNTESTED: written without Xcode.
//
// Word Cue Lab: the developer's bench for Word Cue. It shares the detection
// engine with the app. Load a sermon recording or transcript, see exactly
// what the detector catches, mark what it got wrong or missed, and export
// those as new test cases. Claude can join in through the connector
// (wordcue-lab-mcp, see docs/LAB.md).
import SwiftUI
import UniformTypeIdentifiers
import WordCueKit

@main
struct WordCueLabApp: App {
    @State private var model = LabModel()

    var body: some Scene {
        WindowGroup("Word Cue Lab") {
            LabView()
                .environment(model)
                .frame(minWidth: 980, minHeight: 620)
        }
    }
}

struct LabView: View {
    @Environment(LabModel.self) private var model
    @State private var importing: ImportKind?
    @State private var tab = 0

    enum ImportKind: Identifiable {
        case recording, transcript, corrections
        var id: Int { hashValue }
        var types: [UTType] {
            switch self {
            case .recording: return [.audio, .movie]
            case .transcript: return [.plainText, .json]
            case .corrections: return [.json]
            }
        }
    }

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(selection: $model.selectedID) {
                Section("Sessions") {
                    ForEach(model.sessions) { s in
                        VStack(alignment: .leading) {
                            Text(s.name)
                            Text("\(s.segments.count) segments \u{00B7} \(s.reviews.count) reviewed").font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(s.id)
                    }
                }
            }
            .navigationSplitViewColumnWidth(230)
            .onChange(of: model.selectedID) { model.rerun() }
        } detail: {
            VStack(spacing: 0) {
                Picker("View", selection: $tab) {
                    Text("Detections").tag(0)
                    Text("Transcript").tag(1)
                    Text("Try a Sentence").tag(2)
                    Text("Claude Connector").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(10)
                Divider()
                switch tab {
                case 0: DetectionsTab()
                case 1: TranscriptTab()
                case 2: TryTab()
                default: ConnectorTab()
                }
                Divider()
                HStack {
                    if let busy = model.busy {
                        ProgressView().controlSize(.small)
                        Text(busy)
                    } else {
                        Text(model.message)
                    }
                    Spacer()
                    Text(model.summaryLine)
                }
                .font(.callout).foregroundStyle(.secondary)
                .padding(8)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Menu("Import", systemImage: "square.and.arrow.down") {
                    Button("Sermon Recording\u{2026}") { importing = .recording }
                    Button("Transcript (text or JSON)\u{2026}") { importing = .transcript }
                    Divider()
                    Button("Church Corrections File\u{2026}") { importing = .corrections }
                }
                Toggle("Quoted scripture", isOn: $model.quotes)
                    .toggleStyle(.button)
                    .onChange(of: model.quotes) { model.rerun() }
                Button("Export Cases", systemImage: "square.and.arrow.up") { model.proposeCases() }
                Button("Delete Session", systemImage: "trash") { model.deleteSelected() }.disabled(model.selected == nil)
            }
        }
        .fileImporter(isPresented: Binding(get: { importing != nil }, set: { if !$0 { importing = nil } }),
                      allowedContentTypes: importing?.types ?? [.data]) { result in
            guard case .success(let url) = result, let kind = importing else { return }
            switch kind {
            case .recording: model.importRecording(url)
            case .transcript: model.importTranscript(url)
            case .corrections: model.importCorrections(url)
            }
        }
    }
}

func clock(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }

/// Every reference the detector found, with one-click review.
struct DetectionsTab: View {
    @Environment(LabModel.self) private var model
    @State private var fixing: LabFinding?
    @State private var corrected = ""

    var body: some View {
        if model.selected == nil {
            ContentUnavailableView("No session", systemImage: "waveform",
                                   description: Text("Import a sermon recording or a transcript to begin."))
        } else {
            Table(model.findings) {
                TableColumn("Time") { Text(clock($0.time)).monospacedDigit() }.width(50)
                TableColumn("Verse") { Text($0.display).fontWeight(.semibold) }.width(min: 120, ideal: 150)
                TableColumn("Score") { Text("\(Int($0.detection.confidence * 100))%").monospacedDigit() }.width(46)
                TableColumn("Kind") { Text(($0.detection.flags.isEmpty ? [$0.detection.kind.rawValue] : $0.detection.flags).joined(separator: ", ")).foregroundStyle(.secondary) }
                    .width(min: 80, ideal: 110)
                TableColumn("Heard") { Text($0.detection.text).lineLimit(2) }
                TableColumn("Review") { f in
                    HStack(spacing: 4) {
                        verdictButton(f, .correct, "checkmark", "Correct")
                        verdictButton(f, .wrong, "arrow.triangle.swap", "Wrong verse")
                        verdictButton(f, .falseAlarm, "xmark", "Not a reference")
                        if let k = f.review?.correctedKey { Text(k).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .width(min: 150, ideal: 190)
            }
            .sheet(item: $fixing) { f in
                VStack(alignment: .leading, spacing: 12) {
                    Text("What should it have been?").font(.headline)
                    Text("Word Cue said \(f.display) for \u{201C}\(f.detection.text)\u{201D}.").foregroundStyle(.secondary)
                    TextField("For example 1 Kings 13:2", text: $corrected)
                    HStack {
                        Spacer()
                        Button("Cancel") { fixing = nil }
                        Button("Save") {
                            model.review(f, .wrong, corrected: corrected)
                            fixing = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
                .frame(width: 400)
            }
        }
    }

    private func verdictButton(_ f: LabFinding, _ verdict: LabReview.Verdict, _ icon: String, _ label: String) -> some View {
        let on = f.review?.verdict == verdict
        return Button {
            if on {
                model.review(f, nil)
            } else if verdict == .wrong {
                corrected = ""
                fixing = f
            } else {
                model.review(f, verdict)
            }
        } label: {
            Image(systemName: icon)
        }
        .buttonStyle(.bordered)
        .tint(on ? (verdict == .correct ? .green : .red) : nil)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// The transcript, with a place to record something the detector missed.
struct TranscriptTab: View {
    @Environment(LabModel.self) private var model
    @State private var missText = ""
    @State private var missExpect = ""

    var body: some View {
        VStack(spacing: 0) {
            List(Array((model.selected?.segments ?? []).enumerated()), id: \.offset) { _, segment in
                HStack(alignment: .top) {
                    Text(clock(segment.start)).monospacedDigit().foregroundStyle(.secondary).frame(width: 46, alignment: .leading)
                    Text(segment.text).textSelection(.enabled)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Record a miss").font(.headline)
                HStack {
                    TextField("Paste the words as transcribed", text: $missText)
                    TextField("Should be, e.g. Acts 1:8", text: $missExpect).frame(width: 190)
                    Button("Add") {
                        model.addMiss(text: missText, expect: missExpect)
                        missText = ""
                        missExpect = ""
                    }
                    .disabled(missText.isEmpty || missExpect.isEmpty)
                }
                ForEach(model.selected?.misses ?? []) { m in
                    HStack {
                        Text(m.expect).fontWeight(.semibold)
                        Text(m.text).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Button { model.removeMiss(m.id) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).accessibilityLabel("Remove")
                    }
                }
            }
            .padding(12)
        }
    }
}

/// Type any sentence and see what the detector does with it.
struct TryTab: View {
    @Environment(LabModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            TextField("A sentence a preacher might say", text: $model.tryText, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .textFieldStyle(.roundedBorder)
            let found = model.engine.detect(model.tryText, quotes: model.quotes)
            if found.isEmpty {
                Text("No reference found.").foregroundStyle(.secondary)
            }
            ForEach(found) { d in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(model.engine.display(d.reference)).font(.title3.weight(.bold))
                        Text("\(Int(d.confidence * 100))%").foregroundStyle(.secondary)
                        Text(([d.kind.rawValue] + d.flags).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Heard: \u{201C}\(d.text)\u{201D}").font(.callout).foregroundStyle(.secondary)
                    Text(KJVStore.shared.verses(for: d.reference).first?.text ?? "").font(.system(.body, design: .serif))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
        }
        .padding(16)
    }
}

struct ConnectorTab: View {
    @Environment(LabModel.self) private var model
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connect Claude to the Lab").font(.title2.weight(.semibold))
                Text("The connector is a small program named wordcue-lab-mcp. Claude starts it on this Mac and can then list your sessions, read a transcript, run the detector on any sentence, record reviews and misses, and propose test cases. No API key is used.")
                Text("1. Build it once in Terminal, from the app/WordCueKit folder:").fontWeight(.semibold)
                Text("swift build -c release --product wordcue-lab-mcp").font(.callout.monospaced()).textSelection(.enabled)
                Text("2. Add this to Claude's connector settings, with the real path to your word-cue folder:").fontWeight(.semibold)
                Text(model.connectorConfig)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                Button(copied ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.connectorConfig, forType: .string)
                    copied = true
                }
                Text("Privacy: when Claude asks for a transcript, that text is sent to Claude. Only keep sermons in the Lab that are fine to share that way. Audio is never sent.")
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }
}
