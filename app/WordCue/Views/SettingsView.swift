// UNTESTED: written without Xcode.
// Settings, built to Figures 12 to 21 of the User Guide: a sidebar with nine
// panels in four groups and a search box, and the chosen panel on the right
// as captioned cards of rows. One home per setting.
import SwiftUI
import UniformTypeIdentifiers
import WordCueKit

enum SettingsPanel: String, CaseIterable, Identifiable {
    case general = "General"
    case audio = "Audio Input"
    case detection = "Scripture Detection"
    case output = "Verse Output"
    case appearance = "Appearance"
    case shortcuts = "Shortcuts & Controls"
    case filters = "Filters"
    case advanced = "Advanced"
    case support = "Support"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "sun.max"
        case .audio: return "waveform"
        case .detection: return "book"
        case .output: return "display"
        case .appearance: return "paintpalette"
        case .shortcuts: return "keyboard"
        case .filters: return "line.3.horizontal.decrease"
        case .advanced: return "slider.horizontal.3"
        case .support: return "lifepreserver"
        }
    }

    static let groups: [(String, [SettingsPanel])] = [
        ("", [.general]),
        ("Service", [.audio, .detection, .output]),
        ("Customization", [.appearance, .shortcuts, .filters]),
        ("System", [.advanced, .support])
    ]

    /// Every setting's name and the section it lives in, for search (Figure 12).
    var index: [(name: String, section: String)] {
        switch self {
        case .general: return [("Cue mode", "Cue Mode"), ("Auto-send at", "Cue Mode"), ("Start listening", "Startup"), ("Launch Word Cue at login", "Application Basics"), ("Show menu bar icon", "Application Basics"), ("Keep Mac awake while listening", "Application Basics"), ("Confirm before quitting while listening", "Application Basics"), ("Open Service Log", "Quick Links"), ("Run a Practice Session", "Quick Links")]
        case .audio: return [("Enable live listening", "Audio Input"), ("Audio interface", "Input Source"), ("Input channel", "Input Source"), ("Input gain", "Input Source"), ("Noise gate", "Input Source"), ("Pause detection during music", "Listening Behavior"), ("Auto-pause after silence", "Listening Behavior"), ("Speech engine", "Transcription"), ("Language", "Transcription"), ("Custom vocabulary", "Transcription"), ("Keep transcripts for", "Privacy")]
        case .detection: return [("Enable scripture detection", "Scripture Detection"), ("Verse text from", "Bible"), ("Bible translation", "Bible"), ("Second translation", "Bible"), ("Show translation abbreviation on slides", "Bible"), ("Written-style references", "Recognize"), ("Spoken references", "Recognize"), ("Verse ranges", "Recognize"), ("Follow-up verses", "Recognize"), ("Book name variations", "Recognize"), ("Quoted scripture without a reference", "Recognize"), ("Minimum confidence to show", "Accuracy"), ("Detection method", "Accuracy"), ("Detection speed", "Accuracy")]
        case .output: return [("Presentation app", "Connection"), ("Connection method", "Connection"), ("Port", "Connection"), ("Test Connection", "Connection"), ("Reconnect automatically", "Connection"), ("When a verse is sent", "Sending"), ("Verses per slide", "Sending"), ("Include surrounding verses", "Sending"), ("Clear the screen after", "Sending"), ("Play a sound when a verse is waiting", "Waiting Verses"), ("Dismiss unsent verses after", "Waiting Verses"), ("Pair with app", "Window"), ("Show Word Cue when app opens", "Window"), ("Open app when Word Cue starts", "Window"), ("When the app quits", "Window"), ("Snap app beside Word Cue", "Window"), ("Word Cue\u{2019}s screen", "Window")]
        case .appearance: return [("Appearance", "General Appearance"), ("Accent color", "General Appearance"), ("Position", "Compact Panel"), ("Opacity", "Compact Panel"), ("Show confidence level", "Compact Panel"), ("Keep compact panel above other windows", "Compact Panel"), ("Menu bar icon", "Menu Bar"), ("Show listening status in the menu bar", "Menu Bar"), ("Show the waiting verse in the menu bar", "Menu Bar")]
        case .shortcuts: return [("Send", "Service Shortcuts"), ("Skip", "Service Shortcuts"), ("Pause or resume listening", "Service Shortcuts"), ("Clear screen", "Service Shortcuts"), ("Resend last verse", "Service Shortcuts"), ("Switch compact / full", "Service Shortcuts"), ("Show or hide Word Cue", "Service Shortcuts"), ("Shortcuts work while your app is in front", "Anywhere Shortcuts")]
        case .filters: return [("Require a chapter number", "Book Names That Are Common Words"), ("Ignored phrases", "Ignored Phrases"), ("Ignored books", "Ignored Books"), ("Duplicate cooldown", "Repeats")]
        case .advanced: return [("Buffer size", "Audio Engine"), ("On-device model", "Speech Model"), ("Debug logging", "Diagnostics"), ("Logs", "Diagnostics"), ("Diagnostics report", "Diagnostics"), ("Use a custom connection", "Connection Override"), ("Reset all settings", "Reset")]
        case .support: return [("Permissions", "Permissions"), ("Send Feedback", "Send Feedback"), ("Update channel", "Updates"), ("Check for updates", "Updates"), ("Automatic updates", "Updates"), ("Export settings", "Backup"), ("Import settings", "Backup")]
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var panel: SettingsPanel = .general
    @State private var search = ""
    @FocusState private var searching: Bool

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch panel {
                    case .general: GeneralPanel()
                    case .audio: AudioPanel()
                    case .detection: DetectionPanel()
                    case .output: OutputPanel()
                    case .appearance: AppearancePanel()
                    case .shortcuts: ShortcutsPanel()
                    case .filters: FiltersPanel()
                    case .advanced: AdvancedPanel()
                    case .support: SupportPanel()
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 14)
                .padding(.vertical, 14)
            }
        }
        .padding(6)
        .frame(width: 700, height: 680)
        .foregroundStyle(Theme.text)
        .background(Theme.window)
        .ignoresSafeArea(.container, edges: .top)          // sidebar runs under the traffic lights, as in Figure 13
        .toolbar(removing: .title)                          // VERIFY on macOS 27
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onAppear { model.refreshPermissions() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").font(.system(size: 9)).foregroundStyle(Theme.dim)
                TextField("Search settings", text: $search).textFieldStyle(.plain).font(.system(size: 11)).focused($searching)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 10)) }
                        .buttonStyle(.plain).foregroundStyle(Theme.dim).accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Theme.raise2, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(searching ? Theme.orange : Color.clear))
            .padding(.bottom, 6)

            if search.isEmpty {
                ForEach(SettingsPanel.groups, id: \.0) { group in
                    if !group.0.isEmpty {
                        Text(group.0).font(.system(size: 9.5)).foregroundStyle(Theme.faint).padding(.leading, 8).padding(.top, 8).padding(.bottom, 2)
                    }
                    ForEach(group.1) { p in
                        Button { panel = p } label: {
                            HStack(spacing: 7) {
                                Image(systemName: p.icon).font(.system(size: 10)).frame(width: 14)
                                    .foregroundStyle(p == panel ? Color.white : Theme.dim)
                                Text(p.rawValue).font(.system(size: 11, weight: p == panel ? .semibold : .medium))
                                    .foregroundStyle(p == panel ? Color.white : Theme.text)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(p == panel ? Theme.orange : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(p == panel ? .isSelected : [])
                    }
                }
            } else {
                // Results are grouped by panel; each shows the setting and the section it lives in.
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(SettingsPanel.allCases) { p in
                            let hits = p.index.filter { $0.name.localizedCaseInsensitiveContains(search) }
                            if !hits.isEmpty {
                                Text(p.rawValue).font(.system(size: 9.5)).foregroundStyle(Theme.faint).padding(.leading, 8).padding(.top, 8).padding(.bottom, 2)
                                ForEach(hits, id: \.name) { hit in
                                    Button {
                                        panel = p
                                        search = ""
                                    } label: {
                                        HStack(alignment: .top, spacing: 7) {
                                            Image(systemName: p.icon).font(.system(size: 10)).frame(width: 14).foregroundStyle(Theme.dim).padding(.top, 2)
                                            VStack(alignment: .leading, spacing: 0) {
                                                Text(hit.name).font(.system(size: 11, weight: .medium)).multilineTextAlignment(.leading)
                                                Text(hit.section).font(.system(size: 9.5)).foregroundStyle(Theme.dim)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Rectangle().fill(Theme.hair).frame(height: 1)
            HStack(spacing: 7) {
                IconTile(symbol: "flame.fill", tint: .orange)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Word Cue").font(.system(size: 10.5, weight: .bold))
                    Text("by Fresh Fire Studios").font(.system(size: 9)).foregroundStyle(Theme.dim)
                }
            }
            .padding(.top, 8)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 8)
        .padding(.top, 34)      // room for the window's traffic lights
        .padding(.bottom, 10)
        .frame(width: 170)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Building blocks for the panels

/// A small grey caption above a rounded card of rows.
struct SCard<Content: View>: View {
    let caption: String
    @ViewBuilder var content: Content

    init(_ caption: String = "", @ViewBuilder content: () -> Content) {
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !caption.isEmpty {
                Text(caption).font(.system(size: 9.5, weight: .medium)).foregroundStyle(Theme.dim).padding(.leading, 4)
            }
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, 10)
                .background(Theme.raise, in: RoundedRectangle(cornerRadius: 9))
        }
    }
}

/// One row: optional icon tile, bold label, grey description, control at the right, hairline under it.
struct SRow<Trailing: View>: View {
    var symbol: String? = nil
    var tint: IconTile.Tint = .orange
    let title: String
    var sub: String = ""
    var last = false
    @ViewBuilder var trailing: Trailing

    init(_ title: String, _ sub: String = "", symbol: String? = nil, tint: IconTile.Tint = .orange, last: Bool = false,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.sub = sub
        self.symbol = symbol
        self.tint = tint
        self.last = last
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                if let symbol { IconTile(symbol: symbol, tint: tint) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 10.5, weight: .semibold))
                    if !sub.isEmpty {
                        Text(sub).font(.system(size: 9.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.vertical, 8)
            if !last { Rectangle().fill(Theme.hair).frame(height: 1) }
        }
    }
}

/// An orange checkbox row with a label and optional description.
struct SCheck: View {
    let title: String
    var sub: String = ""
    var badge: String = ""
    var last = false
    @Binding var isOn: Bool

    init(_ title: String, _ sub: String = "", badge: String = "", last: Bool = false, isOn: Binding<Bool>) {
        self.title = title
        self.sub = sub
        self.badge = badge
        self.last = last
        self._isOn = isOn
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(title).font(.system(size: 10.5, weight: .semibold))
                        if !badge.isEmpty {
                            Text(badge).font(.system(size: 8.5, weight: .bold)).foregroundStyle(Color(red: 0.55, green: 0.7, blue: 1))
                                .padding(.horizontal, 4).background(Color(red: 0.35, green: 0.59, blue: 1).opacity(0.25), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    if !sub.isEmpty { Text(sub).font(.system(size: 9.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true) }
                }
            }
            .toggleStyle(OrangeCheckbox())
            .padding(.vertical, 8)
            if !last { Rectangle().fill(Theme.hair).frame(height: 1) }
        }
    }
}

/// A labelled slider with its value at the right and a note under it.
struct SSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    let display: String
    var note: String = ""
    var last = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 10.5, weight: .semibold))
            HStack(spacing: 10) {
                Slider(value: $value, in: range, step: step).controlSize(.mini).tint(Theme.orange).accessibilityLabel(title)
                Text(display).font(.system(size: 10).monospacedDigit()).foregroundStyle(Theme.dim).frame(width: 44, alignment: .trailing)
            }
            if !note.isEmpty { Text(note).font(.system(size: 9.5)).foregroundStyle(Theme.dim) }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Theme.hair).frame(height: 1) } }
    }
}

private func sw(_ isOn: Binding<Bool>) -> some View {
    Toggle("", isOn: isOn).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(Theme.orange)
}

private func dot(_ text: String, _ color: Color = Theme.green) -> some View {
    HStack(spacing: 4) {
        Circle().fill(color).frame(width: 6, height: 6)
        Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
    }
}

private func note(_ text: String) -> some View {
    Text(text).font(.system(size: 9.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
}

private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

// MARK: - Home

struct GeneralPanel: View {
    @Environment(AppModel.self) private var model
    @State private var pickingPractice = false
    @State private var showingLog = false

    var body: some View {
        @Bindable var settings = model.settings
        let app = settings.s.presentationApp.displayName
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: "flame.fill", tint: .orange, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text("Word Cue").font(.system(size: 13, weight: .bold))
                    if model.isListening { StatusPill(text: "Listening", color: Theme.green) }
                    else if model.status == .paused { StatusPill(text: "Paused") }
                    else { StatusPill(text: "Ready", color: Theme.green) }
                }
                note("Listens to the pulpit mic, catches scripture as it\u{2019}s preached, and sends it to \(app), all on this Mac.")
                HStack(spacing: 8) {
                    Button { model.togglePause() } label: {
                        Label(model.isListening ? "Pause" : "Start Listening", systemImage: model.isListening ? "pause" : "play")
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    note((model.permissions.microphone ? "Microphone ready" : "Microphone not allowed") + " \u{00B7} "
                         + app + (model.appConnected == true ? " connected" : " not connected"))
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 9))

        SCard("Cue Mode") {
            SRow("Cue mode", "Review first: every verse waits for Send. Auto-send: confident verses go straight to the screen.", symbol: "paperplane") {
                Segmented(selection: $settings.s.cueMode, options: [(.reviewFirst, "Review first"), (.autoSend, "Auto-send")])
            }
            SSlider(title: "Auto-send at", value: $settings.s.autoSendAt, range: 0.80...1.0, step: 0.01, display: percent(settings.s.autoSendAt),
                    note: "Only used in Auto-send mode. Anything below this still waits for review.", last: true)
                .opacity(settings.s.cueMode == .autoSend ? 1 : 0.55)
        }
        SCard("Startup") {
            SRow("Start listening", "When Word Cue begins listening for scripture.", symbol: "power", tint: .purple, last: true) {
                SelectPill(selection: $settings.s.startListening, options: [(.whenAppOpens, "When \(app) opens"), (.manually, "Manually")])
            }
        }
        SCard("Application Basics") {
            SCheck("Launch Word Cue at login", "Needed so Word Cue can appear the moment \(app) opens.", isOn: $settings.s.launchAtLogin)
            SCheck("Show menu bar icon", isOn: $settings.s.showMenuBarIcon)
            SCheck("Keep Mac awake while listening", "Prevents sleep from cutting off detection mid-sermon.", isOn: $settings.s.keepMacAwake)
            SCheck("Confirm before quitting while listening", last: true, isOn: $settings.s.confirmBeforeQuitting)
        }
        SCard("Quick Links") {
            link("Open Service Log", "Review every verse cued in past services.", "list.bullet", .orange) { showingLog = true }
            link("Run a Practice Session", model.practiceProgress ?? "Test detection with a recorded sermon before Sunday.", "play", .green) { pickingPractice = true }
            link("Help & Setup Guides", "Soundboard and \(app) setup walkthroughs.", "questionmark.circle", .blue, last: true) {
                if let url = URL(string: "https://freshfirestudios.github.io/word-cue/") { NSWorkspace.shared.open(url) }
            }
        }
        .fileImporter(isPresented: $pickingPractice, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { model.runPractice(url) }
        }
        .sheet(isPresented: $showingLog) { ServiceLogView().environment(model) }
    }

    private func link(_ title: String, _ sub: String, _ symbol: String, _ tint: IconTile.Tint, last: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SRow(title, sub, symbol: symbol, tint: tint, last: last) {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.dim)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A record of every verse in a service, exportable for the pastor.
struct ServiceLogView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var exported = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Service Log").font(.system(size: 15, weight: .bold))
            List {
                ForEach(model.pastServices) { service in
                    Section(service.started.formatted(date: .complete, time: .shortened)) {
                        ForEach(service.entries) { e in
                            HStack {
                                Text(e.time.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                                Text(e.title)
                                Spacer()
                                Text(e.outcome.rawValue).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if !exported.isEmpty { note(exported) }
            HStack {
                Button("Show in Finder") { NSWorkspace.shared.open(model.logFolder) }.buttonStyle(PillButtonStyle())
                Button("Export This Service") {
                    if let url = try? FeedbackReporter.save(model.exportServiceLog(), name: "Service Log") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                        exported = "Saved as a text file."
                    }
                }
                .buttonStyle(PillButtonStyle())
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(PillButtonStyle(kind: .primary)).keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 520, height: 460)
    }
}

// MARK: - Service

struct AudioPanel: View {
    @Environment(AppModel.self) private var model
    @State private var newWord = ""
    @State private var addingWord = false
    @State private var history: [Float] = Array(repeating: 0, count: 22)

    var body: some View {
        @Bindable var settings = model.settings
        HStack(alignment: .top, spacing: 12) {
            sw($settings.s.liveListening)
            VStack(alignment: .leading, spacing: 2) {
                Text("Enable live listening").font(.system(size: 11, weight: .semibold))
                note("Hear the soundboard feed and transcribe it on this Mac in real time.")
            }
            Spacer(minLength: 8)
            // The meter: input name, live badge, moving bars, speech detected, level.
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text((model.inputDevices.first { $0.uid == settings.s.inputDeviceUID }?.name ?? "Default input")
                         + (settings.s.inputChannel > 0 ? " \u{00B7} Ch \(settings.s.inputChannel)" : "")).lineLimit(1)
                    Spacer()
                    if model.level > 0.02 { StatusPill(text: "Live", color: Theme.green) }
                }
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(history.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1).fill(history[i] > 0.04 ? Theme.amber : Theme.raise2)
                            .frame(width: 2, height: 3 + 27 * CGFloat(history[i]))
                    }
                }
                .frame(height: 30, alignment: .bottom)
                HStack {
                    Text(model.speechDetected ? "Speech detected" : "Quiet")
                    Spacer()
                    Text("\(Int(model.level * 50 - 50)) dB").monospacedDigit()
                }
            }
            .font(.system(size: 9.5))
            .foregroundStyle(Theme.dim)
            .padding(9)
            .frame(width: 200)
            .background(Theme.inset, in: RoundedRectangle(cornerRadius: 8))
            .onChange(of: model.level) { _, new in
                history.removeFirst()
                history.append(new)
            }
        }
        .padding(12)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 9))

        SCard("Input Source") {
            SRow("Audio interface", "The USB interface or input carrying the soundboard feed.", symbol: "cable.connector") {
                SelectPill(selection: $settings.s.inputDeviceUID, options: [("", "System default")] + model.inputDevices.map { ($0.uid, $0.name) })
            }
            SRow("Input channel", "The channel carrying the pulpit mic.", symbol: "slider.horizontal.3", tint: .purple) {
                SelectPill(selection: $settings.s.inputChannel,
                           options: [(0, "Mix of all channels")] + (1...max(1, AudioInput.channelCount(uid: settings.s.inputDeviceUID))).map { ($0, "Channel \($0)") })
            }
            SSlider(title: "Input gain", value: $settings.s.inputGainDB, range: 0...24, display: "+\(Int(settings.s.inputGainDB)) dB")
            VStack(alignment: .leading, spacing: 5) {
                Text("Live level").font(.system(size: 10.5, weight: .semibold))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.raise2)
                        Capsule().fill(Theme.orange).frame(width: geo.size.width * CGFloat(model.level))
                    }
                }
                .frame(height: 3)
            }
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
            SSlider(title: "Noise gate", value: $settings.s.noiseGateDB, range: -70...(-20), display: "\(Int(settings.s.noiseGateDB)) dB",
                    note: "Sounds quieter than this are ignored, like fans or room noise.", last: true)
        }
        SCard("Listening Behavior") {
            SCheck("Pause detection during music", "Skips worship songs so lyrics that quote scripture don\u{2019}t trigger verses.", isOn: $settings.s.pauseDuringMusic)
            SRow("Auto-pause after silence", "Stops listening when the mic has been quiet this long.", last: true) {
                SelectPill(selection: $settings.s.autoPauseAfterSilenceMinutes, options: [(2, "2 minutes"), (5, "5 minutes"), (10, "10 minutes"), (0, "Never")])
            }
        }
        SCard("Transcription") {
            SRow("Speech engine", "Enhanced uses Apple Intelligence on supported Macs.", symbol: "text.bubble", tint: .blue) {
                Segmented(selection: $settings.s.speechEngine, options: [(.standard, "Standard"), (.enhanced, "Enhanced")])
            }
            SRow("Language", symbol: "globe", tint: .neutral) {
                SelectPill(selection: $settings.s.language, options: [("en-US", "English (US)"), ("es-US", "Spanish")])
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom vocabulary").font(.system(size: 10.5, weight: .semibold))
                note("Teach Word Cue names and words your pastor uses often.")
                FlowLayout {
                    ForEach(settings.s.customVocabulary, id: \.self) { word in
                        Chip(text: word) { settings.s.customVocabulary.removeAll { $0 == word } }
                    }
                    if addingWord {
                        TextField("New word", text: $newWord)
                            .textFieldStyle(.plain).font(.system(size: 10)).frame(width: 90)
                            .padding(.horizontal, 9).padding(.vertical, 3).background(Theme.raise2, in: Capsule())
                            .onSubmit {
                                let w = newWord.trimmingCharacters(in: .whitespaces)
                                if !w.isEmpty && !settings.s.customVocabulary.contains(w) { settings.s.customVocabulary.append(w) }
                                newWord = ""
                                addingWord = false
                            }
                    } else {
                        Button { addingWord = true } label: { Chip(text: "Add Word") }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        SCard("Privacy") {
            SRow("Audio never leaves this Mac", "Transcription runs on-device. Audio is never recorded or saved.", symbol: "checkmark.shield", tint: .green)
            SRow("Keep transcripts for", last: true) {
                SelectPill(selection: $settings.s.keepTranscriptsDays, options: [(0, "This service only"), (7, "7 days"), (30, "30 days"), (-1, "Don\u{2019}t keep")])
            }
        }
        .onAppear {
            model.refreshDevices()
            model.startLevelCheck()
        }
        .onDisappear { model.stopLevelCheck() }
    }
}

struct DetectionPanel: View {
    @Environment(AppModel.self) private var model
    private let sample = "\u{2026}open your Bibles to Acts chapter two, verse thirty eight, then Peter said\u{2026}"

    var body: some View {
        @Bindable var settings = model.settings
        let app = settings.s.presentationApp.displayName
        let found = model.engine.detect(sample).first
        HStack(alignment: .top, spacing: 12) {
            sw($settings.s.detectionEnabled)
            VStack(alignment: .leading, spacing: 2) {
                Text("Enable scripture detection").font(.system(size: 11, weight: .semibold))
                note("Finds Bible references in the live transcript and turns them into Likely Matches.")
            }
            Spacer(minLength: 8)
            // The preview: a sample sentence becoming a Likely Match, run through the real engine.
            VStack(alignment: .leading, spacing: 6) {
                Text("Live transcript").font(.system(size: 9.5)).foregroundStyle(Theme.dim)
                (Text("\u{2026}open your Bibles to ")
                 + Text("Acts chapter two, verse thirty eight").foregroundStyle(Theme.amber).bold()
                 + Text(", then Peter said\u{2026}"))
                    .font(.system(size: 10))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Likely Match").font(.system(size: 9.5)).foregroundStyle(Theme.dim)
                        Spacer()
                        if let found, found.confidence >= settings.s.minimumConfidence { ConfidenceLabel(value: found.confidence) }
                        else { Text("Below your minimum").font(.system(size: 9.5)).foregroundStyle(Theme.dim) }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(found.map { model.engine.display($0.reference) } ?? "No match").font(.system(size: 13, weight: .bold))
                        Text(settings.s.translation).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.amber)
                    }
                }
                .padding(7)
                .background(Theme.raise, in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(9)
            .frame(width: 210)
            .background(Theme.inset, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 9))

        SCard("Bible") {
            SRow("Verse text from", settings.s.verseSource == .wordCue
                    ? "Word Cue sends the King James text it includes."
                    : "Word Cue types the reference into \(app)\u{2019}s Bible search, so \(app) shows the translation your church owns there.",
                 symbol: "text.book.closed", tint: .blue) {
                SelectPill(selection: $settings.s.verseSource, options: [(.wordCue, "Word Cue (KJV)"), (.presentationApp, "\(app)\u{2019}s Bible")])
            }
            if settings.s.verseSource == .presentationApp && !settings.s.presentationApp.apiUsesOwnBible {
                SRow("Typing needs care", "\(app) is brought forward and its Bible search must be ready. Word Cue cannot confirm the verse went live. Needs Accessibility.",
                     symbol: "exclamationmark.triangle", tint: .neutral)
            }
            SRow("Bible translation", settings.s.verseSource == .wordCue ? "Used for the verse text sent to \(app), and shown in Word Cue."
                    : "Shown in Word Cue only. The slide uses \(app)\u{2019}s translation.", symbol: "book") {
                SelectPill(selection: $settings.s.translation, options: [("KJV", "King James Version (KJV)")])
            }
            SRow("Second translation", "Optional parallel translation shown under the first.", symbol: "book", tint: .purple) {
                SelectPill(selection: $settings.s.secondTranslation, options: [("", "None")])
            }
            SCheck("Show translation abbreviation on slides", last: true, isOn: $settings.s.showAbbreviation)
        }
        SCard("Recognize") {
            SCheck("Written-style references", "\u{201C}Acts 2:38\u{201D}", isOn: $settings.s.recognizeWritten)
            SCheck("Spoken references", "\u{201C}Acts chapter two, verse thirty eight\u{201D}", isOn: $settings.s.recognizeSpoken)
            SCheck("Verse ranges", "\u{201C}verses thirty eight through forty\u{201D}", isOn: $settings.s.recognizeRanges)
            SCheck("Follow-up verses", "\u{201C}\u{2026}and verse thirty nine.\u{201D} Uses the last chapter mentioned.", isOn: $settings.s.recognizeFollowUps)
            SCheck("Book name variations", "\u{201C}First John,\u{201D} \u{201C}1st John,\u{201D} \u{201C}Song of Songs\u{201D}", isOn: $settings.s.recognizeBookVariations)
            SCheck("Quoted scripture without a reference", "Matches spoken verse text to the Bible when no reference is said.", badge: "Beta", last: true,
                   isOn: $settings.s.recognizeQuotedScripture)
        }
        SCard("Accuracy") {
            SSlider(title: "Minimum confidence to show", value: $settings.s.minimumConfidence, range: 0.4...0.95, step: 0.05,
                    display: percent(settings.s.minimumConfidence), note: "Anything below this is ignored completely and never appears in Likely Match.")
            SRow("Detection method", settings.s.detectionMethod == .rules
                    ? "Word Cue\u{2019}s rules find every reference, instantly."
                    : "Apple Intelligence double-checks the matches Word Cue is least sure about, on this Mac. " + AppleModelChecker.status.note,
                 symbol: "sparkles", tint: .purple) {
                Segmented(selection: $settings.s.detectionMethod, options: [(.rules, "Rules"), (.rulesPlusApple, "Rules + Apple Intelligence")])
            }
            SRow("Detection speed", "Faster shows verses sooner; More accurate waits for the full sentence.", last: true) {
                Segmented(selection: $settings.s.detectionSpeed, options: [(.faster, "Faster"), (.balanced, "Balanced"), (.moreAccurate, "More accurate")])
            }
        }
    }
}

struct OutputPanel: View {
    @Environment(AppModel.self) private var model
    @State private var testing = false

    var body: some View {
        @Bindable var settings = model.settings
        let app = settings.s.presentationApp.displayName
        let connected = model.appConnected == true
        SCard("Connection") {
            SRow(app, connected ? "Word Cue is talking to \(app) on this Mac." : model.connectionNote, symbol: "display", tint: connected ? .green : .neutral) {
                if connected {
                    dot(settings.s.connectionMethod == .keyboardOnly || !settings.s.presentationApp.hasAPI ? "Connected \u{00B7} Keyboard" : "Connected \u{00B7} API")
                } else {
                    dot("Not connected", Theme.red)
                }
            }
            SRow("Presentation app", symbol: "rectangle.stack") {
                SelectPill(selection: $settings.s.presentationApp, options: PresentationApp.allCases.map { ($0, $0.displayName) })
            }
            SRow("Connection method", "Automatic tries \(app)\u{2019}s API first and falls back to keyboard shortcuts.", symbol: "gearshape", tint: .blue) {
                SelectPill(selection: $settings.s.connectionMethod, options: [(.automatic, "Automatic"), (.apiOnly, "API only"), (.keyboardOnly, "Keyboard only")])
            }
            if settings.s.presentationApp.hasAPI {
                SRow("Port", settings.s.port == 0 ? "Using \(app)\u{2019}s usual port." : "Set by hand.", symbol: "number", tint: .neutral) {
                    TextField("", value: $settings.s.port, format: .number.grouping(.never), prompt: Text(String(settings.s.presentationApp.defaultPort)))
                        .textFieldStyle(.plain).font(.system(size: 10.5)).multilineTextAlignment(.center)
                        .frame(width: 56).padding(.vertical, 4)
                        .background(Theme.window, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hair))
                        .accessibilityLabel("Port")
                }
            }
            if settings.s.connectionMethod != .apiOnly || !settings.s.presentationApp.hasAPI {
                SRow("Key that opens \(app)\u{2019}s Bible search", "Keyboard mode only. Leave empty if the search box is already selected.", symbol: "keyboard", tint: .neutral) {
                    KeyRecorder(text: $settings.s.keyboardOpenSearch)
                }
                if !model.permissions.accessibility {
                    SRow("Accessibility", "Keyboard mode needs it so Word Cue can type for you.", symbol: "hand.raised", tint: .neutral) {
                        Button("Allow\u{2026}") { KeyboardAdapter.requestPermission() }.buttonStyle(PillButtonStyle())
                    }
                }
            }
            HStack(spacing: 10) {
                Button("Test Connection") {
                    testing = true
                    Task {
                        await model.checkConnection()
                        testing = false
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                if testing { ProgressView().controlSize(.small) }
                note("Sends a test signal without changing what\u{2019}s on screen.")
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
            SRow("Reconnect automatically", "If \(app) restarts or the connection drops.", last: true) { sw($settings.s.reconnectAutomatically) }
        }
        SCard("Sending") {
            SRow("When a verse is sent", symbol: "paperplane") {
                SelectPill(selection: $settings.s.whenSent, options: [(.goLive, "Go live immediately"), (.addToServiceList, "Add to the service list")])
            }
            SRow("Verses per slide", symbol: "rectangle.split.1x2", tint: .blue) {
                SelectPill(selection: $settings.s.versesPerSlide, options: [(1, "1 verse"), (2, "2 verses"), (0, "Whole passage")])
            }
            SRow("Include surrounding verses", "Adds context around the verse that was read.", symbol: "text.justify", tint: .purple) {
                SelectPill(selection: $settings.s.surroundingVerses, options: [(0, "None"), (1, "1 before and after")])
            }
            SRow("Clear the screen after", symbol: "clock", tint: .neutral, last: true) {
                SelectPill(selection: $settings.s.clearScreenAfterMinutes, options: [(0, "Never"), (1, "1 minute"), (2, "2 minutes"), (5, "5 minutes")])
            }
        }
        SCard("Waiting Verses") {
            SRow("Play a sound when a verse is waiting") { sw($settings.s.soundWhenWaiting) }
            SRow("Dismiss unsent verses after", last: true) {
                SelectPill(selection: $settings.s.dismissUnsentAfterSeconds, options: [(30, "30 seconds"), (60, "1 minute"), (0, "Never")])
            }
        }
        SCard("Window") {
            SRow("Pair with \(app)", "Word Cue and \(app) come forward and go back together.", symbol: "rectangle.on.rectangle") { sw($settings.s.pairWithApp) }
            SRow("Show Word Cue when \(app) opens", symbol: "macwindow", tint: .blue) { sw($settings.s.showWhenAppOpens) }
            SRow("Open \(app) when Word Cue starts", symbol: "power", tint: .purple) { sw($settings.s.openAppWithWordCue) }
            SRow("When \(app) quits", symbol: "xmark", tint: .neutral) {
                SelectPill(selection: $settings.s.whenAppQuits, options: [(.hide, "Hide Word Cue"), (.quit, "Quit Word Cue")])
            }
            SRow("Snap \(app) beside Word Cue", "Resizes \(app) to fill the rest of the screen. Requires Accessibility permission. Not built yet.",
                 symbol: "rectangle.split.2x1", tint: .neutral) { sw($settings.s.snapAppBeside).disabled(true) }
            SRow("Word Cue\u{2019}s screen", "Where the sidebar lives. Automatic picks this Mac\u{2019}s own display and never the projector.",
                 symbol: "display.2", tint: .blue) {
                SelectPill(selection: $settings.s.operatorScreen, options: [("", "Automatic")] + WindowManager.screenNames.map { ($0, $0) })
            }
            note("Tip: Stage Manager can also group the two apps so they stay together.").padding(.vertical, 8)
        }
    }
}

// MARK: - Customization

struct AppearancePanel: View {
    @Environment(AppModel.self) private var model
    private let accents: [(String, String)] = [("Fresh Fire (default)", "C2611F"), ("Blue", "3B6FE0"), ("Green", "2E9E5B"), ("Purple", "8B5CF6"), ("Graphite", "77736C")]

    var body: some View {
        @Bindable var settings = model.settings
        let app = settings.s.presentationApp.displayName
        SCard("General Appearance") {
            SRow("Appearance") {
                Segmented(selection: $settings.s.appearance, options: [(.system, "System"), (.light, "Light"), (.dark, "Dark")])
            }
            SRow("Accent color", accents.first { $0.1 == settings.s.accentHex }?.0 ?? "Custom", last: true) {
                HStack(spacing: 6) {
                    ForEach(accents, id: \.1) { name, hex in
                        Button { settings.s.accentHex = hex } label: {
                            Circle().fill(Theme.accent(hex)).frame(width: 13, height: 13)
                                .padding(2.5)
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: settings.s.accentHex == hex ? 1.5 : 0))
                        }
                        .buttonStyle(.plain)
                        .help(name)
                        .accessibilityLabel(name)
                        .accessibilityAddTraits(settings.s.accentHex == hex ? .isSelected : [])
                    }
                }
            }
        }
        SCard("Compact Panel") {
            // A live copy of the compact panel, so changes show as they are made.
            ZStack(alignment: alignment(settings.s.panelCorner)) {
                RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.75))
                CompactPanelView()
                    .frame(width: 250, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.hair))
                    .opacity(settings.s.panelOpacity)
                    .padding(10)
                    .allowsHitTesting(false)
            }
            .frame(height: 170)
            .padding(.vertical, 10)
            SRow("Position") {
                SelectPill(selection: $settings.s.panelCorner, options: [(.topLeft, "Top left"), (.topRight, "Top right"), (.bottomLeft, "Bottom left"), (.bottomRight, "Bottom right")])
            }
            SSlider(title: "Opacity", value: $settings.s.panelOpacity, range: 0.5...1, step: 0.05, display: percent(settings.s.panelOpacity))
            SCheck("Show confidence level", isOn: $settings.s.showConfidence)
            SRow("Keep compact panel above other windows", "The full sidebar pairs with \(app) instead.", last: true) { sw($settings.s.keepPanelOnTop) }
        }
        SCard("Menu Bar") {
            SRow("Menu bar icon") {
                SelectPill(selection: $settings.s.menuBarIcon, options: [(.flame, "Flame"), (.waveform, "Waveform"), (.book, "Open book")])
            }
            SCheck("Show listening status in the menu bar", "The icon turns orange while Word Cue is listening.", isOn: $settings.s.menuBarShowsListening)
            SCheck("Show the waiting verse in the menu bar", last: true, isOn: $settings.s.menuBarShowsWaitingVerse)
        }
    }

    private func alignment(_ corner: PanelCorner) -> Alignment {
        switch corner {
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }
}

struct ShortcutsPanel: View {
    @Environment(AppModel.self) private var model
    private let rows: [(String, String, Bool)] = [("send", "Send", true), ("skip", "Skip", true), ("pause", "Pause or resume listening", true),
                                                  ("clear", "Clear screen", true), ("resend", "Resend last verse", true),
                                                  ("compact", "Switch compact / full", false)]

    var body: some View {
        @Bindable var settings = model.settings
        let app = settings.s.presentationApp.displayName
        SCard("Service Shortcuts") {
            HStack {
                Text("Action").frame(maxWidth: .infinity, alignment: .leading)
                Text("In Word Cue").frame(width: 74)
                Text("Anywhere").frame(width: 74)
            }
            .font(.system(size: 9.5)).foregroundStyle(Theme.dim)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
            ForEach(rows, id: \.0) { key, label, anywhere in
                HStack {
                    Text(label).font(.system(size: 10.5, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading)
                    KeyRecorder(text: Binding(get: { settings.s.shortcuts[key] ?? "" }, set: { settings.s.shortcuts[key] = $0 })).frame(width: 74)
                    Group {
                        if anywhere, let combo = KeyCombo(settings.s.shortcuts[key] ?? "") {
                            KeyCap(text: combo.anywhere.symbol).opacity(settings.s.anywhereShortcuts ? 1 : 0.35)
                        } else {
                            Text("\u{2014}").foregroundStyle(Theme.faint)
                        }
                    }
                    .frame(width: 74)
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair).frame(height: 1) }
            }
            HStack {
                Text("Show or hide Word Cue").font(.system(size: 10.5, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading)
                Text("\u{2014}").foregroundStyle(Theme.faint).frame(width: 74)
                KeyCap(text: "\u{2325}\u{2318}W").opacity(settings.s.anywhereShortcuts ? 1 : 0.35).frame(width: 74)
            }
            .padding(.vertical, 6)
        }
        SCard("Anywhere Shortcuts") {
            SRow("Shortcuts work while \(app) is in front",
                 "Uses the \u{201C}Anywhere\u{201D} keys, which include \u{2303}\u{2325} so typing in \(app) is never affected.", symbol: "keyboard", last: true) {
                sw($settings.s.anywhereShortcuts)
            }
        }
        Button("Reset to Defaults") { settings.s.shortcuts = WordCueSettings.defaultShortcuts }.buttonStyle(PillButtonStyle())
        note("Click a key in the In Word Cue column, then press the new one. Undo a file drop is Command-Z.")
    }
}

/// A key cap you click, then press a key to record it as the shortcut.
struct KeyRecorder: View {
    @Binding var text: String
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            KeyCap(text: recording ? "\u{2026}" : (KeyCombo(text)?.symbol ?? "None"))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(recording ? Theme.orange : Color.clear))
        }
        .buttonStyle(.plain)
        .help("Click, then press the new key")
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let names: [UInt16: String] = [36: "return", 53: "escape", 49: "space", 51: "delete", 123: "left", 124: "right", 125: "down", 126: "up", 121: "pagedown", 116: "pageup"]
            let key = names[event.keyCode] ?? (event.charactersIgnoringModifiers ?? "").lowercased()
            guard !key.isEmpty else { return nil }
            var combo = ""
            if event.modifierFlags.contains(.control) { combo += "ctrl+" }
            if event.modifierFlags.contains(.option) { combo += "opt+" }
            if event.modifierFlags.contains(.shift) { combo += "shift+" }
            if event.modifierFlags.contains(.command) { combo += "cmd+" }
            text = combo + key
            stop()
            return nil      // swallow the key so it does not also trigger something
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}

struct FiltersPanel: View {
    @Environment(AppModel.self) private var model
    @State private var newPhrase = ""
    @State private var addingPhrase = false

    var body: some View {
        @Bindable var settings = model.settings
        SCard("Book Names That Are Common Words") {
            SRow("Require a chapter number", "Words like \u{201C}mark my words\u{201D} or \u{201C}acts of kindness\u{201D} won\u{2019}t trigger a verse unless a chapter follows.",
                 symbol: "book", last: true) { sw($settings.s.requireChapterEnabled) }
            FlowLayout {
                ForEach(settings.s.requireChapterBooks, id: \.self) { id in
                    Chip(text: model.engine.book(id)?.name ?? id) { settings.s.requireChapterBooks.removeAll { $0 == id } }
                }
                bookMenu("Edit List", $settings.s.requireChapterBooks)
            }
            .padding(.bottom, 10)
        }
        SCard("Ignored Phrases") {
            VStack(alignment: .leading, spacing: 8) {
                note("Phrases that should never trigger a verse.")
                if settings.s.ignoredPhrases.isEmpty { note("No ignored phrases yet") }
                FlowLayout {
                    ForEach(settings.s.ignoredPhrases, id: \.self) { phrase in
                        Chip(text: phrase) { settings.s.ignoredPhrases.removeAll { $0 == phrase } }
                    }
                    if addingPhrase {
                        TextField("Phrase", text: $newPhrase)
                            .textFieldStyle(.plain).font(.system(size: 10)).frame(width: 160)
                            .padding(.horizontal, 9).padding(.vertical, 3).background(Theme.raise2, in: Capsule())
                            .onSubmit {
                                let p = newPhrase.trimmingCharacters(in: .whitespaces)
                                if !p.isEmpty && !settings.s.ignoredPhrases.contains(p) { settings.s.ignoredPhrases.append(p) }
                                newPhrase = ""
                                addingPhrase = false
                            }
                    } else {
                        Button { addingPhrase = true } label: { Chip(text: "Add Phrase") }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 10)
        }
        SCard("Ignored Books") {
            VStack(alignment: .leading, spacing: 8) {
                note("Books Word Cue should skip entirely.")
                if settings.s.ignoredBooks.isEmpty { note("No books ignored") }
                FlowLayout {
                    ForEach(settings.s.ignoredBooks, id: \.self) { id in
                        Chip(text: model.engine.book(id)?.name ?? id) { settings.s.ignoredBooks.removeAll { $0 == id } }
                    }
                    bookMenu("Choose Books\u{2026}", $settings.s.ignoredBooks)
                }
            }
            .padding(.vertical, 10)
        }
        SCard("Repeats") {
            SSlider(title: "Duplicate cooldown",
                    value: Binding(get: { Double(settings.s.duplicateCooldownSeconds) }, set: { settings.s.duplicateCooldownSeconds = Int($0) }),
                    range: 0...300, step: 15, display: "\(settings.s.duplicateCooldownSeconds) s",
                    note: "The same verse won\u{2019}t appear again within this time.", last: true)
        }
    }

    /// A pill that opens the list of books not yet chosen.
    private func bookMenu(_ title: String, _ ids: Binding<[String]>) -> some View {
        Menu {
            ForEach(model.engine.books.filter { !ids.wrappedValue.contains($0.id) }, id: \.id) { b in
                Button(b.name) { ids.wrappedValue.append(b.id) }
            }
        } label: { Chip(text: title) }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - System

struct AdvancedPanel: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false
    @State private var message = ""

    var body: some View {
        @Bindable var settings = model.settings
        SCard("Audio Engine") {
            SRow("Buffer size", "Lower delay responds faster; More stable avoids dropouts on busy Macs.", symbol: "gearshape", tint: .blue, last: true) {
                SelectPill(selection: $settings.s.bufferSize, options: [(.lowerDelay, "Lower delay"), (.balanced, "Balanced"), (.moreStable, "More stable")])
            }
        }
        SCard("Speech Model") {
            SRow("On-device model", "Downloaded once and kept up to date by macOS.", symbol: "text.bubble", tint: .green, last: true) {
                dot(model.permissions.speech ? "Ready" : "Not allowed", model.permissions.speech ? Theme.green : Theme.amber)
            }
        }
        SCard("Diagnostics") {
            SRow("Debug logging", "Saves detection details to help troubleshoot missed verses.", symbol: "ant") { sw($settings.s.debugLogging) }
            SRow("Logs", symbol: "folder", tint: .neutral) {
                Button("Open Logs Folder") { NSWorkspace.shared.open(DebugLog.folder) }.buttonStyle(PillButtonStyle())
            }
            SRow("Diagnostics report", message.isEmpty ? "For support requests. Contains no audio or transcripts." : message,
                 symbol: "arrow.down.to.line", tint: .neutral, last: true) {
                Button("Export\u{2026}") {
                    let report = FeedbackReporter.build(kind: .other, note: "Diagnostics report", email: "", includeDiagnostics: true, settings: settings.s)
                    if let url = try? FeedbackReporter.save(report, name: "Diagnostics") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                        message = "Saved. It contains no audio or transcripts."
                    }
                }
                .buttonStyle(PillButtonStyle())
            }
        }
        SCard("Connection Override") {
            SRow("Use a custom connection", "For unusual setups only. Leave off for normal use.", symbol: "powerplug", tint: .purple) {
                sw($settings.s.useCustomConnection)
            }
            HStack(alignment: .top, spacing: 10) {
                field("Host", TextField("", text: $settings.s.host, prompt: Text("127.0.0.1")))
                field("Port", TextField("", value: $settings.s.port, format: .number.grouping(.never), prompt: Text(String(settings.s.presentationApp.defaultPort))))
                    .frame(width: 80)
                field("API password, if any", SecureField("", text: $settings.s.apiPassword))
            }
            .padding(.vertical, 8)
            .disabled(!settings.s.useCustomConnection)
            .opacity(settings.s.useCustomConnection ? 1 : 0.5)
        }
        SCard("Reset") {
            SRow("Reset all settings", "Returns every setting to its default. This can\u{2019}t be undone.", symbol: "arrow.counterclockwise", tint: .neutral, last: true) {
                Button("Reset\u{2026}") { confirmReset = true }.buttonStyle(PillButtonStyle(kind: .danger))
            }
        }
        .confirmationDialog("Return every setting to its default? This can\u{2019}t be undone.", isPresented: $confirmReset) {
            Button("Reset All Settings", role: .destructive) { model.settings.reset() }
        }
    }

    private func field<F: View>(_ label: String, _ control: F) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9.5)).foregroundStyle(Theme.dim)
            control.textFieldStyle(.plain).font(.system(size: 10.5))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.window, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hair))
                .accessibilityLabel(label)
        }
    }
}

struct SupportPanel: View {
    @Environment(AppModel.self) private var model
    @State private var kind: FeedbackReporter.Kind = .bug
    @State private var feedback = ""
    @State private var includeDiagnostics = false
    @State private var result = ""
    @State private var exporting = false
    @State private var importing = false

    var body: some View {
        @Bindable var settings = model.settings
        let app = settings.s.presentationApp.displayName
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: "flame.fill", tint: .orange, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text("Word Cue").font(.system(size: 13, weight: .bold))
                    Text("by Fresh Fire Studios").font(.system(size: 8.5, weight: .bold)).foregroundStyle(Theme.amber)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.amber.opacity(0.5)))
                }
                note("Built for local churches. Questions, bugs, or ideas are always welcome.")
                HStack(spacing: 8) {
                    Button("Contact Fresh Fire Studios") { open("https://freshfirestudios.github.io/word-cue/") }.buttonStyle(PillButtonStyle(kind: .primary))
                    Button("Setup Guides") { open("https://freshfirestudios.github.io/word-cue/") }.buttonStyle(PillButtonStyle())
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 9))

        SCard("Permissions") {
            SRow("Microphone", "Required to receive audio from your soundboard\u{2019}s USB interface. macOS treats every audio input as a microphone.",
                 symbol: "mic", tint: .green) { permission(model.permissions.microphone, "Privacy_Microphone") }
            SRow("Speech Recognition", "Required to transcribe the sermon on this Mac.", symbol: "text.bubble", tint: .green) {
                permission(model.permissions.speech, "Privacy_SpeechRecognition")
            }
            SRow("Accessibility", "Only needed for keyboard-shortcut fallback, pairing, or snapping.", symbol: "figure.stand", tint: .neutral) {
                if model.permissions.accessibility { dot("Granted") }
                else if settings.s.presentationApp.hasAPI && settings.s.connectionMethod == .apiOnly { Text("Not needed").font(.system(size: 10)).foregroundStyle(Theme.dim) }
                else { Button("Allow\u{2026}") { KeyboardAdapter.requestPermission() }.buttonStyle(PillButtonStyle()) }
            }
            SRow("Notifications", "Optional. Alerts you if audio or \(app) drops while Word Cue is hidden.", symbol: "bell", tint: .neutral, last: true) {
                if model.permissions.notifications { dot("Granted") }
                else { Button("Turn On") { Task { _ = await SystemIntegration.requestNotifications(); model.refreshPermissions() } }.buttonStyle(PillButtonStyle()) }
            }
        }
        SCard("Send Feedback") {
            SRow("Type") {
                Segmented(selection: $kind, options: [(.bug, "Bug"), (.feature, "Feature Request"), (.other, "Other")])
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $feedback).font(.system(size: 10.5)).scrollContentBackground(.hidden).frame(height: 56)
                    .accessibilityLabel("Your feedback")
                if feedback.isEmpty {
                    Text("What happened, or what would you like to see?").font(.system(size: 10.5)).foregroundStyle(Theme.faint)
                        .padding(.leading, 5).allowsHitTesting(false)
                }
            }
            .padding(6)
            .background(Theme.window, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hair))
            .padding(.vertical, 8)
            SRow("Email (optional)", "Only if you\u{2019}d like a reply.") {
                TextField("", text: $settings.s.feedbackEmail, prompt: Text("name@church.org"))
                    .textFieldStyle(.plain).font(.system(size: 10.5)).frame(width: 150)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.window, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hair))
                    .accessibilityLabel("Email for a reply")
            }
            SCheck("Include diagnostic info", "Settings and recent logs. Never includes audio or transcripts.", isOn: $includeDiagnostics)
            HStack(spacing: 10) {
                Button("Send Feedback") {
                    let report = FeedbackReporter.build(kind: kind, note: feedback, email: settings.s.feedbackEmail,
                                                        includeDiagnostics: includeDiagnostics, settings: settings.s)
                    Task { result = await FeedbackReporter.send(report) }
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                note(result)
            }
            .padding(.vertical, 8)
        }
        SCard("Updates") {
            SRow("Current version", "Version \(Updater.shared.currentVersion)", symbol: "checkmark.seal", tint: .green) {
                if Updater.shared.isAvailable { dot("Up to date") } else { Text("Updates not set up").font(.system(size: 10)).foregroundStyle(Theme.dim) }
            }
            SRow("Update channel", symbol: "arrow.triangle.branch", tint: .blue) {
                SelectPill(selection: $settings.s.updateChannel, options: [(.stable, "Stable"), (.beta, "Beta")])
            }
            SRow("Check for updates", "Never installs during a service.", symbol: "arrow.clockwise") {
                Button("Check Now") { Updater.shared.checkNow() }.buttonStyle(PillButtonStyle()).disabled(!Updater.shared.isAvailable)
            }
            SRow("Automatic updates", "Checks in the background. Never installs during a service.", symbol: "gearshape.2", tint: .purple, last: true) {
                sw($settings.s.automaticUpdates)
            }
        }
        SCard("Backup") {
            SRow("Export settings", "Save your settings to set up another church\u{2019}s Mac.", symbol: "square.and.arrow.up", tint: .neutral) {
                Button("Export\u{2026}") { exporting = true }.buttonStyle(PillButtonStyle())
            }
            SRow("Import settings", "Load a settings file exported from Word Cue.", symbol: "square.and.arrow.down", tint: .neutral, last: true) {
                Button("Import\u{2026}") { importing = true }.buttonStyle(PillButtonStyle())
            }
        }
        .fileExporter(isPresented: $exporting, document: SettingsFile(settings: settings.s), contentType: .json, defaultFilename: "Word Cue Settings") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { picked in
            guard case .success(let url) = picked else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let imported = try? WordCueSettings.imported(data) {
                model.settings.s = imported
                result = "Settings imported."
            } else {
                result = "That file is not a Word Cue settings file."
            }
        }
    }

    private func open(_ address: String) {
        if let url = URL(string: address) { NSWorkspace.shared.open(url) }
    }

    @ViewBuilder
    private func permission(_ granted: Bool, _ pane: String) -> some View {
        if granted { dot("Granted") }
        else { Button("Open System Settings") { SystemIntegration.openPrivacySettings(pane) }.buttonStyle(PillButtonStyle()) }
    }
}

/// The exported settings file.
struct SettingsFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var settings: WordCueSettings

    init(settings: WordCueSettings) { self.settings = settings }

    init(configuration: ReadConfiguration) throws {
        settings = try WordCueSettings.imported(configuration.file.regularFileContents ?? Data())
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var s = settings
        s.apiPassword = ""      // never copy a password to another church's Mac
        s.feedbackEmail = ""
        return FileWrapper(regularFileWithContents: try s.exported())
    }
}
